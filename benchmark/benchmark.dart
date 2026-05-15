// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wisp/services/dir_reader.dart';

/// Benchmarks all DirReader implementations against a real directory.
///
/// Usage:
///   DIR=/path/to/dir flutter test benchmark/benchmark.dart
///   DIR=/path/to/dir ITERATIONS=10 flutter test benchmark/benchmark.dart
///
/// DIR         – directory to scan (required)
/// ITERATIONS  – number of measurement passes per reader (default: 5)

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
    final iterations = int.tryParse(Platform.environment['ITERATIONS'] ?? '') ?? 5;

    final readers = <String, DirReader>{
      'SimpleDirReader': SimpleDirReader(),
      'PileAwaitDirReader': PileAwaitDirReader(),
      'IsolateDirReader': IsolateDirReader(),
      'SyncDirReader': SyncDirReader(),
      'Compute(Sync)': ComputeDirReader(SyncDirReader()),
      'Compute(PileAwait)': ComputeDirReader(PileAwaitDirReader()),
    };

    print('');
    print('Directory: $dirPath');
    print('Iterations: $iterations');
    print('');
    print('Warming up...');

    for (final entry in readers.entries) {
      await entry.value.init();
    }
    for (final entry in readers.entries) {
      await entry.value.readDir(dir).drain();
    }

    print('Running $iterations passes...\n');

    final allResults = <String, List<Duration>>{};
    final sw = Stopwatch();
    int fileCount = 0;

    for (var i = 0; i < iterations; i++) {
      for (final entry in readers.entries) {
        final name = entry.key;
        final reader = entry.value;

        sw.reset();
        sw.start();
        final files = await reader.readDir(dir).toList();
        sw.stop();

        if (i == 0) fileCount = files.length;
        allResults.putIfAbsent(name, () => []).add(sw.elapsed);
      }
    }

    _printResults(allResults, fileCount, iterations);
  });
}

void _printResults(Map<String, List<Duration>> allResults, int fileCount, int iterations) {
  final aggregates = <String, _Aggregate>{};
  for (final entry in allResults.entries) {
    final times = entry.value;
    final sorted = [...times]..sort();
    aggregates[entry.key] = _Aggregate(
      name: entry.key,
      avg: Duration(microseconds: times.fold<int>(0, (s, d) => s + d.inMicroseconds) ~/ times.length),
      min: sorted.first,
      max: sorted.last,
      fileCount: fileCount,
    );
  }

  final sorted = aggregates.values.toList()..sort((a, b) => a.avg.compareTo(b.avg));
  final bestAvg = sorted.first.avg;
  final maxNameLen = aggregates.values.map((r) => r.name.length).reduce(max);

  final sep = '\u2500' * 80;

  print(sep);
  print(
    '${'Reader'.padRight(maxNameLen + 2)} ${'Avg'.padLeft(12)} ${'Min'.padLeft(10)} ${'Max'.padLeft(10)} ${'Files/s'.padLeft(10)} ${'vs Best'.padLeft(10)}',
  );
  print(sep);

  for (final r in sorted) {
    final ratio = bestAvg.inMicroseconds > 0
        ? (r.avg.inMicroseconds / bestAvg.inMicroseconds).toStringAsFixed(2)
        : '\u2014';
    final ratioStr = r.name == sorted.first.name ? '1.00x' : '${ratio}x';
    final rate = r.avg.inMicroseconds > 0 ? (r.fileCount / r.avg.inMicroseconds * 1000000).round() : 0;

    print(
      '${r.name.padRight(maxNameLen + 2)} ${_fmtDuration(r.avg).padLeft(12)} ${_fmtDuration(r.min).padLeft(10)} ${_fmtDuration(r.max).padLeft(10)} ${rate.toString().padLeft(10)} ${ratioStr.padLeft(10)}',
    );
  }

  print(sep);
  print('');
  print('Fastest: ${sorted.first.name} (avg ${_fmtDuration(sorted.first.avg)})');
  print('Slowest: ${sorted.last.name} (avg ${_fmtDuration(sorted.last.avg)})');
  print('');

  print('Observations (vs ${sorted.first.name}):');
  for (final r in aggregates.values) {
    if (r.name != sorted.first.name) _compare(sorted.first, r, iterations);
  }
  print('');
}

void _compare(_Aggregate best, _Aggregate other, int iterations) {
  final pct = best.avg.inMicroseconds > 0
      ? ((other.avg.inMicroseconds / best.avg.inMicroseconds - 1) * 100).round()
      : 0;
  print('  \u2022 ${other.name} is $pct% slower (avg over $iterations passes)');
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

class _Aggregate {
  final String name;
  final Duration avg;
  final Duration min;
  final Duration max;
  final int fileCount;

  _Aggregate({
    required this.name,
    required this.avg,
    required this.min,
    required this.max,
    required this.fileCount,
  });
}
