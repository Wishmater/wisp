import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

class FileData {
  String path;
  FileStatData? statData;
  FileTypeData? typeData;
  FileSpecialData? specialData;

  FileData({
    required this.path,
    this.statData,
    this.typeData,
    this.specialData,
  });

  @override
  String toString() => path;

  @override
  bool operator ==(Object other) => other is FileData && path == other.path;
  @override
  int get hashCode => path.hashCode;

  String get filename => p.basename(path);
  String get extension => p.extension(path);
}

class FileStatData {
  int size;
  DateTime modified;
  DateTime created;
  DateTime accessed;

  FileStatData({
    required this.size,
    required this.modified,
    required this.created,
    required this.accessed,
  });

  factory FileStatData.fromStat(FileStat stat) {
    return FileStatData(
      size: stat.size,
      modified: stat.modified,
      created: stat.changed, // TODO: 1 wtf, there is no created ??
      accessed: stat.accessed,
    );
  }
}

class FileTypeData {
  FileType type;
  String? mimeType;

  FileTypeData({
    required this.type,
    this.mimeType,
  });

  factory FileTypeData.fromMimeType(String? mimeType) {
    return FileTypeData(
      mimeType: mimeType,
      type: switch (mimeType?.split('/').firstOrNull) {
        'directory' => FileType.directory,
        'video' => FileType.video,
        'audio' => FileType.audio,
        'image' => FileType.image,
        'document' => FileType.document,
        _ => FileType.other,
      },
    );
  }
}

enum FileType implements Comparable<FileType> {
  directory,
  video,
  audio,
  image,
  document,
  other
  ;

  String getUiName(BuildContext context) {
    return switch (this) {
      FileType.directory => 'Directory', // "Folder"??
      FileType.video => 'Video',
      FileType.audio => 'Audio',
      FileType.image => 'Image',
      FileType.document => 'Document',
      FileType.other => 'Other',
    };
  }

  @override
  int compareTo(FileType other) {
    return index.compareTo(other.index);
  }
}

sealed class FileSpecialData {
  const FileSpecialData();
}

class FileDirectoryData extends FileSpecialData {
  int itemCount;

  FileDirectoryData({
    required this.itemCount,
  });
}

class FileVideoData extends FileSpecialData {
  int width;
  int height;
  double frameRate;
  Duration duration;

  FileVideoData({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.duration,
  });
}

class FileAudioData extends FileSpecialData {
  int itemCount;
  double bitRate;
  Duration duration;
  String track;
  String artist;
  String genre;
  String album;
  int releaseYear;

  FileAudioData({
    required this.itemCount,
    required this.bitRate,
    required this.duration,
    required this.track,
    required this.artist,
    required this.genre,
    required this.album,
    required this.releaseYear,
  });
}

class FileImageData extends FileSpecialData {
  int width;
  int height;

  FileImageData({
    required this.width,
    required this.height,
  });
}

class FileNoSpecialData extends FileSpecialData {
  const FileNoSpecialData();
}

class WrongFileSpecialDataException implements Exception {
  final FileType fileType;
  final Type dataType;

  WrongFileSpecialDataException(this.fileType, this.dataType);

  @override
  String toString() => 'Wrong FileSpecialData: found $dataType for file type $fileType';
}
