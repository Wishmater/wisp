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
    await for (final e in directory.list(followLinks: false)) {
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
  final List<FileData> fileData;
  _FileDataIsolateReadDirData(this.fileData);
}

class _EndIsolateReadDirData extends _IsolateReadDirData {}

class _IsolateStartData {
  final Directory directory;
  final DirReader reader;
  final SendPort port;
  final int batchSize;
  _IsolateStartData({
    required this.directory,
    required this.reader,
    required this.port,
    required this.batchSize,
  });
}

@visibleForTesting
class IsolateDirReader extends DirReader {
  final DirReader reader;
  final int batchSize;

  IsolateDirReader(
    this.reader, {
    this.batchSize = 100,
  });

  late final SendPort _sp;

  @override
  Stream<FileData> readDir(Directory directory) {
    final rp = ReceivePort();
    final completer = Completer<bool>();
    _sp.send(
      _IsolateStartData(
        directory: directory,
        reader: reader,
        port: rp.sendPort,
        batchSize: batchSize,
      ),
    );

    final response = StreamController<FileData>();

    rp.listen((msg) {
      final data = msg as _IsolateReadDirData;
      switch (data) {
        case _FileDataIsolateReadDirData(:final fileData):
          for (final data in fileData) {
            response.add(data);
          }
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
      final params = msg as _IsolateStartData;
      List<FileData> tempList = [];
      await for (final data in params.reader.readDir(params.directory)) {
        tempList.add(data);
        if (tempList.length >= params.batchSize) {
          final sendList = tempList;
          tempList = [];
          params.port.send(_FileDataIsolateReadDirData(sendList));
        }
      }
      if (tempList.isNotEmpty) {
        params.port.send(_FileDataIsolateReadDirData(tempList));
      }
      params.port.send(_EndIsolateReadDirData());
    });
  }
}

@visibleForTesting
class SyncDirReader extends DirReader {
  @override
  Stream<FileData> readDir(Directory directory) async* {
    for (final e in directory.listSync(followLinks: false)) {
      final stat = e.statSync();
      yield FileData.fromStat(e.absolute.path, stat);
    }
  }
}

@visibleForTesting
class ComputeDirReader extends DirReader {
  final DirReader reader;

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
