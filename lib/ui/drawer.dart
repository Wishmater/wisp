import 'package:fast_copy/fast_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wisp/providers/clipboard.dart';
import 'package:wisp/providers/files.dart';
import 'package:wisp/providers/scaffold.dart';

class ExplorerDrawer extends StatelessWidget {
  const ExplorerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.75),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text('DRAWER'),
            ),
          ),
          DrawerBottomView(),
        ],
      ),
    );
  }
}

class DrawerBottomView extends ConsumerWidget {
  const DrawerBottomView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowSize = MediaQuery.sizeOf(context);
    const goldenRatio = 1 / 2.61803398875;
    final drawerHeight = windowSize.height - ref.watch(appbarHeight);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: drawerHeight * goldenRatio,
      ),
      child: OperationsView(),
    );
  }
}

class OperationsView extends ConsumerWidget {
  const OperationsView({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(fileOperations).reversed.toList();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: operations.length,
      padding: EdgeInsets.only(bottom: 7, top: 7),
      itemBuilder: (context, index) {
        final operation = operations[index];
        return ValueListenableBuilder(
          valueListenable: operation.state,
          builder: (context, state, _) {
            final int? completedFiles;
            final int? completedBytes;
            switch (state) {
              case CopyActive state:
                completedFiles = state.completedFiles;
                completedBytes = state.completedBytes;
              case CopyDone state:
                completedFiles = state.completedFiles;
                completedBytes = state.completedBytes;
              case null:
              case CopyPending():
                completedFiles = null;
                completedBytes = null;
            }
            return Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                SizedBox(height: 5),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      switch (operation.type) {
                        FileOperationType.copy => Icon(
                          Icons.copy,
                          size: 20,
                          color: Colors.green.withValues(alpha: 0.5),
                        ),
                        FileOperationType.cut => Icon(
                          Icons.cut,
                          size: 20,
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      },
                      SizedBox(width: 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(
                              // TODO: 2 improve this when there are many files
                              operation.paths.fold('', (v, e) => v.isEmpty ? e : '$v, $e'),
                              style: Theme.of(context).textTheme.labelMedium,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                            Text(
                              operation.destination,
                              style: Theme.of(context).textTheme.labelMedium,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Stack(
                    children: [
                      LinearProgressIndicator(
                        value: completedBytes == null ? null : completedBytes / state!.totalBytes,
                        minHeight: 12,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      if (completedBytes != null)
                        Positioned.fill(
                          child: Center(
                            child: Text(
                              NumberFormat.decimalPercentPattern(decimalDigits: 1) //
                                  .format(completedBytes / state!.totalBytes),
                              style: Theme.of(context).textTheme.labelSmall!.copyWith(height: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 2),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      if (state != null)
                        Text(
                          '${completedFiles == null ? '-' : '$completedFiles'}/${state.totalFiles}',
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                        ),
                      // TODO: 1 format bytes
                      if (state != null)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Text(
                              '${completedBytes == null ? '-' : '${completedBytes}B'}/${state.totalBytes}B',
                              style: Theme.of(context).textTheme.labelSmall,
                              textAlign: .right,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
                SizedBox(height: 5),
              ],
            );
          },
        );
      },
    );
  }
}
