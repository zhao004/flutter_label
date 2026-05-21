import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/annotation_box.dart';
import '../models/canvas_transform.dart';
import '../models/dataset_split.dart';
import '../models/image_item.dart';
import '../models/project_config.dart';
import '../services/app_toast_service.dart';
import '../services/dataset_import_service.dart';
import '../services/image_index_service.dart';
import '../services/image_scan_service.dart';
import '../services/project_service.dart';
import '../services/yolo_label_service.dart';
import '../utils/coordinate_utils.dart';
import 'class_controller.dart';
import 'image_list_controller.dart';
import 'project_controller.dart';

enum ResizeHandle {
  none,
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

class AnnotationController extends GetxController {
  AnnotationController({
    required ImageListController imageListController,
    required ClassController classController,
    required ProjectController projectController,
    YoloLabelService yoloLabelService = const YoloLabelService(),
    ProjectService projectService = const ProjectService(),
    DatasetImportService datasetImportService = const DatasetImportService(),
  }) : _imageListController = imageListController,
       _classController = classController,
       _projectController = projectController,
       _yoloLabelService = yoloLabelService,
       _projectService = projectService,
       _datasetImportService = datasetImportService;

  static const minZoom = 0.05;
  static const maxZoom = 12.0;
  static const zoomStep = 1.12;
  static const minBoxSize = YoloLabelService.minBoxSize;
  static const _uuid = Uuid();

  final ImageListController _imageListController;
  final ClassController _classController;
  final ProjectController _projectController;
  final YoloLabelService _yoloLabelService;
  final ProjectService _projectService;
  final DatasetImportService _datasetImportService;

  final currentImage = Rxn<ImageItem>();
  final boxes = <AnnotationBox>[].obs;
  final selectedBoxId = RxnString();
  final currentClassId = 0.obs;
  final isDirty = false.obs;
  final transform = CanvasTransform.initial.obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final warnings = <String>[].obs;
  final completedImages = <String>{}.obs;
  final canUndo = false.obs;
  final canRedo = false.obs;

  final List<List<AnnotationBox>> _undoStack = [];
  final List<List<AnnotationBox>> _redoStack = [];
  static const _maxHistoryDepth = 80;

  ImageItem? get image => currentImage.value;
  double get zoom => transform.value.scale;
  Offset get canvasOffset => transform.value.offset;

  ({int width, int height})? _dimensionsOf(ImageItem item) {
    final width = item.width;
    final height = item.height;
    if (width == null || height == null) {
      errorMessage.value = '图片尺寸尚未读取完成';
      return null;
    }
    return (width: width, height: height);
  }

  ({int width, int height}) _requireImageDimensions(ImageItem item) {
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      throw StateError('图片尺寸尚未读取完成');
    }
    return dimensions;
  }

  @override
  void onReady() {
    super.onReady();
    final argument = Get.arguments;
    if (argument is AnnotationOpenRequest) {
      openProject(argument);
    } else if (argument is String && argument.trim().isNotEmpty) {
      openProject(AnnotationOpenRequest(imageDir: argument));
    }
  }

