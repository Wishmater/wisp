import 'dart:math' show min;

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef TableViewChildBuilder<R, C> = Widget? Function(BuildContext, R row, C column, int rowIndex, int colIndex);
typedef TableViewHeaderBuilder<C> = Widget? Function(BuildContext, C column, int colIndex);
typedef TableViewRowBackgroundBuilder<R> = Widget? Function(BuildContext, R row, int rowIndex);
typedef TableViewHeaderBackgroundBuilder = Widget? Function(BuildContext);

class TableView<R, C> extends StatefulWidget {
  final List<R> rows;
  final List<C> columns;
  final double rowHeight;
  final double headerHeight;
  final List<double> columnSizes;
  final EdgeInsets padding;
  final ScrollableDetails verticalDetails;
  final ScrollableDetails horizontalDetails;
  final Widget? Function(BuildContext, R row, C column, int rowIndex, int colIndex) builder;
  final Widget? Function(BuildContext, C column, int colIndex)? headerBuilder;
  final Widget? Function(BuildContext, R row, int rowIndex)? rowBackgroundBuilder;
  final Widget? Function(BuildContext)? headerBackgroundBuilder;
  final bool addRepaintBoundaries;

  const TableView({
    required this.rows,
    required this.columns,
    required this.rowHeight,
    required this.headerHeight,
    required this.columnSizes,
    required this.builder,
    this.padding = EdgeInsets.zero,
    this.verticalDetails = const ScrollableDetails.vertical(),
    this.horizontalDetails = const ScrollableDetails.horizontal(),
    this.headerBuilder,
    this.rowBackgroundBuilder,
    this.headerBackgroundBuilder,
    this.addRepaintBoundaries = true,
    super.key,
  });

  @override
  State<TableView<R, C>> createState() => _TableViewState<R, C>();
}

class _TableViewState<R, C> extends State<TableView<R, C>> {
  late final viewportController = _RenderTableViewViewportController();
  late final invalidationNotifier = ValueNotifier<_DataInvalidation>(_DataInvalidation(rows: [], cols: []));

  late final _FilesChildDelegate<R, C> delegate = getDelegate();

