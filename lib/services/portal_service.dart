import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:dbus/dbus.dart';
import 'capture_service.dart';
import 'log_service.dart';

/// Builds a per-user, unpredictable path for the FD hand-off UNIX socket.
///
/// Prefers `XDG_RUNTIME_DIR` (per-user, mode 0700); falls back to
/// `/run/user/<uid>` and finally `/tmp` only if neither is available.
String _fdSocketPath() {
  String? base = Platform.environment['XDG_RUNTIME_DIR'];
  if (base == null || base.isEmpty) {
    final uid = Platform.environment['UID'];
    final candidate = uid != null ? '/run/user/$uid' : null;
    if (candidate != null && Directory(candidate).existsSync()) {
      base = candidate;
    } else {
      base = '/tmp'; // last resort; the C side still chmod 0600s the socket
    }
  }
  final rnd = Random.secure();
  final token =
      List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '$base/myway_fd_${pid}_$token.sock';
}

/// Struct holding the returned PipeWire stream node ID and extracted file descriptor.
class PortalResult {
  final int nodeId;
  final int fd;
  PortalResult(this.nodeId, this.fd);
}

/// Service coordinating DBus Desktop Portals for Wayland screen captures.
///
/// Handles session creation, display selection prompts, and PipeWire stream file descriptor extraction.
class PortalService {
  final DBusClient _client = DBusClient.session();

  /// Closes the underlying session DBus connection.
  Future<void> close() async {
    await _client.close();
  }

  // Helper to parse D-Bus dictionaries into string-indexed maps
  Map<String, DBusValue> _parseDict(DBusDict dict) {
    final result = <String, DBusValue>{};
    dict.children.forEach((key, val) {
      if (key is DBusString) {
        if (val is DBusVariant) {
          result[key.value] = val.value;
        } else {
          result[key.value] = val;
        }
      }
    });
    return result;
  }

  // Helper that waits for the async 'Response' signal on the Request object path
  Future<Map<String, DBusValue>> _waitForResponse(
    DBusObjectPath requestPath,
  ) async {
    final completer = Completer<Map<String, DBusValue>>();

    final requestObject = DBusRemoteObject(
      _client,
      name: 'org.freedesktop.portal.Desktop',
      path: requestPath,
    );

    final subscription = DBusRemoteObjectSignalStream(
      object: requestObject,
      interface: 'org.freedesktop.portal.Request',
      name: 'Response',
    );

    StreamSubscription? sub;
    sub = subscription.listen(
      (signal) {
        if (signal.values.length >= 2) {
          final responseCode = (signal.values[0] as DBusUint32).value;
          final results = signal.values[1] as DBusDict;

          if (responseCode == 0) {
            completer.complete(_parseDict(results));
          } else {
            completer.completeError(
              Exception(
                "Portal request failed or cancelled by user (code: $responseCode)",
              ),
            );
          }
        } else {
          completer.completeError(Exception("Malformed portal response"));
        }
        sub?.cancel();
      },
      onError: (e) {
        completer.completeError(e);
        sub?.cancel();
      },
    );

    return completer.future;
  }

  // Executes the ScreenCast portal orchestration flow to get the PipeWire video node ID and FD
  /// Runs the full org.freedesktop.portal.ScreenCast DBus orchestration pipeline.
  ///
  /// Requests screen-sharing authorization, waits for user selection signals,
  /// opens the PipeWire remote handle, and extracts the UNIX file descriptor
  /// using SCM_RIGHTS socket messages.
  /// Returns true if the `org.freedesktop.portal.ScreenCast` interface is
  /// present (a portal backend is installed and running for this session).
  Future<bool> isScreenCastPortalAvailable() async {
    try {
      final obj = DBusRemoteObject(
        _client,
        name: 'org.freedesktop.portal.Desktop',
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
      );
      final v = await obj.getProperty(
        'org.freedesktop.portal.ScreenCast',
        'version',
        signature: DBusSignature('u'),
      );
      return v is DBusUint32 && v.value >= 1;
    } catch (_) {
      return false;
    }
  }

