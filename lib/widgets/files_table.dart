import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef TableViewChildBuilder<R, C> = Widget? Function(BuildContext, R row, C column, int rowIndex, int colIndex);
typedef TableViewHeaderBuilder<C> = Widget? Function(BuildContext, C column, int colIndex);
typedef TableViewRowBackgroundBuilder<R> = Widget? Function(BuildContext, R row, int rowIndex);
typedef TableViewHeaderBackgroundBuilder = Widget? Function(BuildContext);

class TableView<R, C> extends TwoDimensionalScrollView {
  final List<R> rows;
  final List<C> columns;
  final double rowHeight;
  final double headerHeight;
  final List<double> columnSizes;
  final EdgeInsets padding;

  TableView({
    required this.rows,
    required this.columns,
    required this.rowHeight,
    required this.headerHeight,
    required this.columnSizes,
    required TableViewChildBuilder<R, C> builder,
    this.padding = EdgeInsets.zero,
    super.verticalDetails,
    super.horizontalDetails,
    TableViewHeaderBuilder<C>? headerBuilder,
    TableViewRowBackgroundBuilder<R>? rowBackgroundBuilder,
    TableViewHeaderBackgroundBuilder? headerBackgroundBuilder,
    bool addRepaintBoundaries = true,
    super.key,
  }) : assert(rowHeight > 0),
       assert(columnSizes.length == columns.length),
       super(
         delegate: FilesChildDelegate(
           rows: rows,
           columns: columns,
           builder: builder,
           headerBuilder: headerBuilder,
           rowBackgroundBuilder: rowBackgroundBuilder,
           headerBackgroundBuilder: headerBackgroundBuilder,
           addRepaintBoundaries: addRepaintBoundaries,
         ),
       );

  @override
  Widget buildViewport(BuildContext context, ViewportOffset verticalOffset, ViewportOffset horizontalOffset) {
    return _TableViewViewport(
      verticalOffset: verticalOffset,
      horizontalOffset: horizontalOffset,
      mainAxis: mainAxis,
      delegate: delegate,
      rowCount: rows.length,
      colCount: columns.length,
      rowHeight: rowHeight,
      headerHeight: headerHeight,
      columnSizes: columnSizes,
      padding: padding,
    );
  }
}

class _TableViewViewport extends TwoDimensionalViewport {
  final int rowCount;
  final int colCount;
  final double rowHeight;
  final double headerHeight;
  final List<double> columnSizes;
  final EdgeInsets padding;

