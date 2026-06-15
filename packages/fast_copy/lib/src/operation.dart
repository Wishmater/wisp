import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:fast_copy/src/copy.dart';
import 'package:fast_copy/src/types.dart';
import 'package:path/path.dart' as p;

class CopyOperation {
  CopyState state;

  List<CopySource> sources;

  Directory dest;

  ICopy manager;

  final List<FileCopyOperation> _actives;

  Completer<bool> _waitPaused;

  final SendPort _mainSendPort;

  bool _replaceAll = false;
  bool _skipAll = false;
  bool _aborted = false;

  int _conflictId = 0;
  final Map<int, Completer<ConflictResolution>> _conflictAwaiters = {};

  CopyOperation(this.sources, this.dest, this.manager, this._mainSendPort, [bool paused = false])
    : state = CopyState.pending(totalBytes: 0, totalFiles: 0, paused: paused),
      _actives = [],
      _waitPaused = Completer() {
    assert(dest.existsSync());
    if (!paused) {
      _waitPaused.complete(true);
    }
    _start(paused);
  }

  Future<void> _start(bool paused) async {
    await _init().timeout(Duration(seconds: 1), onTimeout: () {});
    state = (state as CopyPending).toActive();
    final copyActive = state as CopyActive;

    int i = 0;
    while (i < sources.length) {
      if (!_waitPaused.isCompleted) {
        await _waitPaused.future;
      }
      if (_aborted) break;

      final source = sources[i];
      await _performCopy(source, paused, copyActive);
      paused = false;

      i++;
    }

    state = (state as CopyActive).toDone();
  }

  Future<void> _copyFile(CopyActive state, FileCopyOperation fileCopy) async {
    if (File(fileCopy.dest).existsSync()) {
      print("CONFLICT ${fileCopy.dest}");
      final resolution = await _resolveConflict(fileCopy.source.path, fileCopy.dest);
      print("CONFLICT RESOLVED WITH $resolution");
      switch (resolution) {
        case ConflictResolution.skip || ConflictResolution.skipAll || ConflictResolution.cancel:
          return;
        case ConflictResolution.replace || ConflictResolution.replaceAll:
          break;
      }
    }
    _actives.add(fileCopy);
    try {
      await manager.copyFile(fileCopy);
    } catch (e) {
      _actives.remove(fileCopy);
      state.failures.add(
        FileFailure(sourcePath: fileCopy.source.path, destPath: fileCopy.dest, error: e),
      );
    }
  }

  Future<void> _performCopy(CopySource source, bool paused, CopyActive state) async {
    final destPath = p.join(dest.path, p.basename(source.path));
    switch (source) {
      case FileSource source:
        final fileCopy = FileCopyOperation(
          paused: paused,
          source: source,
          dest: destPath,
          parent: this,
        );
        await _copyFile(state, fileCopy);
      case DirectorySource source:
        final dir = Directory(source.path);
        await for (final entry in dir.list(followLinks: false, recursive: true)) {
          if (_aborted) break;
          final relativePath = entry.path.substring(source.path.length + 1);
          final destinationPath = p.join(destPath, relativePath);

          switch (entry) {
            case Directory():
              try {
                manager.makeDirectorySync(destinationPath);
              } catch (e) {
                state.failures.add(
                  FileFailure(sourcePath: entry.path, destPath: destinationPath, error: e),
                );
              }
            case Link():
              try {
                manager.makeLinkSync(entry, destinationPath);
              } catch (e) {
                state.failures.add(
                  FileFailure(sourcePath: entry.path, destPath: destinationPath, error: e),
                );
              }
            case File file:
              assert(() {
                if (!File(destinationPath).parent.existsSync()) {
                  return false;
                }
                return true;
              }(), "${entry.parent} does not exists");

              final fileStat = file.statSync();
              final fFileStat = FFileStat(
                mode: fileStat.mode,
                byteSize: fileStat.size,
                preferedIOSize: 4096,
                change: fileStat.changed,
                access: fileStat.accessed,
                modification: fileStat.modified,
              );

              final fileCopy = FileCopyOperation(
                paused: paused,
                source: FileSource(path: file.path, stat: fFileStat),
                dest: destinationPath,
                parent: this,
              );
              await _copyFile(state, fileCopy);
          }
        }
    }
  }

  Future<void> _init() async {
    for (final source in sources) {
      switch (source) {
        case FileSource source:
          final stat = File(source.path).statSync();
          state.totalBytes += stat.size;
          state.totalFiles += 1;
        case DirectorySource source:
          final dir = Directory(source.path);
          await for (final entry in dir.list(followLinks: false, recursive: true)) {
            if (entry is Directory) {
              continue;
            }
            if (entry is Link) {
              state.totalFiles += 1;
              continue;
            }
            final file = (entry as File);
            final stat = file.statSync();
            state.totalBytes += stat.size;
            state.totalFiles += 1;
          }
      }
    }
  }

  Future<ConflictResolution> _resolveConflict(String sourcePath, String destPath) async {
    if (_skipAll) return ConflictResolution.skip;
    if (_replaceAll) return ConflictResolution.replace;

    final id = _conflictId++;
    final completer = Completer<ConflictResolution>();
    _conflictAwaiters[id] = completer;
    _mainSendPort.send(ConflictMessage(id, sourcePath, destPath));

    final resolution = await completer.future;

    switch (resolution) {
      case ConflictResolution.replaceAll:
        _replaceAll = true;
      case ConflictResolution.skipAll:
        _skipAll = true;
      case ConflictResolution.cancel:
        _aborted = true;
      case ConflictResolution.replace:
      case ConflictResolution.skip:
        break;
    }

    return resolution;
  }

  void resolveCompleter(int id, ConflictResolution resolution) {
    final completer = _conflictAwaiters.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(resolution);
    }
  }

  void abort() {
    _aborted = true;
    for (final completer in _conflictAwaiters.values) {
      if (!completer.isCompleted) {
        completer.complete(ConflictResolution.cancel);
      }
    }
    _conflictAwaiters.clear();
    if (!_waitPaused.isCompleted) {
      _waitPaused.complete(true);
    }
  }

  void pause() {
    _waitPaused = Completer();
    state.paused = true;
    for (final active in _actives) {
      active.pause();
    }
  }

  void resume() {
    _waitPaused.complete(true);
    for (final active in _actives) {
      active.resume();
    }
  }
}

class FileCopyOperation {
  final FileSource source;
  final String dest;
  final CopyOperation parent;

  Completer<bool> waitPaused;

  FileCopyOperation({
    required bool paused,
    required this.parent,
    required this.source,
    required this.dest,
  }) : waitPaused = Completer() {
    if (!paused) {
      waitPaused.complete(true);
    }
  }

  void report(FCOEvent event) {
    final state = (parent.state as CopyActive);
    switch (event) {
      case FCOEventCopied event:
        state.completedBytes += event.copied;
      case FCOEventFinish():
        state.completedFiles += 1;
        final isRemoved = parent._actives.remove(this);
        assert(isRemoved);
    }
  }

  void pause() {
    waitPaused = Completer();
  }

  void resume() {
    waitPaused.complete(true);
  }
}

sealed class FCOEvent {
  const FCOEvent();

  const factory FCOEvent.copied(int copied) = FCOEventCopied;
  const factory FCOEvent.finish() = FCOEventFinish;
}

class FCOEventCopied extends FCOEvent {
  final int copied;

  const FCOEventCopied(this.copied);
}

class FCOEventFinish extends FCOEvent {
  const FCOEventFinish();
}
