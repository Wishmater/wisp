import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fz_api_handling/fz_api_handling.dart';
import 'package:wisp/models/file_data.dart';

final disposeDelay = Duration(seconds: 15);

final currentDirectory = StateProvider<String>((ref) {
  return File('').absolute.path; // TODO: 1 this should probably come from args
});

void goUp(WidgetRef ref) {
  final state = ref.read(currentDirectory.state);
  state.state = File(state.state).parent.absolute.path;
}

void setCurrentDirectory(WidgetRef ref, String path) {
  ref.read(currentDirectory.state).state = path;
}

final ApiProviderFamily<FileData, String> fileDetails = ApiProviderFamily(
  (ref, path) {
    return ApiState(ref, (apiState) async {
      final file = File(path);
      final stat = await file.stat();
      return _getFileData(path, stat);
    });
  },
  disposeDelay: disposeDelay,
);

final ApiProviderFamily<List<FileData>, String> directoryList = ApiProviderFamily(
  (ref, path) {
    return ApiState(ref, (apiState) async {
      final directory = Directory(path);
      // TODO: 2 maybe we could actually listen to the stream and paint the UI in multiple steps? that would be cool maybe?
      final list = <FileData>[];
      await for (final e in directory.list()) {
        final stat = await e.stat();
        list.add(_getFileData(e.absolute.path, stat));
      }
      return list;
    });
  },
  disposeDelay: disposeDelay,
);

FileData _getFileData(String path, FileStat stat) {
  return switch (stat.type) {
    FileSystemEntityType.directory => DirectoryData(
      path: path,
      size: stat.size,
    ),
    _ => FileData(
      path: path,
      size: stat.size,
    ),
    // TODO: 2 we should probably handle all cases
  };
}
