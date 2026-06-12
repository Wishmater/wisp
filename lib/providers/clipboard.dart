import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clipboard = NotifierProvider(ClipboardFilesNotifier.new);

enum ClipboardFilesOperation { copy, cut }

class ClipboardFiles {
  ClipboardFilesOperation operation;
  List<String> paths;

  ClipboardFiles(this.operation, this.paths);

  @override
  String toString() => "$operation$paths";

  @override
  int get hashCode => Object.hashAllUnordered([operation, ...paths]);

  @override
  bool operator ==(Object other) {
    return other is ClipboardFiles &&
        operation == other.operation &&
        DeepCollectionEquality.unordered().equals(paths, other.paths);
  }
}

class ClipboardFilesNotifier extends Notifier<ClipboardFiles?> {
  @override
  ClipboardFiles? build() {
    // TODO: 1 initialize and set up dispose for clipboard watcher that calls _onClipboardChanged
    // clipboardWatcher.addListener(this);
    // ref.onDispose(() {
    //   clipboardWatcher.removeListener(this);
    // });
    _updateFromSystemClipboard();
    return null;
  }

  void setData(ClipboardFiles data) {
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
