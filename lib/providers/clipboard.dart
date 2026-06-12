import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clipboard = NotifierProvider(ClipboardNotifier.new);

enum ClipboardOperation { copy, cut }

class ClipboardFiles {
  ClipboardOperation operation;
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

class ClipboardNotifier extends Notifier<ClipboardFiles?> {
  @override
  ClipboardFiles? build() => null;

  void setData(ClipboardFiles data) {
    state = data;
    // TODO: 1 set the system clipboard to this operation
  }
}
