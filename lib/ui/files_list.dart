import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_api_handling.dart';
import 'package:from_zero_ui/packages/fz_opacity_gradient.dart';
import 'package:from_zero_ui/packages/fz_scrollbar.dart';
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
    // TODO: 2 implement double-scrollbar support in ScrollbarFromZero
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
                padding: EdgeInsets.only(left: 16, right: 24, bottom: 48),
                delegate: FilesChildDelegate(
                  maxXIndex: columns.length - 1,
                  maxYIndex: data.length - 1,
                  onRowDoubleTap: (index) {
                    final fileData = data[index];
                    if (fileData is DirectoryData) {
                      ref.read(currentDirectory.notifier).setCurrentDirectory(fileData.path);
                    } else {
                      openFile(fileData);
                    }
                  },
                  builder: (BuildContext context, ChildVicinity vicinity) {
                    final statType = columns[vicinity.xIndex];
                    final fileData = data[vicinity.yIndex];
                    return Container(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 6, vertical: 4),
                      alignment: Alignment.centerLeft,
                      child: Text(fileData.getStatTypeFormatted(context, statType)),
                    );
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
  final EdgeInsets padding;

  const FilesListView({
    required super.delegate,
    required this.rowCount,
    required this.colCount,
    required this.rowHeight,
    required this.columnSizes,
    this.padding = EdgeInsets.zero,
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
      padding: padding,
    );
  }
}

class FilesListViewport extends TwoDimensionalViewport {
  final int rowCount;
  final int colCount;
  final double rowHeight;
  final List<double> columnSizes;
  final EdgeInsets padding;

  const FilesListViewport({
    required super.verticalOffset,
    required super.horizontalOffset,
    required super.delegate,
    required super.mainAxis,
    required this.rowCount,
    required this.colCount,
    required this.rowHeight,
    required this.columnSizes,
    this.padding = EdgeInsets.zero,
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
      padding: padding,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFilesListViewport renderObject) {
    renderObject
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalOffset = verticalOffset
      ..verticalAxisDirection = verticalAxisDirection
      ..mainAxis = mainAxis
      ..delegate = delegate
      ..cacheExtent = cacheExtent
      ..clipBehavior = clipBehavior
      ..rowCount = rowCount
      ..colCount = colCount
      ..rowHeight = rowHeight
      ..columnSizes = columnSizes
      ..padding = padding;
  }
}

class RenderFilesListViewport extends RenderTwoDimensionalViewport {
  RenderFilesListViewport({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    required super.childManager,
    required int rowCount,
    required int colCount,
    required double rowHeight,
    required List<double> columnSizes,
    EdgeInsets padding = EdgeInsets.zero,
  }) : _rowCount = rowCount,
       _colCount = colCount,
       _rowHeight = rowHeight,
       _columnSizes = columnSizes,
       _padding = padding;

  int get rowCount => _rowCount;
  int _rowCount;
  set rowCount(int value) {
    if (_rowCount == value) return;
    _rowCount = value;
    markNeedsLayout();
  }

  int get colCount => _colCount;
  int _colCount;
  set colCount(int value) {
    if (_colCount == value) return;
    _colCount = value;
    markNeedsLayout();
  }

  double get rowHeight => _rowHeight;
  double _rowHeight;
  set rowHeight(double value) {
    if (_rowHeight == value) return;
    _rowHeight = value;
    markNeedsLayout();
  }

  List<double> get columnSizes => _columnSizes;
  List<double> _columnSizes;
  set columnSizes(List<double> value) {
    if (_columnSizes == value) return;
    _columnSizes = value;
    markNeedsLayout();
  }

