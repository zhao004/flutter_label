import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/annotation_controller.dart';
import '../../controllers/app_settings_controller.dart';
import '../../controllers/class_controller.dart';
import '../../controllers/image_list_controller.dart';
import '../../models/dataset_split.dart';
import '../../routes/app_route_names.dart';
import '../../services/image_scan_service.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/bbox_list_panel.dart';
import '../../widgets/class_panel.dart';
import '../../widgets/fluent_app_shell.dart';
import '../../widgets/image_canvas.dart';
import '../../widgets/image_list_panel.dart';
import '../../widgets/responsive_tool_scaffold.dart';

enum _ImageImportSource { files, directory }

enum _AnnotationAction { importImage, undo, redo, save }

class AnnotationView extends StatefulWidget {
  const AnnotationView({super.key});

  @override
  State<AnnotationView> createState() => _AnnotationViewState();
}

class _AnnotationViewState extends State<AnnotationView> {
  late final FocusNode _focusNode;
  late final AnnotationController _annotationController;
  late final AppSettingsController _settingsController;
  late final ImageListController _imageListController;
  late final ClassController _classController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'annotation_shortcuts');
    _annotationController = Get.find<AnnotationController>();
    _settingsController = ensureAppSettingsController();
    _imageListController = Get.find<ImageListController>();
    _classController = Get.find<ClassController>();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FluentAppShell(
      showNavigation: false,
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                constraints.maxWidth < ResponsiveBreakpoints.annotation;
            return Scaffold(
              backgroundColor: FluentDesignTokens.appBackground,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: _AnnotationCommandBar(
                  isCompact: isCompact,
                  annotationController: _annotationController,
                  actions: _buildAppBarActions(context, isCompact),
                ),
              ),
              drawer: isCompact
                  ? _ImageListDrawer(
                      imageListController: _imageListController,
                      annotationController: _annotationController,
                    )
                  : null,
              endDrawer: isCompact
                  ? _ToolsDrawer(
                      classController: _classController,
                      annotationController: _annotationController,
                    )
                  : null,
              body: Obx(() {
                final hasCurrentImage =
                    _annotationController.currentImage.value != null;
                final isLoading = _annotationController.isLoading.value;
                return isCompact
                    ? _CompactBody(
                        annotationController: _annotationController,
                        hasCurrentImage: hasCurrentImage,
                        isLoading: isLoading,
                        onImport: () => unawaited(_showImportDialog(context)),
                      )
                    : _DesktopBody(
                        annotationController: _annotationController,
                        imageListController: _imageListController,
                        classController: _classController,
                        hasCurrentImage: hasCurrentImage,
                        isLoading: isLoading,
                        onImport: () => unawaited(_showImportDialog(context)),
                      );
              }),
              bottomNavigationBar: _StatusBar(
                annotationController: _annotationController,
                imageListController: _imageListController,
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, bool isCompact) {
    if (isCompact) {
      return [
        _AppBarInkBoundary(
          child: Builder(
            builder: (context) => IconButton(
              tooltip: '图片列表',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.view_list_outlined),
            ),
          ),
        ),
        _AppBarInkBoundary(
          child: Builder(
            builder: (context) => IconButton(
              tooltip: '类别与标注框',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.tune),
            ),
          ),
        ),
        _AppBarInkBoundary(
          child: PopupMenuButton<_AnnotationAction>(
            tooltip: '更多操作',
            onSelected: (value) => _handleCompactAction(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AnnotationAction.importImage,
                child: Text('导入图片'),
              ),
              PopupMenuItem(
                value: _AnnotationAction.undo,
                child: Text('撤销 Ctrl+Z'),
              ),
              PopupMenuItem(
                value: _AnnotationAction.redo,
                child: Text('重做 Ctrl+Y'),
              ),
              PopupMenuItem(
                value: _AnnotationAction.save,
                child: Text('保存 Ctrl+S'),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      _AppBarInkBoundary(
        child: OutlinedButton.icon(
          onPressed: () => unawaited(_showImportDialog(context)),
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: const Text('导入图片'),
        ),
      ),
      _AppBarInkBoundary(
        child: Obx(
          () => IconButton(
            tooltip: '撤销 Ctrl+Z',
            onPressed: _annotationController.canUndo.value
                ? _annotationController.undo
                : null,
            icon: const Icon(Icons.undo),
          ),
        ),
      ),
      _AppBarInkBoundary(
        child: Obx(
          () => IconButton(
            tooltip: '重做 Ctrl+Y',
            onPressed: _annotationController.canRedo.value
                ? _annotationController.redo
                : null,
            icon: const Icon(Icons.redo),
          ),
        ),
      ),
      _AppBarInkBoundary(
        child: FilledButton.icon(
          onPressed: () => unawaited(
            _annotationController.saveCurrent(showSuccessToast: true),
          ),
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存'),
        ),
      ),
      const SizedBox(width: 8),
    ];
  }

  void _handleCompactAction(BuildContext context, _AnnotationAction action) {
    switch (action) {
      case _AnnotationAction.importImage:
        unawaited(_showImportDialog(context));
      case _AnnotationAction.undo:
        if (_annotationController.canUndo.value) {
          _annotationController.undo();
        }
      case _AnnotationAction.redo:
        if (_annotationController.canRedo.value) {
          _annotationController.redo();
        }
      case _AnnotationAction.save:
        unawaited(_annotationController.saveCurrent(showSuccessToast: true));
    }
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final split = await _selectSplit(context);
    if (split == null || !context.mounted) {
      return;
    }

    final source = await _selectImportSource(context);
    if (source == null || !context.mounted) {
      return;
    }

    switch (source) {
      case _ImageImportSource.files:
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: '请选择要导入的图片',
          type: FileType.custom,
          allowedExtensions: [
            for (final extension in ImageScanService.supportedExtensions)
              extension.substring(1),
          ],
          allowMultiple: true,
        );
        final paths = result?.files
            .map((file) => file.path?.trim())
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList(growable: false);
        if (paths == null || paths.isEmpty) {
          return;
        }
        await _annotationController.importImageFiles(
          split: split,
          filePaths: paths,
        );
      case _ImageImportSource.directory:
        final directory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '请选择要递归导入的图片目录',
        );
        if (directory == null || directory.trim().isEmpty) {
          return;
        }
        await _annotationController.importImageDirectory(
          split: split,
          sourceDir: directory,
        );
    }
  }

  Future<DatasetSplit?> _selectSplit(BuildContext context) {
    return showDialog<DatasetSplit>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('选择导入目标'),
          children: [
            for (final split in DatasetSplit.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(split),
                child: Text('images/${split.directoryName}'),
              ),
          ],
        );
      },
    );
  }

  Future<_ImageImportSource?> _selectImportSource(BuildContext context) {
    return showDialog<_ImageImportSource>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('选择导入来源'),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_ImageImportSource.files),
              child: const Text('选择图片文件'),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_ImageImportSource.directory),
              child: const Text('选择图片目录'),
            ),
          ],
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    if (isControlPressed && key == LogicalKeyboardKey.keyS) {
      unawaited(_annotationController.saveCurrent());
      return KeyEventResult.handled;
    }
    if (isControlPressed && key == LogicalKeyboardKey.keyZ) {
      _annotationController.undo();
      return KeyEventResult.handled;
    }
    if (isControlPressed && key == LogicalKeyboardKey.keyY) {
      _annotationController.redo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (_settingsController.spaceCompletesAndSelectsNext.value) {
        unawaited(_annotationController.completeCurrentAndSelectNext());
      } else {
        unawaited(_annotationController.toggleCompleted());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      _annotationController.deleteSelectedBox();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      unawaited(_annotationController.selectPreviousImage());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      unawaited(_annotationController.selectNextImage());
      return KeyEventResult.handled;
    }

    final digit = _digitFromKey(key);
    if (digit != null) {
      _annotationController.selectClass(digit - 1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  int? _digitFromKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      return 1;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      return 2;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      return 3;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      return 4;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      return 5;
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      return 6;
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      return 7;
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      return 8;
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      return 9;
    }
    return null;
  }
}

