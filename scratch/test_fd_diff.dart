import 'dart:io';

void main() async {
  final before = Directory('/proc/self/fd').listSync().map((e) => e.path).toList();
  
  // Simulate getting a new FD
  final f = await File('/dev/null').open();
  
  final after = Directory('/proc/self/fd').listSync().map((e) => e.path).toList();
  
  final newFds = after.where((e) => !before.contains(e)).toList();
  print("New FDs: $newFds");
}