  Future<void> openProject(AnnotationOpenRequest request) async {
    isLoading.value = true;
    errorMessage.value = null;
    warnings.clear();
    try {
      ProjectConfig? project;
      late final DatasetPaths datasetPaths;
      late final ImageIndexScanMode scanMode;
      if (request.datasetDir != null) {
        project = await _projectController.loadDatasetProject(
          request.datasetDir!,
        );
        datasetPaths = _imageListController.imageScanService
            .validateDatasetRoot(project.datasetDir);
        scanMode = ImageIndexScanMode.datasetRoot;
      } else if (request.projectFilePath != null) {
        project = await _projectController.loadProject(
          request.projectFilePath!,
        );
        datasetPaths = _imageListController.imageScanService
            .validateDatasetImagesDir(project.imageDir);
        scanMode = ImageIndexScanMode.imagesDirectory;
      } else {
        final imageDir = request.imageDir?.trim();
        if (imageDir == null || imageDir.isEmpty) {
          throw const FormatException('请选择数据集项目或图片目录');
        }
        datasetPaths = _imageListController.imageScanService
            .validateDatasetImagesDir(imageDir);
        scanMode = ImageIndexScanMode.imagesDirectory;
      }
      await _classController.loadClasses(
        datasetPaths.dataYamlPath,
        labelDir: datasetPaths.labelDir,
      );
      project ??= ProjectConfig.fromDataset(
        datasetDir: datasetPaths.datasetRoot,
        imageDir: datasetPaths.imageDir,
        labelDir: datasetPaths.labelDir,
        classes: _classController.classNames,
        projectFilePath: _projectService.defaultProjectPath(
          datasetPaths.datasetRoot,
        ),
      );
      project = await _projectController.saveProject(
        project.copyWith(
          datasetDir: datasetPaths.datasetRoot,
          imageDir: datasetPaths.imageDir,
          labelDir: datasetPaths.labelDir,
          classes: _classController.classNames,
        ),
      );
      completedImages.assignAll(project.completedImages.toSet());
      _imageListController.completedImages.assignAll(completedImages);
      final snapshot = await _imageListController.loadCachedIndex(
        paths: datasetPaths,
        scanMode: scanMode,
      );
      warnings.addAll(snapshot.warnings);
      currentClassId.value = _classController.classCount > 0 ? 0 : -1;
      if (_imageListController.images.isEmpty) {
        _clearCurrentImageState();
      } else {
        await loadImageAt(0, saveBeforeSwitch: false);
      }
      _startIndexRefresh(datasetPaths, scanMode);
    } catch (error) {
      errorMessage.value = error.toString();
      AppToast.error(error, source: '图片标注');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openImagesDirectory(String imageDir) {
    return openProject(AnnotationOpenRequest(imageDir: imageDir));
  }

  Future<void> importImageFiles({
    required DatasetSplit split,
    required List<String> filePaths,
  }) async {
    await _importImages(
      () => _datasetImportService.importFiles(
        datasetDir: _requireDatasetDir(),
        filePaths: filePaths,
        split: split,
      ),
    );
  }

  Future<void> importImageDirectory({
    required DatasetSplit split,
    required String sourceDir,
  }) async {
    await _importImages(
      () => _datasetImportService.importDirectory(
        datasetDir: _requireDatasetDir(),
        sourceDir: sourceDir,
        split: split,
      ),
    );
  }

  Future<bool> loadImageAt(int index, {bool saveBeforeSwitch = true}) async {
    if (saveBeforeSwitch && !await saveCurrent()) {
      return false;
    }
    if (!_imageListController.selectByIndex(index)) {
      return false;
    }

    final nextImage = await _imageListController.ensureImageDimensionsAt(index);
    if (nextImage == null) {
      errorMessage.value = _imageListController.errorMessage.value;
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final dimensions = _requireImageDimensions(nextImage);
      final labelResult = await _yoloLabelService.loadLabels(
        labelPath: nextImage.labelPath,
        imageWidth: dimensions.width,
        imageHeight: dimensions.height,
        classCount: _classController.classCount,
      );
      currentImage.value = nextImage;
      boxes.assignAll(labelResult.boxes);
      selectedBoxId.value = null;
      isDirty.value = false;
      _clearHistory();
      resetView();
      warnings.assignAll([
        ..._imageListController.warnings,
        ...labelResult.warnings,
      ]);
      return true;
    } catch (error) {
      errorMessage.value = error.toString();
      AppToast.error(error, source: '图片标注');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> saveCurrent({bool showSuccessToast = false}) async {
    final item = currentImage.value;
    if (item == null) {
      if (showSuccessToast) {
        AppToast.error('当前没有可保存的图片', source: '图片标注');
      }
      return true;
    }
    if (!isDirty.value) {
      if (showSuccessToast) {
        AppToast.success('没有需要保存的更改');
      }
      return true;
    }

    try {
      final dimensions = _requireImageDimensions(item);
      await _yoloLabelService.saveLabels(
        labelPath: item.labelPath,
        boxes: boxes.toList(growable: false),
        imageWidth: dimensions.width,
        imageHeight: dimensions.height,
        classCount: _classController.classCount,
      );
      await _imageListController.refreshImageStatus(
        image: item,
        classCount: _classController.classCount,
      );
      isDirty.value = false;
      errorMessage.value = null;
      if (showSuccessToast) {
        AppToast.success('标签已保存');
      }
      return true;
    } catch (error) {
      errorMessage.value = '保存失败：$error';
      AppToast.error(errorMessage.value, source: '图片标注');
      return false;
    }
  }

  Future<void> selectPreviousImage() async {
    final image = _imageListController.visibleNeighbor(direction: -1);
    if (image != null) {
      await loadImageAt(_imageListController.indexOfPath(image.path));
    }
  }

  Future<void> selectNextImage() async {
    final image = _imageListController.visibleNeighbor(direction: 1);
    if (image != null) {
      await loadImageAt(_imageListController.indexOfPath(image.path));
    }
  }

  void selectClass(int classId) {
    if (classId < 0 || classId >= _classController.classCount) {
      errorMessage.value = '类别编号越界';
      AppToast.error(errorMessage.value, source: '图片标注');
      return;
    }
    currentClassId.value = classId;
  }

  void selectBox(String? boxId) {
    selectedBoxId.value = boxId;
  }

  String classNameOf(int classId) {
    return _classController.classNameOf(classId);
  }

  AnnotationBox? boxById(String? id) {
    if (id == null) {
      return null;
    }
    for (final box in boxes) {
      if (box.id == id) {
        return box;
      }
    }
    return null;
  }

  String? hitTestBox(Offset imagePoint) {
    for (final box in boxes.reversed) {
      if (box.rect.inflate(3 / zoom).contains(imagePoint)) {
        return box.id;
      }
    }
    return null;
  }

  ResizeHandle hitTestHandle(Offset imagePoint) {
    final box = boxById(selectedBoxId.value);
    if (box == null) {
      return ResizeHandle.none;
    }

    final handleSize = 8 / zoom;
    final points = <ResizeHandle, Offset>{
      ResizeHandle.topLeft: box.rect.topLeft,
      ResizeHandle.top: Offset(box.rect.center.dx, box.rect.top),
      ResizeHandle.topRight: box.rect.topRight,
      ResizeHandle.right: Offset(box.rect.right, box.rect.center.dy),
      ResizeHandle.bottomRight: box.rect.bottomRight,
      ResizeHandle.bottom: Offset(box.rect.center.dx, box.rect.bottom),
      ResizeHandle.bottomLeft: box.rect.bottomLeft,
      ResizeHandle.left: Offset(box.rect.left, box.rect.center.dy),
    };

    for (final entry in points.entries) {
      if ((entry.value - imagePoint).distance <= handleSize) {
        return entry.key;
      }
    }
    return ResizeHandle.none;
  }

  AnnotationBox? createBox(Rect imageRect) {
    final item = currentImage.value;
    if (item == null) {
      return null;
    }
    if (_classController.classCount == 0) {
      errorMessage.value = '请先新增类别，再创建标注框';
      AppToast.error(errorMessage.value, source: '图片标注');
      return null;
    }
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      return null;
    }
    final rect = CoordinateUtils.clampRectToImage(
      imageRect,
      imageWidth: dimensions.width,
      imageHeight: dimensions.height,
    );
    if (rect.width < minBoxSize || rect.height < minBoxSize) {
      return null;
    }
    captureUndoSnapshot();
    final box = AnnotationBox(
      id: _uuid.v4(),
      classId: currentClassId.value,
      rect: rect,
    );
    boxes.add(box);
    selectedBoxId.value = box.id;
    isDirty.value = true;
    return box;
  }

  void replaceDraftBox(String boxId, Rect imageRect) {
    final item = currentImage.value;
    if (item == null) {
      return;
    }
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      return;
    }
    _replaceBox(
      boxId,
      CoordinateUtils.clampRectToImage(
        imageRect,
        imageWidth: dimensions.width,
        imageHeight: dimensions.height,
      ),
    );
  }

  void moveSelectedBox(Offset imageDelta) {
    final box = boxById(selectedBoxId.value);
    if (box == null) {
      return;
    }

    captureUndoSnapshot();
    _moveBoxWithinImage(box.id, box.rect, imageDelta);
  }

  void moveSelectedBoxFromStart(Rect startRect, Offset imageDelta) {
    final box = boxById(selectedBoxId.value);
    if (box == null) {
      return;
    }
    _moveBoxWithinImage(box.id, startRect, imageDelta);
  }

  void _moveBoxWithinImage(String boxId, Rect startRect, Offset imageDelta) {
    final item = currentImage.value;
    if (item == null) {
      return;
    }
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      return;
    }

    final moved = startRect.shift(imageDelta);
    final dx = _overflowCorrection(
      min: moved.left,
      max: moved.right,
      limit: dimensions.width.toDouble(),
    );
    final dy = _overflowCorrection(
      min: moved.top,
      max: moved.bottom,
      limit: dimensions.height.toDouble(),
    );
    _replaceBox(boxId, moved.shift(Offset(dx, dy)));
  }

  void resizeSelectedBox(ResizeHandle handle, Offset imagePoint) {
    final item = currentImage.value;
    final box = boxById(selectedBoxId.value);
    if (item == null || box == null || handle == ResizeHandle.none) {
      return;
    }
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      return;
    }

    var left = box.rect.left;
    var top = box.rect.top;
    var right = box.rect.right;
    var bottom = box.rect.bottom;

    switch (handle) {
      case ResizeHandle.topLeft:
        left = imagePoint.dx;
        top = imagePoint.dy;
      case ResizeHandle.top:
        top = imagePoint.dy;
      case ResizeHandle.topRight:
        right = imagePoint.dx;
        top = imagePoint.dy;
      case ResizeHandle.right:
        right = imagePoint.dx;
      case ResizeHandle.bottomRight:
        right = imagePoint.dx;
        bottom = imagePoint.dy;
      case ResizeHandle.bottom:
        bottom = imagePoint.dy;
      case ResizeHandle.bottomLeft:
        left = imagePoint.dx;
        bottom = imagePoint.dy;
      case ResizeHandle.left:
        left = imagePoint.dx;
      case ResizeHandle.none:
        return;
    }

    final rect = CoordinateUtils.clampRectToImage(
      Rect.fromLTRB(left, top, right, bottom),
      imageWidth: dimensions.width,
      imageHeight: dimensions.height,
    );
    if (rect.width >= minBoxSize && rect.height >= minBoxSize) {
      _replaceBox(box.id, rect);
    }
  }

