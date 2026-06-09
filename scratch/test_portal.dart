import 'package:dbus/dbus.dart';

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
  
  print("Listening on $reqPath");
  stream.listen((signal) {
     print("Got signal: ${signal.values}");
     client.close();
  });
  
  final res = await portalObj.callMethod('org.freedesktop.portal.ScreenCast', 'CreateSession', [
    DBusDict.stringVariant({'session_handle_token': DBusString(token)})
  ]);
  
  print("CreateSession returned: ${res.values}");
  await Future.delayed(Duration(seconds: 3));
  client.close();
}
