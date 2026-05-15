import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_api_handling.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/services/dir_reader.dart';

final disposeDelay = Duration(seconds: 15);

final currentDirectory = NotifierProvider<CurrentDirectoryNotifier, String>(() {
  return CurrentDirectoryNotifier();
});

class CurrentDirectoryNotifier extends Notifier<String> {
  @override
  String build() {
    return File('').absolute.path; // TODO: 1 this should probably come from args
  }

  void goUp() {
    state = File(state).parent.absolute.path;
  }

  void setCurrentDirectory(String path) {
    state = path;
  }
}

// final mimedbFuture = SharedMimeInfo.open();
// final demFuture = DesktopEntryManager.create();
void openFile(FileData fileData) {}

final fileDetails = ApiProviderFamily<FileData, String>(
  (path) => ApiState(
    (apiState) async {
      final file = File(path);
      final stat = await file.stat();
      return FileData.fromStat(path, stat);
    },
    disposeDelay: disposeDelay,
  ),
);

final directoryList = ApiProviderFamily<List<FileData>, String>(
  (path) => ApiState(
    (apiState) async {
      final directory = Directory(path);
      // TODO: 2 maybe we could actually listen to the stream and paint the UI in multiple steps? that would be cool maybe?
      final stream = dirReader.readDir(directory);
      final response = await stream.toList();
      return response;
    },
    disposeDelay: disposeDelay,
  ),
);
