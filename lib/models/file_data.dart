import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

class FileData {
  String path;
  int size;
  DateTime modified;

  FileData({
    required this.path,
    required this.size,
    required this.modified,
  });

  @override
  String toString() => path;

  @override
  bool operator ==(Object other) => other is FileData && path == other.path;
  @override
  int get hashCode => path.hashCode;

  String get filename => p.basename(path);

  factory FileData.fromStat(String path, FileStat stat) {
    return switch (stat.type) {
      FileSystemEntityType.directory => DirectoryData(
        path: path,
        size: stat.size,
        modified: stat.modified,
      ),
      _ => FileData(
        path: path,
        size: stat.size,
        modified: stat.modified,
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
