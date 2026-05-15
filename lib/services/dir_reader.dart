import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:wisp/models/file_data.dart';

final dirReader = PileAwaitDirReader();

sealed class DirReader {
  Future<void> init() async {}

  Stream<FileData> readDir(Directory directory);
}

@visibleForTesting
class SimpleDirReader extends DirReader {
  @override
  Stream<FileData> readDir(Directory directory) async* {
    await for (final e in directory.list()) {
      final stat = await e.stat();
      yield FileData.fromStat(e.absolute.path, stat);
    }
  }
}

@visibleForTesting
class PileAwaitDirReader extends DirReader {
  @override
  Stream<FileData> readDir(Directory directory) async* {
    final list = <(String, Future<FileStat>)>[];
    await for (final e in directory.list(followLinks: false)) {
      list.add((e.absolute.path, e.stat()));
    }
    for (final f in list) {
      final stat = await f.$2;
      final path = f.$1;
      yield FileData.fromStat(path, stat);
    }
  }
}

sealed class _IsolateReadDirData {}

class _FileDataIsolateReadDirData extends _IsolateReadDirData {
  final FileData fileData;
  _FileDataIsolateReadDirData(this.fileData);
}

class _EndIsolateReadDirData extends _IsolateReadDirData {}

@visibleForTesting
class IsolateDirReader extends DirReader {
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
        final data = FileData.fromStat(path, stat);
        port.send(_FileDataIsolateReadDirData(data));
      }
      port.send(_EndIsolateReadDirData());
    });
  }
}

@visibleForTesting
class SyncDirReader extends DirReader {
  @override
  Stream<FileData> readDir(Directory directory) async* {
    for (final e in directory.listSync()) {
      final stat = e.statSync();
      yield FileData.fromStat(e.absolute.path, stat);
    }
  }
}

@visibleForTesting
class ComputeDirReader extends DirReader {
  DirReader reader;

  ComputeDirReader(this.reader);

  @override
  Stream<FileData> readDir(Directory directory) async* {
    final result = await compute((directory) {
      return reader.readDir(directory).toList();
    }, directory);
    for (final e in result) {
      yield e;
    }
  }
}
