import 'dart:async';
import 'dart:io';

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

  CopyOperation(this.sources, this.dest, this.manager, [bool paused = false])
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

      final source = sources[i];
      await _performCopy(source, paused, copyActive);
      paused = false;

      i++;
    }

    state = (state as CopyActive).toDone();
  }

  Future<void> _copyFile(CopyActive state, FileCopyOperation fileCopy) async {
    if (File(fileCopy.dest).existsSync()) {}
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
        _copyFile(state, fileCopy);
      case DirectorySource source:
        final dir = Directory(source.path);
        await for (final entry in dir.list(followLinks: false, recursive: true)) {
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
              _copyFile(state, fileCopy);
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
