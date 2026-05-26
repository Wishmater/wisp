import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisp/providers/explorer.dart';
import 'package:wisp/widgets/gestures.dart';

class PathViewer extends ConsumerStatefulWidget {
  const PathViewer({super.key});

  @override
  ConsumerState<PathViewer> createState() => _PathViewerState();
}

class _PathViewerState extends ConsumerState<PathViewer> {
  bool showingTextField = false;

  @override
  Widget build(BuildContext context) {
    final currentDirectoryValue = ref.watch(currentDirectory);
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: showingTextField ? 1 : 0,
          child: CallbackShortcuts(
            bindings: {
              ModifierIgnoringActivator(LogicalKeyboardKey.escape): () {
                if (showingTextField) {
                  setState(() {
                    showingTextField = false;
                  });
                }
              },
            },
            child: GestureDetector(
              onTap: () {
                if (!showingTextField) {
                  setState(() {
                    showingTextField = true;
                  });
                }
              },
              child: PathTextfieldView(
                key: ValueKey(currentDirectoryValue),
                path: currentDirectoryValue,
              ),
            ),
          ),
        ),
        Opacity(
          opacity: showingTextField ? 0 : 1,
          child: PathPartsView(path: currentDirectoryValue),
        ),
      ],
    );
  }
}

class PathPartsView extends ConsumerWidget {
  final String path;

  const PathPartsView({
    required this.path,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            final fullPath = splitPath.sublist(0, i + 1).join('/');
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: .center,
        children: [
          SizedBox(width: 15),
          ...widgets,
          SizedBox(width: 12),
        ],
      ),
    );
  }
}

class PathTextfieldView extends ConsumerWidget {
  final String path;

  const PathTextfieldView({
    required this.path,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      autofocus: true,
      initialValue: path,
      onFieldSubmitted: (value) {
        ref.read(currentDirectory.notifier).setCurrentDirectory(value);
      },
    );
  }
}