  void deleteSelectedBox() {
    final id = selectedBoxId.value;
    if (id == null) {
      return;
    }
    captureUndoSnapshot();
    boxes.removeWhere((box) => box.id == id);
    selectedBoxId.value = null;
    isDirty.value = true;
  }

  Future<void> toggleCompleted() async {
    final item = currentImage.value;
    if (item == null) {
      return;
    }
    await _setImageCompleted(
      item,
      completed: !completedImages.contains(item.relativePath),
    );
  }

  Future<void> completeCurrentAndSelectNext() async {
    final item = currentImage.value;
    if (item == null) {
      return;
    }
    if (!await saveCurrent()) {
      return;
    }
    await _setImageCompleted(item, completed: true);
    await selectNextImage();
  }

  Future<void> _setImageCompleted(
    ImageItem item, {
    required bool completed,
  }) async {
    final next = Set<String>.from(completedImages);
    final changed = completed
        ? next.add(item.relativePath)
        : next.remove(item.relativePath);
    if (!changed) {
      return;
    }

    completedImages.assignAll(next);
    _imageListController.setCompleted(item.relativePath, completed);
    await _imageListController.refreshImageStatus(
      image: item,
      classCount: _classController.classCount,
    );
    await _projectController.updateCompletedImages(next);
  }