class _AnnotationCommandBar extends StatelessWidget {
  const _AnnotationCommandBar({
    required this.isCompact,
    required this.annotationController,
    required this.actions,
  });

  final bool isCompact;
  final AnnotationController annotationController;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluentDesignTokens.titleBarBackground,
        border: Border(bottom: BorderSide(color: FluentDesignTokens.border)),
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _AppBarInkBoundary(
                child: _BackToHomeButton(isCompact: isCompact),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() {
                  final image = annotationController.currentImage.value;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '图片标注',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        image?.relativePath ?? '未加载图片',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FluentDesignTokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(width: 12),
              for (final action in actions) action,
            ],
          ),
        ),
      ),
    );
  }
}

class _BackToHomeButton extends StatelessWidget {
  const _BackToHomeButton({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return IconButton(
        tooltip: '返回工作页',
        onPressed: _returnToHome,
        icon: const Icon(Icons.arrow_back),
      );
    }

    return OutlinedButton.icon(
      onPressed: _returnToHome,
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('返回工作页'),
    );
  }

  void _returnToHome() {
    if (Get.testMode || Get.key.currentState == null) {
      return;
    }
    Get.offAllNamed(AppRouteNames.home);
  }
}

/// 为 AppBar 操作提供独立的透明 Material，避免响应式重建后旧水波纹继续引用已卸载按钮。
class _AppBarInkBoundary extends StatelessWidget {
  const _AppBarInkBoundary({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(type: MaterialType.transparency, child: child);
  }
}

class _DesktopBody extends StatefulWidget {
  const _DesktopBody({
    required this.annotationController,
    required this.imageListController,
    required this.classController,
    required this.hasCurrentImage,
    required this.isLoading,
    required this.onImport,
  });

