import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/annotation_controller.dart';
import '../controllers/class_controller.dart';
import '../theme/fluent_design_tokens.dart';
import 'bbox_painter.dart';

class ClassPanel extends StatelessWidget {
  const ClassPanel({
    required this.classController,
    required this.annotationController,
    super.key,
  });

  final ClassController classController;
  final AnnotationController annotationController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentClassId = annotationController.currentClassId.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '类别',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '新增类别',
                  onPressed: () => _showClassNameDialog(context),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: classController.classes.length,
              itemBuilder: (context, index) {
                final item = classController.classes[index];
                return _ClassListItem(
                  classId: item.id,
                  name: item.name,
                  selected: item.id == currentClassId,
                  canMoveUp: item.id > 0,
                  canMoveDown: item.id < classController.classes.length - 1,
                  onTap: () => annotationController.selectClass(item.id),
                  onAction: (value) {
                    switch (value) {
                      case 'up':
                        annotationController.moveClass(item.id, -1);
                      case 'down':
                        annotationController.moveClass(item.id, 1);
                      case 'rename':
                        _showClassNameDialog(
                          context,
                          classId: item.id,
                          initialName: item.name,
                        );
                      case 'delete':
                        annotationController.deleteClass(item.id);
                    }
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Future<void> _showClassNameDialog(
    BuildContext context, {
    int? classId,
    String initialName = '',
  }) async {
    final textController = TextEditingController(text: initialName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(classId == null ? '新增类别' : '重命名类别'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(labelText: '类别名称'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(textController.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    textController.dispose();
    if (name == null) {
      return;
    }
    if (classId == null) {
      await annotationController.addClass(name);
    } else {
      await annotationController.renameClass(classId, name);
    }
  }
}

class _ClassListItem extends StatelessWidget {
  const _ClassListItem({
    required this.classId,
    required this.name,
    required this.selected,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTap,
    required this.onAction,
  });

  final int classId;
  final String name;
  final bool selected;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final classColor = BboxPainter.colorForClass(classId);
    final borderRadius = BorderRadius.circular(10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? FluentDesignTokens.selectedBackground : null,
          borderRadius: borderRadius,
          border: Border(left: BorderSide(color: classColor, width: 3)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: borderRadius,
            hoverColor: FluentDesignTokens.selectedBackground.withValues(
              alpha: 0.42,
            ),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: classColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: classColor.withValues(alpha: 0.28),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '#${classId + 1}',
                    style: const TextStyle(
                      color: FluentDesignTokens.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '类别操作',
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'up',
                        enabled: canMoveUp,
                        child: const Text('上移并同步标签'),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: canMoveDown,
                        child: const Text('下移并同步标签'),
                      ),
                      const PopupMenuItem(value: 'rename', child: Text('重命名')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除未使用类别'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