  const _TableViewViewport({
    required super.verticalOffset,
    required super.horizontalOffset,
    required super.delegate,
    required super.mainAxis,
    required this.rowCount,
    required this.colCount,
    required this.rowHeight,
    required this.headerHeight,
    required this.columnSizes,
    this.padding = EdgeInsets.zero,
  }) : super(
         verticalAxisDirection: .down,
         horizontalAxisDirection: .right,
       );

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context) {
    return _RenderTableViewViewport(
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
      headerHeight: headerHeight,
      columnSizes: columnSizes,
      padding: padding,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderTableViewViewport renderObject) {
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

class _RenderTableViewViewport extends RenderTwoDimensionalViewport {
  _RenderTableViewViewport({
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
    required double headerHeight,
    required List<double> columnSizes,
    EdgeInsets padding = EdgeInsets.zero,
  }) : _rowCount = rowCount,
       _colCount = colCount,
       _rowHeight = rowHeight,
       _headerHeight = headerHeight,
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

  double get headerHeight => _headerHeight;
  double _headerHeight;
  set headerHeight(double value) {
    if (_headerHeight == value) return;
    _headerHeight = value;
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
    final padding = this.padding + EdgeInsets.only(top: headerHeight);
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
      // // Layout selection indicator
      // final selection = buildOrObtainChildFor(
      //   SelectedRowChildVicinity(yIndex: row, extent: 0),
      // );
      // if (selection != null) {
      //   final selectionParentData = selection.parentData! as TwoDimensionalViewportParentData;
      //   // TODO: 3 it probably looks better if we limit this to the viewport with instead of spanning over edges
      //   selection.layout(BoxConstraints.tight(Size(maxWidth, cellHeight)));
      //   selectionParentData.layoutOffset = Offset(
      //     0,
      //     padding.top + row * cellHeight - verticalOffset.pixels,
      //   );
      // }
      // Layout row background
      final rowBackground = buildOrObtainChildFor(
        RowBackgroundChildVicinity(yIndex: row, xCount: colCount),
      );
      if (rowBackground != null) {
        final rowBackgroundParentData = rowBackground.parentData! as TwoDimensionalViewportParentData;
        // TODO: 3 it probably looks better if we limit this to the viewport with instead of spanning over edges
        rowBackground.layout(BoxConstraints.tight(Size(maxWidth, cellHeight)));
        rowBackgroundParentData.layoutOffset = Offset(
          0,
          padding.top + row * cellHeight - verticalOffset.pixels,
        );
      }
      // Layout row cells
      for (int col = firstCol; col <= lastCol; col++) {
        final child = buildOrObtainChildFor(
          NormalChildVicinity(xIndex: col, yIndex: row),
        );
        if (child != null) {
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

    // Layout header background
    final rowBackground = buildOrObtainChildFor(
      HeaderBackgroundChildVicinity(yCount: rowCount),
    );
    if (rowBackground != null) {
      final rowBackgroundParentData = rowBackground.parentData! as TwoDimensionalViewportParentData;
      // TODO: 3 would it be better if we limit this to the viewport with instead of spanning over edges
      rowBackground.layout(BoxConstraints.tight(Size(maxWidth, cellHeight)));
      rowBackgroundParentData.layoutOffset = Offset(
        0,
        this.padding.top,
      );
    }
    for (int col = firstCol; col <= lastCol; col++) {
      // Layout header cells
      final header = buildOrObtainChildFor(
        HeaderChildVicinity(xIndex: col, yCount: rowCount),
      );
      if (header != null) {
        final cellWidth = columnSizes[col];
        final headerParentData = header.parentData! as TwoDimensionalViewportParentData;
        header.layout(BoxConstraints.tight(Size(cellWidth, cellHeight)));
        headerParentData.layoutOffset = Offset(
          padding.left + columnOffsets[col] - horizontalOffset.pixels,
          this.padding.top,
        );
      }
    }
  }
}

const int _reservedX = 2;
const int _reservedY = 0;

class SelectedRowChildVicinity extends ChildVicinity {
  final int extent;
  const SelectedRowChildVicinity({
    required int yIndex,
    required this.extent,
  }) : super(xIndex: 0, yIndex: yIndex + _reservedY);
}

class HeaderChildVicinity extends ChildVicinity {
  const HeaderChildVicinity({
    required int xIndex,
    required int yCount,
  }) : super(xIndex: xIndex + _reservedX, yIndex: yCount);
}

class RowBackgroundChildVicinity extends ChildVicinity {
  const RowBackgroundChildVicinity({
    required int yIndex,
    required int xCount,
  }) : super(xIndex: 1, yIndex: yIndex + _reservedY);
}

class HeaderBackgroundChildVicinity extends ChildVicinity {
  const HeaderBackgroundChildVicinity({
    required int yCount,
  }) : super(xIndex: 1, yIndex: yCount);
}

class NormalChildVicinity extends ChildVicinity {
  const NormalChildVicinity({
    required int xIndex,
    required int yIndex,
  }) : super(xIndex: xIndex + _reservedX, yIndex: yIndex + _reservedY);
}

class FilesChildDelegate<R, C> extends TwoDimensionalChildDelegate {
  final List<R> rows;
  final List<C> columns;
  final Widget? Function(BuildContext, R row, C column, int rowIndex, int colIndex) builder;
  final Widget? Function(BuildContext, C column, int colIndex)? headerBuilder;
  final Widget? Function(BuildContext, R row, int rowIndex)? rowBackgroundBuilder;
  final Widget? Function(BuildContext)? headerBackgroundBuilder;
  final bool addRepaintBoundaries;

  // TODO: 3 implement column background

  // final bool addAutomaticKeepAlives; // if we ever need this, check out implementation in TwoDimensionalChildBuilderDelegate

  FilesChildDelegate({
    required this.rows,
    required this.columns,
    required this.builder,
    this.headerBuilder,
    this.rowBackgroundBuilder,
    this.headerBackgroundBuilder,
    this.addRepaintBoundaries = true,
  });

  @override
  Widget? build(BuildContext context, covariant ChildVicinity vicinity) {
    Widget? child;
    try {
      child = _build(context, vicinity);
    } catch (exception, stackTrace) {
      child = _createErrorWidget(exception, stackTrace);
    }
    if (child == null) {
      return null;
    }
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    return child;
  }

  Widget? _build(BuildContext context, covariant ChildVicinity vicinity) {
    if (vicinity is HeaderChildVicinity) {
      final colIndex = vicinity.xIndex - _reservedX;
      return headerBuilder?.call(context, columns[colIndex], colIndex);
    }
    if (vicinity is RowBackgroundChildVicinity) {
      final rowIndex = vicinity.yIndex - _reservedY;
      return rowBackgroundBuilder?.call(context, rows[rowIndex], rowIndex);
    }
    if (vicinity is HeaderBackgroundChildVicinity) {
      return headerBackgroundBuilder?.call(context);
    }
    if (vicinity is SelectedRowChildVicinity) {
      if (vicinity.extent == 0) return null;
      return null; // TODO: 3 implement selection UI
    }
    final rowIndex = vicinity.yIndex - _reservedY;
    final colIndex = vicinity.xIndex - _reservedX;
    return builder(context, rows[rowIndex], columns[colIndex], rowIndex, colIndex);
  }

  @override
  bool shouldRebuild(covariant TwoDimensionalChildDelegate oldDelegate) {
    if (oldDelegate is! FilesChildDelegate) return true;
    if (headerBuilder != oldDelegate.headerBuilder) return true;
    if (rowBackgroundBuilder != oldDelegate.rowBackgroundBuilder) return true;
    if (headerBackgroundBuilder != oldDelegate.headerBackgroundBuilder) return true;
    return false;
  }
}

// Return a Widget for the given Exception
Widget _createErrorWidget(Object exception, StackTrace stackTrace) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stackTrace,
    library: 'widgets library',
    context: ErrorDescription('building'),
  );
  FlutterError.reportError(details);
  return ErrorWidget.builder(details);
}