  final AnnotationController annotationController;
  final ImageListController imageListController;
  final ClassController classController;
  final bool hasCurrentImage;
  final bool isLoading;
  final VoidCallback onImport;

  @override
  State<_DesktopBody> createState() => _DesktopBodyState();
}

class _DesktopBodyState extends State<_DesktopBody> {
  static const double _imageListWidth = 276;
  static const double _imageListCollapsedWidth = 52;
  static const double _toolsExpandedWidth = 300;
  static const double _toolsCollapsedWidth = 52;
  bool _isImageListCollapsed = false;
  bool _isToolsCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: _isImageListCollapsed
                ? _imageListCollapsedWidth
                : _imageListWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FluentDesignTokens.cardBackground,
                border: Border.all(color: FluentDesignTokens.border),
                borderRadius: BorderRadius.circular(
                  FluentDesignTokens.cardRadius,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  FluentDesignTokens.cardRadius,
                ),
                child: _isImageListCollapsed
                    ? _CollapsedImageListPanel(
                        onExpand: () => setState(() {
                          _isImageListCollapsed = false;
                        }),
                      )
                    : ImageListPanel(
                        imageListController: widget.imageListController,
                        annotationController: widget.annotationController,
                        headerTrailing: IconButton(
                          tooltip: '折叠左侧面板',
                          onPressed: () => setState(() {
                            _isImageListCollapsed = true;
                          }),
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FluentDesignTokens.previewBackground,
                border: Border.all(color: FluentDesignTokens.border),
                borderRadius: BorderRadius.circular(
                  FluentDesignTokens.cardRadius,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _CanvasArea(
                  annotationController: widget.annotationController,
                  hasCurrentImage: widget.hasCurrentImage,
                  isLoading: widget.isLoading,
                  onImport: widget.onImport,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: _isToolsCollapsed
                ? _toolsCollapsedWidth
                : _toolsExpandedWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FluentDesignTokens.cardBackground,
                border: Border.all(color: FluentDesignTokens.border),
                borderRadius: BorderRadius.circular(
                  FluentDesignTokens.cardRadius,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  FluentDesignTokens.cardRadius,
                ),
                child: _isToolsCollapsed
                    ? _CollapsedToolsPanel(
                        onExpand: () => setState(() {
                          _isToolsCollapsed = false;
                        }),
                      )
                    : _ExpandedToolsPanel(
                        classController: widget.classController,
                        annotationController: widget.annotationController,
                        onCollapse: () => setState(() {
                          _isToolsCollapsed = true;
                        }),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedImageListPanel extends StatelessWidget {
  const _CollapsedImageListPanel({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: IconButton(
          tooltip: '展开左侧面板',
          onPressed: onExpand,
          icon: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _ExpandedToolsPanel extends StatelessWidget {
  const _ExpandedToolsPanel({
    required this.classController,
    required this.annotationController,
    required this.onCollapse,
  });

  final ClassController classController;
  final AnnotationController annotationController;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '工具面板',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '折叠右侧面板',
                onPressed: onCollapse,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _ToolsPanel(
            classController: classController,
            annotationController: annotationController,
          ),
        ),
      ],
    );
  }
}

class _CollapsedToolsPanel extends StatelessWidget {
  const _CollapsedToolsPanel({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: IconButton(
          tooltip: '展开右侧面板',
          onPressed: onExpand,
          icon: const Icon(Icons.chevron_left),
        ),
      ),
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({
    required this.annotationController,
    required this.hasCurrentImage,
    required this.isLoading,
    required this.onImport,
  });

  final AnnotationController annotationController;
  final bool hasCurrentImage;
  final bool isLoading;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return _CanvasArea(
      annotationController: annotationController,
      hasCurrentImage: hasCurrentImage,
      isLoading: isLoading,
      onImport: onImport,
    );
  }
}

class _CanvasArea extends StatelessWidget {
  const _CanvasArea({
    required this.annotationController,
    required this.hasCurrentImage,
    required this.isLoading,
    required this.onImport,
  });

  final AnnotationController annotationController;
  final bool hasCurrentImage;
  final bool isLoading;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: FluentDesignTokens.canvasBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ImageCanvas(controller: annotationController),
        ),
        if (!hasCurrentImage && !isLoading)
          _EmptyAnnotationState(onImport: onImport),
        if (isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ImageListDrawer extends StatelessWidget {
  const _ImageListDrawer({
    required this.imageListController,
    required this.annotationController,
  });

  final ImageListController imageListController;
  final AnnotationController annotationController;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ImageListPanel(
          imageListController: imageListController,
          annotationController: annotationController,
        ),
      ),
    );
  }
}

class _ToolsDrawer extends StatelessWidget {
  const _ToolsDrawer({
    required this.classController,
    required this.annotationController,
  });

  final ClassController classController;
  final AnnotationController annotationController;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: _ToolsPanel(
          classController: classController,
          annotationController: annotationController,
        ),
      ),
    );
  }
}

class _ToolsPanel extends StatelessWidget {
  const _ToolsPanel({
    required this.classController,
    required this.annotationController,
  });

