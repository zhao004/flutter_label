import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_label/app/utils/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageUtils', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('image_utils_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('可以从 PNG 文件头读取尺寸', () async {
      final file = File('${tempDir.path}/sample.png');
      await file.writeAsBytes(_pngHeader(width: 640, height: 480));

      final size = await ImageUtils.readImageSize(file);

      expect(size.width, 640);
      expect(size.height, 480);
    });

    test('可以从 JPEG SOF 文件头读取尺寸', () async {
      final file = File('${tempDir.path}/sample.jpg');
      await file.writeAsBytes(_jpegHeader(width: 1920, height: 1080));

      final size = await ImageUtils.readImageSize(file);

      expect(size.width, 1920);
      expect(size.height, 1080);
    });

    test('可以从 BMP 文件头读取尺寸', () async {
      final file = File('${tempDir.path}/sample.bmp');
      await file.writeAsBytes(_bmpHeader(width: 320, height: 240));

      final size = await ImageUtils.readImageSize(file);

      expect(size.width, 320);
      expect(size.height, 240);
    });

    test('可以从 WebP VP8X 文件头读取尺寸', () async {
      final file = File('${tempDir.path}/sample.webp');
      await file.writeAsBytes(_webpVp8xHeader(width: 1024, height: 768));

      final size = await ImageUtils.readImageSize(file);

      expect(size.width, 1024);
      expect(size.height, 768);
    });

    test('空文件会被拒绝', () async {
      final file = File('${tempDir.path}/empty.png');
      await file.writeAsBytes(const []);

      expect(() => ImageUtils.readImageSize(file), throwsFormatException);
    });
  });
}

Uint8List _pngHeader({required int width, required int height}) {
  final bytes = Uint8List(24)
    ..setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(16, width, Endian.big);
  data.setUint32(20, height, Endian.big);
  return bytes;
}

Uint8List _jpegHeader({required int width, required int height}) {
  final bytes = Uint8List(32)
    ..setAll(0, const [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
    ..setAll(20, const [0xFF, 0xC0, 0x00, 0x11, 0x08]);
  final data = ByteData.sublistView(bytes);
  data.setUint16(25, height, Endian.big);
  data.setUint16(27, width, Endian.big);
  return bytes;
}

Uint8List _bmpHeader({required int width, required int height}) {
  final bytes = Uint8List(54)..setAll(0, const [0x42, 0x4D]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(14, 40, Endian.little);
  data.setInt32(18, width, Endian.little);
  data.setInt32(22, height, Endian.little);
  return bytes;
}

Uint8List _webpVp8xHeader({required int width, required int height}) {
  final bytes = Uint8List(30)
    ..setAll(0, 'RIFF'.codeUnits)
    ..setAll(8, 'WEBP'.codeUnits)
    ..setAll(12, 'VP8X'.codeUnits);
  _writeUint24(bytes, 24, width - 1);
  _writeUint24(bytes, 27, height - 1);
  return bytes;
}

void _writeUint24(Uint8List bytes, int offset, int value) {
  bytes[offset] = value & 0xFF;
  bytes[offset + 1] = (value >> 8) & 0xFF;
  bytes[offset + 2] = (value >> 16) & 0xFF;
}