  @override
  void didUpdateWidget(covariant TableView<R, C> oldWidget) {
    super.didUpdateWidget(oldWidget);
    delegate.rows = widget.rows;
    delegate.columns = widget.columns;
    delegate.builder = widget.builder;
    delegate.headerBuilder = widget.headerBuilder;
    delegate.rowBackgroundBuilder = widget.rowBackgroundBuilder;
    delegate.headerBackgroundBuilder = widget.headerBackgroundBuilder;
    delegate.addRepaintBoundaries = widget.addRepaintBoundaries;
    delegate.invalidationNotifier = invalidationNotifier;
    if (widget.addRepaintBoundaries != oldWidget.addRepaintBoundaries
    // TODO: 2 these comparisons throw, how to check if the builders changed? tbf they shouldn't, but the way the API is right now they could
    // || widget.headerBuilder != oldWidget.headerBuilder
    // || widget.rowBackgroundBuilder != oldWidget.rowBackgroundBuilder
    // || widget.headerBackgroundBuilder != oldWidget.headerBackgroundBuilder
    ) {
      // refresh the delegate that has shouldRebuild=>true, this rebuilds all children
      // TODO: 3 maybe we should instead have setters in the Delegate itself,
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      delegate.notifyListeners();
    } else {
      // if we already told the entire delegate to update, we dont need to send specific data invalidation
      final firstRow = viewportController.getFirstRow();
      final lastRow = min(viewportController.getLastRow(), widget.rows.lastIndex);
      final firstCol = viewportController.getFirstCol();
      final lastCol = min(viewportController.getLastCol(), widget.columns.lastIndex);
      List<int> invalidateRows = [];
      List<int> invalidateCols = [];
      for (int row = firstRow; row <= lastRow; row++) {
        if (widget.rows.getOrNull(row) != oldWidget.rows.getOrNull(row)) {
          invalidateRows.add(row + _reservedBeforeY);
        }
      }
      for (int col = firstCol; col <= lastCol; col++) {
        if (widget.columns.getOrNull(col) != oldWidget.columns.getOrNull(col)) {
          invalidateCols.add(col + _reservedBeforeX);
        }
      }
      // invalidate reserved rows after the last one that will be reused because row count increased
      final lastRelevantReservedAfterY = min(widget.rows.length, oldWidget.rows.length + _reservedAfterY);
      for (int i = oldWidget.rows.length; i < lastRelevantReservedAfterY; i++) {
        invalidateRows.add(i + _reservedBeforeY);
      }
      // invalidate reserved columns after the last one that will be reused because col count increased
      final lastRelevantReservedAfterX = min(widget.columns.length, oldWidget.columns.length + _reservedAfterX);
      for (int i = oldWidget.columns.length; i < lastRelevantReservedAfterX; i++) {
        invalidateCols.add(i + _reservedBeforeX);
      }
      if (invalidateRows.isNotEmpty || invalidateCols.isNotEmpty) {
        print('INVALIDATE rows=$invalidateRows ;; cols=$invalidateCols');
        invalidationNotifier.value = _DataInvalidation(
          rows: invalidateRows,
          cols: invalidateCols,
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    invalidationNotifier.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TableView(
      rows: widget.rows,
      columns: widget.columns,
      rowHeight: widget.rowHeight,
      headerHeight: widget.headerHeight,
      columnSizes: widget.columnSizes,
      padding: widget.padding,
      verticalDetails: widget.verticalDetails,
      horizontalDetails: widget.horizontalDetails,
      viewportController: viewportController,
      delegate: delegate,
    );
  }

  _FilesChildDelegate<R, C> getDelegate() => _FilesChildDelegate<R, C>(
    rows: widget.rows,
    columns: widget.columns,
    builder: widget.builder,
    headerBuilder: widget.headerBuilder,
    rowBackgroundBuilder: widget.rowBackgroundBuilder,
    headerBackgroundBuilder: widget.headerBackgroundBuilder,
    addRepaintBoundaries: widget.addRepaintBoundaries,
    invalidationNotifier: invalidationNotifier,
  );
}

class _TableView<R, C> extends TwoDimensionalScrollView {
  final List<R> rows;
  final List<C> columns;
  final double rowHeight;
  final double headerHeight;
  final List<double> columnSizes;
  final EdgeInsets padding;
  final _RenderTableViewViewportController? viewportController;

  const _TableView({
    required this.rows,
    required this.columns,
    required this.rowHeight,
    required this.headerHeight,
    required this.columnSizes,
    required super.delegate,
    this.padding = EdgeInsets.zero,
    this.viewportController,
    super.verticalDetails,
    super.horizontalDetails,
  }) : assert(rowHeight > 0),
       assert(columnSizes.length == columns.length);

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
      controller: viewportController,
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
  final _RenderTableViewViewportController? controller;

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
    this.controller,
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
      controller: controller,
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
      ..headerHeight = headerHeight
      ..columnSizes = columnSizes
      ..padding = padding
      ..controller = controller;
  }
}

class _RenderTableViewViewportController {
  late int Function() getFirstRow, getLastRow, getFirstCol, getLastCol;
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
    _RenderTableViewViewportController? controller,
  }) : _rowCount = rowCount,
       _colCount = colCount,
       _rowHeight = rowHeight,
       _headerHeight = headerHeight,
       _columnSizes = columnSizes,
       _padding = padding,
       _controller = controller {
    _setUpController();
  }

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

  _RenderTableViewViewportController? get controller => _controller;
  _RenderTableViewViewportController? _controller;
  set controller(_RenderTableViewViewportController? value) {
    if (_controller == value) return;
    _controller = value;
    _setUpController();
  }

  void _setUpController() {
    _controller?.getFirstRow = () => firstRow;
    _controller?.getLastRow = () => lastRow;
    _controller?.getFirstCol = () => firstCol;
    _controller?.getLastCol = () => lastCol;
  }

