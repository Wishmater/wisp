import 'dart:io';

import 'package:from_zero_ui/packages/fz_riverpod.dart';
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

final directoryList = FzStreamProviderFamily<Iterable<FileData>?, String>(
  (path) => FzStreamNotifierBuilder(
    (apiState) async* {
      final progressNotifier = apiState.ref.read(apiState.selfProgress.notifier);
      final Map<String, FileData> result = {};
      int iteration = 1;
      final stopwatch = Stopwatch()..start();
      // TODO: 2 use apiState.ref.OnDispose to cancel operation if it's still running
      await for (final message in dirReader.readDir(Directory(path))) {
        switch (message) {
          case SingleFileData(:final data):
            result[data.path] = data;
            progressNotifier.setCount((progressNotifier.progress.count ?? 0) + 1);
          case SingleStatData(:final path, :final data):
            result[path]!.statData = data;
            progressNotifier.setCount((progressNotifier.progress.count ?? 0) + 1);
          case SingleTypeData(:final path, :final data):
            result[path]!.typeData = data;
            progressNotifier.setCount((progressNotifier.progress.count ?? 0) + 1);
          case SingleSpecialData(:final path, :final data):
            result[path]!.specialData = data;
            progressNotifier.setCount((progressNotifier.progress.count ?? 0) + 1);
          case FilesListDone():
            progressNotifier.setTotal(result.length * 4);
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
            progressNotifier.setValues(update.totalCount?.toDouble(), update.totalProcessedCount.toDouble());
        }
        print(
          'Provider received message ${iteration++} after ${stopwatch.elapsed}:'
          ' total=${apiState.ref.read(apiState.selfProgress).total}'
          ' done=${apiState.ref.read(apiState.selfProgress).count}',
        );
        yield result.values;
      }
      apiState.ref.addDisposeDelay(disposeDelay);
    },
  ),
);

final sortedDirectoryList = FzStreamProviderFamily<List<FileData>?, String>(
  (path) => FzStreamNotifierBuilder(
    (apiState) async* {
      // TODO: 2 optimize sorting
      apiState.ref.read(apiState.selfProgress.notifier).setValues(0, 0);
      final sort = apiState.ref.watch(currentSort);
      await for (final files in apiState.watchStream(directoryList.call(path))) {
        if (files == null) continue;
        final result = List<FileData>.from(files);
        result.sort((a, b) => a.compareTo(b, sort.field, asc: sort.asc));
        print('PASS SORT $sort ${DateTime.now()}');
        yield result;
      }
      print('PASS END SORT $sort ${DateTime.now()}');
      apiState.ref.addDisposeDelay(disposeDelay);
    },
  ),
);
