import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisp/providers/scaffold.dart';
import 'package:wisp/ui/appbar.dart';
import 'package:wisp/ui/drawer.dart';
import 'package:wisp/ui/files_list.dart';

class ExplorerScaffold extends ConsumerWidget {
  const ExplorerScaffold({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appbarHeightValue = ref.watch(appbarHeight);
    final drawerWidthValue = ref.watch(drawerWidth);
    return Stack(
      children: [
        const FilesList(),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: appbarHeightValue,
          child: const ExplorerAppbar(),
          // TODO: 2 experiment with blur, hard to do on table header
          // child: ClipRect(
          //   child: BackdropFilter(
          //     filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          //     child: const ExplorerAppbar(),
          //   ),
          // ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          top: appbarHeightValue,
          width: drawerWidthValue,
          child: const ExplorerDrawer(),
          // TODO: 2 experiment with blur, hard to do on table header
          // child: ClipRect(
          //   child: BackdropFilter(
          //     filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          //     child: const ExplorerDrawer(),
          //   ),
          // ),
        ),
      ],
    );
  }
}
