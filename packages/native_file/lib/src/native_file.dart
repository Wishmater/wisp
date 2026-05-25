import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:native_file/src/ffi/binding.dart';

import 'native_errno.dart';
import 'native_file_flags.dart';
import 'native_stat.dart';
import 'ffi/native_file_bindings.dart' as c;


class NativeFile {
  int _fd;

  NativeFile._(this._fd);

  NativeFile.fromFd(this._fd);

  factory NativeFile.open(
    String path,
    OpenFlags flags, {
    int mode = 0666,
  }) {
    final cPath = path.toNativeUtf8();
    try {
      final fd = bindings.open(cPath.cast<Char>(), flags.value, mode);
      throwOnError(fd, 'open($path)');
      return NativeFile._(fd);
    } finally {
      calloc.free(cPath);
    }
  }

  factory NativeFile.openAt(
    int dirFd,
    String path,
    OpenFlags flags, {
    int mode = 0666,
  }) {
    final cPath = path.toNativeUtf8();
    try {
      final fd = bindings.openat(dirFd, cPath.cast<Char>(), flags.value, mode);
      throwOnError(fd, 'openat($path)');
      return NativeFile._(fd);
    } finally {
      calloc.free(cPath);
    }
  }

  int get fd => _fd;

  int read(Uint8List buffer, {int? offset, int? count}) {
    final len = count ?? buffer.length - (offset ?? 0);
    final start = offset ?? 0;
    final ptr = calloc<Uint8>(len);
    try {
      final bytesRead = bindings.read(_fd, ptr.cast<Void>(), len);
      throwOnError(bytesRead, 'read');
      final result = ptr.asTypedList(bytesRead);
      buffer.setRange(start, start + bytesRead, result);
      return bytesRead;
    } finally {
      calloc.free(ptr);
    }
  }

  Uint8List readBytes(int count) {
    final buffer = Uint8List(count);
    final bytesRead = read(buffer, count: count);
    return Uint8List.sublistView(buffer, 0, bytesRead);
  }

  int pread(Uint8List buffer, int fileOffset, {int? offset, int? count}) {
    final len = count ?? buffer.length - (offset ?? 0);
    final start = offset ?? 0;
    final ptr = calloc<Uint8>(len);
    try {
      final bytesRead =
          bindings.pread(_fd, ptr.cast<Void>(), len, fileOffset);
      throwOnError(bytesRead, 'pread');
      final result = ptr.asTypedList(bytesRead);
      buffer.setRange(start, start + bytesRead, result);
      return bytesRead;
    } finally {
      calloc.free(ptr);
    }
  }

  int write(Uint8List buffer, {int? offset, int? count}) {
    final len = count ?? buffer.length - (offset ?? 0);
    final start = offset ?? 0;
    final ptr = calloc<Uint8>(len);
    try {
      ptr.asTypedList(len).setRange(0, len, buffer, start);
      final bytesWritten = bindings.write(_fd, ptr.cast<Void>(), len);
      throwOnError(bytesWritten, 'write');
      return bytesWritten;
    } finally {
      calloc.free(ptr);
    }
  }

  int pwrite(Uint8List buffer, int fileOffset, {int? offset, int? count}) {
    final len = count ?? buffer.length - (offset ?? 0);
    final start = offset ?? 0;
    final ptr = calloc<Uint8>(len);
    try {
      ptr.asTypedList(len).setRange(0, len, buffer, start);
      final bytesWritten =
          bindings.pwrite(_fd, ptr.cast<Void>(), len, fileOffset);
      throwOnError(bytesWritten, 'pwrite');
      return bytesWritten;
    } finally {
      calloc.free(ptr);
    }
  }

  int seek(int offset, {Whence whence = Whence.set}) {
    final result = bindings.lseek(_fd, offset, whence.value);
    throwOnError(result, 'lseek');
    return result;
  }

  void close() {
    bindings.close(_fd);
  }

  int copyFileRange(NativeFile dst, int count,
      {int? srcOffset, int? dstOffset, int flags = 0}) {
    Pointer<Long> pSrcOff = nullptr;
    Pointer<Long> pDstOff = nullptr;
    if (srcOffset != null) {
      pSrcOff = calloc<Long>()..value = srcOffset;
    }
    if (dstOffset != null) {
      pDstOff = calloc<Long>()..value = dstOffset;
    }
    try {
      final result =
          bindings.copy_file_range(_fd, pSrcOff, dst._fd, pDstOff, count, flags);
      throwOnError(result, 'copy_file_range');
      return result;
    } finally {
      if (srcOffset != null) calloc.free(pSrcOff);
      if (dstOffset != null) calloc.free(pDstOff);
    }
  }

  NativeStat stat() {
    final st = calloc<c.stat>();
    try {
      throwOnError(bindings.fstat(_fd, st), 'fstat');
      return NativeStat.fromRaw(st);
    } finally {
      calloc.free(st);
    }
  }

  void fsync() {
    throwOnError(bindings.fsync(_fd), 'fsync');
  }

  void fdatasync() {
    throwOnError(bindings.fdatasync(_fd), 'fdatasync');
  }

  void fallocate(int offset, int length, {int mode = 0}) {
    throwOnErrorWithResult(
      bindings.posix_fallocate(_fd, offset, length),
      'posix_fallocate',
    );
  }

  void ftruncate(int length) {
    throwOnError(bindings.ftruncate(_fd, length), 'ftruncate');
  }

  int dup() {
    final result = bindings.dup(_fd);
    throwOnError(result, 'dup');
    return result;
  }

  int dupTo(int targetFd) {
    final result = bindings.dup2(_fd, targetFd);
    throwOnError(result, 'dup2');
    return result;
  }

  int fcntl(int cmd, [int arg = 0]) {
    final result = bindings.fcntl(_fd, cmd, arg);
    throwOnError(result, 'fcntl');
    return result;
  }

  int getFdFlags() {
    return fcntl(fGetFD);
  }

  void setFdFlags(int flags) {
    fcntl(fSetFD, flags);
  }

  int getStatusFlags() {
    return fcntl(fGetFL);
  }

  void setStatusFlags(int flags) {
    fcntl(fSetFL, flags);
  }
}
