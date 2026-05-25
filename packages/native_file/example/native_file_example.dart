import 'dart:io';
import 'dart:typed_data';

import 'package:native_file/native_file.dart';

void main() {
  final tempDir = Directory.systemTemp.path;
  final filePath = '$tempDir/native_file_example.txt';

  final file = NativeFile.open(
    filePath,
    OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
    mode: 0644,
  );

  print('Opened file: $filePath');
  print('Fd: ${file.fd}');

  final data = Uint8List.fromList('Hello from native_file!'.codeUnits);
  final written = file.write(data);
  print('Wrote $written bytes');

  file.seek(0);

  final buffer = Uint8List(written);
  final read = file.read(buffer);
  print('Read $read bytes: ${String.fromCharCodes(buffer, 0, read)}');

  final st = file.stat();
  print('Stat: size=${st.size}, inode=${st.inode}, uid=${st.uid}, gid=${st.gid}');
  print('Type: ${st.fileTypeString}');
  print('Permissions: ${st.permissionsString} (0${st.mode.toRadixString(8)})');

  final flux = file.getStatusFlags();
  print('Status flags: $flux');

  file.close();
  print('Closed');

  File(filePath).deleteSync();
}