  late int firstRow, lastRow, firstCol, lastCol;

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
    if (colCount == 0) {
      firstCol = 0;
      lastCol = -1;
    } else {
      final renderStartX = (horizontalOffset.pixels - cacheExtent - padding.left).coerceAtLeast(0);
      final renderEndX = horizontalOffset.pixels + viewportDimension.width + cacheExtent;
      final firstFullyVisibleCol = columnOffsets.indexWhere((e) => e > renderStartX);
      firstCol = firstFullyVisibleCol == -1 ? colCount - 1 : (firstFullyVisibleCol - 1).coerceAtLeast(0);
      final lastFullyVisibleCol = columnOffsets.indexWhere((e) => e > renderEndX);
      lastCol = lastFullyVisibleCol == -1 ? colCount - 1 : firstFullyVisibleCol;
    }

    // Compute visible row range
    if (rowCount == 0) {
      firstRow = 0;
      lastRow = -1;
    } else {
      final renderStartY = (verticalOffset.pixels - cacheExtent - padding.top).coerceAtLeast(0);
      final renderEndY = verticalOffset.pixels + viewportDimension.height + cacheExtent;
      firstRow = (renderStartY / cellHeight).floor().clamp(0, rowCount - 1);
      lastRow = (renderEndY / cellHeight).ceil().clamp(0, rowCount - 1);
    }

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
        TableViewRowBackgroundVicinity(yIndex: row),
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
          TableViewChildVicinity(xIndex: col, yIndex: row),
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
      TableViewHeaderBackgroundVicinity(yCount: rowCount),
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
        TableViewHeaderChildVicinity(xIndex: col, yCount: rowCount),
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

const int _reservedBeforeX = 2;
const int _reservedAfterX = 0;
const int _reservedBeforeY = 0;
const int _reservedAfterY = 1;

sealed class TableViewVicinity extends ChildVicinity {
  const TableViewVicinity({required super.xIndex, required super.yIndex});

  bool check(ChildVicinity vicinity, {required int yCount, required int xCount});

  @protected
  bool checkInternal(
    ChildVicinity vicinity, {
    required int yCount,
    required int xCount,
    int? beforeY,
    int? afterY,
    int? beforeX,
    int? afterX,
  }) {
    assert(beforeY == null || afterY == null);
    assert(beforeX == null || afterX == null);
    assert(beforeY == null || beforeY < _reservedBeforeY);
    assert(afterY == null || afterY < _reservedAfterY);
    assert(beforeX == null || beforeX < _reservedBeforeX);
    assert(afterX == null || afterX < _reservedAfterX);

    if (beforeY == null && afterY == null) {
      if (vicinity.yIndex < _reservedBeforeY || vicinity.yIndex - _reservedBeforeY >= yCount) return false;
    } else if (beforeY != null) {
      if (beforeY != vicinity.yIndex) return false;
    } else {
      if (afterY != vicinity.yIndex - yCount - _reservedBeforeY) return false;
    }

    if (beforeX == null && afterX == null) {
      if (vicinity.xIndex < _reservedBeforeX || vicinity.xIndex - _reservedBeforeX >= xCount) return false;
    } else if (beforeX != null) {
      if (beforeX != vicinity.xIndex) return false;
    } else {
      if (afterX != vicinity.xIndex - xCount - _reservedBeforeX) return false;
    }

    return true;
  }
}

class TableViewChildVicinity extends TableViewVicinity {
  static const checker = TableViewChildVicinity(yIndex: 0, xIndex: 0);

  const TableViewChildVicinity({
    required int xIndex,
    required int yIndex,
  }) : super(
         xIndex: xIndex + _reservedBeforeX,
         yIndex: yIndex + _reservedBeforeY,
       );

  @override
  bool check(ChildVicinity vicinity, {required int yCount, required int xCount}) {
    return checkInternal(vicinity, yCount: yCount, xCount: xCount);
  }
}

sealed class TableViewSpecialVicinity extends TableViewVicinity {
  const TableViewSpecialVicinity({required super.xIndex, required super.yIndex});

