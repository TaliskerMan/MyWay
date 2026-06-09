import 'package:dbus/dbus.dart';
import 'dart:io';

void main() async {
  final client = DBusClient.session();
  final dbusObj = DBusRemoteObject(client, name: 'org.freedesktop.DBus', path: DBusObjectPath('/org/freedesktop/DBus'));
  await dbusObj.callMethod('org.freedesktop.DBus', 'GetId', [], replySignature: DBusSignature('s'));
  
  final portalObj = DBusRemoteObject(client, name: 'org.freedesktop.portal.Desktop', path: DBusObjectPath('/org/freedesktop/portal/desktop'));
  final senderName = client.uniqueName.substring(1).replaceAll('.', '_');
  final token = 'myway_test_123';
  
  final reqPath = DBusObjectPath('/org/freedesktop/portal/desktop/request/$senderName/$token');
  final reqObj = DBusRemoteObject(client, name: 'org.freedesktop.portal.Desktop', path: reqPath);
  final stream = DBusRemoteObjectSignalStream(object: reqObj, interface: 'org.freedesktop.portal.Request', name: 'Response');
  
  var sub = stream.listen((signal) async {
     print("Got signal: ${signal.values}");
     if (signal.values.length > 1) {
       final dict = signal.values[1] as DBusDict;
       var sessionHandle = "";
       dict.children.forEach((k, v) {
         if (k is DBusString && k.value == 'session_handle') {
           sessionHandle = (v as DBusVariant).value.asString();
         }
       });
       print("Session handle: $sessionHandle");
       
       if (sessionHandle.isNotEmpty) {
           final res = await portalObj.callMethod('org.freedesktop.portal.ScreenCast', 'OpenPipeWireRemote', [
             DBusObjectPath(sessionHandle),
             DBusDict.stringVariant({})
           ], replySignature: DBusSignature('h'));
           print("OpenPipeWireRemote returned: ${res.values}");
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
