import 'dart:ffi';

import 'ffi/native_file_bindings.dart' as c;
import 'ffi/native_file_bindings.dart' show stat;

class NativeStat {
  final int device;
  final int inode;
  final int linkCount;
  final int mode;
  final int uid;
  final int gid;
  final int rdev;
  final int size;
  final int blockSize;
  final int blockCount;
  final DateTime accessTime;
  final DateTime modificationTime;
  final DateTime changeTime;

  NativeStat.fromRaw(Pointer<stat> s)
    : device = s.ref.st_dev,
      inode = s.ref.st_ino,
      linkCount = s.ref.st_nlink,
      mode = s.ref.st_mode,
      uid = s.ref.st_uid,
      gid = s.ref.st_gid,
      rdev = s.ref.st_rdev,
      size = s.ref.st_size,
      blockSize = s.ref.st_blksize,
      blockCount = s.ref.st_blocks,
      accessTime = DateTime.fromMillisecondsSinceEpoch(
        s.ref.st_atim.tv_sec * 1000 + s.ref.st_atim.tv_nsec ~/ 1000000,
      ),
      modificationTime = DateTime.fromMillisecondsSinceEpoch(
        s.ref.st_mtim.tv_sec * 1000 + s.ref.st_mtim.tv_nsec ~/ 1000000,
      ),
      changeTime = DateTime.fromMillisecondsSinceEpoch(
        s.ref.st_ctim.tv_sec * 1000 + s.ref.st_ctim.tv_nsec ~/ 1000000,
      );

  bool get isFile => (mode & c.S_IFMT) == c.S_IFREG;
  bool get isDirectory => (mode & c.S_IFMT) == c.S_IFDIR;
  bool get isSymlink => (mode & c.S_IFMT) == c.S_IFLNK;
  bool get isFifo => (mode & c.S_IFMT) == c.S_IFIFO;
  bool get isSocket => (mode & c.S_IFMT) == c.S_IFSOCK;
  bool get isCharDevice => (mode & c.S_IFMT) == c.S_IFCHR;
  bool get isBlockDevice => (mode & c.S_IFMT) == c.S_IFBLK;
  bool get isDevice => isCharDevice || isBlockDevice;

  String get fileTypeString {
    if (isFile) return 'regular file';
    if (isDirectory) return 'directory';
    if (isSymlink) return 'symlink';
    if (isFifo) return 'fifo';
    if (isSocket) return 'socket';
    if (isCharDevice) return 'character device';
    if (isBlockDevice) return 'block device';
    return 'unknown';
  }

  int get ownerPermissions => (mode >> 6) & 7;
  int get groupPermissions => (mode >> 3) & 7;
  int get otherPermissions => mode & 7;

  String get permissionsString {
    String rwx(int bits) {
      return '${(bits & 4) != 0 ? 'r' : '-'}'
          '${(bits & 2) != 0 ? 'w' : '-'}'
          '${(bits & 1) != 0 ? 'x' : '-'}';
    }

    return rwx(ownerPermissions) + rwx(groupPermissions) + rwx(otherPermissions);
  }

  @override
  String toString() {
    return 'NativeStat('
        'dev=$device, ino=$inode, mode=0${mode.toRadixString(8)}, '
        'uid=$uid, gid=$gid, size=$size, '
        'type=$fileTypeString, '
        'perms=$permissionsString'
        ')';
  }
}
