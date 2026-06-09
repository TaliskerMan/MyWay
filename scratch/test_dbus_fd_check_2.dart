import 'dart:io';

void main() async {
  // Test if we can see raw sockets in /proc/self/fd
  final fds1 = Directory('/proc/self/fd').listSync().map((e) => e.path).toList();
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final fds2 = Directory('/proc/self/fd').listSync().map((e) => e.path).toList();
  
  final newFds = fds2.where((e) => !fds1.contains(e)).toList();
  for (var p in newFds) {
    print("New FD: $p -> ${File(p).resolveSymbolicLinksSync()}");
  }
}
