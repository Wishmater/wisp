import 'package:flutter/widgets.dart';
import 'package:wisp/models/file_data.dart';

enum FileDataField {
  path,
  filename,
  // stat
  size,
  modified,
  created,
  accessed,
  // mime
  type,
  // special
  // audio / video
  duration,
  // video / image
  width,
  height,
  dimensions,
  aspectRatio,
  orientation,
  // video
  frameRate,
  // audio
  bitrate,
  track,
  artist,
  genre,
  album,
  releaseYear,
  ;

  String getUiName(BuildContext context) {
    return switch (this) {
      FileDataField.path => 'Path',
      FileDataField.filename => 'Name',
      FileDataField.size => 'Size',
      FileDataField.modified => 'Modified',
      FileDataField.created => 'Created',
      FileDataField.accessed => 'Accessed',
      FileDataField.type => 'Type',
      FileDataField.duration => 'Duration',
      FileDataField.width => 'Width',
      FileDataField.height => 'Height',
      FileDataField.dimensions => 'Dimensions',
      FileDataField.aspectRatio => 'Aspect Ratio',
      FileDataField.orientation => 'Orientation',
      FileDataField.frameRate => 'Frame Rate',
      FileDataField.bitrate => 'Bitrate',
      FileDataField.track => 'Track',
      FileDataField.artist => 'Artist',
      FileDataField.genre => 'Genre',
      FileDataField.album => 'Album',
      FileDataField.releaseYear => 'Release Year',
    };
  }
}

int _compareNullable<T extends Comparable<dynamic>>(T? a, T? b) {
  if (a == null) {
    if (b == null) {
      return 0;
    } else {
      return 1;
    }
  } else if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}

int _compare<T extends Comparable<dynamic>, M>(M a, M b, T? Function(M) getter) {
  return _compareNullable(getter(a), getter(b));
}

