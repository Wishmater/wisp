import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:wisp/models/file_data.dart';
import 'package:wisp/services/disk_type.dart';
import 'package:wisp/services/xdg_mime.dart';

final dirReader = HddAwareDirReader(
  ssdReader: IsolateDirReader(SyncDirReader()),
  // ssdReader: IsolateDirReader(PileAwaitDirReader()),
  hddReader: IsolateDirReader(PileAwaitDirReader()),
);

class DirReaderSettings {}

sealed class DirReader {
  Future<void> init() async {}

  Stream<DirReaderMessage> readDir(Directory directory, DirReaderSettings settings);
}

sealed class DirReaderMessage {}

class SingleFileData extends DirReaderMessage {
  final FileData data;
  SingleFileData(this.data);
}

class DirReaderError extends DirReaderMessage {
  final Object error;

  DirReaderError(this.error);
}

class FilesListDone extends DirReaderMessage {}

class SingleStatData extends DirReaderMessage {
  final String path;
  final FileStatData data;
  SingleStatData(this.path, this.data);
}

class SingleTypeData extends DirReaderMessage {
  final String path;
  final FileTypeData data;
  SingleTypeData(this.path, this.data);
}

class SingleSpecialData extends DirReaderMessage {
  final String path;
  final FileSpecialData data;
  SingleSpecialData(this.path, this.data);
}

class FullUpdate extends DirReaderMessage {
  final List<FileData> newFileData;
  final List<SingleStatData> statDataUpdates;
  final List<SingleTypeData> typeDataUpdates;
  final List<SingleSpecialData> specialDataUpdates;
  final int? fileCount;
  final int fileDataProcessedCount;
  final int statDataProcessedCount;
  final int typeDataProcessedCount;
  final int specialDataProcessedCount;
  FullUpdate({
    required this.newFileData,
    required this.statDataUpdates,
    required this.typeDataUpdates,
    required this.specialDataUpdates,
    required this.fileCount,
    required this.fileDataProcessedCount,
    required this.statDataProcessedCount,
    required this.typeDataProcessedCount,
    required this.specialDataProcessedCount,
  });
  int? get totalCount => fileCount == null ? null : fileCount! * 4;
  int get totalProcessedCount =>
      fileDataProcessedCount + statDataProcessedCount + typeDataProcessedCount + specialDataProcessedCount;
}

@visibleForTesting
class SimpleDirReader extends DirReader {
  @override
  Stream<DirReaderMessage> readDir(Directory directory, DirReaderSettings settings) async* {
    await for (final e in directory.list(followLinks: false)) {
      final path = e.absolute.path;
      yield SingleFileData(FileData(path: path));
      final stat = await e.stat();
      yield SingleStatData(path, FileStatData.fromStat(stat));
      yield SingleTypeData(path, switch (stat.type) {
        // TODO: 1 in these cases where we know the type from the stat, maybe we can do a single yield for stat+type
        .directory => FileTypeData(type: .directory),
        // TODO: 2 we should probably handle most cases (links, etc.)
        // TODO: 1 if fromMimeType sometimes reads the file, there should probably be an async version, and then we do PileAwait with it
        _ => FileTypeData.fromMimeType(mimedb.getMimeType(path)),
      });
      // TODO: 2 load special data, according to type
      yield SingleSpecialData(path, FileNoSpecialData());
    }
  }
}

@visibleForTesting
class SyncDirReader extends DirReader {
  @override
  Stream<DirReaderMessage> readDir(Directory directory, DirReaderSettings settings) async* {
    List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(followLinks: false);
    } catch(e) {
      yield DirReaderError(e);
      return;
    }

    for (final e in entries) {
      final path = e.absolute.path;

      print("AAAA ${p.basename(path)} ${p.basename(path).startsWith(".")}");
      if (p.basename(path).startsWith(".")) {
        continue;
      }
      // await Future.delayed(Duration(milliseconds: 10));
      yield SingleFileData(FileData(path: path));
      final stat = e.statSync();
      // await Future.delayed(Duration(milliseconds: 10));
      yield SingleStatData(path, FileStatData.fromStat(stat));
      // await Future.delayed(Duration(milliseconds: 10));
      yield SingleTypeData(path, switch (stat.type) {
        // TODO: 1 in these cases where we know the type from the stat, maybe we can do a single yield for stat+type
        .directory => FileTypeData(type: .directory),
        // TODO: 2 we should probably handle most cases (links, etc.)
        // TODO: 1 if fromMimeType sometimes reads the file, there should probably be an async version, and then we do PileAwait with it
        _ => FileTypeData.fromMimeType(mimedb.getMimeType(path)),
      });
      // await Future.delayed(Duration(milliseconds: 10));
      // TODO: 2 load special data, according to type
      yield SingleSpecialData(path, FileNoSpecialData());
    }
  }
}