  EdgeInsets get padding => _padding;
  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  @override
  void layoutChildSequence() {
    final cellHeight = rowHeight;
    final columnOffsets = List.generate(columnSizes.length, (i) => columnSizes.sublist(0, i).sum());
    final maxWidth = columnOffsets.last + columnSizes.last + padding.horizontal;
    final maxHeight = cellHeight * rowCount + padding.vertical;
    horizontalOffset.applyContentDimensions(0, (maxWidth - viewportDimension.width).coerceAtLeast(0));
    verticalOffset.applyContentDimensions(0, (maxHeight - viewportDimension.height).coerceAtLeast(0));

    // Compute visible column range
    final renderStartX = (horizontalOffset.pixels - cacheExtent - padding.left).coerceAtLeast(0);
    final renderEndX = horizontalOffset.pixels + viewportDimension.width + cacheExtent;
    final firstFullyVisibleCol = columnOffsets.indexWhere((e) => e > renderStartX);
    final firstCol = firstFullyVisibleCol == -1 ? colCount - 1 : (firstFullyVisibleCol - 1).coerceAtLeast(0);
    final lastFullyVisibleCol = columnOffsets.indexWhere((e) => e > renderEndX);
    final lastCol = lastFullyVisibleCol == -1 ? colCount - 1 : firstFullyVisibleCol;

    // Compute visible row range
    final renderStartY = (verticalOffset.pixels - cacheExtent - padding.top).coerceAtLeast(0);
    final renderEndY = verticalOffset.pixels + viewportDimension.height + cacheExtent;
    final int firstRow = (renderStartY / cellHeight).floor().clamp(0, rowCount - 1);
    final int lastRow = (renderEndY / cellHeight).ceil().clamp(0, rowCount - 1);

    for (int row = firstRow; row <= lastRow; row++) {
      // Layout row-wide hit target
      final RenderBox? rowGesture = buildOrObtainChildFor(RowGestureChildVicinity(yIndex: row));
      if (rowGesture != null) {
        final rowGestureParentData = rowGesture.parentData! as TwoDimensionalViewportParentData;
        // TODO: 3 it probably looks better if we limit this to the viewport with instead of spanning over edges
        rowGesture.layout(BoxConstraints.tight(Size(maxWidth, cellHeight)));
        rowGestureParentData.layoutOffset = Offset(
          0,
          padding.top + row * cellHeight - verticalOffset.pixels,
        );
      }
      // Layout row cells
      for (int col = firstCol; col <= lastCol; col++) {
        final RenderBox? child = buildOrObtainChildFor(ChildVicinity(xIndex: col, yIndex: row));
        if (child == null) continue;
        final cellWidth = columnSizes[col];
        final parentData = child.parentData! as TwoDimensionalViewportParentData;
        child.layout(BoxConstraints.tight(Size(cellWidth, cellHeight)));
        parentData.layoutOffset = Offset(
          padding.left + columnOffsets[col] - horizontalOffset.pixels,
          padding.top + row * cellHeight - verticalOffset.pixels,
        );
      }
    }
  }
}

class RowGestureChildVicinity extends ChildVicinity {
  const RowGestureChildVicinity({required super.yIndex}) : super(xIndex: -1);
}

class SelectedRowChildVicinity extends ChildVicinity {
  final int extent;
  const SelectedRowChildVicinity({
    required super.yIndex,
    required this.extent,
  }) : assert(extent > 0),
       super(xIndex: -2);
}

class FilesChildDelegate extends TwoDimensionalChildBuilderDelegate {
  void Function(int rowIndex)? onRowTap;
  void Function(int rowIndex)? onRowDoubleTap;

  FilesChildDelegate({
    required super.builder,
    this.onRowTap,
    this.onRowDoubleTap,
    super.maxXIndex,
    super.maxYIndex,
    super.addRepaintBoundaries,
    super.addAutomaticKeepAlives,
  });

  @override
  Widget? build(BuildContext context, covariant ChildVicinity vicinity) {
    if (vicinity is RowGestureChildVicinity) {
      if (onRowTap == null && onRowDoubleTap == null) {
        return null;
      }
      return InkWell(
        onTap: onRowTap == null ? null : () => onRowTap!(vicinity.yIndex),
        onDoubleTap: onRowDoubleTap == null ? null : () => onRowDoubleTap!(vicinity.yIndex),
      );
    }
    if (vicinity is SelectedRowChildVicinity) {
      return null; // TODO: 3 implement selection UI
    }
    return builder(context, vicinity);
  }

  @override
  bool shouldRebuild(covariant TwoDimensionalChildDelegate oldDelegate) {
    if (oldDelegate is! FilesChildDelegate) return true;
    if (onRowTap != oldDelegate.onRowTap) return true;
    if (onRowDoubleTap != oldDelegate.onRowDoubleTap) return true;
    return super.shouldRebuild(oldDelegate);
  }
}
