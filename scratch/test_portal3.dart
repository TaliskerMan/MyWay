import 'package:dbus/dbus.dart';

void main() async {
  final dict = DBusDict.stringVariant({'session_handle': DBusString('foo')});
  dict.children.forEach((key, val) {
    print("key type: ${key.runtimeType}");
    print("val type: ${val.runtimeType}");
    print("val: $val");
    if (val is DBusVariant) {
       print("Variant child type: ${val.value.runtimeType}");
    }
  });
}
