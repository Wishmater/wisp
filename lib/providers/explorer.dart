import 'dart:io';
import 'dart:math' show min, max;

import 'package:dartx/dartx.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/files.dart';
import 'package:wisp/widgets/table_view.dart';

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
    if (!path.endsWith('/')) {
      path += '/';
    }
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
  // Dolphin starts with focusedPath=firstRow, so when you press down for the first time,
  // the second row is selected. I like it better this way (how Nautilus works), where there
  // is no initial focus, so when you press down or up the first row is focused and selected
  String? focusedPath;
  // PERF: 3 this should be a structure that facilitates querying .contains(), maybe a Set?
  List<String> selectedPaths;

  FileSelection({
    this.focusedPath,
    List<String>? selectedPaths,
  }) : selectedPaths = selectedPaths ?? [];
}

class FileSelectionNotifier extends Notifier<FileSelection> {
  final String directoryPath;

  FileSelectionNotifier(this.directoryPath);

  @override
  FileSelection build() {
    return FileSelection();
  }

  void deselectAll() {
    state.selectedPaths = [];
    ref.notifyListeners();
  }

  void onDownPressed({
    bool? isControlPressed,
    bool? isShiftPressed,
    bool? isAltPressed,
  }) => _onUpOrDownPressed(1);

  void onUpPressed({
    bool? isControlPressed,
    bool? isShiftPressed,
    bool? isAltPressed,
  }) => _onUpOrDownPressed(-1);

  void _onUpOrDownPressed(
    int movement, {
    bool? isControlPressed,
    bool? isShiftPressed,
    bool? isAltPressed,
  }) {
    // TODO: 1 handle alt
    isControlPressed ??= HardwareKeyboard.instance.isControlPressed;
    isShiftPressed ??= HardwareKeyboard.instance.isShiftPressed;
    isAltPressed ??= HardwareKeyboard.instance.isAltPressed;
    final list = ref.read(sortedDirectoryList.call(directoryPath));
    if (list == null) return;
    final focusedPath = state.focusedPath;
    final selectedPaths = state.selectedPaths;

    int index = focusedPath == null ? 0 : list.indexWhere((e) => e.path == focusedPath).coerceAtLeast(0);
    if (!isControlPressed && (focusedPath == null || !selectedPaths.contains(focusedPath))) {
      // If focusedPath is not selected, don't move so it is selected next, Nautilus works this way.
      // Dolphin doesn't behave this way, it instead moves out of the focused and then selects, so there is
      // no way to select a focused element that is not already selected.
    } else {
      index = (index + movement).clamp(0, list.lastIndex);
    }

    final newFocusedPath = list[index].path;
    if (newFocusedPath != focusedPath) {
      state.focusedPath = newFocusedPath;
      ref.notifyListeners();
    } else {
      // // In dolphin if you press up/down and you are already focusing the last element,
      // // that element won't be selected, that is what this return would accomplish.
      // // I prefer however, Nautilus's behaviour, where it does select that last element.
      // return;
    }

    // Ctrl takes priority over shift when moving with arrows in both Dolphin and Nautilus
    if (isControlPressed) {
      return; // control moves focus without changing selection
    }
    if (isShiftPressed) {
      if (!selectedPaths.contains(newFocusedPath)) {
        state.selectedPaths.add(newFocusedPath);
        ref.notifyListeners();
      } else {
        final oppositeIndex = index + movement * -2;
        final oppositePath = list.getOrNull(oppositeIndex);
        final isAtEdge = oppositePath == null || !selectedPaths.contains(oppositePath.path);
        if (isAtEdge) {
          state.selectedPaths.remove(focusedPath);
          ref.notifyListeners();
        }
      }
    } else {
      if (selectedPaths.length != 1 || selectedPaths.first != newFocusedPath) {
        state.selectedPaths = [newFocusedPath];
        ref.notifyListeners();
      }
    }
  }

  void onClicked(String newPath) {
    final initialFocusedPath = state.focusedPath;
    if (initialFocusedPath != newPath) {
      state.focusedPath = newPath;
      ref.notifyListeners();
    }
    // It's weird that shift takes priority over ctrl here and it's the other way around
    // when moving with arrows, but that's how both Dolphin and Nautilus work.
    if (HardwareKeyboard.instance.isShiftPressed) {
      final list = ref.read(sortedDirectoryList.call(directoryPath));
      if (list == null) return; // this shouldn't happen
      final initialIndex = initialFocusedPath == null
          ? 0
          : list.indexWhere((e) => e.path == initialFocusedPath).coerceAtLeast(0);
      final newIndex = list.indexWhere((e) => e.path == newPath).coerceAtLeast(0);
      List<(String, bool)> affected = [];
      for (int i = min(initialIndex, newIndex); i <= max(initialIndex, newIndex); i++) {
        affected.add((list[i].path, state.selectedPaths.contains(list[i].path)));
      }
      final select = affected.any((e) => !e.$2);
      for (final e in affected) {
        final selectLocal = select || e.$1 == newPath;
        if (selectLocal != e.$2) {
          if (selectLocal) {
            state.selectedPaths.add(e.$1);
          } else {
            state.selectedPaths.remove(e.$1);
          }
          ref.notifyListeners();
        }
      }
    } else if (HardwareKeyboard.instance.isControlPressed) {
      if (state.selectedPaths.contains(newPath)) {
        state.selectedPaths.remove(newPath);
      } else {
        state.selectedPaths.add(newPath);
      }
      ref.notifyListeners();
    } else {
      if (state.selectedPaths.length != 1 || state.selectedPaths.first != newPath) {
        state.selectedPaths = [newPath];
        ref.notifyListeners();
      }
    }
  }

  // TODO: 1 implement drag
}
