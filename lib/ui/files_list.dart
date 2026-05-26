import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_opacity_gradient.dart';
import 'package:from_zero_ui/packages/fz_scrollbar.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/explorer.dart';
import 'package:wisp/providers/files.dart';
import 'package:wisp/providers/scaffold.dart';
import 'package:wisp/widgets/gestures.dart';
import 'package:wisp/widgets/table_view.dart';

class FilesList extends ConsumerWidget {
  const FilesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
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
                  top: appbarHeightValue,
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
                  data: files.value ?? [],
                  horizontalController: horizontalController,
                  verticalController: verticalController,
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: filesNotifier.wholePercentageNotifier,
          builder: (context, progress, _) {
            if (progress == 1) {
              return SizedBox.shrink();
            }
            return Positioned(
              right: 0,
              left: drawerWidthValue,
              top: appbarHeightValue,
              // TODO: 3 make better progressIndicator that maybe uses motor to smoothly change the value
              child: LinearProgressIndicator(
                value: progress,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FilesTable extends ConsumerWidget {
  final List<FileData> data;
  final ScrollController? horizontalController;
  final ScrollController? verticalController;

  static const columns = <FileDataField>[.filename, .size, .type, .modified];
  static const columnSizes = <double>[512, 128, 128, 256];
  static const padding = EdgeInsets.only(
    left: 16,
    right: 24,
    bottom: 48,
  );
  static const selectionBorderRadius = BorderRadius.all(Radius.circular(12));

  const _FilesTable({
    required this.data,
    this.horizontalController,
    this.verticalController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appbarHeightValue = ref.watch(appbarHeight);
    final drawerWidthValue = ref.watch(drawerWidth);
    final currentDirectoryValue = ref.watch(currentDirectory);
    final selection = ref.watch(fileSelection.call(currentDirectoryValue));
    print('BUILD ${selection.focusedPath} ${selection.selectedPaths}');
    final relayoutListener = ChangeNotifier();
    // TODO: 2 the ideal solution for this is: TableView takes a list of selected (selection would need to)
    // provide a list of FileData instead of just paths), then in didUpdateWidget, it can check if specifically
    // any of the rows that are visible changed their selected status, and only refresh if any of them did.
    ref.listen(fileSelection.call(currentDirectoryValue), (_, _) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      relayoutListener.notifyListeners();
    });
    return CallbackShortcuts(
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
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        child: TableView(
          rows: data,
          columns: columns,
          columnSizes: columnSizes,
          rowHeight: 36,
          headerHeight: 30,
          horizontalDetails: ScrollableDetails.horizontal(controller: horizontalController),
          verticalDetails: ScrollableDetails.vertical(controller: verticalController),
          relayoutListenable: relayoutListener,
          padding: padding,
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
          headerBuilder: (context, fileField, _) {
            return _FileHeaderCell(fileField: fileField);
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
                borderRadius: selectionBorderRadius,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FileRowBackground extends ConsumerWidget {
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
    return ColoredBox(
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
          child: ref.watch(fileSelection.call(directory)).focusedPath != fileData.path
              ? null
              : DecoratedBox(
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

class _FileHeaderCell extends ConsumerWidget {
  final FileDataField fileField;

  const _FileHeaderCell({
    required this.fileField,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExcludeFocusTraversal(
      child: InkWell(
        onTap: () {
          ref.read(currentSort.notifier).setField(fileField);
        },
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IntrinsicWidth(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fileField.getUiName(context),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final currentSortValue = ref.watch(currentSort);
                      if (currentSortValue.field != fileField) {
                        return SizedBox.shrink();
                      }
                      return Icon(
                        currentSortValue.asc ? Icons.arrow_drop_down : Icons.arrow_drop_up,
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
