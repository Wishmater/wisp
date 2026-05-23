import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_api_handling.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/services/dir_reader.dart';
import 'package:wisp/services/xdg_mime.dart';
import 'package:xdg_mime/xdg_mime.dart';

final disposeDelay = Duration(seconds: 30);

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
    }
    state = (value, true);
  }
}

bool openFile(FileData fileData) {
  // TODO: 1 should this go get the typeData if it's not loaded yet? or should the UI delay the call to here until it is loaded?
  final mimeType = fileData.typeData?.mimeType;
  if (mimeType == null) {
    // print("Empty mime type");
    return false;
  }
  List<String> defaults = XdgMimeApps.defaults(mimeType);
  if (defaults.isEmpty) {
    for (final ancester in mimedb.getAncesters(mimeType)) {
      defaults = XdgMimeApps.defaults(ancester);
      if (defaults.isNotEmpty) {
        break;
      }
    }
  }
  // print(
  //   "Default application for $mimeType: ${defaults.map((e) {
  //     final entry = desktopEntryManager.get_(e);
  //     return "$e ${entry?.fields.name}";
  //   })}",
  // );
  if (defaults.isEmpty) {
    return false;
  } else {
    return true;
  }
}

// final fileDetails = ApiProviderFamily<FileData, String>(
//   (path) => ApiState(
//     (apiState) async {
//       final file = File(path);
//       final stat = await file.stat();
//       return FileData.fromStat(path, stat);
//     },
//     disposeDelay: disposeDelay,
//   ),
// );

final directoryList = ApiProviderFamily<Iterable<FileData>, String>(
  (path) => ApiState(
    (apiState) async {
      final Map<String, FileData> result = {};
      int iteration = 1;
      final stopwatch = Stopwatch()..start();
      await for (final message in dirReader.readDir(Directory(path))) {
        switch (message) {
          case SingleFileData(:final data):
            result[data.path] = data;
          case SingleStatData(:final path, :final data):
            result[path]!.statData = data;
          case SingleTypeData(:final path, :final data):
            result[path]!.typeData = data;
          case SingleSpecialData(:final path, :final data):
            result[path]!.specialData = data;
          case FilesListDone():
            apiState.selfTotalNotifier.value = result.length * 4;
          case FullUpdate update:
            for (final data in update.newFileData) {
              result[data.path] = data;
            }
            for (final e in update.statDataUpdates) {
              result[e.path]!.statData = e.data;
            }
            for (final e in update.typeDataUpdates) {
              result[e.path]!.typeData = e.data;
            }
            for (final e in update.specialDataUpdates) {
              result[e.path]!.specialData = e.data;
            }
            apiState.selfTotalNotifier.value = update.totalCount?.toDouble();
            apiState.selfProgressNotifier.value = update.totalProcessedCount.toDouble();
        }
        print(
          'Received message ${iteration++} after ${stopwatch.elapsed}:'
          ' total=${apiState.selfTotalNotifier.value}'
          ' done=${apiState.selfProgressNotifier.value}',
        );
        apiState.state = AsyncValue.data(result.values);
        apiState.ref.notifyListeners();
      }
      // TODO: 2 use apiState.ref.OnDispose to cancel operation if it's still running
      return result.values;
    },
    disposeDelay: disposeDelay,
  ),
);

final sortedDirectoryList = ApiProviderFamily<List<FileData>, String>(
  (path) => ApiState(
    (apiState) async {
      // TODO: 2 optimize sorting
      apiState.selfTotalNotifier.value = 0;
      apiState.selfProgressNotifier.value = 0;
      final sort = apiState.ref.watch(currentSort);
      final completer = Completer();
      final subscription = apiState.ref.listen(directoryList.call(path), (prev, next) {
        final result = List<FileData>.from(next.value!);
        print('PASS SORT ${DateTime.now()}');
        result.sort((a, b) => a.compareTo(b, sort.$1, asc: sort.$2));
        apiState.state = AsyncValue.data(result);
      });
      await apiState.watch(directoryList.call(path));
      subscription.close();
      print('PASS END SORT ${DateTime.now()}');
      await completer.future;
      return apiState.state.value!;
    },
    disposeDelay: disposeDelay,
  ),
);
