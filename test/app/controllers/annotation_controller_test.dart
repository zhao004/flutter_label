import 'dart:io';
import 'dart:ui';

import 'package:flutter_label/app/controllers/annotation_controller.dart';
import 'package:flutter_label/app/controllers/class_controller.dart';
import 'package:flutter_label/app/controllers/image_list_controller.dart';
import 'package:flutter_label/app/controllers/project_controller.dart';
import 'package:flutter_label/app/models/image_annotation_status.dart';
import 'package:flutter_label/app/models/image_item.dart';
import 'package:flutter_label/app/models/canvas_transform.dart';
import 'package:flutter_label/app/services/image_index_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AnnotationController', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'flutter_label_annotation_controller_test_',
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('完成当前图片后会切换到下一张可见图片', () async {
      ImageItem imageItem(String fileName) {
        final imagePath = p.join(directory.path, 'images', fileName);
        final labelPath = p.join(
          directory.path,
          'labels',
          p.setExtension(fileName, '.txt'),
        );
        return ImageItem(
          path: imagePath,
          labelPath: labelPath,
          fileName: fileName,
          relativePath: 'images/$fileName',
          width: 100,
          height: 80,
        );
      }

      final imageListController = ImageListController();
      final classController = ClassController();
      final projectController = ProjectController();
      final controller = AnnotationController(
        imageListController: imageListController,
        classController: classController,
        projectController: projectController,
      );
      final firstImage = imageItem('a.jpg');
      final secondImage = imageItem('b.jpg');

      imageListController.applyIndexUpdate(
        ImageIndexUpdate(
          upserts: [firstImage, secondImage],
          statuses: {
            firstImage.relativePath: ImageAnnotationStatus.unlabeled,
            secondImage.relativePath: ImageAnnotationStatus.unlabeled,
          },
          removedRelativePaths: const [],
          warnings: const [],
          processedCount: 2,
          totalCount: 2,
          isComplete: true,
        ),
      );
      controller.currentImage.value = firstImage;

      await controller.completeCurrentAndSelectNext();

      expect(controller.completedImages, contains(firstImage.relativePath));
      expect(
        imageListController.completedImages,
        contains(firstImage.relativePath),
      );
      expect(
        controller.currentImage.value?.relativePath,
        secondImage.relativePath,
      );
      expect(imageListController.selectedIndex.value, 1);
    });

    test('画布拖动会限制在图片可见边界内', () {
      final imageListController = ImageListController();
      final classController = ClassController();
      final projectController = ProjectController();
      final controller = AnnotationController(
        imageListController: imageListController,
        classController: classController,
        projectController: projectController,
      );

      controller.currentImage.value = const ImageItem(
        path: '/dataset/images/train/wide.jpg',
        labelPath: '/dataset/labels/train/wide.txt',
        fileName: 'wide.jpg',
        relativePath: 'images/train/wide.jpg',
        width: 1000,
        height: 500,
      );
      controller.transform.value = const CanvasTransform(
        scale: 1,
        offset: Offset.zero,
      );

      controller.panCanvas(const Offset(-900, -300), const Size(400, 300));
      expect(controller.canvasOffset, const Offset(-600, -200));

      controller.panCanvas(const Offset(1200, 600), const Size(400, 300));
      expect(controller.canvasOffset, Offset.zero);

      controller.currentImage.value = const ImageItem(
        path: '/dataset/images/train/small.jpg',
        labelPath: '/dataset/labels/train/small.txt',
        fileName: 'small.jpg',
        relativePath: 'images/train/small.jpg',
        width: 200,
        height: 100,
      );
      controller.transform.value = const CanvasTransform(
        scale: 1,
        offset: Offset.zero,
      );

      controller.panCanvas(const Offset(-100, -100), const Size(400, 300));
      expect(controller.canvasOffset, const Offset(100, 100));
    });
  });
}
