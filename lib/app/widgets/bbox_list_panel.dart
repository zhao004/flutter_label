import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/annotation_controller.dart';
import '../theme/fluent_design_tokens.dart';
import 'bbox_painter.dart';

class BboxListPanel extends StatelessWidget {
  const BboxListPanel({required this.annotationController, super.key});

  final AnnotationController annotationController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final boxes = annotationController.boxes;
      final selectedId = annotationController.selectedBoxId.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.select_all_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '标注框（${boxes.length}）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: boxes.length,
              itemBuilder: (context, index) {
                final box = boxes[index];
                return _BboxListItem(
                  classId: box.classId,
                  className: annotationController.classNameOf(box.classId),
                  coordinateText:
                      'x=${box.rect.left.toStringAsFixed(0)}, y=${box.rect.top.toStringAsFixed(0)}, '
                      'w=${box.rect.width.toStringAsFixed(0)}, h=${box.rect.height.toStringAsFixed(0)}',
                  selected: box.id == selectedId,
                  onTap: () => annotationController.selectBox(box.id),
                  onDelete: () {
                    annotationController.selectBox(box.id);
                    annotationController.deleteSelectedBox();
                  },
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _BboxListItem extends StatelessWidget {
  const _BboxListItem({
    required this.classId,
    required this.className,
    required this.coordinateText,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final int classId;
  final String className;
  final String coordinateText;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: borderRadius,
            hoverColor: FluentDesignTokens.selectedBackground.withValues(
              alpha: 0.42,
            ),
            onTap: onTap,
            child: Row(
              children: [
                SizedBox(
                  width: 3,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: classColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$classId: $className',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          coordinateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FluentDesignTokens.textSecondary,
                            fontFamily: 'Consolas',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '删除标注框',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
