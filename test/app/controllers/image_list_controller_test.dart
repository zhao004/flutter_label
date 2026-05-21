import 'package:flutter_label/app/controllers/image_list_controller.dart';
import 'package:flutter_label/app/models/dataset_split.dart';
import 'package:flutter_label/app/models/image_annotation_status.dart';
import 'package:flutter_label/app/models/image_item.dart';
import 'package:flutter_label/app/services/image_index_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageListController', () {
    test('可以按相对路径快速定位并保持排序', () async {
      final controller = ImageListController(
        imageIndexService: const ImageIndexService(),
      );
      controller.applyIndexUpdate(
        const ImageIndexUpdate(
          upserts: [
            ImageItem(
              path: '/dataset/images/train/b.png',
              labelPath: '/dataset/labels/train/b.txt',
              fileName: 'b.png',
              relativePath: 'images/train/b.png',
              width: 200,
              height: 100,
            ),
            ImageItem(
              path: '/dataset/images/train/a.png',
              labelPath: '/dataset/labels/train/a.txt',
              fileName: 'a.png',
              relativePath: 'images/train/a.png',
              width: 100,
              height: 50,
            ),
          ],
          statuses: {
            'images/train/a.png': ImageAnnotationStatus.labeled,
            'images/train/b.png': ImageAnnotationStatus.unlabeled,
          },
          removedRelativePaths: [],
          warnings: [],
          processedCount: 2,
          totalCount: 2,
          isComplete: true,
        ),
      );

      expect(controller.images.first.relativePath, 'images/train/a.png');
      expect(controller.images.last.relativePath, 'images/train/b.png');
      expect(controller.indexOfPath('/dataset/images/train/b.png'), 1);
      expect(controller.indexOfRelativePath('images/train/a.png'), 0);
      expect(controller.statusCounts()[ImageAnnotationStatus.all], 2);
      expect(
        controller.visibleNeighbor(direction: 1)?.relativePath,
        'images/train/b.png',
      );
    });

    test('可以按数据集文件夹筛选图片', () {
      final controller = ImageListController(
        imageIndexService: const ImageIndexService(),
      );
      controller.applyIndexUpdate(
        const ImageIndexUpdate(
          upserts: [
            ImageItem(
              path: '/dataset/images/train/train.png',
              labelPath: '/dataset/labels/train/train.txt',
              fileName: 'train.png',
              relativePath: 'images/train/train.png',
              width: 100,
              height: 80,
            ),
            ImageItem(
              path: '/dataset/images/val/val.png',
              labelPath: '/dataset/labels/val/val.txt',
              fileName: 'val.png',
              relativePath: 'images\\val\\val.png',
              width: 100,
              height: 80,
            ),
            ImageItem(
              path: '/dataset/images/test/test.png',
              labelPath: '/dataset/labels/test/test.txt',
              fileName: 'test.png',
              relativePath: 'test/test.png',
              width: 100,
              height: 80,
            ),
          ],
          statuses: {
            'images/train/train.png': ImageAnnotationStatus.unlabeled,
            'images\\val\\val.png': ImageAnnotationStatus.unlabeled,
            'test/test.png': ImageAnnotationStatus.unlabeled,
          },
          removedRelativePaths: [],
          warnings: [],
          processedCount: 3,
          totalCount: 3,
          isComplete: true,
        ),
      );

      controller.setFolderFilter(DatasetFolderFilter.val);

      expect(controller.visibleImages, hasLength(1));
      expect(controller.visibleImages.single.fileName, 'val.png');

      controller.setFolderFilter(DatasetFolderFilter.test);

      expect(controller.visibleImages, hasLength(1));
      expect(controller.visibleImages.single.fileName, 'test.png');
    });
  });
}
