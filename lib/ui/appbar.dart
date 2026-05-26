import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:from_zero_ui/packages/fz_actions.dart';
import 'package:from_zero_ui/packages/fz_appbar.dart';
import 'package:wisp/providers/explorer.dart';
import 'package:wisp/ui/path_viewer.dart';

class ExplorerAppbar extends ConsumerWidget {
  const ExplorerAppbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppBarTheme.of(context).backgroundColor ?? Theme.of(context).colorScheme.surface;
    return AppbarFromZero(
      title: const PathViewer(),
      primary: true,
      mainAppbar: true,
      mainAppbarShowButtons: false,
      backgroundColor: color.withValues(alpha: 0.75),
      actions: [
        ActionFromZero(
          icon: Icon(Icons.keyboard_arrow_up_outlined),
          title: 'Up',
          onTap: (context) {
            ref.read(currentDirectory.notifier).goUp();
          },
        ),
      ],
    );
  }
}