@visibleForTesting
class PileAwaitDirReader extends DirReader {
  @override
  Stream<DirReaderMessage> readDir(Directory directory, DirReaderSettings settings) {
    final response = StreamController<DirReaderMessage>();
    final list = directory.list(followLinks: false);
    final futures = <Future<void>>[];
    // final random = Random();
    list.listen(
      (e) {
        final path = e.absolute.path;
        if (p.basename(path).startsWith(".")) {
          return;
        }
        response.add(SingleFileData(FileData(path: path)));
        futures.add(() async {
          final stat = await e.stat();
          // await Future.delayed(Duration(milliseconds: random.nextInt(10000)));
          response.add(SingleStatData(path, FileStatData.fromStat(stat)));
          // await Future.delayed(Duration(milliseconds: random.nextInt(10000)));
          response.add(
            SingleTypeData(path, switch (stat.type) {
              // TODO: 1 in these cases where we know the type from the stat, maybe we can do a single yield for stat+type
              .directory => FileTypeData(type: .directory),
              // TODO: 2 we should probably handle most cases (links, etc.)
              // TODO: 1 if fromMimeType sometimes reads the file, there should probably be an async version, and then we do PileAwait with it
              _ => FileTypeData.fromMimeType(mimedb.getMimeType(path)),
            }),
          );
          // TODO: 2 load special data, according to type
          // await Future.delayed(Duration(milliseconds: random.nextInt(10000)));
          response.add(SingleSpecialData(path, FileNoSpecialData()));
        }());
      },
      onError: response.addError,
      onDone: () {
        response.add(FilesListDone());
        Future.wait(futures).then((_) => response.close());
      },
    );
    return response.stream;
  }
}

sealed class _DirReaderIsolateMessage {}

class _DirReaderIsolateData extends _DirReaderIsolateMessage {
  final FullUpdate message;
  _DirReaderIsolateData(this.message);
}

class _DirReaderIsolateEnd extends _DirReaderIsolateMessage {}

