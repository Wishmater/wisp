import 'package:collection/collection.dart';
import 'package:fast_copy/fast_copy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clipboard = NotifierProvider(ClipboardFilesNotifier.new);

enum FileOperationType { copy, cut }

class ClipboardFilesData {
  FileOperationType operationType;
  List<String> paths;

  ClipboardFilesData(this.operationType, this.paths);

  @override
  String toString() => "$operationType$paths";

  @override
  int get hashCode => Object.hashAllUnordered([operationType, ...paths]);

  @override
  bool operator ==(Object other) {
    return other is ClipboardFilesData &&
        operationType == other.operationType &&
        DeepCollectionEquality.unordered().equals(paths, other.paths);
  }
}

class ClipboardFilesNotifier extends Notifier<ClipboardFilesData?> {
  @override
  ClipboardFilesData? build() {
    // TODO: 1 initialize and set up dispose for clipboard watcher that calls _onClipboardChanged
    // clipboardWatcher.addListener(this);
    // ref.onDispose(() {
    //   clipboardWatcher.removeListener(this);
    // });
    _updateFromSystemClipboard();
    return null;
  }

  void setData(ClipboardFilesData data) {
    state = data;
    _setSystemClipboard();
  }

  // TODO: 1 this needs to be called whenever system clipboard data changes
  Future<void> _onSystemClipboardChanged() async {
    return _updateFromSystemClipboard();
  }

  Future<void> _updateFromSystemClipboard() async {
    // TODO: 1 get data from system clipbard, parse, and set state
  }

  Future<void> _setSystemClipboard() async {
    // TODO: 1 set system clipboard to our data
  }
}

class FileOperation {
  final DateTime startTime;
  final FileOperationType type;
  final List<String> paths;
  final String destination;
  final ValueNotifier<CopyState?> state = ValueNotifier(null);

  FileOperation({
    required this.startTime,
    required this.type,
    required this.paths,
    required this.destination,
  });

  @override
  String toString() => "$type $startTime $paths => $destination";

  @override
  int get hashCode => Object.hashAllUnordered([type, ...paths, destination, startTime]);

  @override
  bool operator ==(Object other) {
    return other is FileOperation &&
        startTime == other.startTime &&
        type == other.type &&
        destination == other.destination &&
        DeepCollectionEquality.unordered().equals(paths, other.paths);
  }
}
