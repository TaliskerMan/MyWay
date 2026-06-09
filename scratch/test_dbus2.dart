import 'package:dbus/dbus.dart';

void main() async {
  final client = DBusClient.session();
  print("Before: '${client.uniqueName}'");
  
  final dbusObj = DBusRemoteObject(
    client,
    name: 'org.freedesktop.DBus',
    path: DBusObjectPath('/org/freedesktop/DBus'),
  );
  
  await dbusObj.callMethod(
    'org.freedesktop.DBus',
    'GetId',
    [],
    replySignature: DBusSignature('s'),
  );
  
  print("After: '${client.uniqueName}'");
  await client.close();
}
