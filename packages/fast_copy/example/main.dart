import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fast_copy/fast_copy.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'copier',
      abbr: 'c',
      defaultsTo: 'file_range',
      allowed: ['simple', 'file_range', 'failing'],
      help: 'Copy strategy to use.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage.',
    );

  final results = parser.parse(args);

  if (results['help'] as bool) {
    print(parser.usage);
    return;
  }

  final copierName = results['copier'] as String;

  final srcPath = 'example/test_data';
  final destPath = 'example/test_data_copy';

  if (!Directory(srcPath).existsSync()) {
    print('Test data not found at "$srcPath".');
    print('Run: dart run example/generate_test_data.dart');
    return;
  }

  final destDir = Directory(destPath);
  if (destDir.existsSync()) {
    stdout.write('Deleting existing destination... ');
    destDir.deleteSync(recursive: true);
    print('done.');
  }

  final copier = switch (copierName) {
    'simple' => UserlandReadWriteCopy(),
    'file_range' => CopyFileRange(),
    'failing' => FailingCopy(),
    _ => CopyFileRange(),
  };

  print('Using copier: $copierName');
  print('Copying "$srcPath" -> "$destPath"');
  print('');

  final runner = await IsolateCopyRunner.spawn();
  final start = DateTime.now();

  await runner.startCopy(copier, srcPath, destPath);

  const frameDuration = Duration(microseconds: 16667); // 60 fps
  while (true) {
    final frameStart = DateTime.now();
    final state = await runner.snapshot();
    switch (state) {
      case CopyPending():
        stdout.write('\x1b[2K\rScanning source...');
      case CopyActive():
        final pct = state.totalBytes > 0
            ? (state.completedBytes * 100.0 / state.totalBytes).toStringAsFixed(1)
            : '0.0';
        final elapsed = DateTime.now().difference(start);
        var speed = '';
        if (elapsed.inMilliseconds > 100 && state.completedBytes > 0) {
          final bytesPerSec = state.completedBytes * 1000 ~/ elapsed.inMilliseconds;
          speed = ' | ${_formatBytes(bytesPerSec)}/s';
        }
        stdout.write(
          '\x1b[2K\r'
          'Files: ${state.completedFiles}/${state.totalFiles}'
          ' | Bytes: ${_formatBytes(state.completedBytes)}/${_formatBytes(state.totalBytes)}'
          ' | $pct%$speed',
        );
      case CopyDone():
        stdout.write('\x1b[2K\r');
        final elapsed = DateTime.now().difference(start);
        final avgSpeed = elapsed.inMilliseconds > 0
            ? state.completedBytes * 1000 ~/ elapsed.inMilliseconds
            : 0;
        print('');
        print('Done in ${_formatDuration(elapsed)}.');
        print('Files: ${state.completedFiles}/${state.totalFiles}');
        print('Data:  ${_formatBytes(state.completedBytes)}/${_formatBytes(state.totalBytes)}');
        print('Speed: ${_formatBytes(avgSpeed)}/s (average)');
        if (state.failures.isNotEmpty) {
          print('');
          print('Failures:');
          for (final f in state.failures) {
            print('  \x1b[31m${f.sourcePath} -> ${f.destPath}: ${f.error}\x1b[0m');
          }
        }
    }
    if (state is CopyDone) break;
    final frameElapsed = DateTime.now().difference(frameStart);
    final wait = frameDuration - frameElapsed;
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
  }

  runner.dispose();
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  } else if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _formatDuration(Duration d) {
  final ms = d.inMilliseconds;
  if (ms >= 60000) {
    final min = ms ~/ 60000;
    final sec = (ms % 60000) / 1000;
    return '${min}m ${sec.toStringAsFixed(0)}s';
  } else if (ms >= 1000) {
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }
  return '${ms}ms';
}
