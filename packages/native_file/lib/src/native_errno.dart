import 'dart:ffi';
import 'package:ffi/ffi.dart' show Utf8, Utf8Pointer;

import 'package:native_file/src/ffi/binding.dart';

int getCurrentErrno() => bindings.errno_location().value;

class NativeErrnoException implements Exception {
  final int errno;
  final String message;
  final String syscall;

  NativeErrnoException(this.syscall, this.errno)
    : message = '$syscall failed: ${bindings.strerror(errno).cast<Utf8>().toDartString()}';

  @override
  String toString() => message;
}

void throwOnError(int result, String syscall) {
  if (result == -1) {
    throw NativeErrnoException(syscall, getCurrentErrno());
  }
}

void throwOnErrorWithResult(int result, String syscall) {
  if (result != 0) {
    throw NativeErrnoException(syscall, result);
  }
}
