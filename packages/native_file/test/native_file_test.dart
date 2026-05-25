import 'dart:io';
import 'dart:typed_data';

import 'package:native_file/native_file.dart';
import 'package:test/test.dart';

String tmpPath(String name) =>
    '${Directory.systemTemp.path}/native_file_test_$name';

void main() {
  group('NativeFile', () {
    test('write and read bytes', () {
      final path = tmpPath('write_read');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final written = file.write(data);
      expect(written, equals(8));

      file.seek(0);

      final buffer = Uint8List(8);
      final read = file.read(buffer);
      expect(read, equals(8));
      expect(buffer, equals(data));

      file.close();
      File(path).deleteSync();
    });

    test('readBytes convenience method', () {
      final path = tmpPath('read_bytes');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      final data = Uint8List.fromList([10, 20, 30, 40]);
      file.write(data);
      file.seek(0);

      final read = file.readBytes(4);
      expect(read, equals(data));

      file.close();
      File(path).deleteSync();
    });

    test('seek operations', () {
      final path = tmpPath('seek');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      final data = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      file.write(data);

      file.seek(0, whence: Whence.set);
      final buf = Uint8List(3);
      file.read(buf);
      expect(buf, equals([0, 1, 2]));

      file.seek(2, whence: Whence.current);
      file.read(buf);
      expect(buf, equals([5, 6, 7]));

      file.seek(-2, whence: Whence.end);
      file.read(Uint8List(1));
      expect(buf[0], isNot(equals(0)));

      file.close();
      File(path).deleteSync();
    });

    test('pread and pwrite', () {
      final path = tmpPath('pread_pwrite');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      final data = Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]);
      final written = file.write(data);
      expect(written, equals(8));

      final buf = Uint8List(3);
      final read = file.pread(buf, 2);
      expect(read, equals(3));
      expect(buf, equals([30, 40, 50]));

      final pwriteData = Uint8List.fromList([99, 99]);
      final pw = file.pwrite(pwriteData, 4);
      expect(pw, equals(2));

      file.seek(0);
      final verify = Uint8List(8);
      file.read(verify);
      expect(verify, equals([10, 20, 30, 40, 99, 99, 70, 80]));

      file.close();
      File(path).deleteSync();
    });

    test('stat on regular file', () {
      final path = tmpPath('stat_test');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );
      file.write(Uint8List.fromList([1, 2, 3, 4]));
      file.seek(0);

      final st = file.stat();
      expect(st.isFile, isTrue);
      expect(st.isDirectory, isFalse);
      expect(st.isSymlink, isFalse);
      expect(st.size, equals(4));
      expect(st.uid, greaterThanOrEqualTo(0));
      expect(st.gid, greaterThanOrEqualTo(0));
      expect(st.inode, greaterThan(0));
      expect(st.device, greaterThan(0));

      file.close();
      File(path).deleteSync();
    });

    test('fallocate', () {
      final path = tmpPath('fallocate');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      file.fallocate(0, 4096);
      final st = file.stat();
      expect(st.size, greaterThanOrEqualTo(4096));

      file.close();
      File(path).deleteSync();
    });

    test('ftruncate', () {
      final path = tmpPath('ftruncate');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      file.write(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]));
      file.ftruncate(3);
      expect(file.stat().size, equals(3));

      file.close();
      File(path).deleteSync();
    });

    test('dup creates new fd', () {
      final path = tmpPath('dup');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );
      final newFd = file.dup();
      expect(newFd, isNot(equals(file.fd)));

      final file2 = NativeFile.fromFd(newFd);
      file2.close();

      file.close();
      File(path).deleteSync();
    });

    test('open non-existent file throws', () {
      expect(
        () => NativeFile.open(
          '/tmp/nonexistent_file_xyz123456',
          OpenFlags.readOnly,
        ),
        throwsA(isA<NativeErrnoException>()),
      );
    });

    test('fcntl getFdFlags and setFdFlags', () {
      final path = tmpPath('fcntl_fd');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      final flags = file.getFdFlags();
      expect(flags, greaterThanOrEqualTo(0));

      file.setFdFlags(fdCloseExec);
      expect(file.getFdFlags() & fdCloseExec, equals(fdCloseExec));

      file.setFdFlags(0);
      expect(file.getFdFlags() & fdCloseExec, equals(0));

      file.close();
      File(path).deleteSync();
    });

    test('fcntl getStatusFlags', () {
      final path = tmpPath('fcntl_fl');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );

      final flags = file.getStatusFlags();
      final modeMask = flags & accessModeMask;
      expect(
        modeMask,
        anyOf(OpenFlags.readOnly.value, OpenFlags.writeOnly.value,
            OpenFlags.readWrite.value),
      );

      file.close();
      File(path).deleteSync();
    });

    test('openAt with AT_FDCWD', () {
      final path = tmpPath('openat');
      final file = NativeFile.openAt(
        atFdCwd,
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );
      file.close();
      File(path).deleteSync();
    });
  });

  group('Flags', () {
    test('| operator', () {
      expect(OpenFlags.create | OpenFlags.writeOnly, equals(OpenFlags(65)));
    });
  });

  group('NativeStat', () {
    test('constructs from raw stat', () {
      final path = tmpPath('stat_raw');
      final file = NativeFile.open(
        path,
        OpenFlags.readWrite | OpenFlags.create | OpenFlags.truncate,
      );
      file.write(Uint8List.fromList([1, 2, 3]));
      file.seek(0);

      final st = file.stat();
      expect(st.fileTypeString, contains('regular file'));
      expect(st.size, equals(3));
      expect(st.permissionsString.length, equals(9));

      file.close();
      File(path).deleteSync();
    });
  });
}
