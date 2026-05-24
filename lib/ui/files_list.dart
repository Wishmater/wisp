import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_api_handling.dart';
import 'package:from_zero_ui/packages/fz_opacity_gradient.dart';
import 'package:from_zero_ui/packages/fz_scrollbar.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/files.dart';
import 'package:wisp/providers/scaffold.dart';
import 'package:wisp/widgets/table_view.dart';

class FilesList extends ConsumerWidget {
  const FilesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const columns = <FileDataField>[.filename, .size, .type, .modified];
    const columnSizes = <double>[512, 128, 128, 256];
    final currentDirectoryValue = ref.watch(currentDirectory);
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
    final notifier = ref.watch(sortedDirectoryList.call(currentDirectoryValue).notifier);
    // PERF: 2 listening to the whole media query is expensive, so make sure this rebuilds the least amount of widgets possible
    final mediaQuery = MediaQuery.of(context);
    final appbarHeightValue = ref.watch(appbarHeight);
    final drawerWidthValue = ref.watch(drawerWidth);
    return Stack(
      children: [
        // TODO: 2 make this a feature in ScrollbarFromZero .padding, and it will internally just do this with mediaQuery
        // for the scrollbars
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
                child: ApiProviderBuilder(
                  provider: sortedDirectoryList.call(currentDirectoryValue),
                  transitionDuration: Duration.zero,
                  addLoadingStateAsValueKeys: false,
                  loadingBuilder: (context, progress) {
                    if (progress == null) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(),
                      );
                    }
                    return ValueListenableBuilder(
                      valueListenable: progress,
                      builder: (context, value, _) {
                        return Align(
                          alignment: Alignment.topCenter,
                          child: LinearProgressIndicator(
                            value: value,
                          ),
                        );
                      },
                    );
                  },
                  dataBuilder: (context, data) {
                    // PERF: 2 maybe move this into a separate widget to rebuild less
                    final appbarHeightValue = ref.watch(appbarHeight);
                    final drawerWidthValue = ref.watch(drawerWidth);
                    return TableView(
                      rows: data.toList(),
                      columns: columns,
                      columnSizes: columnSizes,
                      rowHeight: 36,
                      headerHeight: 48,
                      horizontalDetails: ScrollableDetails.horizontal(controller: horizontalController),
                      verticalDetails: ScrollableDetails.vertical(controller: verticalController),
                      padding: EdgeInsets.only(
                        top: appbarHeightValue,
                        left: 16 + drawerWidthValue,
                        right: 24,
                        bottom: 48,
                      ),
                      builder: (context, fileData, fileField, _, _) {
                        return FileCell(fileData: fileData, fileField: fileField);
                      },
                      headerBuilder: (context, fileField, _) {
                        return HeaderCell(fileField: fileField);
                      },
                      rowBackgroundBuilder: (context, fileData, _) {
                        return InkWell(
                          onDoubleTap: () {
                            if (fileData.typeData?.type == .directory) {
                              ref.read(currentDirectory.notifier).setCurrentDirectory(fileData.path);
                            } else {
                              openFile(fileData);
                            }
                          },
                        );
                      },
                      headerBackgroundBuilder: (context) {
                        return Material(
                          color: Theme.of(context).canvasColor.withValues(alpha: 0.75),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: notifier.wholePercentageNotifier,
          builder: (context, progress, _) {
            if (progress == 1) {
              return SizedBox.shrink();
            }
            return Positioned(
              left: 0,
              right: 0,
              top: 0,
              // TODO: 3 make better progressIndicator that maybe use motor to smoothly change the value
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

class FileCell extends StatelessWidget {
  final FileData fileData;
  final FileDataField fileField;

  const FileCell({
    required this.fileData,
    required this.fileField,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final value = fileData.getFormatted(context, fileField);
    return IgnorePointer(
      child: Container(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          value ?? '',
          maxLines: 1,
        ), // TODO: 2 show loading if value is null?
      ),
    );
  }
}

class HeaderCell extends ConsumerWidget {
  final FileDataField fileField;

  const HeaderCell({
    required this.fileField,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = fileField.getUiName(context);
    return InkWell(
      onTap: () {
        ref.read(currentSort.notifier).setField(fileField);
      },
      child: Padding(
        padding: EdgeInsetsGeometry.symmetric(horizontal: 6, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: IntrinsicWidth(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final currentSortValue = ref.watch(currentSort);
                    if (currentSortValue.$1 != fileField) {
                      return SizedBox.shrink();
                    }
                    return Icon(
                      currentSortValue.$2 ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
