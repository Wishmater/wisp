import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_api_handling.dart';
import 'package:from_zero_ui/packages/fz_opacity_gradient.dart';
import 'package:from_zero_ui/packages/fz_scrollbar.dart';
import 'package:wisp/models/file_data_field.dart';
import 'package:wisp/providers/files.dart';
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
    // TODO: 2 implement double-scrollbar support in ScrollbarFromZero
    return Stack(
      children: [
        ScrollbarFromZero(
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
                  print('BUILD: ${data.map((e) => e.filename)}');
                  return TableView(
                    rows: data.toList(),
                    columns: columns,
                    columnSizes: columnSizes,
                    rowHeight: 36,
                    headerHeight: 48,
                    horizontalDetails: ScrollableDetails.horizontal(controller: horizontalController),
                    verticalDetails: ScrollableDetails.vertical(controller: verticalController),
                    padding: EdgeInsets.only(left: 16, right: 24, bottom: 48),
                    builder: (context, fileData, fileField, _, _) {
                      final value = fileData.getFormatted(context, fileField);
                      return InkWell(
                        onTap: () {
                          print('XDD');
                        },
                        child: Container(
                          padding: EdgeInsetsGeometry.symmetric(horizontal: 6, vertical: 4),
                          alignment: Alignment.centerLeft,
                          child: Text(value ?? ''), // TODO: 2 show loading if value is null?
                        ),
                      );
                    },
                    headerBuilder: (context, fileField, _) {
                      final value = fileField.getUiName(context);
                      return InkWell(
                        onTap: () {
                          ref.read(currentSort.notifier).setField(fileField);
                        },
                        child: Container(
                          padding: EdgeInsetsGeometry.symmetric(horizontal: 6, vertical: 4),
                          alignment: Alignment.centerLeft,
                          child: Text(value),
                        ),
                      );
                    },
                    headerBackgroundBuilder: (context) {
                      return InkWell(
                        onTap: () {
                          print('WTF');
                        },
                        child: Material(color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.75)),
                      );
                    },
                    rowBackgroundBuilder: (context, fileData, _) {
                      return Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onDoubleTap: () {
                            if (fileData.typeData?.type == .directory) {
                              ref.read(currentDirectory.notifier).setCurrentDirectory(fileData.path);
                            } else {
                              openFile(fileData);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
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
