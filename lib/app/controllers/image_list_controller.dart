import 'package:get/get.dart';

import '../models/dataset_split.dart';
import '../models/image_annotation_status.dart';
import '../models/image_item.dart';
import '../services/image_index_service.dart';
import '../services/image_scan_service.dart';
import '../services/yolo_label_service.dart';

class ImageListController extends GetxController {
  ImageListController({
    ImageScanService imageScanService = const ImageScanService(),
    ImageIndexService imageIndexService = const ImageIndexService(),
    YoloLabelService yoloLabelService = const YoloLabelService(),
  }) : _imageScanService = imageScanService,
       _imageIndexService = imageIndexService,
       _yoloLabelService = yoloLabelService;

  final ImageScanService _imageScanService;
  final ImageIndexService _imageIndexService;
  final YoloLabelService _yoloLabelService;

  final images = <ImageItem>[].obs;
  final visibleImages = <ImageItem>[].obs;
  final selectedIndex = 0.obs;
  final warnings = <String>[].obs;
  final paths = Rxn<DatasetPaths>();
  final errorMessage = RxnString();
  final statuses = <String, ImageAnnotationStatus>{}.obs;
  final completedImages = <String>{}.obs;
  final statusFilter = ImageAnnotationStatus.all.obs;
  final folderFilter = DatasetFolderFilter.all.obs;
  final searchText = ''.obs;
  final isRefreshingIndex = false.obs;
  final refreshProgressText = RxnString();
  final statusCountsVersion = 0.obs;

  final Map<String, int> _indexByPath = {};
  final Map<String, int> _indexByRelativePath = {};
  final Map<String, int> _visibleIndexByPath = {};
  final Map<ImageAnnotationStatus, int> _statusCounts = {
    for (final status in ImageAnnotationStatus.values) status: 0,
  };
  int _indexSession = 0;

  ImageItem? get selectedImage {
    if (images.isEmpty ||
        selectedIndex.value < 0 ||
        selectedIndex.value >= images.length) {
      return null;
    }
    return images[selectedIndex.value];
  }

  ImageScanService get imageScanService => _imageScanService;