  Future<void> refreshStatuses() async {
    await _imageListController.refreshStatuses(
      classCount: _classController.classCount,
      completed: completedImages,
    );
  }

  void captureUndoSnapshot() {
    _undoStack.add(_cloneBoxes(boxes));
    if (_undoStack.length > _maxHistoryDepth) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _syncHistoryState();
  }

  void undo() {
    if (_undoStack.isEmpty) {
      return;
    }
    _redoStack.add(_cloneBoxes(boxes));
    boxes.assignAll(_undoStack.removeLast());
    selectedBoxId.value = null;
    isDirty.value = true;
    _syncHistoryState();
  }

  void redo() {
    if (_redoStack.isEmpty) {
      return;
    }
    _undoStack.add(_cloneBoxes(boxes));
    boxes.assignAll(_redoStack.removeLast());
    selectedBoxId.value = null;
    isDirty.value = true;
    _syncHistoryState();
  }

  Future<void> addClass(String name) async {
    try {
      await _classController.addClass(name);
      if (currentClassId.value < 0 && _classController.classCount > 0) {
        currentClassId.value = 0;
      }
      await _afterClassesChanged();
      AppToast.success('类别已新增');
    } catch (error) {
      errorMessage.value = error.toString();
      AppToast.error(error, source: '图片标注');
    }
  }

  Future<void> renameClass(int classId, String name) async {
    try {
      await _classController.renameClass(classId, name);
      await _afterClassesChanged();
      AppToast.success('类别已重命名');
    } catch (error) {
      errorMessage.value = error.toString();
      AppToast.error(error, source: '图片标注');
    }
  }

