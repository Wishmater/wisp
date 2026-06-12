import 'dart:ui' as ui;

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/from_zero_ui.dart';
import 'package:wisp/providers/explorer.dart';
import 'package:wisp/providers/scaffold.dart';
import 'package:wisp/widgets/gestures.dart';

class PathViewer extends ConsumerStatefulWidget {
  const PathViewer({super.key});

  @override
  ConsumerState<PathViewer> createState() => _PathViewerState();
}

class _PathViewerState extends ConsumerState<PathViewer> {
  late final textfieldScrollController = ScrollController();
  late final pathviewerScrollController = ScrollController();
  late final FocusNode textFieldFocusNode;
  bool showingTextField = false;
  bool queueScrollbarUpdate = false;

  @override
  void initState() {
    super.initState();
    textFieldFocusNode = FocusNode();
    textFieldFocusNode.addListener(onTextFieldFocus);
  }

  void onTextFieldFocus() {
    if (!textFieldFocusNode.hasFocus) {
      if (showingTextField) {
        setState(() {
          showingTextField = false;
          queueScrollbarUpdate = true;
        });
      }
    } else {
      if (!showingTextField) {
        setState(() {
          showingTextField = true;
          queueScrollbarUpdate = true;
        });
      }
    }
  }

  void showPathViewer() {
    if (showingTextField) {
      setState(() {
        showingTextField = false;
        queueScrollbarUpdate = true;
        textFieldFocusNode.unfocus();
        // TODO: 2 should we reset the text on the textfield when pressing escape? (Dolphin does it, Nautilus does not)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDirectoryValue = ref.watch(currentDirectory);
    final scrollController = showingTextField ? textfieldScrollController : pathviewerScrollController;
    return Padding(
      padding: EdgeInsets.only(left: 15),
      child: ScrollbarFromZero(
        controller: scrollController,
        applyOpacityGradientToChildren: false,
        child: Builder(
          builder: (context) {
            if (queueScrollbarUpdate) {
              queueScrollbarUpdate = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Force the scrollbar to update, otherwise it's stuck with the size of the previous widget
                context.dispatchNotification(
                  ScrollMetricsNotification(
                    context: context,
                    metrics: FixedScrollMetrics(
                      minScrollExtent: scrollController.position.minScrollExtent,
                      maxScrollExtent: scrollController.position.maxScrollExtent,
                      pixels: scrollController.position.pixels,
                      viewportDimension: scrollController.position.viewportDimension,
                      axisDirection: scrollController.position.axisDirection,
                      devicePixelRatio: scrollController.position.devicePixelRatio,
                    ),
                  ),
                );
              });
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener(
                  onNotification: (notification) {
                    return !showingTextField &&
                        (notification is ScrollNotification || notification is ScrollMetricsNotification);
                  },
                  child: ExcludeFocusTraversal(
                    excluding: !showingTextField,
                    child: Opacity(
                      opacity: showingTextField ? 1 : 0,
                      child: CallbackShortcuts(
                        bindings: {
                          ModifierIgnoringActivator(LogicalKeyboardKey.escape): showPathViewer,
                        },
                        child: PathTextFieldView(
                          key: ValueKey(currentDirectoryValue),
                          focusNode: textFieldFocusNode,
                          path: currentDirectoryValue,
                          scrollController: textfieldScrollController,
                        ),
                      ),
                    ),
                  ),
                ),
                NotificationListener(
                  onNotification: (notification) {
                    return showingTextField &&
                        (notification is ScrollNotification || notification is ScrollMetricsNotification);
                  },
                  child: ExcludeFocusTraversal(
                    excluding: showingTextField,
                    child: ExcludeFocus(
                      excluding: showingTextField,
                      child: IgnorePointer(
                        ignoring: showingTextField,
                        child: Opacity(
                          opacity: showingTextField ? 0 : 1,
                          child: PathPartsView(
                            path: currentDirectoryValue,
                            scrollController: pathviewerScrollController,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PathPartsView extends ConsumerWidget {
  final String path;
  final ScrollController? scrollController;

  const PathPartsView({
    required this.path,
    this.scrollController,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = this.scrollController ?? ScrollController();
    final splitPath = path.split('/')..removeWhere((e) => e.isEmpty);
    if (path.startsWith('/')) {
      splitPath.insert(0, '/');
    }
    final widgets = <Widget>[];
    for (int i = 0; i < splitPath.length; i++) {
      final e = splitPath[i];
      widgets.addAll([
        InkWell(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          onTap: () {
            var fullPath = splitPath
                .sublist(0, i + 1) //
                .fold('', (value, e) => value == '/' || e == '/' ? value + e : '$value/$e');
            ref.read(currentDirectory.notifier).setCurrentDirectory(fullPath);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Text(e),
          ),
        ),
        if (i != splitPath.lastIndex)
          // TODO: 3 there could be a dropdown here that shows all of this directory's folders, like in dolphin
          SizedBox(
            width: 12,
            child: OverflowBox(
              alignment: Alignment.center,
              maxWidth: double.infinity,
              child: Icon(
                Icons.arrow_right,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
      ]);
    }
    return Container(
      // Leave this space so you can always click it and go int TextField mode
      padding: const EdgeInsets.only(right: 48),
      alignment: Alignment.centerLeft,
      child: ScrollOpacityGradient(
        scrollController: scrollController,
        direction: OpacityGradient.horizontal,
        child: SingleChildScrollView(
          scrollDirection: .horizontal,
          hitTestBehavior: .translucent,
          controller: scrollController,
          reverse: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: AbsorbPointer(),
              ),
              Row(
                crossAxisAlignment: .center,
                mainAxisSize: .min,
                children: [
                  ...widgets,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PathTextFieldView extends ConsumerStatefulWidget {
  final String path;
  final FocusNode? focusNode;
  final ScrollController? scrollController;

  const PathTextFieldView({
    required this.path,
    this.focusNode,
    this.scrollController,
    super.key,
  });

  @override
  ConsumerState<PathTextFieldView> createState() => _PathTextFieldViewState();
}

class _PathTextFieldViewState extends ConsumerState<PathTextFieldView> {
  double _pixelsFromEnd = 0;
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.scrollController ?? ScrollController();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PathTextFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_controller.hasClients) {
      _pixelsFromEnd = _controller.position.maxScrollExtent - _controller.position.pixels;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final textPainter = TextPainter(
      text: TextSpan(text: widget.path, style: style!.copyWith(height: 1)),
      textDirection: ui.TextDirection.ltr,
      textScaler: MediaQuery.of(context).textScaler,
    )..layout();
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // hack to make textfield scroll behave kinda like ListView with reverse=true
          if (_controller.hasClients) {
            final max = _controller.position.maxScrollExtent;
            final newPixels = (max - _pixelsFromEnd).clamp(0.0, max);
            _controller.jumpTo(newPixels);
          }
        });
        return ScrollOpacityGradient(
          scrollController: _controller,
          direction: OpacityGradient.horizontal,
          child: TextFormField(
            scrollController: _controller,
            focusNode: widget.focusNode,
            initialValue: widget.path,
            maxLines: 1,
            style: style,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.only(
                left: 6,
                right: 42,
                top: (ref.watch(appbarHeight) - textPainter.height) / 2 + 1,
              ),
            ),
            onFieldSubmitted: (value) {
              ref.read(currentDirectory.notifier).setCurrentDirectory(value);
            },
          ),
        );
      },
    );
  }
}
