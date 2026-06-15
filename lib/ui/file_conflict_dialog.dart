import 'package:fast_copy/fast_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisp/providers/clipboard.dart';
import 'package:wisp/providers/files.dart';


class ConflictListener extends ConsumerStatefulWidget {
  final FileOperation operation;

  const ConflictListener({required this.operation, super.key});

  @override
  ConsumerState<ConflictListener> createState() => _ConflictListenerState();
}

class _ConflictListenerState extends ConsumerState<ConflictListener> {
  bool _showingDialog = false;

  void _onConflict() {
    if (_showingDialog) return;
    final conflict = widget.operation.currentConflict.value;
    if (conflict == null) return;
    _showingDialog = true;
    showFileConflictDialog(
      context,
      sourcePath: conflict.sourcePath,
      destPath: conflict.destPath,
    ).then((resolution) {
      _showingDialog = false;
      if (resolution != null) {
        ref.read(fileOperations.notifier).respondToConflict(widget.operation, resolution);
      }
    });
  }

  @override
  void initState() {
    print("_ConflictListenerState initState ${widget.operation.currentConflict}");
    super.initState();
    widget.operation.currentConflict.addListener(_onConflict);
    if (widget.operation.currentConflict.value != null) {
      SchedulerBinding.instance.scheduleFrameCallback((_) => _onConflict());
    }
  }

  @override
  void dispose() {
    widget.operation.currentConflict.removeListener(_onConflict);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}


Future<ConflictResolution?> showFileConflictDialog(
  BuildContext context, {
  required String sourcePath,
  required String destPath,
}) {
  return showDialog<ConflictResolution>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('File already exists'),
      content: Text('A file named\n$destPath\nalready exists in the destination.\n\nDo you want to replace it?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictResolution.skipAll),
          child: const Text('Skip All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictResolution.skip),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictResolution.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictResolution.replaceAll),
          child: const Text('Replace All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictResolution.replace),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
}
