import 'package:dbus/dbus.dart';

void main() async {
  final client = DBusClient.session();
  print("DBus Client connected.");
  client.close();
}
