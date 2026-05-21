import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageSize {
  const ImageSize({required this.width, required this.height});

  final int width;
  final int height;
}

class ImageUtils {
  ImageUtils._();

  static const int _maxHeaderBytes = 64 * 1024;

  static Future<ImageSize> readImageSize(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('图片文件不存在', file.path);
    }

    final length = await file.length();
    if (length <= 0) {
      throw const FormatException('图片文件为空');
    }

    final header = await _readHeader(file, length);
    final sizeFromHeader = _tryReadSizeFromHeader(header);
    if (sizeFromHeader != null) {
      return sizeFromHeader;
    }

    // 文件头不覆盖少数编码变体时再退回复用 Flutter 解码器，保证兼容性。
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = ImageSize(width: image.width, height: image.height);
    image.dispose();
    codec.dispose();
    return size;
  }

  static Future<Uint8List> _readHeader(File file, int fileLength) async {
    final end = math.min(fileLength, _maxHeaderBytes);
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, end)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static ImageSize? _tryReadSizeFromHeader(Uint8List bytes) {
    return _readPngSize(bytes) ??
        _readJpegSize(bytes) ??
        _readBmpSize(bytes) ??
        _readWebpSize(bytes);
  }

  static ImageSize? _readPngSize(Uint8List bytes) {
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < 24) {
      return null;
    }
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) {
        return null;
      }
    }
    final width = _uint32(bytes, 16, Endian.big);
    final height = _uint32(bytes, 20, Endian.big);
    return _validSize(width, height);
  }

  static ImageSize? _readJpegSize(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return null;
    }

    var offset = 2;
    while (offset + 9 < bytes.length) {
      while (offset < bytes.length && bytes[offset] != 0xFF) {
        offset += 1;
      }
      while (offset < bytes.length && bytes[offset] == 0xFF) {
        offset += 1;
      }
      if (offset >= bytes.length) {
        return null;
      }

      final marker = bytes[offset];
      offset += 1;
      if (marker == 0xD9 || marker == 0xDA) {
        return null;
      }
      if (_isStandaloneJpegMarker(marker)) {
        continue;
      }
      if (offset + 2 > bytes.length) {
        return null;
      }

      final segmentLength = _uint16(bytes, offset, Endian.big);
      if (segmentLength < 2) {
        return null;
      }
      if (_isJpegStartOfFrame(marker)) {
        if (offset + 7 > bytes.length) {
          return null;
        }
        final height = _uint16(bytes, offset + 3, Endian.big);
        final width = _uint16(bytes, offset + 5, Endian.big);
        return _validSize(width, height);
      }
      offset += segmentLength;
    }
    return null;
  }

  static bool _isStandaloneJpegMarker(int marker) {
    return marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8);
  }

  static bool _isJpegStartOfFrame(int marker) {
    return (marker >= 0xC0 && marker <= 0xC3) ||
        (marker >= 0xC5 && marker <= 0xC7) ||
        (marker >= 0xC9 && marker <= 0xCB) ||
        (marker >= 0xCD && marker <= 0xCF);
  }

  static ImageSize? _readBmpSize(Uint8List bytes) {
    if (bytes.length < 26 || bytes[0] != 0x42 || bytes[1] != 0x4D) {
      return null;
    }
    final dibHeaderSize = _uint32(bytes, 14, Endian.little);
    if (dibHeaderSize == 12) {
      final width = _uint16(bytes, 18, Endian.little);
      final height = _uint16(bytes, 20, Endian.little);
      return _validSize(width, height);
    }
    if (bytes.length < 30 || dibHeaderSize < 40) {
      return null;
    }
    final width = _int32(bytes, 18, Endian.little);
    final height = _int32(bytes, 22, Endian.little).abs();
    return _validSize(width, height);
  }

  static ImageSize? _readWebpSize(Uint8List bytes) {
    if (bytes.length < 30 ||
        !_matchesAscii(bytes, 0, 'RIFF') ||
        !_matchesAscii(bytes, 8, 'WEBP')) {
      return null;
    }

    if (_matchesAscii(bytes, 12, 'VP8X')) {
      final width = 1 + _uint24(bytes, 24);
      final height = 1 + _uint24(bytes, 27);
      return _validSize(width, height);
    }
    if (_matchesAscii(bytes, 12, 'VP8L') && bytes[20] == 0x2F) {
      final packed = _uint32(bytes, 21, Endian.little);
      final width = 1 + (packed & 0x3FFF);
      final height = 1 + ((packed >> 14) & 0x3FFF);
      return _validSize(width, height);
    }
    if (_matchesAscii(bytes, 12, 'VP8 ') &&
        bytes[23] == 0x9D &&
        bytes[24] == 0x01 &&
        bytes[25] == 0x2A) {
      final width = _uint16(bytes, 26, Endian.little) & 0x3FFF;
      final height = _uint16(bytes, 28, Endian.little) & 0x3FFF;
      return _validSize(width, height);
    }
    return null;
  }

  static bool _matchesAscii(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) {
      return false;
    }
    for (var index = 0; index < value.length; index += 1) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }

  static int _uint16(Uint8List bytes, int offset, Endian endian) {
    return ByteData.sublistView(bytes).getUint16(offset, endian);
  }

  static int _uint24(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
  }

  static int _uint32(Uint8List bytes, int offset, Endian endian) {
    return ByteData.sublistView(bytes).getUint32(offset, endian);
  }

  static int _int32(Uint8List bytes, int offset, Endian endian) {
    return ByteData.sublistView(bytes).getInt32(offset, endian);
  }

  static ImageSize? _validSize(int width, int height) {
    if (width <= 0 || height <= 0) {
      return null;
    }
    return ImageSize(width: width, height: height);
  }
}