  Future<void> deleteClass(int classId) async {
    try {
      await saveCurrent();
      await _classController.deleteClass(classId);
      if (currentClassId.value >= _classController.classCount) {
        currentClassId.value = _classController.classCount - 1;
      }
      await _afterClassesChanged(reloadCurrentLabels: true);
      AppToast.success('类别已删除');
    } catch (error) {
      errorMessage.value = error.toString();
      AppToast.error(error, source: '图片标注');
    }
  }

  Future<void> moveClass(int classId, int direction) async {
    try {
      await saveCurrent();
      await _classController.moveClass(classId, direction);
      final target = classId + direction;
      if (currentClassId.value == classId) {
        currentClassId.value = target;
      } else if (currentClassId.value == target) {
        currentClassId.value = classId;
      }
      await _afterClassesChanged(reloadCurrentLabels: true);
      AppToast.success('类别顺序已同步');
    } catch (error) {
      errorMessage.value = error.toString();
      AppToast.error(error, source: '图片标注');
    }
  }

  void resetView() {
    transform.value = CanvasTransform.initial;
  }

  void fitToViewport(Size viewportSize) {
    final item = currentImage.value;
    if (item == null || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return;
    }
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      return;
    }

    final scale = math
        .min(
          viewportSize.width / dimensions.width,
          viewportSize.height / dimensions.height,
        )
        .clamp(minZoom, maxZoom);
    final scaledWidth = dimensions.width * scale;
    final scaledHeight = dimensions.height * scale;
    final offset = Offset(
      (viewportSize.width - scaledWidth) / 2,
      (viewportSize.height - scaledHeight) / 2,
    );
    transform.value = CanvasTransform(scale: scale, offset: offset);
  }

  void clampViewToViewport(Size viewportSize) {
    final currentTransform = transform.value;
    final clampedOffset = _clampCanvasOffset(
      offset: currentTransform.offset,
      scale: currentTransform.scale,
      viewportSize: viewportSize,
    );
    if (clampedOffset == currentTransform.offset) {
      return;
    }
    transform.value = currentTransform.copyWith(offset: clampedOffset);
  }

  void panCanvas(Offset delta, Size viewportSize) {
    final currentTransform = transform.value;
    final nextOffset = _clampCanvasOffset(
      offset: currentTransform.offset + delta,
      scale: currentTransform.scale,
      viewportSize: viewportSize,
    );
    transform.value = currentTransform.copyWith(offset: nextOffset);
  }

  void replaceSelectedBoxRect(Rect rect) {
    final box = boxById(selectedBoxId.value);
    if (box == null) {
      return;
    }
    _replaceBox(box.id, rect);
  }

  void zoomAt(Offset canvasPoint, double scrollDelta, Size viewportSize) {
    final oldScale = zoom;
    final factor = scrollDelta < 0 ? zoomStep : 1 / zoomStep;
    final newScale = (oldScale * factor).clamp(minZoom, maxZoom);
    if (newScale == oldScale) {
      return;
    }

    // 以鼠标位置为锚点缩放，避免滚轮缩放时目标区域跳动。
    final imagePoint = CoordinateUtils.canvasPointToImage(
      canvasPoint,
      scale: oldScale,
      offset: canvasOffset,
    );
    final newOffset = _clampCanvasOffset(
      offset: canvasPoint - imagePoint * newScale,
      scale: newScale,
      viewportSize: viewportSize,
    );
    transform.value = CanvasTransform(scale: newScale, offset: newOffset);
  }

  Offset canvasPointToImage(Offset canvasPoint) {
    return CoordinateUtils.canvasPointToImage(
      canvasPoint,
      scale: zoom,
      offset: canvasOffset,
    );
  }

  Rect imageRectToCanvas(Rect imageRect) {
    return CoordinateUtils.imageToCanvas(
      imageRect,
      scale: zoom,
      offset: canvasOffset,
    );
  }

  void _replaceBox(String boxId, Rect rect) {
    final item = currentImage.value;
    if (item == null) {
      return;
    }
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      return;
    }
    final index = boxes.indexWhere((box) => box.id == boxId);
    if (index < 0) {
      return;
    }
    boxes[index] = boxes[index].copyWith(
      rect: CoordinateUtils.clampRectToImage(
        rect,
        imageWidth: dimensions.width,
        imageHeight: dimensions.height,
      ),
    );
    isDirty.value = true;
  }

  Future<void> _afterClassesChanged({bool reloadCurrentLabels = false}) async {
    await _projectController.updateClasses(_classController.classNames);
    await refreshStatuses();
    if (reloadCurrentLabels && currentImage.value != null) {
      await loadImageAt(
        _imageListController.selectedIndex.value,
        saveBeforeSwitch: false,
      );
    }
  }

  void _startIndexRefresh(DatasetPaths paths, ImageIndexScanMode scanMode) {
    _imageListController.refreshIndexInBackground(
      paths: paths,
      scanMode: scanMode,
      classCount: _classController.classCount,
      completed: completedImages.toSet(),
      onImagesAvailable: () {
        if (currentImage.value == null &&
            _imageListController.images.isNotEmpty) {
          unawaited(loadImageAt(0, saveBeforeSwitch: false));
        }
      },
    );
  }

  Future<void> _importImages(
    Future<DatasetImportResult> Function() importAction,
  ) async {
    if (!await saveCurrent()) {
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await importAction();
      warnings.addAll(result.logs);
      final project = _projectController.currentProject.value;
      if (project == null) {
        throw StateError('项目未初始化');
      }

      final datasetPaths = _imageListController.imageScanService
          .validateDatasetRoot(project.datasetDir);
      final snapshot = await _imageListController.loadCachedIndex(
        paths: datasetPaths,
        scanMode: ImageIndexScanMode.datasetRoot,
      );
      warnings.addAll(snapshot.warnings);
      if (_imageListController.images.isEmpty) {
        _clearCurrentImageState();
      } else if (currentImage.value == null) {
        await loadImageAt(0, saveBeforeSwitch: false);
      }
      _startIndexRefresh(datasetPaths, ImageIndexScanMode.datasetRoot);
      AppToast.success('已导入 ${result.importedCount} 张图片');
    } catch (error) {
      errorMessage.value = '导入图片失败：$error';
      AppToast.error(errorMessage.value, source: '图片标注');
    } finally {
      isLoading.value = false;
    }
  }

  String _requireDatasetDir() {
    final project = _projectController.currentProject.value;
    if (project == null || project.datasetDir.trim().isEmpty) {
      throw StateError('请先打开或新建数据集项目');
    }
    return project.datasetDir;
  }

  void _clearCurrentImageState() {
    currentImage.value = null;
    boxes.clear();
    selectedBoxId.value = null;
    isDirty.value = false;
    resetView();
    _clearHistory();
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _syncHistoryState();
  }

  void _syncHistoryState() {
    canUndo.value = _undoStack.isNotEmpty;
    canRedo.value = _redoStack.isNotEmpty;
  }

  List<AnnotationBox> _cloneBoxes(Iterable<AnnotationBox> source) {
    return [
      for (final box in source)
        AnnotationBox(id: box.id, classId: box.classId, rect: box.rect),
    ];
  }

  double _overflowCorrection({
    required double min,
    required double max,
    required double limit,
  }) {
    if (min < 0) {
      return -min;
    }
    if (max > limit) {
      return limit - max;
    }
    return 0;
  }

  Offset _clampCanvasOffset({
    required Offset offset,
    required double scale,
    required Size viewportSize,
  }) {
    final item = currentImage.value;
    if (item == null || viewportSize.width <= 0 || viewportSize.height <= 0) {
      return offset;
    }
    final dimensions = _dimensionsOf(item);
    if (dimensions == null) {
      return offset;
    }

    final scaledWidth = dimensions.width * scale;
    final scaledHeight = dimensions.height * scale;
    return Offset(
      _clampAxisOffset(
        offset: offset.dx,
        contentExtent: scaledWidth,
        viewportExtent: viewportSize.width,
      ),
      _clampAxisOffset(
        offset: offset.dy,
        contentExtent: scaledHeight,
        viewportExtent: viewportSize.height,
      ),
    );
  }

  double _clampAxisOffset({
    required double offset,
    required double contentExtent,
    required double viewportExtent,
  }) {
    if (contentExtent <= 0 || viewportExtent <= 0) {
      return offset;
    }
    if (contentExtent <= viewportExtent) {
      return (viewportExtent - contentExtent) / 2;
    }
    return offset.clamp(viewportExtent - contentExtent, 0).toDouble();
  }

  Rect rectFromPoints(Offset start, Offset end) {
    return Rect.fromLTRB(
      math.min(start.dx, end.dx),
      math.min(start.dy, end.dy),
      math.max(start.dx, end.dx),
      math.max(start.dy, end.dy),
    );
  }
}