  Future<ImageScanResult> scan(String imageDir) async {
    errorMessage.value = null;
    try {
      final result = await _imageScanService.scanImagesDirectory(imageDir);
      _applyScanResult(result);
      return result;
    } catch (error) {
      _clearScanState();
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  Future<ImageScanResult> scanDatasetRoot(String datasetRoot) async {
    errorMessage.value = null;
    try {
      final result = await _imageScanService.scanDatasetRoot(datasetRoot);
      _applyScanResult(result);
      return result;
    } catch (error) {
      _clearScanState();
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  Future<ImageIndexSnapshot> loadCachedIndex({
    required DatasetPaths paths,
    required ImageIndexScanMode scanMode,
  }) async {
    final session = ++_indexSession;
    isRefreshingIndex.value = false;
    refreshProgressText.value = null;
    errorMessage.value = null;
    try {
      this.paths.value = paths;
      final snapshot = await _imageIndexService.loadCachedSnapshot(
        paths: paths,
        scanMode: scanMode,
      );
      if (session == _indexSession) {
        _applyIndexSnapshot(snapshot);
      }
      return snapshot;
    } catch (error) {
      if (session == _indexSession) {
        _clearScanState();
        errorMessage.value = error.toString();
      }
      rethrow;
    }
  }

  void refreshIndexInBackground({
    required DatasetPaths paths,
    required ImageIndexScanMode scanMode,
    required int classCount,
    required Set<String> completed,
    void Function()? onImagesAvailable,
  }) {
    final session = _indexSession;
    isRefreshingIndex.value = true;
    refreshProgressText.value = '正在更新图片索引...';

    _imageIndexService
        .refreshIndex(
          paths: paths,
          scanMode: scanMode,
          classCount: classCount,
          completedImages: completed,
          isCancelled: () => session != _indexSession,
          onUpdate: (update) {
            if (session != _indexSession) {
              return;
            }
            final hadImages = images.isNotEmpty;
            applyIndexUpdate(update);
            if (!hadImages && images.isNotEmpty) {
              onImagesAvailable?.call();
            }
          },
        )
        .then((_) {
          if (session == _indexSession) {
            isRefreshingIndex.value = false;
            refreshProgressText.value = null;
          }
        })
        .catchError((Object error) {
          if (session == _indexSession) {
            isRefreshingIndex.value = false;
            refreshProgressText.value = null;
            errorMessage.value = '图片索引更新失败：$error';
          }
        });
  }

  bool selectByIndex(int index) {
    if (index < 0 || index >= images.length) {
      return false;
    }
    selectedIndex.value = index;
    return true;
  }

  bool selectImage(ImageItem image) {
    final index = indexOfPath(image.path);
    return selectByIndex(index);
  }

  int indexOfPath(String path) {
    return _indexByPath[path] ?? -1;
  }

  int indexOfRelativePath(String relativePath) {
    return _indexByRelativePath[relativePath] ?? -1;
  }

  Future<ImageItem?> ensureImageDimensionsAt(int index) async {
    if (index < 0 || index >= images.length) {
      return null;
    }
    final image = images[index];
    if (image.hasDimensions) {
      return image;
    }
    try {
      final updated = await _imageIndexService.resolveImageDimensions(image);
      _replaceImage(updated);
      errorMessage.value = null;
      return updated;
    } catch (error) {
      errorMessage.value = '读取图片尺寸失败：$error';
      statuses[image.relativePath] = ImageAnnotationStatus.labelError;
      _recomputeStatusCounts();
      applyFilters();
      return null;
    }
  }

  Future<void> refreshStatuses({
    required int classCount,
    required Set<String> completed,
  }) async {
    completedImages.assignAll(completed);
    final nextStatuses = <String, ImageAnnotationStatus>{};
    for (final image in images) {
      nextStatuses[image.relativePath] = await _yoloLabelService
          .inspectLabelStatus(
            labelPath: image.labelPath,
            classCount: classCount,
            isCompleted: completed.contains(image.relativePath),
          );
    }
    statuses.assignAll(nextStatuses);
    _recomputeStatusCounts();
    applyFilters();
  }

  Future<void> refreshImageStatus({
    required ImageItem image,
    required int classCount,
  }) async {
    statuses[image.relativePath] = await _yoloLabelService.inspectLabelStatus(
      labelPath: image.labelPath,
      classCount: classCount,
      isCompleted: completedImages.contains(image.relativePath),
    );
    _recomputeStatusCounts();
    applyFilters();
  }

  void setStatusFilter(ImageAnnotationStatus filter) {
    statusFilter.value = filter;
    applyFilters();
  }

  void setFolderFilter(DatasetFolderFilter filter) {
    folderFilter.value = filter;
    applyFilters();
  }

  void setSearchText(String text) {
    searchText.value = text.trim().toLowerCase();
    applyFilters();
  }

  void setCompleted(String relativePath, bool completed) {
    final next = Set<String>.from(completedImages);
    if (completed) {
      next.add(relativePath);
    } else {
      next.remove(relativePath);
    }
    completedImages.assignAll(next);
    statuses[relativePath] = completed
        ? ImageAnnotationStatus.completed
        : statuses[relativePath] ?? ImageAnnotationStatus.unlabeled;
    _recomputeStatusCounts();
    applyFilters();
  }

  Map<ImageAnnotationStatus, int> statusCounts() {
    return Map.unmodifiable(_statusCounts);
  }

  ImageAnnotationStatus statusOf(ImageItem image) {
    return statuses[image.relativePath] ?? ImageAnnotationStatus.unlabeled;
  }

  ImageItem? visibleNeighbor({required int direction}) {
    final selected = selectedImage;
    if (selected == null || visibleImages.isEmpty) {
      return null;
    }
    final visibleIndex = _visibleIndexByPath[selected.path] ?? -1;
    if (visibleIndex < 0) {
      return visibleImages.first;
    }
    final nextIndex = visibleIndex + direction;
    if (nextIndex < 0 || nextIndex >= visibleImages.length) {
      return null;
    }
    return visibleImages[nextIndex];
  }

  void applyFilters() {
    final keyword = searchText.value;
    final filter = statusFilter.value;
    final folder = folderFilter.value;
    final filtered = images.where((image) {
      final matchesSearch =
          keyword.isEmpty || image.fileName.toLowerCase().contains(keyword);
      final status = statusOf(image);
      final matchesStatus =
          filter == ImageAnnotationStatus.all || status == filter;
      final matchesFolder = folder.matchesRelativePath(image.relativePath);
      return matchesSearch && matchesStatus && matchesFolder;
    }).toList();
    visibleImages.assignAll(filtered);
    _rebuildVisibleIndexLookup();
  }

  void _applyScanResult(ImageScanResult result) {
    paths.value = result.paths;
    warnings.assignAll(result.warnings);
    images.assignAll(result.images);
    statuses.clear();
    _recomputeStatusCounts();
    _rebuildIndexLookup();
    visibleImages.assignAll(result.images);
    _rebuildVisibleIndexLookup();
    selectedIndex.value = 0;
  }

  void _applyIndexSnapshot(ImageIndexSnapshot snapshot) {
    warnings.assignAll(snapshot.warnings);
    images.assignAll(snapshot.images);
    statuses.assignAll(snapshot.statuses);
    _rebuildIndexLookup();
    _recomputeStatusCounts();
    selectedIndex.value = images.isEmpty
        ? 0
        : selectedIndex.value.clamp(0, images.length - 1).toInt();
    applyFilters();
  }

  void applyIndexUpdate(ImageIndexUpdate update) {
    warnings.addAll(update.warnings);
    if (update.removedRelativePaths.isNotEmpty || update.upserts.isNotEmpty) {
      final selectedPath = selectedImage?.path;
      final removedSet = update.removedRelativePaths.toSet();
      for (final relativePath in removedSet) {
        statuses.remove(relativePath);
      }
      final nextImages = _mergeSortedImages(
        currentImages: images,
        upserts: update.upserts,
        removedRelativePaths: removedSet,
      );

      images.assignAll(nextImages);
      _rebuildIndexLookup();
      _restoreSelection(selectedPath);
    }

    statuses.addAll(update.statuses);
    _recomputeStatusCounts();
    refreshProgressText.value = update.isComplete
        ? null
        : '正在更新图片索引 ${update.processedCount}/${update.totalCount}';
    applyFilters();
  }

  void _clearScanState() {
    _indexSession++;
    isRefreshingIndex.value = false;
    refreshProgressText.value = null;
    images.clear();
    visibleImages.clear();
    statuses.clear();
    warnings.clear();
    paths.value = null;
    _indexByPath.clear();
    _indexByRelativePath.clear();
    _visibleIndexByPath.clear();
    _recomputeStatusCounts();
  }

  ImageItem _mergeImage(ImageItem current, ImageItem next) {
    return current.copyWith(
      path: next.path,
      labelPath: next.labelPath,
      fileName: next.fileName,
      relativePath: next.relativePath,
      width: next.width,
      height: next.height,
    );
  }

  void _replaceImage(ImageItem updated) {
    final index = indexOfRelativePath(updated.relativePath);
    if (index < 0) {
      return;
    }
    final nextImages = images.toList(growable: false);
    nextImages[index] = _mergeImage(nextImages[index], updated);
    images.assignAll(nextImages);
    _rebuildIndexLookup();
    applyFilters();
  }

  void _restoreSelection(String? selectedPath) {
    if (images.isEmpty) {
      selectedIndex.value = 0;
      return;
    }
    final restoredIndex = selectedPath == null ? -1 : indexOfPath(selectedPath);
    selectedIndex.value = restoredIndex >= 0
        ? restoredIndex
        : selectedIndex.value.clamp(0, images.length - 1).toInt();
  }

  void _rebuildIndexLookup() {
    _indexByPath.clear();
    _indexByRelativePath.clear();
    for (var index = 0; index < images.length; index += 1) {
      final image = images[index];
      _indexByPath[image.path] = index;
      _indexByRelativePath[image.relativePath] = index;
    }
  }

  void _rebuildVisibleIndexLookup() {
    _visibleIndexByPath.clear();
    for (var index = 0; index < visibleImages.length; index += 1) {
      _visibleIndexByPath[visibleImages[index].path] = index;
    }
  }

  void _recomputeStatusCounts() {
    for (final status in ImageAnnotationStatus.values) {
      _statusCounts[status] = 0;
    }
    _statusCounts[ImageAnnotationStatus.all] = images.length;
    for (final status in statuses.values) {
      _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;
    }
    statusCountsVersion.value++;
  }

  List<ImageItem> _mergeSortedImages({
    required List<ImageItem> currentImages,
    required List<ImageItem> upserts,
    required Set<String> removedRelativePaths,
  }) {
    final deduplicatedUpserts =
        {for (final image in upserts) image.relativePath: image}.values.toList()
          ..sort(
            (left, right) => left.relativePath.compareTo(right.relativePath),
          );
    final merged = <ImageItem>[];
    var upsertIndex = 0;

    for (final current in currentImages) {
      if (removedRelativePaths.contains(current.relativePath)) {
        continue;
      }
      while (upsertIndex < deduplicatedUpserts.length &&
          deduplicatedUpserts[upsertIndex].relativePath.compareTo(
                current.relativePath,
              ) <
              0) {
        merged.add(deduplicatedUpserts[upsertIndex]);
        upsertIndex += 1;
      }
      if (upsertIndex < deduplicatedUpserts.length &&
          deduplicatedUpserts[upsertIndex].relativePath ==
              current.relativePath) {
        merged.add(_mergeImage(current, deduplicatedUpserts[upsertIndex]));
        upsertIndex += 1;
      } else {
        merged.add(current);
      }
    }

    while (upsertIndex < deduplicatedUpserts.length) {
      merged.add(deduplicatedUpserts[upsertIndex]);
      upsertIndex += 1;
    }
    return merged;
  }
}