  @override
  bool checkInternal(
    ChildVicinity vicinity, {
    required int yCount,
    required int xCount,
    int? beforeY,
    int? afterY,
    int? beforeX,
    int? afterX,
  }) {
    assert(
      beforeY != null || afterY != null || beforeX != null || afterX != null,
      'Subclasses of TableViewSpecialChildVicinity should have some reserved X or Y',
    );
    return super.checkInternal(
      vicinity,
      yCount: yCount,
      xCount: xCount,
      beforeY: beforeY,
      afterY: afterY,
      beforeX: beforeX,
      afterX: afterX,
    );
  }
}

class TableViewSelectedRowVicinity extends TableViewVicinity {
  static const checker = TableViewSelectedRowVicinity(yIndex: 0, extent: 0);
  static const beforeX = 0;

  final int extent;

  const TableViewSelectedRowVicinity({
    required int yIndex,
    required this.extent,
  }) : super(xIndex: beforeX, yIndex: yIndex + _reservedBeforeY);

  @override
  bool check(ChildVicinity vicinity, {required int yCount, required int xCount}) {
    return checkInternal(vicinity, yCount: yCount, xCount: xCount, beforeX: beforeX);
  }
}

class TableViewHeaderChildVicinity extends TableViewVicinity {
  static const checker = TableViewHeaderChildVicinity(xIndex: 0, yCount: 0);
  static const afterY = 0;

  const TableViewHeaderChildVicinity({
    required int xIndex,
    required int yCount,
  }) : super(xIndex: xIndex + _reservedBeforeX, yIndex: yCount + afterY);

  @override
  bool check(ChildVicinity vicinity, {required int yCount, required int xCount}) {
    return checkInternal(vicinity, yCount: yCount, xCount: xCount, afterY: afterY);
  }
}

class TableViewRowBackgroundVicinity extends TableViewVicinity {
  static const checker = TableViewRowBackgroundVicinity(yIndex: 0);
  static const beforeX = 1;

  const TableViewRowBackgroundVicinity({
    required int yIndex,
  }) : super(xIndex: beforeX, yIndex: yIndex + _reservedBeforeY);

  @override
  bool check(ChildVicinity vicinity, {required int yCount, required int xCount}) {
    return checkInternal(vicinity, yCount: yCount, xCount: xCount, beforeX: beforeX);
  }
}

class TableViewHeaderBackgroundVicinity extends TableViewVicinity {
  static const checker = TableViewHeaderBackgroundVicinity(yCount: 0);
  static const beforeX = 1;
  static const afterY = 0;

  const TableViewHeaderBackgroundVicinity({
    required int yCount,
  }) : super(xIndex: beforeX, yIndex: yCount + afterY);

  @override
  bool check(ChildVicinity vicinity, {required int yCount, required int xCount}) {
    return checkInternal(vicinity, yCount: yCount, xCount: xCount, beforeX: beforeX, afterY: afterY);
  }
}

class _FilesChildDelegate<R, C> extends TwoDimensionalChildDelegate {
  List<R> rows;
  List<C> columns;
  Widget? Function(BuildContext, R row, C column, int rowIndex, int colIndex) builder;
  Widget? Function(BuildContext, C column, int colIndex)? headerBuilder;
  Widget? Function(BuildContext, R row, int rowIndex)? rowBackgroundBuilder;
  Widget? Function(BuildContext)? headerBackgroundBuilder;
  bool addRepaintBoundaries;
  ValueNotifier<_DataInvalidation> invalidationNotifier;

  // TODO: 3 implement column background

  // final bool addAutomaticKeepAlives; // if we ever need this, check out implementation in TwoDimensionalChildBuilderDelegate

  _FilesChildDelegate({
    required this.rows,
    required this.columns,
    required this.builder,
    required this.invalidationNotifier,
    this.headerBuilder,
    this.rowBackgroundBuilder,
    this.headerBackgroundBuilder,
    this.addRepaintBoundaries = true,
  });

  @override
  bool shouldRebuild(covariant TwoDimensionalChildDelegate oldDelegate) {
    return true; // we don't really use this, since we create this once and then update it as needed
  }

