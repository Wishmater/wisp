import 'package:flutter/material.dart';

class ExplorerDrawer extends StatelessWidget {
  const ExplorerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).canvasColor.withValues(alpha: 0.75),
      child: Center(
        child: Text('DRAWER'),
      ),
    );
  }
}
