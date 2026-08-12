import 'package:dartx/dartx.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_icons.dart';
import 'package:from_zero_ui/packages/fz_opacity_gradient.dart';
import 'package:from_zero_ui/packages/fz_scrollbar.dart';
import 'package:from_zero_ui/packages/fz_state_positioning.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:motor/motor.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/clipboard.dart';
import 'package:wisp/providers/explorer.dart';
import 'package:wisp/providers/files.dart';
import 'package:wisp/providers/scaffold.dart';
import 'package:wisp/ui/file_conflict_dialog.dart';
import 'package:wisp/widgets/gestures.dart';
import 'package:wisp/widgets/table_view.dart';

class FilesList extends ConsumerStatefulWidget {
  const FilesList({super.key});

  @override
  ConsumerState<FilesList> createState() => _FilesListState();
}

class _FilesListState extends ConsumerState<FilesList> {
  late final verticalController = ScrollController();
  late final horizontalController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // PERF: 2 listening to the whole media query is expensive, so make sure this rebuilds the least amount of widgets possible
    final mediaQuery = MediaQuery.of(context);
    final appbarHeightValue = ref.watch(appbarHeight);
    final drawerWidthValue = ref.watch(drawerWidth);
    final currentDirectoryValue = ref.watch(currentDirectory);
    final filesNotifier = ref.watch(sortedDirectoryList.call(currentDirectoryValue).notifier);
    final files = ref.watch(sortedDirectoryList.call(currentDirectoryValue));
    return Stack(
      children: [
        // TODO: 2 make this a feature in ScrollbarFromZero .padding, and it will internally just do this with mediaQuery
        // for the scrollbars. This will also prevent the chilren from rebuilding, improving performance.
        MediaQuery(
          data: mediaQuery.copyWith(
            padding:
                mediaQuery.padding +
                EdgeInsets.only(
                  top: appbarHeightValue + _FilesTable.headerHeight,
                  left: drawerWidthValue,
                ),
          ),
          // TODO: 2 implement double-scrollbar support in ScrollbarFromZero
          child: ScrollbarFromZero(
            controller: verticalController,
            applyOpacityGradientToChildren: false,
            child: ScrollbarFromZero(
              controller: horizontalController,
              blockScrollNotifications: false,
              child: ScrollOpacityGradient(
                direction: OpacityGradient.vertical,
                scrollController: verticalController,
                child: _FilesTable(
                  data: files ?? [],
                  horizontalController: horizontalController,
                  verticalController: verticalController,
                ),
              ),
            ),
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final progress = ref.watch(filesNotifier.wholeProgress);
            if (progress.progress == 1) {
              return SizedBox.shrink();
            }
            return Positioned(
              right: 0,
              left: drawerWidthValue,
              top: appbarHeightValue,
              // TODO: 3 make better progressIndicator that maybe uses motor to smoothly change the value
              child: LinearProgressIndicator(
                value: progress.progress,
              ),
            );
          },
        ),
        Consumer(
          builder: (context, ref, _) {
            final operations = ref.watch(fileOperations);
            return Column(
              children: operations
                  .map(
                    (op) => ConflictListener(
                      key: ValueKey(op.startTime),
                      operation: op,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FilesTable extends ConsumerStatefulWidget {
  final List<FileData> data;
  final ScrollController? horizontalController;
  final ScrollController? verticalController;

  static const rowHeight = 36.0;
  static const headerHeight = 30.0;
  static const padding = EdgeInsets.only(left: 16, right: 24, bottom: 48);
  static const selectionBorderRadius = BorderRadius.all(Radius.circular(12));
  static const defaultColumns = <FileDataField>[.icon, .filename, .size, .type, .modified];

  const _FilesTable({
    required this.data,
    this.horizontalController,
    this.verticalController,
  });

  @override
  ConsumerState<_FilesTable> createState() => _FilesTableState();
}

class _FilesTableState extends ConsumerState<_FilesTable> {
  late var columns = List<FileDataField>.from(_FilesTable.defaultColumns);
  late var columnSizes = columns.map((e) => e.getDefaultWidth()).toList();

  @override
  Widget build(BuildContext context) {
    final appbarHeightValue = ref.watch(appbarHeight);
    final drawerWidthValue = ref.watch(drawerWidth);
    final currentDirectoryValue = ref.watch(currentDirectory);
    final selection = ref.watch(fileSelection.call(currentDirectoryValue));
    // print(
    //   'BUILD _FilesTable'
    //   '\n    file count: ${widget.data.length}'
    //   '\n    focused: ${selection.focusedPath}'
    //   '\n    selected: ${selection.selectedPaths}',
    // );
    final relayoutListener = ChangeNotifier();
    // TODO: 2 the ideal solution for this is: TableView takes a list of selected (selection would need to)
    // provide a list of FileData instead of just paths), then in didUpdateWidget, it can check if specifically
    // any of the rows that are visible changed their selected status, and only refresh if any of them did.
    ref.listen(fileSelection.call(currentDirectoryValue), (_, _) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      relayoutListener.notifyListeners();
    });
    return IconTheme(
      data: Theme.of(context).iconTheme.copyWith(size: 22),
      child: CallbackShortcuts(
        bindings: {
          ModifierIgnoringActivator(LogicalKeyboardKey.arrowUp, includeRepeats: true): () {
            ref.read(fileSelection.call(currentDirectoryValue).notifier).onUpPressed();
          },
          ModifierIgnoringActivator(LogicalKeyboardKey.arrowDown, includeRepeats: true): () {
            ref.read(fileSelection.call(currentDirectoryValue).notifier).onDownPressed();
          },
          ModifierIgnoringActivator(LogicalKeyboardKey.escape, includeRepeats: true): () {
            ref.read(fileSelection.call(currentDirectoryValue).notifier).deselectAll();
          },
          CharacterActivator('c', control: true, includeRepeats: false): () {
            ref.read(clipboard.notifier).setData(ClipboardFilesData(.copy, List.from(selection.selectedPaths)));
          },
          CharacterActivator('x', control: true, includeRepeats: false): () {
            ref.read(clipboard.notifier).setData(ClipboardFilesData(.cut, List.from(selection.selectedPaths)));
          },
          CharacterActivator('v', control: true, includeRepeats: false): () {
            final clipboardFiles = ref.read(clipboard);
            if (clipboardFiles == null) return;
            final operationsNotifier = ref.read(fileOperations.notifier);
            operationsNotifier.startOperation(
              type: clipboardFiles.operationType,
              paths: clipboardFiles.paths,
              destination: currentDirectoryValue,
            );
          },
        },
        child: Focus(
          autofocus: true,
          canRequestFocus: true,
          child: TableView(
            rows: widget.data,
            columns: columns,
            columnSizes: columnSizes,
            rowHeight: _FilesTable.headerHeight,
            headerHeight: _FilesTable.rowHeight,
            horizontalDetails: ScrollableDetails.horizontal(controller: widget.horizontalController),
            verticalDetails: ScrollableDetails.vertical(controller: widget.verticalController),
            relayoutListenable: relayoutListener,
            padding: _FilesTable.padding,
            hardPadding: EdgeInsets.only(
              top: appbarHeightValue,
              left: drawerWidthValue,
            ),
            selectedChecker: (fileData, _) {
              return selection.selectedPaths.contains(fileData.path);
            },
            builder: (context, fileData, fileField, _, _) {
              return _FileCell(fileData: fileData, fileField: fileField);
            },
            headerBuilder: (context, fileField, index) {
              _FileHeaderCell._globalKeys[fileField] ??= GlobalKey();
              return _FileHeaderCell(
                fileField: fileField,
                index: index,
                key: _FileHeaderCell._globalKeys[fileField],
                onDragColumn: onDragColumn,
                onDragGlobalPositionChange: onDragGlobalPositionChange,
                onResizeColumn: onResizeColumn,
              );
            },
            rowBackgroundBuilder: (context, fileData, rowIndex) {
              return _FileRowBackground(fileData: fileData, index: rowIndex, directory: currentDirectoryValue);
            },
            headerBackgroundBuilder: (context) {
              return Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.75),
              );
            },
            selectionBuilder: (context) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _FilesTable.selectionBorderRadius,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void onResizeColumn(int index, DragUpdateDetails details) {
    if (details.delta.dx == 0) return;
    setState(() {
      columnSizes[index] += details.delta.dx;
    });
  }

  void onDragGlobalPositionChange(FileDataField from, Offset dragGlobalOffset) {
    final renderObject = context.findRenderObject()! as RenderBox;
    final dragLocalOffset = renderObject.globalToLocal(dragGlobalOffset);
    final fromIndex = columns.indexOf(from);
    final fromOffset = _FilesTable.padding.left + columnSizes.sublist(0, fromIndex).sum();
    final List<int> toIndices = [];
    if (dragLocalOffset.dx == fromOffset) {
      return;
    } else if (dragLocalOffset.dx < fromOffset) {
      double accumulatedOffset = fromOffset;
      for (int i = fromIndex - 1; i > 0; i--) {
        if (accumulatedOffset < dragGlobalOffset.dx) {
          break;
        }
        toIndices.add(i);
        accumulatedOffset -= columnSizes[i];
      }
    } else {
      double accumulatedOffset = fromOffset;
      for (int i = fromIndex; i < columns.length; i++) {
        toIndices.add(i);
        accumulatedOffset += columnSizes[i];
        if (accumulatedOffset > dragGlobalOffset.dx) {
          break;
        }
      }
    }
    for (final i in toIndices) {
      onDragColumn(from, columns[i], dragGlobalOffset);
    }
  }

  void onDragColumn(FileDataField from, FileDataField to, Offset dragGlobalOffset) {
    for (final e in _FileHeaderCell._globalKeys.entries) {
      if (e.key == from) continue;
      e.value.currentState?.dragMouseOffset.value = Offset.zero;
    }
    if (from == to) {
      return;
    }
    final fromState = _FileHeaderCell._globalKeys[from]!.currentState!;
    final toState = _FileHeaderCell._globalKeys[to]!.currentState!;
    final fromPositioning = fromState.getPositioning();
    final toPositioning = toState.getPositioning();
    final diff = toPositioning.size.width - fromPositioning.size.width;
    if (diff > 0) {
      double penetration;
      if (fromPositioning.offset.dx < toPositioning.offset.dx) {
        penetration = dragGlobalOffset.dx - toPositioning.offset.dx;
      } else {
        penetration = toPositioning.offset.dx + toPositioning.size.width - dragGlobalOffset.dx;
      }
      if (diff - penetration > -12) {
        if (fromPositioning.offset.dx < toPositioning.offset.dx) {
          final fromContentPositioning = fromState.contentPositioningController.getPositioning();
          toState.dragMouseOffset.value = Offset(
            penetration + (fromContentPositioning.size.width / 2) + 18,
            0,
          );
        }
        return;
      }
    }
    print('Moving (dragging) column $from into $to');
    final indexFrom = columns.indexOf(from);
    final indexTo = columns.indexOf(to);
    final newColumns = List<FileDataField>.from(columns);
    final newColumnSizes = List<double>.from(columnSizes);
    newColumns.insert(indexTo, newColumns.removeAt(indexFrom));
    newColumnSizes.insert(indexTo, newColumnSizes.removeAt(indexFrom));
    setState(() {
      columns = newColumns;
      columnSizes = newColumnSizes;
    });
  }
}

class _FileRowBackground extends ConsumerWidget {
  static final copyMarkWidth = _FilesTable.padding.left / 2;

  final String directory;
  final FileData fileData;
  final int index;

  const _FileRowBackground({
    required this.directory,
    required this.fileData,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: 1 implement custom hover highlight
    // TODO: 1 implement custom ink splash only on double click
    final isFocused = ref.watch(
      fileSelection.call(directory).select((value) {
        return value.focusedPath == fileData.path;
      }),
    );
    final copyOperation = ref.watch(
      clipboard.select((value) {
        if (value == null) return null;
        if (!value.paths.contains(fileData.path)) return null;
        return value.operationType;
      }),
    );
    return Stack(
      children: [
        ColoredBox(
          color: index % 2 != 0 ? Colors.transparent : Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: EdgeInsets.only(
              left: _FilesTable.padding.left,
              right: _FilesTable.padding.right,
            ),
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                // Hack to prevent the delay on single click when a double click action is declared
                // https://github.com/flutter/flutter/issues/110300#issuecomment-1239969799
                SerialTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<SerialTapGestureRecognizer>(
                  () => SerialTapGestureRecognizer(
                    allowedButtonsFilter: (int buttons) => buttons == kPrimaryButton,
                  ),
                  (SerialTapGestureRecognizer instance) {
                    instance.onSerialTapDown = (SerialTapDownDetails details) {
                      if (details.count == 1) {
                        final currentDirectoryValue = ref.read(currentDirectory);
                        final notifier = ref.read(fileSelection.call(currentDirectoryValue).notifier);
                        notifier.onClicked(fileData.path);
                      } else if (details.count == 2) {
                        if (fileData.typeData?.type == .directory) {
                          ref.read(currentDirectory.notifier).setCurrentDirectory(fileData.path);
                        } else {
                          openFile(fileData);
                        }
                      }
                    };
                  },
                ),
              },
            ),
          ),
        ),
        if (copyOperation != null)
          Positioned(
            left: _FilesTable.padding.left - copyMarkWidth,
            width: _FilesTable.selectionBorderRadius.topLeft.x + copyMarkWidth,
            top: -copyMarkWidth,
            bottom: -copyMarkWidth,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadiusGeometry.horizontal(
                    left: Radius.circular(_FilesTable.selectionBorderRadius.topLeft.x + copyMarkWidth),
                  ),
                  border: BoxBorder.fromLTRB(
                    left: _getOperationBorderSide(context, copyOperation),
                    top: _getOperationBorderSide(context, copyOperation),
                    bottom: _getOperationBorderSide(context, copyOperation),
                  ),
                ),
              ),
            ),
          ),
        if (isFocused)
          Positioned.fill(
            left: _FilesTable.padding.left,
            right: _FilesTable.padding.right,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _FilesTable.selectionBorderRadius,
                  border: BoxBorder.all(
                    width: 2,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  BorderSide _getOperationBorderSide(BuildContext context, FileOperationType operation) {
    return BorderSide(
      width: copyMarkWidth,
      color: (switch (operation) {
        FileOperationType.copy => Colors.green,
        FileOperationType.cut => Colors.orange,
      }).withValues(alpha: 0.5),
    );
  }
}

class _FileCell extends StatelessWidget {
  final FileData fileData;
  final FileDataField fileField;

  const _FileCell({
    required this.fileData,
    required this.fileField,
  });

  @override
  Widget build(BuildContext context) {
    if (fileField == .icon) {
      return IgnorePointer(
        child: Container(
          padding: EdgeInsets.only(left: 10),
          alignment: Alignment.center,
          child: switch (fileData.typeData?.type) {
            null => SizedBox.shrink(),
            // TODO: 2 implement colors from theme
            FileType.directory => SymbolIcon(Symbols.folder, color: Colors.orange),
            FileType.video => SymbolIcon(Symbols.videocam, color: Colors.purple.shade400),
            FileType.audio => SymbolIcon(Symbols.audiotrack, color: Colors.red),
            FileType.image => SymbolIcon(Symbols.image, color: Colors.blue),
            FileType.document => SymbolIcon(Symbols.text_snippet, color: Colors.green),
            FileType.other => SymbolIcon(Symbols.question_mark, color: Colors.grey),
          },
        ),
      );
    }
    final value = fileData.getFormatted(context, fileField);
    return IgnorePointer(
      child: Container(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.centerLeft,
        // TODO: 1 implement a good Text widget that shows truncated as a tooltip on hover, truncates smartly, etc.
        child: Text(
          value ?? '',
          maxLines: 1,
        ), // TODO: 2 show loading if value is null?
      ),
    );
  }
}

class _FileHeaderCell extends ConsumerStatefulWidget {
  // needed so the draggables return to the correct place
  static final _globalKeys = <FileDataField, GlobalKey<_FileHeaderCellState>>{};

  final int index;
  final FileDataField fileField;
  final void Function(FileDataField from, Offset offset) onDragGlobalPositionChange;
  final void Function(FileDataField from, FileDataField to, Offset dragGlobalOffset) onDragColumn;
  final void Function(int index, DragUpdateDetails details) onResizeColumn;

  const _FileHeaderCell({
    required this.index,
    required this.fileField,
    required this.onDragGlobalPositionChange,
    required this.onDragColumn,
    required this.onResizeColumn,
    super.key,
  });

  @override
  ConsumerState<_FileHeaderCell> createState() => _FileHeaderCellState();
}

class _FileHeaderCellState extends ConsumerState<_FileHeaderCell> with StatePositioningMixin {
  final contentPositioningController = PositioningController();
  final ValueNotifier<Offset> dragMouseOffset = ValueNotifier(Offset.zero);

  static const cellPadding = 8.0;
  static const resizeDetectorWidth = 9.0; // *2 because it is on the left and right

  @override
  Widget build(BuildContext context) {
    return ExcludeFocusTraversal(
      child: Stack(
        children: [
          MotionDraggable(
            data: widget.fileField,
            motion: MaterialSpringMotion.standardSpatialSlow(),
            axis: Axis.horizontal,
            dragAnchorStrategy: (Draggable<Object> draggable, BuildContext context, Offset position) {
              final renderObject = context.findRenderObject()! as RenderBox;
              final result = renderObject.globalToLocal(position);
              final contentPositioning = contentPositioningController.getPositioning();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                dragMouseOffset.value = result - Offset(contentPositioning.size.width / 2 + cellPadding, 0);
              });
              return result;
            },
            onDragEnd: (details) {
              for (final e in _FileHeaderCell._globalKeys.entries) {
                if (e.key == widget.fileField) continue;
                e.value.currentState?.dragMouseOffset.value = Offset.zero;
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                dragMouseOffset.value = Offset.zero;
              });
            },
            onDragUpdate: (details) {
              widget.onDragGlobalPositionChange(widget.fileField, details.globalPosition);
            },
            feedback: Builder(
              builder: (builderContext) {
                final positioning = getPositioning();
                return IconTheme(
                  data: IconTheme.of(context),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      // width: positioning.size.width,
                      height: positioning.size.height,
                      child: _buildContent(context),
                    ),
                  ),
                );
              },
            ),
            child: _buildContent(
              context,
              positioningController: contentPositioningController,
            ),
          ),
          // Positioned.fill(
          //   child: DragTarget(
          //     onMove: (details) {
          //       if (widget.fileField == .icon) return;
          //       if (details.data case final FileDataField data) {
          //         widget.onDragColumn(data, widget.fileField, );
          //       }
          //     },
          //     builder: (_, _, _) => Container(),
          //   ),
          // ),
          if (widget.index >= 2)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: resizeDetectorWidth,
              child: MouseRegion(
                // cursor: SystemMouseCursors.resizeLeftRight,
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    widget.onResizeColumn(widget.index - 1, details);
                  },
                ),
              ),
            ),
          if (widget.index >= 1)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: resizeDetectorWidth,
              child: MouseRegion(
                // cursor: SystemMouseCursors.resizeLeftRight,
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    widget.onResizeColumn(widget.index, details);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    PositioningController? positioningController,
  }) {
    Widget text = Text(
      widget.fileField.getUiName(context),
      maxLines: 1,
      style: Theme.of(context).textTheme.labelMedium,
    );
    if (positioningController != null) {
      text = PositioningMonitor(
        controller: positioningController,
        child: text,
      );
    }
    return ValueListenableBuilder(
      valueListenable: dragMouseOffset,
      builder: (context, mouseOffset, child) {
        return MotionPadding(
          motion: MaterialSpringMotion.standardSpatialSlow(),
          padding: EdgeInsetsGeometry.only(left: mouseOffset.dx),
          child: child!,
        );
      },
      child: InkWell(
        onTap: widget.fileField == .icon
            ? null
            : () {
                ref.read(currentSort.notifier).setField(widget.fileField);
              },
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: cellPadding),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IntrinsicWidth(
              child: Row(
                children: [
                  Expanded(
                    child: text,
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final currentSortValue = ref.watch(currentSort);
                      if (currentSortValue.field != widget.fileField) {
                        return SizedBox.shrink();
                      }
                      return SymbolIcon(
                        currentSortValue.asc ? Symbols.arrow_drop_down : Symbols.arrow_drop_up,
                        color: Theme.of(context).colorScheme.outline,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