  @override
  Widget? build(BuildContext context, covariant ChildVicinity vicinity) {
    Widget? child = _InvalidatableBuilder(
      invalidationNotifier: invalidationNotifier,
      row: vicinity.yIndex,
      col: vicinity.xIndex,
      builder: (context, rowIndex, colIndex) {
        try {
          if (TableViewChildVicinity.checker.check(vicinity, yCount: rows.length, xCount: columns.length)) {
            return builder(context, rows[rowIndex], columns[colIndex], rowIndex, colIndex);
          }
          if (TableViewRowBackgroundVicinity.checker.check(vicinity, yCount: rows.length, xCount: columns.length)) {
            return rowBackgroundBuilder!(context, rows[rowIndex], rowIndex);
          }
          if (TableViewSelectedRowVicinity.checker.check(vicinity, yCount: rows.length, xCount: columns.length)) {
            return null; // TODO: 3 implement selection UI
          }
          if (TableViewHeaderChildVicinity.checker.check(vicinity, yCount: rows.length, xCount: columns.length)) {
            return headerBuilder!(context, columns[colIndex], colIndex);
          }
          if (TableViewHeaderBackgroundVicinity.checker.check(vicinity, yCount: rows.length, xCount: columns.length)) {
            return headerBackgroundBuilder?.call(context);
          }
          // if (vicinity.xIndex == TableViewSelectedRowVicinity.beforeX &&
          //     vicinity.yIndex == columns.length + _reservedBeforeY + TableViewHeaderChildVicinity.afterY) {
          //   // selected indicator for header, this never makes sense
          //   return null;
          // }
        } catch (exception, stackTrace) {
          return _createErrorWidget(exception, stackTrace);
        }
        throw Exception(
          'No Vicinity type found that could handle this vicinity.'
          '\n    vicinity=$vicinity'
          '\n    originalRuntimeType=${vicinity.runtimeType}'
          '\n    rowCount=${rows.length}'
          '\n    colCount=${columns.length}',
        );
      },
    );
    // if (child == null) {
    //   return null;
    // }
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    return child;
  }
}

@immutable
class _DataInvalidation {
  final List<int> rows;
  final List<int> cols;
  // TODO: 2 implement cell-based invalidation

  const _DataInvalidation({
    required this.rows,
    required this.cols,
  });
}

class _InvalidatableBuilder extends StatefulWidget {
  final ValueNotifier<_DataInvalidation> invalidationNotifier;
  final Widget? Function(BuildContext context, int row, int col) builder;
  final int col;
  final int row;

  const _InvalidatableBuilder({
    required this.builder,
    required this.invalidationNotifier,
    required this.col,
    required this.row,
  });

  @override
  State<_InvalidatableBuilder> createState() => _InvalidatableBuilderState();
}

class _InvalidatableBuilderState extends State<_InvalidatableBuilder> {
  @override
  void initState() {
    super.initState();
    widget.invalidationNotifier.addListener(onDataInvalidation);
  }

  @override
  void didUpdateWidget(covariant _InvalidatableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invalidationNotifier != oldWidget.invalidationNotifier) {
      oldWidget.invalidationNotifier.removeListener(onDataInvalidation);
      widget.invalidationNotifier.addListener(onDataInvalidation);
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.invalidationNotifier.removeListener(onDataInvalidation);
  }

  void onDataInvalidation() {
    final data = widget.invalidationNotifier.value;
    if (data.cols.contains(widget.col) || data.rows.contains(widget.row)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // when the builder returns null, we still return SizedBox.shrink(), which causes it to be
    // layed out (which it wouldn't be if it was null). This is less efficient, but it should be
    // fine, in real life this shouldn't happen too much
    return widget.builder(
          context,
          widget.row - _reservedBeforeY,
          widget.col - _reservedBeforeX,
        ) ??
        SizedBox.shrink();
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

extension ListGetOrNull<T> on List<T> {
  T? getOrNull(int i) {
    if (i < 0) return null;
    if (i >= length) return null;
    return this[i];
  }
}
