import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/files.dart';

final currentDirectory = NotifierProvider<CurrentDirectoryNotifier, String>(() {
  return CurrentDirectoryNotifier();
});

final currentSort = NotifierProvider<FileSortNotifier, FileSort>(() {
  return FileSortNotifier();
});

final fileSelection = NotifierProvider.family<FileSelectionNotifier, FileSelection, String>((path) {
  return FileSelectionNotifier(path);
});

class CurrentDirectoryNotifier extends Notifier<String> {
  @override
  String build() {
    return File('').absolute.path; // TODO: 1 this should probably come from args
    return '/nix/var/nix/profiles/';
  }

  void goUp() {
    state = File(state).parent.absolute.path;
  }

  void setCurrentDirectory(String path) {
    state = path;
  }
}

@immutable
class FileSort {
  final FileDataField field;
  final bool asc;

  const FileSort({
    required this.field,
    required this.asc,
  });

  @override
  String toString() => "FileSort(field=$field, asc=$asc)";

  @override
  int get hashCode => Object.hash(field, asc);

  @override
  bool operator ==(Object other) {
    return other is FileSort && field == other.field && asc == other.asc;
  }
}

class FileSortNotifier extends Notifier<FileSort> {
  @override
  FileSort build() {
    return FileSort(field: .filename, asc: true);
  }

  void setField(FileDataField value) {
    if (value == state.field) {
      state = FileSort(field: value, asc: !state.asc);
    } else {
      state = FileSort(field: value, asc: true);
    }
  }
}

class FileSelection {
  String? focusedPath;
  // PERF: 3 this should be a structure that facilitates querying .contains(), maybe a Set?
  List<String> selectedPaths;

  FileSelection({
    this.focusedPath,
    List<String>? selectedPaths,
  }) : selectedPaths = selectedPaths ?? [];
}

class FileSelectionNotifier extends Notifier<FileSelection> {
  final String path;

  FileSelectionNotifier(this.path);

  @override
  FileSelection build() {
    return FileSelection();
  }

  void onDownPressed() => _onUpOrDownPressed(1);

  void onUpPressed() => _onUpOrDownPressed(-1);

  void _onUpOrDownPressed(int movement) {
    final listValue = ref.read(sortedDirectoryList.call(path));
    final list = listValue.asData?.value;
    if (list == null) return;
    final focusedPath = state.focusedPath;
    final selectedPaths = state.selectedPaths;

    int index = focusedPath == null ? 0 : list.indexWhere((e) => e.path == focusedPath).coerceAtLeast(0);
    if (!HardwareKeyboard.instance.isControlPressed && //
        (focusedPath == null || !selectedPaths.contains(focusedPath))) {
      // if focusedPath is not selected, don't move so it is selected next
    } else {
      index = (index + movement).clamp(0, list.lastIndex);
    }

    final newFocusedPath = list[index].path;
    if (newFocusedPath != focusedPath) {
      state.focusedPath = newFocusedPath;
      ref.notifyListeners();
    }

    if (HardwareKeyboard.instance.isControlPressed) {
      return; // control moves focus without changing selection
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      if (!selectedPaths.contains(newFocusedPath)) {
        state.selectedPaths.add(newFocusedPath);
        ref.notifyListeners();
      }
    } else {
      if (selectedPaths.length != 1 || selectedPaths.first != newFocusedPath) {
        state.selectedPaths = [newFocusedPath];
        ref.notifyListeners();
      }
    }
  }

  void onClicked(String path) {
    // TODO: 1 handle shift and ctrl pressed
    if (state.focusedPath != path) {
      print('pass notifyListeners 1');
      state.focusedPath = path;
      ref.notifyListeners();
    }
    if (state.selectedPaths.length != 1 || state.selectedPaths.first != path) {
      print('pass notifyListeners 2');
      state.selectedPaths = [path];
      ref.notifyListeners();
    }
  }

  // TODO: 1 implement drag
}
