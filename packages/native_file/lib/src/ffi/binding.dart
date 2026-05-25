import 'dart:ffi';

import 'native_file_bindings.dart' as c;
final bindings = c.NativeFileBindings(DynamicLibrary.process());
