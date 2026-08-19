import 'package:flutter/widgets.dart';
import 'package:from_zero_ui/packages/fz_actions.dart';
import 'package:from_zero_ui/packages/fz_popup.dart';

class ContextMenu extends StatelessWidget {
  final Widget child;
  final List<ActionFromZero> actions;

  /// overrides everything else and is used as context menu widget
  final Widget? contextMenuWidget;
  final double contextMenuWidth;
  final Alignment anchorAlignment;
  final Alignment popupAlignment;
  final Offset offsetCorrection;
  final Color? barrierColor;
  final bool useCursorLocation;

  /// Default true. Set to false so menu will only be shown manually. Useful when stacking with a button.
  final bool addGestureDetector;
  final bool enabled;
  final bool? addAncestorContextMenuActions;
  final bool addOnTapDown;

  /// Default true. This blocks GestureDetectors behind it.
  final VoidCallback? onShowMenu;

  const ContextMenu({
    required this.child,
    this.enabled = true,
    this.contextMenuWidget,
    this.actions = const [],
    this.contextMenuWidth = 256,
    this.anchorAlignment = Alignment.bottomRight,
    this.popupAlignment = Alignment.bottomRight,
    this.offsetCorrection = Offset.zero,
    this.barrierColor,
    this.addAncestorContextMenuActions,
    this.useCursorLocation = true,
    this.addGestureDetector = true,
    this.onShowMenu,
    this.addOnTapDown = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenuFromZero(
      enabled: enabled,
      contextMenuWidget: contextMenuWidget,
      actions: actions,
      contextMenuWidth: contextMenuWidth,
      anchorAlignment: anchorAlignment,
      popupAlignment: popupAlignment,
      offsetCorrection: offsetCorrection,
      barrierColor: barrierColor,
      addAncestorContextMenuActions: addAncestorContextMenuActions,
      useCursorLocation: useCursorLocation,
      addGestureDetector: addGestureDetector,
      onShowMenu: onShowMenu,
      addOnTapDown: addOnTapDown,
      child: child,
    );
  }
}
