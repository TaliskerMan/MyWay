import 'package:dbus/dbus.dart';
import 'dart:io';

void main() async {
  final client = DBusClient.session();
  final portalObj = DBusRemoteObject(client, name: 'org.freedesktop.portal.Desktop', path: DBusObjectPath('/org/freedesktop/portal/desktop'));
  final senderName = client.uniqueName.substring(1).replaceAll('.', '_');
  final token = 'myway_test_fd_proc';
  
  final reqPath = DBusObjectPath('/org/freedesktop/portal/desktop/request/$senderName/$token');
  final reqObj = DBusRemoteObject(client, name: 'org.freedesktop.portal.Desktop', path: reqPath);
  final stream = DBusRemoteObjectSignalStream(object: reqObj, interface: 'org.freedesktop.portal.Request', name: 'Response');
  
  var sub = stream.listen((signal) async {
     if (signal.values.length > 1) {
       final dict = signal.values[1] as DBusDict;
       var sessionHandle = "";
       dict.children.forEach((k, v) {
         if (k is DBusString && k.k == 'session_handle') {
           // wait, k.value is the way to get string
         }
       });
     }
  });
  // Too complex to do the full dance in dart just to test. I will just test what happens if I list /proc/self/fd
}
