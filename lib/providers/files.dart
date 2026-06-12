import 'dart:io';

import 'package:fast_copy/fast_copy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:wisp/models/file_data.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/clipboard.dart';
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

final fileOperations = NotifierProvider(FileOperationsNotifier.new);

class FileOperationsNotifier extends Notifier<List<FileOperation>> {
  @override
  List<FileOperation> build() => [];

  FileOperation startOperation({
    required FileOperationType type,
    required List<String> paths,
    required String destination,
  }) {
    print('Start operation $type: $paths => $destination');
    assert(paths.isNotEmpty);
    final operation = FileOperation(
      startTime: DateTime.timestamp(),
      type: type,
      paths: paths,
      destination: destination,
    );
    state.add(operation);
    _executeOperation(operation);
    return operation;
  }

  Future<void> _executeOperation(FileOperation operation) async {
    // TODO: 1 should we have a single runner for multiple operations, or start a runner for each like this
    final runner = await IsolateCopyRunner.spawn();
    // TODO: 1 add option to change copier ?
    final copier = CopyFileRange();
    // TODO: 1 why am i forced to distinguish files from directories, shouldn't the isolate do this ?
    final sources = operation.paths.map((e) {
      final stat = File(e).statSync();
      if (stat.type == .directory) {
        return DirectorySource(path: e);
      } else {
        return FileSource(
          path: e,
          stat: FFileStat(
            mode: stat.mode,
            byteSize: stat.size,
            change: stat.changed,
            access: stat.accessed,
            modification: stat.modified,
            preferedIOSize: 69420, // ???????????????????????????????????????????????
          ),
        );
      }
    }).toList();
    final targetFps = PlatformDispatcher.instance.implicitView?.display.refreshRate ?? 60;
    final frameDuration = Duration(microseconds: 1000000 ~/ targetFps); // 60 fps
    print('targetFps: $targetFps ($frameDuration)');
    // TODO: 3 we can listen to this to react to changes in targetFps
    // PlatformDispatcher.instance.onMetricsChanged = () {
    //   // react...
    // };
    // TODO: 1 how do we do cut instead of copy ?
    await runner.startCopy(copier, sources, operation.destination);
    while (true) {
      final frameStart = DateTime.timestamp();
      final state = await runner.snapshot();
      switch (state) {
        case CopyPending():
          print('CopyPending ${state.totalFiles} ${state.totalBytes}');
          if (operation.state.value == null || !_copyStateEquals(state, operation.state.value!)) {
            operation.state.value = state;
          }
        case CopyActive():
          print('CopyPending ${state.completedFiles} ${state.completedBytes}');
          if (operation.state.value == null || !_copyStateEquals(state, operation.state.value!)) {
            operation.state.value = state;
          }
        case CopyDone():
          stdout.write('\x1b[2K\r');
          print('CopyDone');
          if (operation.state.value == null || !_copyStateEquals(state, operation.state.value!)) {
            operation.state.value = state;
          }
      }
      if (state is CopyDone) break;
      final frameElapsed = DateTime.timestamp().difference(frameStart);
      final wait = frameDuration - frameElapsed;
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
    }
  }
}

bool _copyStateEquals(CopyState a, CopyState b) {
  if (a.runtimeType != b.runtimeType) return false;
  if (a.totalBytes != b.totalBytes) return false;
  if (a.totalFiles != b.totalFiles) return false;
  if (a is CopyActive && b is CopyActive) {
    return a.completedFiles == b.completedFiles &&
        a.completedBytes == b.completedBytes &&
        a.failures.length == b.failures.length;
  }
  if (a is CopyDone && b is CopyDone) {
    return a.completedFiles == b.completedFiles &&
        a.completedBytes == b.completedBytes &&
        a.failures.length == b.failures.length;
  }
  return false;
}
