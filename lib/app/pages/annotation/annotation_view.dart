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
      title: '图片标注',
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
                preferredSize: const Size.fromHeight(48),
                child: _AnnotationCommandBar(
                  isCompact: isCompact,
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
        child: Obx(
          () => _UndoRedoButtonGroup(
            canUndo: _annotationController.canUndo.value,
            canRedo: _annotationController.canRedo.value,
            onUndo: _annotationController.undo,
            onRedo: _annotationController.redo,
          ),
        ),
      ),
      const _ToolbarDivider(),
      _AppBarInkBoundary(
        child: _CompactToolbarButton(
          tooltip: '导入图片',
          icon: Icons.add_photo_alternate_outlined,
          onPressed: () => unawaited(_showImportDialog(context)),
        ),
      ),
      _AppBarInkBoundary(
        child: Obx(() {
          final isDirty = _annotationController.isDirty.value;
          return _CompactToolbarButton(
            tooltip: isDirty ? '保存 Ctrl+S（未保存）' : '保存 Ctrl+S',
            icon: isDirty ? Icons.save : Icons.save_outlined,
            color: isDirty ? FluentDesignTokens.warningText : null,
            onPressed: () => unawaited(
              _annotationController.saveCurrent(showSuccessToast: true),
            ),
          );
        }),
      ),
      const SizedBox(width: 4),
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
  const _AnnotationCommandBar({required this.isCompact, required this.actions});

  final bool isCompact;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluentDesignTokens.titleBarBackground,
        border: Border(bottom: BorderSide(color: FluentDesignTokens.border)),
      ),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const _AppBarInkBoundary(child: _BackToHomeButton()),
              if (isCompact) const Spacer() else const _ToolbarDivider(),
              for (final action in actions) action,
            ],
          ),
        ),
      ),
    );
  }
}

class _BackToHomeButton extends StatelessWidget {
  const _BackToHomeButton();

  @override
  Widget build(BuildContext context) {
    return _CompactToolbarButton(
      tooltip: '返回工作页',
      icon: Icons.arrow_back,
      onPressed: _returnToHome,
    );
  }

  void _returnToHome() {
    if (Get.testMode || Get.key.currentState == null) {
      return;
    }
    Get.offAllNamed(AppRouteNames.home);
  }
}

class _UndoRedoButtonGroup extends StatelessWidget {
  const _UndoRedoButtonGroup({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FluentDesignTokens.fieldBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactToolbarButton(
            tooltip: '撤销 Ctrl+Z',
            icon: Icons.undo,
            onPressed: canUndo ? onUndo : null,
          ),
          Container(width: 1, height: 20, color: FluentDesignTokens.border),
          _CompactToolbarButton(
            tooltip: '重做 Ctrl+Y',
            icon: Icons.redo,
            onPressed: canRedo ? onRedo : null,
          ),
        ],
      ),
    );
  }
}

class _CompactToolbarButton extends StatelessWidget {
  const _CompactToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(width: 1, height: 20, color: FluentDesignTokens.border),
    );
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
      child: InkWell(
        onTap: onExpand,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              IconButton(
                tooltip: '展开左侧面板',
                onPressed: onExpand,
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(height: 12),
              const Icon(Icons.view_list_outlined, size: 20),
              const SizedBox(height: 10),
              const RotatedBox(
                quarterTurns: 1,
                child: Text(
                  '图片列表',
                  style: TextStyle(
                    color: FluentDesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
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
              const Icon(Icons.build_outlined, size: 18),
              const SizedBox(width: 8),
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
        const Divider(height: 1, color: FluentDesignTokens.border),
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
      child: InkWell(
        onTap: onExpand,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              IconButton(
                tooltip: '展开右侧面板',
                onPressed: onExpand,
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(height: 12),
              const Icon(Icons.tune, size: 20),
              const SizedBox(height: 10),
              const RotatedBox(
                quarterTurns: 1,
                child: Text(
                  '工具面板',
                  style: TextStyle(
                    color: FluentDesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FluentDesignTokens.canvasBackground.withValues(alpha: 0.92),
              const Color(0xFF151515).withValues(alpha: 0.92),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(34, 32, 34, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '开始你的第一张标注',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '请在左侧选择图片，或导入新图片后开始绘制标注框。类别可在右侧工具面板维护。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
      final items = [
        _StatusItem(
          icon: Icons.collections_outlined,
          label: '进度',
          value: '$index/$total',
        ),
        _StatusItem(
          icon: Icons.photo_size_select_large_outlined,
          label: '尺寸',
          value: image == null ? '-' : image.dimensionText,
        ),
        _StatusItem(
          icon: Icons.select_all_outlined,
          label: '框',
          value: '${annotationController.boxes.length}',
        ),
        _StatusItem(icon: Icons.zoom_in_outlined, label: '缩放', value: zoomText),
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
                ? _CompactStatusContent(
                    imageText: imageText,
                    items: items,
                    dirtyText: dirtyText,
                    completed: completed,
                  )
                : _DesktopStatusContent(
                    imageText: imageText,
                    items: items,
                    dirtyText: dirtyText,
                    completed: completed,
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
    required this.items,
    required this.dirtyText,
    required this.completed,
    required this.itemGap,
  });

  final String imageText;
  final List<_StatusItem> items;
  final String dirtyText;
  final bool completed;
  final double itemGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(imageText, overflow: TextOverflow.ellipsis)),
        for (var index = 0; index < items.length; index += 1) ...[
          _StatusChip(item: items[index]),
          if (index < items.length - 1) SizedBox(width: itemGap),
        ],
        SizedBox(width: itemGap),
        _SaveStatusChip(text: dirtyText, dirty: dirtyText == '未保存'),
        const SizedBox(width: 8),
        _CompletionStatusChip(completed: completed),
      ],
    );
  }
}

class _CompactStatusContent extends StatelessWidget {
  const _CompactStatusContent({
    required this.imageText,
    required this.items,
    required this.dirtyText,
    required this.completed,
  });

  final String imageText;
  final List<_StatusItem> items;
  final String dirtyText;
  final bool completed;

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
              for (final item in items) ...[
                _StatusChip(item: item),
                const SizedBox(width: 8),
              ],
              _SaveStatusChip(text: dirtyText, dirty: dirtyText == '未保存'),
              const SizedBox(width: 8),
              _CompletionStatusChip(completed: completed),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusItem {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final _StatusItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: FluentDesignTokens.fieldBackground,
        border: Border.all(color: FluentDesignTokens.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 13, color: FluentDesignTokens.textSecondary),
          const SizedBox(width: 5),
          Text(
            '${item.label} ${item.value}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({required this.text, required this.dirty});

  final String text;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final color = dirty
        ? const Color(0xFFFF8C00)
        : FluentDesignTokens.successGreen;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionStatusChip extends StatelessWidget {
  const _CompletionStatusChip({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? FluentDesignTokens.successGreen
        : FluentDesignTokens.textSecondary;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: completed ? 0.10 : 0.06),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            completed ? '已完成' : '未完成',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: completed ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
