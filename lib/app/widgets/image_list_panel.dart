import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/annotation_controller.dart';
import '../controllers/image_list_controller.dart';
import '../models/dataset_split.dart';
import '../models/image_annotation_status.dart';
import '../theme/fluent_design_tokens.dart';

class ImageListPanel extends StatelessWidget {
  const ImageListPanel({
    required this.imageListController,
    required this.annotationController,
    this.headerTrailing,
    super.key,
  });

  final ImageListController imageListController;
  final AnnotationController annotationController;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return _ImageListPanelBody(
      imageListController: imageListController,
      annotationController: annotationController,
      headerTrailing: headerTrailing,
    );
  }
}

class _ImageListPanelBody extends StatefulWidget {
  const _ImageListPanelBody({
    required this.imageListController,
    required this.annotationController,
    this.headerTrailing,
  });

  final ImageListController imageListController;
  final AnnotationController annotationController;
  final Widget? headerTrailing;

  @override
  State<_ImageListPanelBody> createState() => _ImageListPanelBodyState();
}

class _ImageListPanelBodyState extends State<_ImageListPanelBody> {
  static const double _imageTileExtent = 64;

  late final ScrollController _scrollController;
  int _lastSelectedIndex = -1;
  int _lastVisibleIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final imageListController = widget.imageListController;
      final images = imageListController.images;
      final visibleImages = imageListController.visibleImages;
      final selectedIndex = imageListController.selectedIndex.value;
      final visibleSelectedIndex = visibleImages.indexWhere(
        (image) => imageListController.indexOfPath(image.path) == selectedIndex,
      );
      final _ = imageListController.statusCountsVersion.value;
      final counts = imageListController.statusCounts();
      final progressText = imageListController.refreshProgressText.value;

      if (selectedIndex != _lastSelectedIndex ||
          visibleSelectedIndex != _lastVisibleIndex) {
        _lastSelectedIndex = selectedIndex;
        _lastVisibleIndex = visibleSelectedIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _scrollSelectedItemIntoView();
        });
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '图片列表（${visibleImages.length}/${images.length}）',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (widget.headerTrailing != null) widget.headerTrailing!,
                  ],
                ),
                if (progressText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    progressText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<DatasetFolderFilter>(
                  initialValue: imageListController.folderFilter.value,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '文件夹筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final filter in DatasetFolderFilter.values)
                      DropdownMenuItem(
                        value: filter,
                        child: Text(filter.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      imageListController.setFolderFilter(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    labelText: '搜索文件名',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: imageListController.setSearchText,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ImageAnnotationStatus>(
                  initialValue: imageListController.statusFilter.value,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '状态筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final status in ImageAnnotationStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text('${status.label}（${counts[status] ?? 0}）'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      imageListController.setStatusFilter(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: _imageTileExtent,
              itemCount: visibleImages.length,
              itemBuilder: (context, index) {
                final image = visibleImages[index];
                final rawIndex = imageListController.indexOfPath(image.path);
                final status = imageListController.statusOf(image);
                final selected = rawIndex == selectedIndex;
                return Material(
                  color: selected
                      ? FluentDesignTokens.selectedBackground
                      : Colors.transparent,
                  child: ListTile(
                    dense: true,
                    selected: selected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        FluentDesignTokens.controlRadius,
                      ),
                    ),
                    title: Text(
                      image.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${status.label} · ${image.dimensionText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: status == ImageAnnotationStatus.completed
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () =>
                        widget.annotationController.loadImageAt(rawIndex),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  void _scrollSelectedItemIntoView() {
    if (!_scrollController.hasClients) {
      return;
    }
    final controller = widget.imageListController;
    final selectedIndex = controller.selectedIndex.value;
    if (selectedIndex < 0) {
      return;
    }
    final visibleIndex = controller.visibleImages.indexWhere(
      (image) => controller.indexOfPath(image.path) == selectedIndex,
    );
    if (visibleIndex < 0) {
      return;
    }
    final targetOffset = (visibleIndex * _imageTileExtent).toDouble();
    final maxOffset = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final viewportExtent = _scrollController.position.viewportDimension;
    final itemTop = targetOffset - currentOffset;
    final itemBottom = itemTop + _imageTileExtent;
    double? nextOffset;
    if (itemTop < 0) {
      nextOffset = targetOffset;
    } else if (itemBottom > viewportExtent) {
      nextOffset = targetOffset - viewportExtent + _imageTileExtent;
    }
    if (nextOffset == null) {
      return;
    }
    final clampedOffset = nextOffset.clamp(0.0, maxOffset).toDouble();
    if ((clampedOffset - currentOffset).abs() < 1) {
      return;
    }
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
}
