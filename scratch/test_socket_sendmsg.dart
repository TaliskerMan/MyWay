import 'dart:io';

void main() async {
  final s = await RawSocket.connect(InternetAddress('127.0.0.1'), 80);
  // How do we send SocketControlMessage?
  s.sendMessage([1], InternetAddress('127.0.0.1'), 80);
}
