import 'dart:io';

final diskType = DiskType();

class DiskType {
  late final List<_Mount> _mounts;

  /// Call once at startup before any [isRotational] queries.
  /// Scans mountinfo and caches rotational status per mount point.
  Future<void> init() async {
    if (!Platform.isLinux) return;
    _mounts = <_Mount>[];
    for (final entry in _parseMountinfo()) {
      final device = _resolveDeviceName(entry.$1, entry.$2);
      if (device == null) continue;
      final rot = _readRotational(device);
      _mounts.add(_Mount(entry.$3, rotational: rot));
    }
    _mounts.sort((a, b) => b.path.length.compareTo(a.path.length));
  }

  /// Returns `true` if [dirPath] lives on a rotational (HDD) drive.
  /// Requires [init] to have been called first.
  bool isRotational(String dirPath) {
    for (final m in _mounts) {
      if (dirPath.startsWith(m.path)) return m.rotational;
    }
    return false;
  }

  // ── parsing ──────────────────────────────────────────────────────────

  /// Returns `(major, minor, mountPoint)` for every block-device-backed mount.
  static Iterable<(int, int, String)> _parseMountinfo() sync* {
    final mi = File('/proc/self/mountinfo');
    if (!mi.existsSync()) return;

    for (final line in mi.readAsLinesSync()) {
      final fields = line.split(' ');
      if (fields.length < 6) continue;
      final parts = fields[2].split(':');
      if (parts.length != 2) continue;
      final major = int.tryParse(parts[0]);
      final minor = int.tryParse(parts[1]);
      if (major == null || minor == null || major == 0) continue;
      final mountPoint = _unescape(fields[4]);
      yield (major, minor, mountPoint);
    }
  }

  static String? _resolveDeviceName(int major, int minor) {
    final link = Link('/sys/dev/block/$major:$minor');
    if (!link.existsSync()) return null;
    final target = link.resolveSymbolicLinksSync();
    final deviceWithPartition = target.split('/').last;
    return _stripPartition(deviceWithPartition);
  }

  static String? _stripPartition(String name) {
    final match = _partitionRe.firstMatch(name);
    return match?.group(1) ?? name;
  }

  static final _partitionRe = RegExp(r'^(.+?)(p\d+|\d+)$');

  static bool _readRotational(String device) {
    final f = File('/sys/block/$device/queue/rotational');
    if (!f.existsSync()) return false;
    return f.readAsStringSync().trim() == '1';
  }

  static String _unescape(String s) {
    return s.replaceAll(r'\040', ' ').replaceAll(r'\011', '\t').replaceAll(r'\012', '\n').replaceAll(r'\134', r'\');
  }
}

class _Mount {
  final String path;
  final bool rotational;
  _Mount(this.path, {required this.rotational});
}
