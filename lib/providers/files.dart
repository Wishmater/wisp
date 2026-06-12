import 'dart:io';

import 'package:from_zero_ui/packages/fz_riverpod.dart';
import 'package:path/path.dart' as p;
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
  print("OPEN FILE $mimeType");
  if (mimeType == null) {
    // print("Empty mime type");
    return false;
  }
  List<String> defaults = XdgMimeApps.defaults(mimeType, desktopEntries: desktopEntryManager);
  if (defaults.isEmpty) {
    for (final ancester in mimedb.getAncesters(mimeType)) {
      print("ANCESTER $ancester");
      defaults = XdgMimeApps.defaults(ancester, desktopEntries: desktopEntryManager);
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
    print("DEFAULTS ARE EMPTY");
    return false;
  } else {
    print("DEFAULTS ARE $defaults");
    for (final e in defaults) {
      final entry = desktopEntryManager.get_(e);
      if (entry == null) continue;
      final exec = entry.fields.exec;
      if (exec == null) continue;
      final cmds = expandExec(exec, files: [fileData.path], urls: [p.toUri(fileData.path).toString()]);
      print("COMMANDS $cmds");
      assert(cmds.isNotEmpty);
      assert(cmds.length != 1);
      Process.run(cmds[0], cmds.sublist(1));
      return true;
    }
    return false;
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
    keepDataOnLoading: true,
    keepDataOnError: true,
    (notifier) async* {
      final progressNotifier = notifier.ref.read(notifier.selfProgress.notifier);
      final Map<String, FileData> result = {};
      int iteration = 1;
      final stopwatch = Stopwatch()..start();
      // TODO: 2 use apiState.ref.OnDispose to cancel operation if it's still running
      await for (final message in dirReader.readDir(Directory(path), DirReaderSettings())) {
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
            progressNotifier.setValues(update.totalProcessedCount.toDouble(), update.totalCount?.toDouble());
          case DirReaderError():
            // TODO: Handle this case.
            throw UnimplementedError();
        }
        print(
          'Provider received message ${iteration++} after ${stopwatch.elapsed}:'
          ' total=${notifier.ref.read(notifier.selfProgress).total}'
          ' done=${notifier.ref.read(notifier.selfProgress).count}',
        );
        yield result.values;
      }
      notifier.ref.addDisposeDelay(disposeDelay);
    },
  ),
);

final sortedDirectoryList = FzStreamProviderFamily<List<FileData>?, String>(
  (path) => FzStreamNotifierBuilder(
    keepDataOnLoading: true,
    keepDataOnError: true,
    (notifier) async* {
      // TODO: 2 optimize sorting
      notifier.ref.read(notifier.selfProgress.notifier).setValues(0, 0);
      final sort = notifier.ref.watch(currentSort);
      final stream = notifier.watchStream(directoryList.call(path));
      await for (final files in stream) {
        if (files == null) continue;
        final result = List<FileData>.from(files);
        result.sort((a, b) => a.compareTo(b, sort.field, asc: sort.asc));
        yield result;
      }
      notifier.ref.addDisposeDelay(disposeDelay);
    },
  ),
);
