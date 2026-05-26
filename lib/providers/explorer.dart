import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisp/models/file_data_field.dart';

final currentDirectory = NotifierProvider<CurrentDirectoryNotifier, String>(() {
  return CurrentDirectoryNotifier();
});

class CurrentDirectoryNotifier extends Notifier<String> {
  @override
  String build() {
    return File('').absolute.path; // TODO: 1 this should probably come from args
    return '/nix/var/nix/profiles/';
  }

  void goUp() {
    state = File(state).parent.absolute.path;
  }

  void setCurrentDirectory(String path) {
    state = path;
  }
}

typedef FileSort = (FileDataField field, bool asc);
final currentSort = NotifierProvider<FileSortNotifier, FileSort>(() {
  return FileSortNotifier();
});

class FileSortNotifier extends Notifier<FileSort> {
  @override
  FileSort build() {
    return (FileDataField.filename, true);
  }

  void setField(FileDataField value) {
    if (value == state.$1) {
      state = (value, !state.$2);
    } else {
      state = (value, true);
    }
  }
}
