import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_label/app/controllers/auto_label_controller.dart';
import 'package:flutter_label/app/models/dataset_split.dart';
import 'package:flutter_label/app/models/detection_result.dart';
import 'package:flutter_label/app/models/image_item.dart';
import 'package:flutter_label/app/pages/auto_label/auto_label_view.dart';
import 'package:flutter_label/app/widgets/detection_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AutoLabelController());
  });

  tearDown(Get.reset);

  testWidgets('自动预标注页面展示核心控件', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const AutoLabelView()));

    expect(find.text('自动预标注'), findsOneWidget);
    expect(find.text('ONNX 模型'), findsOneWidget);
    expect(find.text('图片目录（可选择数据集根目录）'), findsOneWidget);
    expect(find.text('开始预标注'), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
    expect(find.text('实时预览'), findsAtLeastNWidgets(1));
  });

  testWidgets('自动预标注页面窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const AutoLabelView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('实时预览'), findsAtLeastNWidgets(1));
  });

  testWidgets('自动预标注运行时展示流式进度', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final tempDir = (await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'auto_label_view_test_',
      );
      return directory;
    }))!;
    Get.reset();
    try {
      final imageFile = File('${tempDir.path}/dataset/images/a.png');
      await tester.runAsync(() async {
        await imageFile.parent.create(recursive: true);
        await imageFile.writeAsBytes(_transparentPngBytes);
      });
      final controller = AutoLabelController();
      Get.put(controller);
      controller.isRunning.value = true;
      controller.processedCount.value = 1;
      controller.totalCount.value = 3;
      controller.currentImagePath.value = imageFile.path;
      controller.currentPreviewDetections.assignAll(const [
        DetectionResult(
          classId: 0,
          className: 'person',
          confidence: 0.92,
          left: 10,
          top: 12,
          width: 30,
          height: 24,
        ),
      ]);
      controller.previewImages.assignAll([
        ImageItem(
          path: imageFile.path,
          labelPath: '${tempDir.path}/dataset/labels/a.txt',
          fileName: 'a.png',
          relativePath: 'images/a.png',
          width: 100,
          height: 80,
        ),
      ]);

      await tester.pumpWidget(buildTestApp(home: const AutoLabelView()));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('处理中 1/3'), findsOneWidget);
      expect(find.text(imageFile.path), findsOneWidget);
      expect(find.text('images/a.png'), findsOneWidget);
      expect(find.byType(DetectionPreview), findsOneWidget);
      final preview = tester.widget<DetectionPreview>(
        find.byType(DetectionPreview),
      );
      expect(preview.imagePath, imageFile.path);
      expect(preview.detections, hasLength(1));
      expect(preview.detections.single.className, 'person');
      expect(preview.showImage, isTrue);
      expect(preview.imageWidth, 100);
      expect(preview.imageHeight, 80);
      expect(find.byType(Image), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      imageCache.clear();
      imageCache.clearLiveImages();
      await tester.runAsync(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
    }
  });

  testWidgets('自动预标注预览使用快照图片尺寸避免图框错配', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final tempDir = (await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp(
        'auto_label_snapshot_view_test_',
      );
      return directory;
    }))!;
    Get.reset();
    try {
      final firstImage = File('${tempDir.path}/dataset/images/a.png');
      final secondImage = File('${tempDir.path}/dataset/images/b.png');
      await tester.runAsync(() async {
        await firstImage.parent.create(recursive: true);
        await firstImage.writeAsBytes(_transparentPngBytes);
        await secondImage.writeAsBytes(_transparentPngBytes);
      });
      final controller = AutoLabelController();
      Get.put(controller);
      controller.isRunning.value = true;
      controller.processedCount.value = 2;
      controller.totalCount.value = 2;
      controller.currentImagePath.value = secondImage.path;
      controller.currentPreviewFrame.value = AutoLabelPreviewFrame(
        imagePath: firstImage.path,
        imageItem: ImageItem(
          path: firstImage.path,
          labelPath: '${tempDir.path}/dataset/labels/a.txt',
          fileName: 'a.png',
          relativePath: 'images/a.png',
          width: 100,
          height: 80,
        ),
        detections: const [
          DetectionResult(
            classId: 0,
            className: 'person',
            confidence: 0.92,
            left: 10,
            top: 12,
            width: 30,
            height: 24,
          ),
        ],
      );
      controller.previewImages.assignAll([
        ImageItem(
          path: firstImage.path,
          labelPath: '${tempDir.path}/dataset/labels/a.txt',
          fileName: 'a.png',
          relativePath: 'images/a.png',
          width: 100,
          height: 80,
        ),
        ImageItem(
          path: secondImage.path,
          labelPath: '${tempDir.path}/dataset/labels/b.txt',
          fileName: 'b.png',
          relativePath: 'images/b.png',
          width: 200,
          height: 160,
        ),
      ]);
      controller.selectedPreviewIndex.value = 1;

      await tester.pumpWidget(buildTestApp(home: const AutoLabelView()));
      await tester.pump();

      final preview = tester.widget<DetectionPreview>(
        find.byType(DetectionPreview),
      );
      expect(preview.imagePath, firstImage.path);
      expect(preview.imageWidth, 100);
      expect(preview.imageHeight, 80);
      expect(preview.detections.single.className, 'person');
      expect(find.text('images/a.png'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      imageCache.clear();
      imageCache.clearLiveImages();
      await tester.runAsync(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
    }
  });

  testWidgets('自动预标注运行时显示停止按钮', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final controller = Get.find<AutoLabelController>();
    controller.isRunning.value = true;

    await tester.pumpWidget(buildTestApp(home: const AutoLabelView()));
    await tester.pump();

    expect(find.text('预标注中...'), findsOneWidget);
    expect(find.text('停止预标注'), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);

    controller.isStopping.value = true;
    await tester.pump();

    expect(find.text('停止中...'), findsOneWidget);
  });

  testWidgets('自动预标注预览支持按文件夹筛选', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final controller = Get.find<AutoLabelController>();
    controller.imageDir.value = 'C:/dataset/images';
    controller.previewImages.assignAll(const [
      ImageItem(
        path: 'C:/dataset/images/train/train.jpg',
        labelPath: 'C:/dataset/labels/train/train.txt',
        fileName: 'train.jpg',
        relativePath: 'images/train/train.jpg',
        width: 100,
        height: 80,
      ),
      ImageItem(
        path: 'C:/dataset/images/val/val.jpg',
        labelPath: 'C:/dataset/labels/val/val.txt',
        fileName: 'val.jpg',
        relativePath: 'images/val/val.jpg',
        width: 100,
        height: 80,
      ),
    ]);

    await tester.pumpWidget(buildTestApp(home: const AutoLabelView()));
    await tester.pumpAndSettle();

    expect(find.text('images/train/train.jpg'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    controller.setFolderFilter(DatasetFolderFilter.val);
    await tester.pumpAndSettle();

    expect(find.text('images/val/val.jpg'), findsOneWidget);
    expect(find.text('1/1（共 2）'), findsOneWidget);
    expect(find.text('已筛选 1/2 张预览图片'), findsOneWidget);
  });
}

final _transparentPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);
