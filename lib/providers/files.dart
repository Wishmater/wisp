import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_api_handling.dart';
import 'package:wisp/models/file_data.dart';

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
      return _getFileData(path, stat);
    },
    disposeDelay: disposeDelay,
  ),
);

final readDirectory = _PileAwait();

final directoryList = ApiProviderFamily<List<FileData>, String>(
  (path) => ApiState(
    (apiState) async {
      final directory = Directory(path);
      // TODO: 2 maybe we could actually listen to the stream and paint the UI in multiple steps? that would be cool maybe?
      final sw = Stopwatch()..start();
      final stream = readDirectory.readDir(directory);
      final response = await stream.toList();
      print("READ DIR DELAY: ${sw.elapsed}");
      return response;
      // final list = <FileData>[];
      // await for (final e in directory.list()) {
      //   final stat = await e.stat();
      //   list.add(_getFileData(e.absolute.path, stat));
      // }
      // return list;
    },
    disposeDelay: disposeDelay,
  ),
);

FileData _getFileData(String path, FileStat stat) {
  return switch (stat.type) {
    FileSystemEntityType.directory => DirectoryData(
      path: path,
      size: stat.size,
      modified: stat.modified,
    ),
    _ => FileData(
      path: path,
      size: stat.size,
      modified: stat.modified,
    ),
    // TODO: 2 we should probably handle all cases
  };
}

sealed class _ReadDir {
  Future<void> init() async {}

  Stream<FileData> readDir(Directory directory);
}

class _Simple extends _ReadDir {
  @override
  Stream<FileData> readDir(Directory directory) async* {
    await for (final e in directory.list()) {
      final stat = await e.stat();
      yield _getFileData(e.absolute.path, stat);
    }
  }
}

class _PileAwait extends _ReadDir {
  @override
  Stream<FileData> readDir(Directory directory) async* {
    final list = <(String, Future<FileStat>)>[];
    await for (final e in directory.list(followLinks: false)) {
      list.add((e.absolute.path, e.stat()));
    }
    for (final f in list) {
      final stat = await f.$2;
      final path = f.$1;
      yield _getFileData(path, stat);
    }
  }
}

sealed class _IsolateReadDirData {}

class _FileDataIsolateReadDirData extends _IsolateReadDirData {
  final FileData fileData;
  _FileDataIsolateReadDirData(this.fileData);
}

class _EndIsolateReadDirData extends _IsolateReadDirData {}

class _IsolateReadDir extends _ReadDir {
  late final SendPort _sp;

  @override
  Stream<FileData> readDir(Directory directory) {
    final rp = ReceivePort();
    final completer = Completer<bool>();
    _sp.send((directory, rp.sendPort));

    final response = StreamController<FileData>();

    rp.listen((msg) {
      final data = msg as _IsolateReadDirData;
      switch (data) {
        case _FileDataIsolateReadDirData(:final fileData):
          response.add(fileData);
        case _EndIsolateReadDirData():
          completer.complete(true);
      }
    });

    completer.future.then((_) {
      rp.close();
      response.close();
    });

    return response.stream;
  }

  @override
  Future<void> init() async {
    final instaceReciever = ReceivePort();
    Isolate.spawn(_isolate, instaceReciever.sendPort);

    final completer = Completer<SendPort>();
    instaceReciever.listen((msg) {
      completer.complete(msg as SendPort);
    });

    _sp = await completer.future;
    instaceReciever.close();
  }

  static void _isolate(SendPort sp) {
    ReceivePort rpIsolate = ReceivePort();
    sp.send(rpIsolate.sendPort);

    rpIsolate.listen((msg) async {
      final (directory, port) = msg as (Directory, SendPort);
      await for (final entry in directory.list(followLinks: false)) {
        final stat = entry.statSync();
        final path = entry.absolute.path;
        final data = _getFileData(path, stat);
        port.send(_FileDataIsolateReadDirData(data));
      }
      port.send(_EndIsolateReadDirData());
    });
  }
}
