import 'dart:io';
import 'package:dbus/dbus.dart';

void main() async {
  final client = DBusClient.session();
  final portalObj = DBusRemoteObject(client, name: 'org.freedesktop.portal.Desktop', path: DBusObjectPath('/org/freedesktop/portal/desktop'));
  final senderName = client.uniqueName.substring(1).replaceAll('.', '_');
  final token = 'myway_test_fd_debug';
  
  final reqPath = DBusObjectPath('/org/freedesktop/portal/desktop/request/$senderName/$token');
  final reqObj = DBusRemoteObject(client, name: 'org.freedesktop.portal.Desktop', path: reqPath);
  final stream = DBusRemoteObjectSignalStream(object: reqObj, interface: 'org.freedesktop.portal.Request', name: 'Response');
  
  var sub = stream.listen((signal) async {
     if (signal.values.length > 1) {
       final dict = signal.values[1] as DBusDict;
       var sessionHandle = "";
       dict.children.forEach((k, v) {
         if (k is DBusString && k.value == 'session_handle') {
           sessionHandle = (v as DBusVariant).value.asString();
         }
       });
       if (sessionHandle.isNotEmpty) {
           final before = Directory('/proc/self/fd').listSync().map((e) => e.path).toList();
           final res = await portalObj.callMethod('org.freedesktop.portal.ScreenCast', 'OpenPipeWireRemote', [
             DBusObjectPath(sessionHandle),
             DBusDict.stringVariant({})
           ], replySignature: DBusSignature('h'));
           
           final dbusFd = res.values[0] as DBusUnixFd;
           print("Got DBusUnixFd! Handle: ${dbusFd.handle}");
           
           final after = Directory('/proc/self/fd').listSync().map((e) => e.path).toList();
           
           final newFds = after.where((e) => !before.contains(e)).toList();
           print("New FDs: $newFds");
           for (var p in newFds) {
               print("New FD: $p -> ${File(p).resolveSymbolicLinksSync()}");
           }
           exit(0);
       }
     }
  });
  
  await portalObj.callMethod('org.freedesktop.portal.ScreenCast', 'CreateSession', [
    DBusDict.stringVariant({
      'session_handle_token': DBusString(token),
      'handle_token': DBusString(token)
    })
  ]);
  
  await Future.delayed(Duration(seconds: 4));
  client.close();
}
