import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:wisp/services/xdg_mime.dart';

class FileData {
  String path;
  int size;
  DateTime modified;
  String? mimeType;

  FileData({
    required this.path,
    required this.size,
    required this.modified,
    required this.mimeType,
  });

  @override
  String toString() => path;

  @override
  bool operator ==(Object other) => other is FileData && path == other.path;
  @override
  int get hashCode => path.hashCode;

  String get filename => p.basename(path);
  String get extension => p.extension(path);

  factory FileData.fromStat(String path, FileStat stat) {
    final mimeType = mimedb.getMimeType(p.basename(path));
    return switch (stat.type) {
      FileSystemEntityType.directory => DirectoryData(
        path: path,
        size: stat.size,
        modified: stat.modified,
        mimeType: mimeType,
      ),
      _ => FileData(
        path: path,
        size: stat.size,
        modified: stat.modified,
        mimeType: mimeType,
      ),
      // TODO: 2 we should probably handle all cases
    };
  }

  dynamic getStatType(FileStatType type) {
    return switch (type) {
      FileStatType.path => path,
      FileStatType.filename => filename,
      FileStatType.size => size,
      FileStatType.modified => modified,
    };
  }

  String getStatTypeFormatted(BuildContext context, FileStatType type) {
    return switch (type) {
      FileStatType.path => path,
      FileStatType.filename => filename,
      FileStatType.size => '${size}B', // TODO: 1 format size properly
      FileStatType.modified => modified.toString(), // TODO: 1 format datetime properly
    };
  }
}

class DirectoryData extends FileData {
  DirectoryData({
    required super.path,
    required super.size,
    required super.modified,
    required super.mimeType,
  });
}

enum FileStatType {
  path,
  filename,
  size,
  modified
  ;

  String getUiName(BuildContext context) {
    return switch (this) {
      FileStatType.path => 'Path',
      FileStatType.filename => 'Name',
      FileStatType.size => 'Size',
      FileStatType.modified => 'Modified',
    };
  }
}
