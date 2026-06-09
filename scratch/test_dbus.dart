import 'package:dbus/dbus.dart';

void main() async {
  final client = DBusClient.session();
  final obj = DBusRemoteObject(client, name: 'org.freedesktop.DBus', path: DBusObjectPath('/org/freedesktop/DBus'));
  final res = await obj.callMethod('org.freedesktop.DBus', 'Hello', []);
  print(res.values[0]);
  await client.close();
}
