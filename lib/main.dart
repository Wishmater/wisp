import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wisp/ui/explorer_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  windowManager.setAsFrameless();
  runApp(const WispFM());
}

class WispFM extends StatelessWidget {
  const WispFM({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Wisp',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: .fromSeed(seedColor: Colors.deepPurple),
        ),
        darkTheme: ThemeData(
          brightness: .dark,
          colorScheme: .fromSeed(seedColor: Colors.deepPurple, brightness: .dark),
        ),
        home: const Scaffold(
          body: ExplorerScaffold(),
        ),
      ),
    );
  }
}
