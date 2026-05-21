import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/annotation_controller.dart';

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
            child: Text(
              '标注框（${boxes.length}）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: boxes.length,
              itemBuilder: (context, index) {
                final box = boxes[index];
                return ListTile(
                  dense: true,
                  selected: box.id == selectedId,
                  title: Text(
                    '${box.classId}: ${annotationController.classNameOf(box.classId)}',
                  ),
                  subtitle: Text(
                    'x=${box.rect.left.toStringAsFixed(0)}, y=${box.rect.top.toStringAsFixed(0)}, '
                    'w=${box.rect.width.toStringAsFixed(0)}, h=${box.rect.height.toStringAsFixed(0)}',
                  ),
                  onTap: () => annotationController.selectBox(box.id),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