  final ClassController classController;
  final AnnotationController annotationController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClassPanel(
            classController: classController,
            annotationController: annotationController,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: BboxListPanel(annotationController: annotationController),
        ),
      ],
    );
  }
}

class _EmptyAnnotationState extends StatelessWidget {
  const _EmptyAnnotationState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 52,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '当前数据集还没有图片',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '可先导入图片，也可以在右侧类别面板新增类别后再开始标注。',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('导入图片'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.annotationController,
    required this.imageListController,
  });

  static const double _compactBreakpoint = 720;
  static const double _desktopHeight = 32;
  static const double _compactHeight = 56;
  static const double _itemGap = 16;

  final AnnotationController annotationController;
  final ImageListController imageListController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = annotationController.currentImage.value;
      final total = imageListController.images.length;
      final index = total == 0
          ? 0
          : imageListController.selectedIndex.value + 1;
      final dirtyText = annotationController.isDirty.value ? '未保存' : '已保存';
      final completed =
          image != null &&
          annotationController.completedImages.contains(image.relativePath);
      final zoomText =
          '${(annotationController.zoom * 100).toStringAsFixed(0)}%';
      final imageText = image?.relativePath ?? '未加载图片';
      final details = [
        '进度 $index/$total',
        image == null ? '尺寸 -' : image.dimensionText,
        '框 ${annotationController.boxes.length}',
        '缩放 $zoomText',
        dirtyText,
        completed ? '已完成' : '未完成',
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < _compactBreakpoint;
          return Container(
            height: isCompact ? _compactHeight : _desktopHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: FluentDesignTokens.titleBarBackground,
              border: Border(top: BorderSide(color: FluentDesignTokens.border)),
            ),
            child: isCompact
                ? _CompactStatusContent(imageText: imageText, details: details)
                : _DesktopStatusContent(
                    imageText: imageText,
                    details: details,
                    itemGap: _itemGap,
                  ),
          );
        },
      );
    });
  }
}

class _DesktopStatusContent extends StatelessWidget {
  const _DesktopStatusContent({
    required this.imageText,
    required this.details,
    required this.itemGap,
  });

  final String imageText;
  final List<String> details;
  final double itemGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(imageText, overflow: TextOverflow.ellipsis)),
        for (var index = 0; index < details.length; index += 1) ...[
          Text(details[index]),
          if (index < details.length - 1) SizedBox(width: itemGap),
        ],
      ],
    );
  }
}

class _CompactStatusContent extends StatelessWidget {
  const _CompactStatusContent({required this.imageText, required this.details});

  final String imageText;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(imageText, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < details.length; index += 1) ...[
                Text(details[index]),
                if (index < details.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
