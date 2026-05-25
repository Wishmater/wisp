import 'dart:async';
import 'dart:io';

import 'package:fast_copy/src/copy.dart';
import 'package:fast_copy/src/types.dart';

class CopyOperation {
  CopyState state;

  CopySource source;

  String dest;

  ICopy manager;

  final List<FileCopyOperation> _actives;

  Completer<bool> _waitPaused;

  CopyOperation(this.source, this.dest, this.manager, [bool paused = false])
    : state = CopyState.pending(totalBytes: 0, totalFiles: 0),
      _actives = [],
      _waitPaused = Completer() {
    if (!paused) {
      _waitPaused.complete(true);
    }
    _start(paused);
  }

  Future<void> _start(bool paused) async {
    await _init().timeout(Duration(seconds: 1), onTimeout: () {});
    state = (state as CopyPending).toActive();

    switch (source) {
      case FileSource source:
        final fileCopy = FileCopyOperation(
          paused: paused,
          source: source,
          dest: dest,
          parent: this,
        );
        _actives.add(fileCopy);
        await manager.copyFile(fileCopy);
      case DirectorySource source:
        final dir = Directory(source.path);
        await for (final entry in dir.list(followLinks: false, recursive: true)) {
          final relativePath = entry.path.substring(source.path.length + 1);
          final destinationPath = '$dest/$relativePath';

          if (entry is Directory) {
            _createDirectory(destinationPath);
            continue;
          }

          if (entry is Link) {
            _copyLink(entry, destinationPath);
            continue;
          }
          final file = (entry as File);

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
          _actives.add(fileCopy);
          try {
            await manager.copyFile(fileCopy);
          } catch (e) {
            _actives.remove(fileCopy);
            (state as CopyActive).failures.add(
              FileFailure(sourcePath: file.path, destPath: destinationPath, error: e),
            );
          }
        }
    }

    state = (state as CopyActive).toDone();
  }

  Future<void> _init() async {
    switch (source) {
      case FileSource source:
        final stat = File(source.path).statSync();
        state.totalBytes += stat.size;
        state.totalFiles = 1;
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

  void pause() {
    _waitPaused = Completer();
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

void _copyLink(Link source, String dest) {
  final target = source.targetSync();
  try {
    Link(dest).createSync(target);
  } catch (_) {}
}

void _createDirectory(String dest) {
  Directory(dest).createSync(recursive: true);
}