class _IsolateStartData {
  final Directory directory;
  final DirReader reader;
  DirReaderSettings settings;
  final SendPort port;
  final int batchSize;
  _IsolateStartData({
    required this.directory,
    required this.reader,
    required this.settings,
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
  Stream<DirReaderMessage> readDir(Directory directory, DirReaderSettings settings) {
    final rp = ReceivePort();
    final completer = Completer<bool>();
    _sp.send(
      _IsolateStartData(
        directory: directory,
        reader: reader,
        settings: settings,
        port: rp.sendPort,
        batchSize: batchSize,
      ),
    );

    final response = StreamController<DirReaderMessage>();

    rp.listen((msg) {
      final data = msg as _DirReaderIsolateMessage;
      switch (data) {
        case _DirReaderIsolateData(:final message):
          response.add(message);
        case _DirReaderIsolateEnd():
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

  static Future<void> _isolate(SendPort sp) async {
    ReceivePort rpIsolate = ReceivePort();
    await initXdgMime();
    sp.send(rpIsolate.sendPort);

    rpIsolate.listen((msg) async {
      final params = msg as _IsolateStartData;
      bool filesDone = false;
      int fileCount = 0;
      int statCount = 0;
      int typeCount = 0;
      int specialCount = 0;
      Map<String, FileData> tempFileData = {};
      List<SingleStatData> tempStatData = [];
      List<SingleTypeData> tempTypeData = [];
      List<SingleSpecialData> tempSpecialData = [];
      await for (final message in params.reader.readDir(params.directory, params.settings)) {
        switch (message) {
          case SingleFileData(:final data):
            fileCount++;
            tempFileData[data.path] = data;
          case SingleStatData(:final path, :final data):
            statCount++;
            if (tempFileData.containsKey(path)) {
              tempFileData[path]!.statData = data;
            } else {
              tempStatData.add(message);
            }
          case SingleTypeData(:final path, :final data):
            typeCount++;
            if (tempFileData.containsKey(path)) {
              tempFileData[path]!.typeData = data;
            } else {
              tempTypeData.add(message);
            }
          case SingleSpecialData(:final path, :final data):
            specialCount++;
            if (tempFileData.containsKey(path)) {
              tempFileData[path]!.specialData = data;
            } else {
              tempSpecialData.add(message);
            }
          case FilesListDone():
            filesDone = true;
          case FullUpdate update:
            fileCount = update.fileDataProcessedCount;
            statCount = update.statDataProcessedCount;
            typeCount = update.typeDataProcessedCount;
            specialCount = update.specialDataProcessedCount;
            for (final data in update.newFileData) {
              tempFileData[data.path] = data;
            }
            for (final e in update.statDataUpdates) {
              if (tempFileData.containsKey(e.path)) {
                tempFileData[e.path]!.statData = e.data;
              } else {
                tempStatData.add(e);
              }
            }
            for (final e in update.typeDataUpdates) {
              if (tempFileData.containsKey(e.path)) {
                tempFileData[e.path]!.typeData = e.data;
              } else {
                tempTypeData.add(e);
              }
            }
            for (final e in update.specialDataUpdates) {
              if (tempFileData.containsKey(e.path)) {
                tempFileData[e.path]!.specialData = e.data;
              } else {
                tempSpecialData.add(e);
              }
            }
          case DirReaderError(:final error):
            print("$error");
            filesDone = true;
        }
        if ((fileCount + statCount + typeCount + specialCount) % params.batchSize == 0) {
          params.port.send(
            _DirReaderIsolateData(
              FullUpdate(
                newFileData: tempFileData.values.toList(),
                statDataUpdates: tempStatData,
                typeDataUpdates: tempTypeData,
                specialDataUpdates: tempSpecialData,
                fileCount: filesDone ? fileCount : null,
                fileDataProcessedCount: fileCount,
                statDataProcessedCount: statCount,
                typeDataProcessedCount: typeCount,
                specialDataProcessedCount: specialCount,
              ),
            ),
          );
          tempFileData = {};
          tempStatData = [];
          tempTypeData = [];
          tempSpecialData = [];
        }
      }
      if (tempFileData.isNotEmpty || tempStatData.isNotEmpty || tempTypeData.isNotEmpty || tempSpecialData.isNotEmpty) {
        params.port.send(
          _DirReaderIsolateData(
            FullUpdate(
              newFileData: tempFileData.values.toList(),
              statDataUpdates: tempStatData,
              typeDataUpdates: tempTypeData,
              specialDataUpdates: tempSpecialData,
              fileCount: fileCount,
              fileDataProcessedCount: fileCount,
              statDataProcessedCount: statCount,
              typeDataProcessedCount: typeCount,
              specialDataProcessedCount: specialCount,
            ),
          ),
        );
      }
      params.port.send(_DirReaderIsolateEnd());
    });
  }
}

@visibleForTesting
class ComputeDirReader extends DirReader {
  final DirReader reader;

  ComputeDirReader(this.reader);

  @override
  Stream<DirReaderMessage> readDir(Directory directory, DirReaderSettings settings) async* {
    yield await compute((directory) async {
      final result = <String, FileData>{};
      await for (final message in reader.readDir(directory, settings)) {
        switch (message) {
          case SingleFileData(:final data):
            result[data.path] = data;
          case SingleStatData(:final path, :final data):
            result[path]!.statData = data;
          case SingleTypeData(:final path, :final data):
            result[path]!.typeData = data;
          case SingleSpecialData(:final path, :final data):
            result[path]!.specialData = data;
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
          case FilesListDone():
          case DirReaderError():
            // TODO: Handle this case.
            throw UnimplementedError();
        }
      }
      return FullUpdate(
        newFileData: result.values.toList(),
        statDataUpdates: [],
        typeDataUpdates: [],
        specialDataUpdates: [],
        fileCount: result.length,
        fileDataProcessedCount: result.length,
        statDataProcessedCount: result.length,
        typeDataProcessedCount: result.length,
        specialDataProcessedCount: result.length,
      );
    }, directory);
  }
}

@visibleForTesting
class HddAwareDirReader extends DirReader {
  final DirReader ssdReader;
  final DirReader hddReader;

  HddAwareDirReader({
    required this.ssdReader,
    required this.hddReader,
  });

  @override
  Future<void> init() {
    return Future.wait([
      diskType.init(),
      ssdReader.init(),
      hddReader.init(),
    ]);
  }

  @override
  Stream<DirReaderMessage> readDir(Directory directory, DirReaderSettings settings) {
    if (diskType.isRotational(directory.absolute.path)) {
      return hddReader.readDir(directory, settings);
    } else {
      return ssdReader.readDir(directory, settings);
    }
  }
}
