import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fz_api_handling/fz_api_handling.dart';
import 'package:fz_opacity_gradient/fz_opacity_gradient.dart';
import 'package:fz_scrollbar/fz_scrollbar.dart';
import 'package:wisp/models/file_data.dart';
import 'package:wisp/providers/files.dart';

class FilesList extends ConsumerWidget {
  const FilesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const columns = <FileStatType>[.filename, .size, .modified];
    const columnSizes = <double>[512, 128, 256];
    final currentDirectoryValue = ref.watch(currentDirectory);
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
    verticalController.addListener(() {
      // print(horizontalController.positions.firstOrNull?.axis);
    });
    return ScrollbarFromZero(
      controller: verticalController,
      applyOpacityGradientToChildren: false,
      child: ScrollbarFromZero(
        controller: horizontalController,
        blockScrollNotifications: false,
        child: ScrollOpacityGradient(
          direction: OpacityGradient.vertical,
          scrollController: verticalController,
          child: ApiProviderBuilder(
            provider: directoryList.call(currentDirectoryValue),
            dataBuilder: (context, data) {
              return FilesListView(
                colCount: columns.length,
                columnSizes: columnSizes,
                rowCount: data.length,
                rowHeight: 48,
                horizontalDetails: ScrollableDetails.horizontal(controller: horizontalController),
                verticalDetails: ScrollableDetails.vertical(controller: verticalController),
                delegate: TwoDimensionalChildBuilderDelegate(
                  maxXIndex: columns.length - 1,
                  maxYIndex: data.length - 1,
                  builder: (BuildContext context, ChildVicinity vicinity) {
                    final type = columns[vicinity.xIndex];
                    final file = data[vicinity.yIndex];
                    return Text(file.getStatTypeFormatted(context, type));
                  },
                ),
              );
              // return ListView.builder(
              //   itemCount: data.length,
              //   itemBuilder: (context, index) {
              //     final fileData = data[index];
              //     return ListTile(
              //       leading: Icon(fileData is DirectoryData ? Icons.folder : Icons.file_copy),
              //       title: Text(fileData.filename),
              //       onTap: () {
              //         if (fileData is DirectoryData) {
              //           setCurrentDirectory(ref, fileData.path);
              //         } else {
              //           openFile(fileData);
              //         }
              //       },
              //     );
              //   },
              // );
            },
          ),
        ),
      ),
    );
  }
}

class FilesListView extends TwoDimensionalScrollView {
  final int rowCount;
  final int colCount;
  final double rowHeight;
  final List<double> columnSizes;

  const FilesListView({
    required super.delegate,
    required this.rowCount,
    required this.colCount,
    required this.rowHeight,
    required this.columnSizes,
    super.verticalDetails,
    super.horizontalDetails,
    super.key,
  }) : assert(rowCount >= 0),
       assert(colCount >= 0),
       assert(rowHeight > 0),
       assert(columnSizes.length == colCount),
       super();

  @override
  Widget buildViewport(BuildContext context, ViewportOffset verticalOffset, ViewportOffset horizontalOffset) {
    return FilesListViewport(
      verticalOffset: verticalOffset,
      horizontalOffset: horizontalOffset,
      mainAxis: mainAxis,
      delegate: delegate,
      rowCount: rowCount,
      colCount: colCount,
      rowHeight: rowHeight,
      columnSizes: columnSizes,
    );
  }
}

class FilesListViewport extends TwoDimensionalViewport {
  final int rowCount;
  final int colCount;
  final double rowHeight;
  final List<double> columnSizes;

  const FilesListViewport({
    required super.verticalOffset,
    required super.horizontalOffset,
    required super.delegate,
    required super.mainAxis,
    required this.rowCount,
    required this.colCount,
    required this.rowHeight,
    required this.columnSizes,
    super.key,
  }) : super(
         verticalAxisDirection: .down,
         horizontalAxisDirection: .right,
       );

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context) {
    return RenderFilesListViewport(
      verticalOffset: verticalOffset,
      verticalAxisDirection: verticalAxisDirection,
      horizontalOffset: horizontalOffset,
      horizontalAxisDirection: horizontalAxisDirection,
      mainAxis: mainAxis,
      delegate: delegate,
      childManager: context as TwoDimensionalChildManager,
      rowCount: rowCount,
      colCount: colCount,
      rowHeight: rowHeight,
      columnSizes: columnSizes,
    );
  }
}

class RenderFilesListViewport extends RenderTwoDimensionalViewport {
  final int rowCount;
  final int colCount;
  final double rowHeight;
  final List<double> columnSizes;

  RenderFilesListViewport({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    required super.childManager,
    required this.rowCount,
    required this.colCount,
    required this.rowHeight,
    required this.columnSizes,
  });

  @override
  void layoutChildSequence() {
    final cellHeight = rowHeight;
    final columnOffsets = List.generate(columnSizes.length, (i) => columnSizes.sublist(0, i).sum());
    final maxWidth = columnOffsets.last + columnSizes.last;
    final maxHeight = cellHeight * rowCount;
    horizontalOffset.applyContentDimensions(0, (maxWidth - viewportDimension.width).coerceAtLeast(0));
    verticalOffset.applyContentDimensions(0, (maxHeight - viewportDimension.height).coerceAtLeast(0));

    // Compute visible column range
    final renderStartX = horizontalOffset.pixels - cacheExtent;
    final renderEndX = horizontalOffset.pixels + viewportDimension.width + cacheExtent;
    final firstFullyVisibleCol = columnOffsets.indexWhere((e) => e > renderStartX);
    final firstCol = firstFullyVisibleCol == -1 ? colCount - 1 : (firstFullyVisibleCol - 1).coerceAtLeast(0);
    final lastFullyVisibleCol = columnOffsets.indexWhere((e) => e > renderEndX);
    final lastCol = lastFullyVisibleCol == -1 ? colCount - 1 : firstFullyVisibleCol;

    // Compute visible row range
    final renderStartY = verticalOffset.pixels - cacheExtent;
    final renderEndY = verticalOffset.pixels + viewportDimension.height + cacheExtent;
    final int firstRow = (renderStartY / cellHeight).floor().clamp(0, rowCount - 1);
    final int lastRow = (renderEndY / cellHeight).ceil().clamp(0, rowCount - 1);

    for (int row = firstRow; row <= lastRow; row++) {
      for (int col = firstCol; col <= lastCol; col++) {
        final cellWidth = columnSizes[col];
        final vicinity = ChildVicinity(xIndex: col, yIndex: row);
        final RenderBox? child = buildOrObtainChildFor(vicinity);
        if (child == null) continue;
        final parentData = child.parentData! as TwoDimensionalViewportParentData;
        // Layout the cell with a fixed tight constraint.
        child.layout(BoxConstraints.tight(Size(cellWidth, cellHeight)));
        // Position the cell relative to the viewport origin.
        parentData.layoutOffset = Offset(
          columnOffsets[col] - horizontalOffset.pixels,
          row * cellHeight - verticalOffset.pixels,
        );
      }
    }
  }
}
