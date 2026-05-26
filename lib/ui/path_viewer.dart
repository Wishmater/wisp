import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisp/providers/explorer.dart';

class PathViewer extends ConsumerWidget {
  const PathViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDirectoryValue = ref.watch(currentDirectory);
    return Text(currentDirectoryValue);
    // return ApiProviderBuilder(
    //   provider: fileDetails.call(currentDirectoryValue),
    //   dataBuilder: (context, data) {
    //     return Text(data.path);
    //   },
    // );
  }
}
