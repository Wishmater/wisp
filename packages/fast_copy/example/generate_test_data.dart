import 'dart:io';

Future<void> main() async {
  final base = Directory('example/test_data');
  if (base.existsSync()) {
    stdout.write('Deleting existing test data... ');
    base.deleteSync(recursive: true);
    print('done.');
  }
  base.createSync(recursive: true);

  final subdirs = [
    'dir_a/sub_a1',
    'dir_a/sub_a2',
    'dir_b/sub_b1',
    'dir_c/sub_c1/sub_c2',
    'dir_d',
  ];
  for (final d in subdirs) {
    Directory('${base.path}/$d').createSync(recursive: true);
  }

  final specs = <(String, int)>[
    ('dir_a/sub_a1/large1.bin', 250),
    ('dir_a/large2.bin', 150),
    ('dir_b/sub_b1/large3.bin', 100),
    ('root_file.bin', 200),
    ('dir_c/sub_c1/sub_c2/medium1.bin', 80),
    ('dir_d/medium2.bin', 75),
    ('dir_a/sub_a2/small1.bin', 10),
    ('dir_a/sub_a2/small2.bin', 15),
    ('dir_b/sub_b1/small3.bin', 5),
    ('dir_c/sub_c1/small4.bin', 8),
    ('dir_d/small5.bin', 20),
    ('dir_c/misc1.bin', 2),
    ('dir_c/misc2.bin', 3),
    ('dir_b/misc3.bin', 4),
    ('dir_d/misc4.bin', 1),
    ('dir_a/sub_a1/misc5.bin', 7),
  ];

  final rng = File('/dev/urandom').openSync();
  const blockSize = 64 * 1024;
  var totalMB = 0;

  for (final (rel, sizeMB) in specs) {
    final f = File('${base.path}/$rel');
    final sink = f.openWrite();
    var remaining = sizeMB * 1024 * 1024;
    while (remaining > 0) {
      final chunk = remaining < blockSize ? remaining : blockSize;
      sink.add(rng.readSync(chunk));
      remaining -= chunk;
    }
    await sink.flush();
    await sink.close();
    totalMB += sizeMB;
    stdout.write('\x1b[2K\rGenerated: ${(totalMB / 1024).toStringAsFixed(1)} GB');
  }
  rng.closeSync();
  stdout.write('\x1b[2K\r');
  print('Done. Total: ${(totalMB / 1024).toStringAsFixed(1)} GB across ${specs.length} files.');
}
