import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_api_handling.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/explorer.dart';
import 'package:wisp/services/dir_reader.dart';
import 'package:wisp/services/xdg_mime.dart';
import 'package:xdg_mime/xdg_mime.dart';

final disposeDelay = Duration(seconds: 30);

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
          'Provider received message ${iteration++} after ${stopwatch.elapsed}:'
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
      final subscription = apiState.ref.listen(directoryList.call(path), (prev, next) {
        if (apiState.wholeProgressNotifier.value == 1) {
          return;
        }
        final result = List<FileData>.from(next.value!);
        print('PASS SORT $sort ${DateTime.now()}');
        result.sort((a, b) => a.compareTo(b, sort.field, asc: sort.asc));
        apiState.state = AsyncValue.data(result);
      });
      final list = await apiState.watch(directoryList.call(path));
      subscription.close();
      final result = List<FileData>.from(list);
      result.sort((a, b) => a.compareTo(b, sort.field, asc: sort.asc));
      print('PASS END SORT $sort ${DateTime.now()}');
      return result;
    },
    disposeDelay: disposeDelay,
  ),
);
