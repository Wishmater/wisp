import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fz_actions/fz_actions.dart';
import 'package:fz_appbar/fz_appbar.dart';
import 'package:wisp/providers/files.dart';
import 'package:wisp/ui/files_list.dart';
import 'package:wisp/ui/path_viewer.dart';

class ExplorerScaffold extends ConsumerWidget {
  const ExplorerScaffold({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        AppbarFromZero(
          title: const PathViewer(),
          actions: [
            ActionFromZero(
              icon: Icon(Icons.keyboard_arrow_up_outlined),
              title: 'Up',
              onTap: (context) {
                goUp(ref);
              },
            ),
          ],
        ),
        Expanded(
          child: const FilesList(),
        ),
      ],
    );
  }
}
