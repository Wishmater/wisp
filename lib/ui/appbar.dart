import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_actions.dart';
import 'package:from_zero_ui/packages/fz_appbar.dart';
import 'package:wisp/providers/explorer.dart';
import 'package:wisp/providers/scaffold.dart';
import 'package:wisp/ui/path_viewer.dart';

class ExplorerAppbar extends ConsumerWidget {
  const ExplorerAppbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppBarTheme.of(context).backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerLowest;
    final appbarHeightValue = ref.watch(drawerWidth);
    final drawerWidthValue = ref.watch(drawerWidth);
    return SizedBox(
      height: double.infinity,
      child: AppbarFromZero(
        title: Row(
          children: [
            SizedBox(width: 4),
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: drawerWidthValue,
                minHeight: appbarHeightValue,
              ),
              child: Row(
                crossAxisAlignment: .center,
                children: [
                  ActionFromZero(
                    icon: Icon(Icons.keyboard_arrow_up_outlined),
                    title: 'Up',
                    onTap: (context) {
                      ref.read(currentDirectory.notifier).goUp();
                    },
                  ).buildIcon(context),
                  ActionFromZero(
                    icon: Icon(Icons.keyboard_arrow_left_outlined),
                    title: 'Back',
                  ).buildIcon(context),
                  ActionFromZero(
                    icon: Icon(Icons.keyboard_arrow_right_outlined),
                    title: 'Forward',
                  ).buildIcon(context),
                  // SizedBox(width: 12),
                ],
              ),
            ),
            const Expanded(
              child: PathViewer(),
            ),
          ],
        ),
        useFlutterAppbar: false,
        primary: true,
        mainAppbar: true,
        mainAppbarShowButtons: false,
        backgroundColor: color.withValues(alpha: 0.75),
        toolbarHeight: appbarHeightValue,
        actions: [],
      ),
    );
  }
}
