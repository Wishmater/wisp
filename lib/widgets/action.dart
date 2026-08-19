import 'package:from_zero_ui/packages/fz_actions.dart';

class MenuAction extends ActionFromZero {
  MenuAction({
    required super.title,
    super.onTap,
    super.icon,
    super.color,
    super.disablingError,
    super.breakpoints,
    super.overflowBuilder,
    super.iconBuilder,
    super.buttonBuilder,
    super.expandedBuilder,
    super.centerExpanded,
    super.key,
  });

  MenuAction.divider({
    super.breakpoints,
    super.buttonBuilder,
    super.iconBuilder,
    super.overflowBuilder,
    super.key,
  }) : super.divider();
}
