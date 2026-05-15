// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wisp/services/dir_reader.dart';

/// Benchmarks all DirReader implementations against a real directory.
///
/// Usage:  DIR=/path/to/dir flutter test benchmark/benchmark.dart
///
/// Set the DIR environment variable to the directory you want to scan.
/// The test warms up each reader, then measures execution time and throughput.

void main() {
  test('DirReader benchmark', () async {
    final dirPath = Platform.environment['DIR'];
    if (dirPath == null || dirPath.isEmpty) {
      print('');
      print('Usage: DIR=/path/to/dir flutter test benchmark/benchmark.dart');
      print('');
      return;
    }
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      print('');
      print('Directory not found: $dirPath');
      print('');
      return;
    }

    final readers = <String, DirReader>{
      'SimpleDirReader': SimpleDirReader(),
      'PileAwaitDirReader': PileAwaitDirReader(),
      'IsolateDirReader': IsolateDirReader(),
      'SyncDirReader': SyncDirReader(),
      'Compute(Sync)': ComputeDirReader(SyncDirReader()),
      'Compute(PileAwait)': ComputeDirReader(PileAwaitDirReader()),
    };

    final results = <String, _BenchResult>{};
    final sw = Stopwatch();

    print('');
    print('Warming up...');

    for (final entry in readers.entries) {
      await entry.value.init();
    }
    for (final entry in readers.entries) {
      await entry.value.readDir(dir).drain();
    }

    print('Running benchmarks...\n');

    for (final entry in readers.entries) {
      final name = entry.key;
      final reader = entry.value;

      sw.reset();
      sw.start();
      final stream = reader.readDir(dir);
      final files = await stream.toList();
      sw.stop();

      results[name] = _BenchResult(
        name: name,
        elapsed: sw.elapsed,
        fileCount: files.length,
      );
    }

    _printResults(results);
  });
}

void _printResults(Map<String, _BenchResult> results) {
  final sorted = results.values.toList()..sort((a, b) => a.elapsed.compareTo(b.elapsed));
  final best = sorted.first.elapsed;
  final maxNameLen = results.values.map((r) => r.name.length).reduce((a, b) => a > b ? a : b);

  final sep = '\u2500' * 80;

  print(sep);
  print(
    '${'Reader'.padRight(maxNameLen + 2)} ${'Time'.padLeft(12)} ${'Files'.padLeft(8)} ${'Files/s'.padLeft(10)} ${'vs Best'.padLeft(10)}',
  );
  print(sep);

  for (final r in sorted) {
    final timeStr = _fmtDuration(r.elapsed);
    final rate = r.elapsed.inMicroseconds > 0 ? (r.fileCount / r.elapsed.inMicroseconds * 1000000).round() : 0;
    final ratio = best.inMicroseconds > 0
        ? (r.elapsed.inMicroseconds / best.inMicroseconds).toStringAsFixed(2)
        : '\u2014';
    final ratioStr = r.name == sorted.first.name ? '1.00x' : '${ratio}x';

    print(
      '${r.name.padRight(maxNameLen + 2)} ${timeStr.padLeft(12)} ${r.fileCount.toString().padLeft(8)} ${rate.toString().padLeft(10)} ${ratioStr.padLeft(10)}',
    );
  }

  print(sep);
  print('');
  print('Fastest: ${sorted.first.name} (${_fmtDuration(sorted.first.elapsed)})');
  print('Slowest: ${sorted.last.name} (${_fmtDuration(sorted.last.elapsed)})');
  print('');

  print('Observations:');
  for (final r in results.values) {
    if (r.name != sorted.first.name) _compare(sorted.first, r);
  }
  print('');
}

void _compare(_BenchResult best, _BenchResult other) {
  final pct = best.elapsed.inMicroseconds > 0
      ? ((other.elapsed.inMicroseconds / best.elapsed.inMicroseconds - 1) * 100).round()
      : 0;
  print('  \u2022 ${other.name} is $pct% slower than ${best.name}.');
}

String _fmtDuration(Duration d) {
  if (d.inMicroseconds < 1000) {
    return '${d.inMicroseconds}\u03bcs';
  } else if (d.inMilliseconds < 10) {
    return '${(d.inMicroseconds / 1000).toStringAsFixed(2)}ms';
  } else if (d.inSeconds < 1) {
    return '${d.inMilliseconds}ms';
  } else {
    return '${(d.inMilliseconds / 1000).toStringAsFixed(2)}s';
  }
}

class _BenchResult {
  final String name;
  final Duration elapsed;
  final int fileCount;

  _BenchResult({
    required this.name,
    required this.elapsed,
    required this.fileCount,
  });
}
