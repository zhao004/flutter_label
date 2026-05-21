import 'package:flutter/material.dart';
import 'package:flutter_label/app/controllers/annotation_controller.dart';
import 'package:flutter_label/app/controllers/class_controller.dart';
import 'package:flutter_label/app/controllers/image_list_controller.dart';
import 'package:flutter_label/app/controllers/project_controller.dart';
import 'package:flutter_label/app/models/dataset_split.dart';
import 'package:flutter_label/app/models/image_annotation_status.dart';
import 'package:flutter_label/app/models/image_item.dart';
import 'package:flutter_label/app/pages/annotation/annotation_view.dart';
import 'package:flutter_label/app/services/image_index_service.dart';
import 'package:flutter_label/app/theme/fluent_design_tokens.dart';
import 'package:flutter_label/app/widgets/image_canvas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';
import '../../support/test_settings.dart';

void main() {
  setUp(() async {
    Get.testMode = true;
    await putTestSettingsController();
    Get.put(ImageListController());
    Get.put(ClassController());
    Get.put(ProjectController());
    Get.put(
      AnnotationController(
        imageListController: Get.find<ImageListController>(),
        classController: Get.find<ClassController>(),
        projectController: Get.find<ProjectController>(),
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('空标注页展示导入入口与空态提示', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    expect(find.text('图片标注'), findsAtLeastNWidgets(1));
    expect(find.text('工作台'), findsNothing);
    expect(find.text('返回工作页'), findsOneWidget);
    expect(find.text('导入图片'), findsWidgets);
    expect(find.text('当前数据集还没有图片'), findsOneWidget);
    expect(find.text('导入图片'), findsWidgets);
  });

  testWidgets('标注页窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('图片列表'), findsOneWidget);
    expect(find.byTooltip('类别与标注框'), findsOneWidget);

    await tester.tap(find.byTooltip('图片列表'));
    await tester.pumpAndSettle();
    expect(find.text('图片列表（0/0）'), findsOneWidget);

    Navigator.of(tester.element(find.byType(AnnotationView))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('类别与标注框'));
    await tester.pumpAndSettle();
    expect(find.text('类别'), findsOneWidget);
    expect(find.text('标注框（0）'), findsOneWidget);
  });

  testWidgets('标注页 AppBar 操作在响应式切换时不会残留失效水波纹', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pump();
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('图片标注'), findsAtLeastNWidgets(1));
  });

  testWidgets('桌面右侧面板支持手动折叠与展开', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('折叠右侧面板'), findsOneWidget);
    expect(find.text('工具面板'), findsOneWidget);

    await tester.tap(find.byTooltip('折叠右侧面板'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('展开右侧面板'), findsOneWidget);
    expect(find.text('工具面板'), findsNothing);

    await tester.tap(find.byTooltip('展开右侧面板'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('折叠右侧面板'), findsOneWidget);
    expect(find.text('工具面板'), findsOneWidget);
  });

  testWidgets('桌面左侧图片列表支持手动折叠与展开', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final imageListController = Get.find<ImageListController>();

    imageListController.applyIndexUpdate(
      const ImageIndexUpdate(
        upserts: [
          ImageItem(
            path: '/dataset/images/train/current.jpg',
            labelPath: '/dataset/labels/train/current.txt',
            fileName: 'current.jpg',
            relativePath: 'images/train/current.jpg',
            width: 100,
            height: 80,
          ),
        ],
        statuses: {'images/train/current.jpg': ImageAnnotationStatus.unlabeled},
        removedRelativePaths: [],
        warnings: [],
        processedCount: 1,
        totalCount: 1,
        isComplete: true,
      ),
    );

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('折叠左侧面板'), findsOneWidget);
    expect(find.text('图片列表（1/1）'), findsOneWidget);
    expect(find.text('current.jpg'), findsOneWidget);

    await tester.tap(find.byTooltip('折叠左侧面板'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('展开左侧面板'), findsOneWidget);
    expect(find.text('图片列表（1/1）'), findsNothing);
    expect(find.text('current.jpg'), findsNothing);

    await tester.tap(find.byTooltip('展开左侧面板'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('折叠左侧面板'), findsOneWidget);
    expect(find.text('图片列表（1/1）'), findsOneWidget);
    expect(find.text('current.jpg'), findsOneWidget);
  });

  testWidgets('画布绘制被裁剪在中间区域内', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    final clipFinder = find.descendant(
      of: find.byType(ImageCanvas),
      matching: find.byType(ClipRect),
    );

    expect(clipFinder, findsOneWidget);
    expect(tester.widget<ClipRect>(clipFinder).clipBehavior, Clip.hardEdge);
  });

  testWidgets('切换图片后左侧图片列表自动滚动到当前图片', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final imageListController = Get.find<ImageListController>();

    imageListController.applyIndexUpdate(
      ImageIndexUpdate(
        upserts: [
          for (var index = 0; index < 30; index += 1)
            ImageItem(
              path: '/dataset/images/train/image_$index.jpg',
              labelPath: '/dataset/labels/train/image_$index.txt',
              fileName: 'image_$index.jpg',
              relativePath: 'images/train/image_$index.jpg',
              width: 100,
              height: 80,
            ),
        ],
        statuses: {
          for (var index = 0; index < 30; index += 1)
            'images/train/image_$index.jpg': ImageAnnotationStatus.unlabeled,
        },
        removedRelativePaths: const [],
        warnings: const [],
        processedCount: 30,
        totalCount: 30,
        isComplete: true,
      ),
    );
    imageListController.selectByIndex(0);

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    expect(find.text('image_29.jpg'), findsNothing);

    imageListController.selectByIndex(29);
    await tester.pumpAndSettle();

    expect(find.text('image_29.jpg'), findsOneWidget);
  });

  testWidgets('左侧图片列表支持按文件夹筛选', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final imageListController = Get.find<ImageListController>();

    imageListController.applyIndexUpdate(
      const ImageIndexUpdate(
        upserts: [
          ImageItem(
            path: '/dataset/images/train/train.jpg',
            labelPath: '/dataset/labels/train/train.txt',
            fileName: 'train.jpg',
            relativePath: 'images/train/train.jpg',
            width: 100,
            height: 80,
          ),
          ImageItem(
            path: '/dataset/images/val/val.jpg',
            labelPath: '/dataset/labels/val/val.txt',
            fileName: 'val.jpg',
            relativePath: 'images/val/val.jpg',
            width: 100,
            height: 80,
          ),
          ImageItem(
            path: '/dataset/images/test/test.jpg',
            labelPath: '/dataset/labels/test/test.txt',
            fileName: 'test.jpg',
            relativePath: 'images/test/test.jpg',
            width: 100,
            height: 80,
          ),
        ],
        statuses: {
          'images/train/train.jpg': ImageAnnotationStatus.unlabeled,
          'images/val/val.jpg': ImageAnnotationStatus.unlabeled,
          'images/test/test.jpg': ImageAnnotationStatus.unlabeled,
        },
        removedRelativePaths: [],
        warnings: [],
        processedCount: 3,
        totalCount: 3,
        isComplete: true,
      ),
    );

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    expect(find.text('train.jpg'), findsOneWidget);
    expect(find.text('val.jpg'), findsOneWidget);
    expect(find.text('test.jpg'), findsOneWidget);

    imageListController.setFolderFilter(DatasetFolderFilter.val);
    await tester.pumpAndSettle();

    expect(find.text('图片列表（1/3）'), findsOneWidget);
    expect(find.text('train.jpg'), findsNothing);
    expect(find.text('val.jpg'), findsOneWidget);
    expect(find.text('test.jpg'), findsNothing);
  });

  testWidgets('当前图片列表项显示选中背景色', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final imageListController = Get.find<ImageListController>();

    imageListController.applyIndexUpdate(
      const ImageIndexUpdate(
        upserts: [
          ImageItem(
            path: '/dataset/images/train/current.jpg',
            labelPath: '/dataset/labels/train/current.txt',
            fileName: 'current.jpg',
            relativePath: 'images/train/current.jpg',
            width: 100,
            height: 80,
          ),
        ],
        statuses: {'images/train/current.jpg': ImageAnnotationStatus.unlabeled},
        removedRelativePaths: [],
        warnings: [],
        processedCount: 1,
        totalCount: 1,
        isComplete: true,
      ),
    );
    imageListController.selectByIndex(0);

    await tester.pumpWidget(buildTestApp(home: const AnnotationView()));
    await tester.pumpAndSettle();

    final tileFinder = find.ancestor(
      of: find.text('current.jpg'),
      matching: find.byType(ListTile),
    );
    final materialFinder = find.ancestor(
      of: tileFinder,
      matching: find.byType(Material),
    );
    final tile = tester.widget<ListTile>(tileFinder);
    final material = tester.widget<Material>(materialFinder.first);

    expect(tile.selected, isTrue);
    expect(material.color, FluentDesignTokens.selectedBackground);
  });
}