extension FileDataFieldUtils on FileData {
  int compareTo(FileData other, FileDataField compareBy, {bool asc = true}) {
    if (typeData?.type == .directory && other.typeData?.type != .directory) {
      return -1;
    }
    if (typeData?.type != .directory && other.typeData?.type == .directory) {
      return 1;
    }

    var result = switch (compareBy) {
      FileDataField.path => path.compareTo(other.path),
      FileDataField.filename => filename.compareTo(other.filename),
      FileDataField.size => _compareNullable(statData?.size, other.statData?.size),
      FileDataField.modified => _compareNullable(statData?.modified, other.statData?.modified),
      FileDataField.created => _compareNullable(statData?.created, other.statData?.created),
      FileDataField.accessed => _compareNullable(statData?.accessed, other.statData?.accessed),
      FileDataField.type => _compareNullable(typeData?.type, other.typeData?.type),
      FileDataField.duration => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileVideoData data => data.duration,
          FileAudioData data => data.duration,
          _ => null,
        },
      ),
      FileDataField.width => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileVideoData data => data.width,
          FileImageData data => data.width,
          _ => null,
        },
      ),
      FileDataField.height => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileVideoData data => data.height,
          FileImageData data => data.height,
          _ => null,
        },
      ),
      FileDataField.dimensions => () {
        var result = _compare(
          this,
          other,
          (e) => switch (e.specialData) {
            FileVideoData data => data.width,
            FileImageData data => data.width,
            _ => null,
          },
        );
        if (result == 0) {
          result = _compare(
            this,
            other,
            (e) => switch (e.specialData) {
              FileVideoData data => data.height,
              FileImageData data => data.height,
              _ => null,
            },
          );
        }
        return result;
      }(),
      FileDataField.aspectRatio => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileVideoData data => data.width / data.height,
          FileImageData data => data.width / data.height,
          _ => null,
        },
      ),
      FileDataField.orientation => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileVideoData data => data.width >= data.height ? 1 : 0,
          FileImageData data => data.width >= data.height ? 1 : 0,
          _ => null,
        },
      ),
      FileDataField.frameRate => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileVideoData data => data.frameRate,
          _ => null,
        },
      ),
      FileDataField.bitrate => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileAudioData data => data.bitRate,
          _ => null,
        },
      ),
      FileDataField.track => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileAudioData data => data.track,
          _ => null,
        },
      ),
      FileDataField.artist => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileAudioData data => data.artist,
          _ => null,
        },
      ),
      FileDataField.genre => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileAudioData data => data.genre,
          _ => null,
        },
      ),
      FileDataField.album => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileAudioData data => data.album,
          _ => null,
        },
      ),
      FileDataField.releaseYear => _compare(
        this,
        other,
        (e) => switch (e.specialData) {
          FileAudioData data => data.releaseYear,
          _ => null,
        },
      ),
    };

    if (result == 0) {
      result = path.compareTo(other.path);
    }
    if (!asc) {
      result *= -1;
    }
    return result;
  }

  String? getFormatted(BuildContext context, FileDataField type) {
    return switch (type) {
      FileDataField.path => path,
      FileDataField.filename => filename,
      FileDataField.size => switch (typeData?.type) {
        null => null,
        .directory => switch (specialData) {
          FileDirectoryData data => '${data.itemCount} items',
          null => null,
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => statData == null ? null : '${statData!.size} B', // TODO: 1 format size properly
      },
      FileDataField.modified => statData?.modified.toString(), // TODO: 1 format datetime properly
      FileDataField.created => statData?.created.toString(), // TODO: 1 format datetime properly
      FileDataField.accessed => statData?.accessed.toString(), // TODO: 1 format datetime properly
      FileDataField.type => typeData?.type.getUiName(context),
      FileDataField.duration => switch (typeData?.type) {
        null => null,
        .video => switch (specialData) {
          null => null,
          FileVideoData data => data.duration.toString(), // TODO: 1 format duration properly
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        .audio => switch (specialData) {
          null => null,
          FileAudioData data => data.duration.toString(), // TODO: 1 format duration properly
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.width => switch (typeData?.type) {
        null => null,
        .video => switch (specialData) {
          null => null,
          FileVideoData data => data.width.toString(),
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        .image => switch (specialData) {
          null => null,
          FileImageData data => data.width.toString(),
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.height => switch (typeData?.type) {
        null => null,
        .video => switch (specialData) {
          null => null,
          FileVideoData data => data.height.toString(),
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        .image => switch (specialData) {
          null => null,
          FileImageData data => data.height.toString(),
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.dimensions => switch (typeData?.type) {
        null => null,
        .video => switch (specialData) {
          null => null,
          FileVideoData data => '${data.width} x ${data.height}',
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        .image => switch (specialData) {
          null => null,
          FileImageData data => '${data.width} x ${data.height}',
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.aspectRatio => switch (typeData?.type) {
        null => null,
        .video => switch (specialData) {
          null => null,
          FileVideoData data => (data.width / data.height).toString(), // TODO: 1 format aspect ratio properly
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        .image => switch (specialData) {
          null => null,
          FileImageData data => (data.width / data.height).toString(), // TODO: 1 format aspect ratio properly
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.orientation => switch (typeData?.type) {
        null => null,
        .video => switch (specialData) {
          null => null,
          FileVideoData data => data.width >= data.height ? 'Landscape' : 'Portrait',
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        .image => switch (specialData) {
          null => null,
          FileImageData data => data.width >= data.height ? 'Landscape' : 'Portrait',
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.frameRate => switch (typeData?.type) {
        null => null,
        .video => switch (specialData) {
          null => null,
          FileVideoData data => data.frameRate.toString(), // TODO: 1 format frameRate properly
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.bitrate => switch (typeData?.type) {
        null => null,
        .audio => switch (specialData) {
          null => null,
          FileAudioData data => data.bitRate.toString(), // TODO: 1 format properly
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.track => switch (typeData?.type) {
        null => null,
        .audio => switch (specialData) {
          null => null,
          FileAudioData data => data.track,
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.artist => switch (typeData?.type) {
        null => null,
        .audio => switch (specialData) {
          null => null,
          FileAudioData data => data.artist,
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.genre => switch (typeData?.type) {
        null => null,
        .audio => switch (specialData) {
          null => null,
          FileAudioData data => data.genre,
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.album => switch (typeData?.type) {
        null => null,
        .audio => switch (specialData) {
          null => null,
          FileAudioData data => data.album,
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
      FileDataField.releaseYear => switch (typeData?.type) {
        null => null,
        .audio => switch (specialData) {
          null => null,
          FileAudioData data => data.releaseYear.toString(),
          _ => '',
          _ => throw WrongFileSpecialDataException(typeData!.type, specialData.runtimeType),
        },
        _ => '',
      },
    };
  }
}