  Future<PortalResult> obtainVideoNodeId() async {
    // Detect up front whether a ScreenCast portal backend is actually present,
    // so a non-portal session (e.g. plain X11, or a compositor without
    // xdg-desktop-portal) gets a clear message instead of failing deep inside
    // the portal call.
    if (!await isScreenCastPortalAvailable()) {
      throw Exception(
          'Screen recording requires xdg-desktop-portal with a ScreenCast '
          'backend (e.g. xdg-desktop-portal-gnome) on a Wayland session. It '
          'does not appear to be available here. On X11, use window/area '
          'capture instead of full-screen portal capture.');
    }

    final portalObj = DBusRemoteObject(
      _client,
      name: 'org.freedesktop.portal.Desktop',
      path: DBusObjectPath('/org/freedesktop/portal/desktop'),
    );

    // Warm up the DBus client connection to populate _client.uniqueName
    if (_client.uniqueName.isEmpty) {
      final dbusObj = DBusRemoteObject(
        _client,
        name: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
      );
      await dbusObj.callMethod(
        'org.freedesktop.DBus',
        'GetId',
        [],
        replySignature: DBusSignature('s'),
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final senderName = _client.uniqueName.replaceFirst(':', '').replaceAll('.', '_');

    // Step 1: Create Session
    final sessionToken = 'myway_session_$timestamp';
    final createRequestPath = DBusObjectPath('/org/freedesktop/portal/desktop/request/$senderName/$sessionToken');
    final createResponseFuture = _waitForResponse(createRequestPath);

    await portalObj.callMethod(
      'org.freedesktop.portal.ScreenCast',
      'CreateSession',
      [
        DBusDict.stringVariant({
          'session_handle_token': DBusString(sessionToken),
          'handle_token': DBusString(sessionToken),
        }),
      ],
      replySignature: DBusSignature('o'),
    );

    final createResults = await createResponseFuture;
    final sessionHandleVal = createResults['session_handle'];
    if (sessionHandleVal == null || sessionHandleVal is! DBusString) {
      throw Exception(
        "Failed to retrieve session handle from ScreenCast portal",
      );
    }
    final sessionHandle = sessionHandleVal.value;
    LogService().logInfo("MyWay Portal: Created Session: $sessionHandle");

    // Step 2: Select Sources
    final selectToken = 'myway_select_$timestamp';
    final selectRequestPath = DBusObjectPath('/org/freedesktop/portal/desktop/request/$senderName/$selectToken');
    final selectResponseFuture = _waitForResponse(selectRequestPath);

    await portalObj.callMethod(
      'org.freedesktop.portal.ScreenCast',
      'SelectSources',
      [
        DBusObjectPath(sessionHandle),
        DBusDict.stringVariant({
          'types': DBusUint32(3), // 1 = Screen, 2 = Window, 3 = Both
          'multiple': DBusBoolean(false),
          'cursor_mode': DBusUint32(2), // 2 = Embedded cursor
          'handle_token': DBusString(selectToken),
        }),
      ],
      replySignature: DBusSignature('o'),
    );

    await selectResponseFuture;
    LogService().logInfo("MyWay Portal: Sources selected successfully");

    // Step 3: Start Session
    final startToken = 'myway_start_$timestamp';
    final startRequestPath = DBusObjectPath('/org/freedesktop/portal/desktop/request/$senderName/$startToken');
    final startResponseFuture = _waitForResponse(startRequestPath);

    await portalObj.callMethod(
      'org.freedesktop.portal.ScreenCast',
      'Start',
      [
        DBusObjectPath(sessionHandle),
        DBusString(''), // parent_window (none)
        DBusDict.stringVariant({'handle_token': DBusString(startToken)}),
      ],
      replySignature: DBusSignature('o'),
    );

    final startResults = await startResponseFuture;

    final streamsVal = startResults['streams'];
    if (streamsVal == null || streamsVal is! DBusArray) {
      throw Exception("No streams returned by ScreenCast portal");
    }

    final streamsArray = streamsVal.children;
    if (streamsArray.isEmpty) {
      throw Exception("ScreenCast portal returned an empty list of streams");
    }

    // A stream structure is (uint32 stream_id, dict properties)
    final firstStream = streamsArray.first as DBusStruct;
    final nodeId = (firstStream.children[0] as DBusUint32).value;
    LogService().logInfo(
      "MyWay Portal: Obtained PipeWire Video Node ID: $nodeId",
    );

    // Step 4: Open PipeWire Remote to get the file descriptor
    final fdResponse = await portalObj.callMethod(
      'org.freedesktop.portal.ScreenCast',
      'OpenPipeWireRemote',
      [
        DBusObjectPath(sessionHandle),
        DBusDict.stringVariant({}),
      ],
      replySignature: DBusSignature('h'),
    );

    final dbusFd = fdResponse.values[0] as DBusUnixFd;

    // Use a UNIX socket to hand the screen-capture FD to the C layer.
    // Security: place it in the per-user XDG_RUNTIME_DIR (mode 0700, owned by
    // this user) rather than the world-writable /tmp, and use an unpredictable
    // random name. The C binder additionally chmod()s the socket to 0600.
    final sockPath = _fdSocketPath();
    CaptureService().setupFdExtraction(sockPath);

    int fd = -1;
    try {
      final socket = await RawSocket.connect(
        InternetAddress(sockPath, type: InternetAddressType.unix), 
        0
      );
      final controlMessage = SocketControlMessage.fromHandles([dbusFd.handle]);
      socket.sendMessage([controlMessage], [1]);
      await socket.close();

      fd = CaptureService().readExtractedFd();
      LogService().logInfo("MyWay Portal: Successfully extracted PipeWire FD: $fd via SCM_RIGHTS");
    } catch (e) {
      LogService().logError("MyWay Portal: Failed to extract FD: $e");
    }

    if (fd == -1) {
       LogService().logError("MyWay Portal: Extracted FD was -1!");
    }

    // Keep a reference to the response so the DBusUnixFd isn't garbage collected 
    // and its ResourceHandle isn't closed before we start the capture
    _lastFdResponse = fdResponse;

    return PortalResult(nodeId, fd);
  }
  
  /// Reference holding the last DBus descriptor response to prevent early garbage collection.
  // ignore: unused_field
  dynamic _lastFdResponse;
}
