import 'dart:io';
void main() async {
  File f = File('/dev/null');
  var raf = await f.open();
  print("has fd? ${raf.fd}");
}
