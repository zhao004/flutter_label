import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/annotation_controller.dart';
import '../controllers/class_controller.dart';

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
                return ListTile(
                  dense: true,
                  selected: item.id == currentClassId,
                  leading: CircleAvatar(
                    radius: 13,
                    child: Text(
                      '${item.id + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: '类别操作',
                    onSelected: (value) {
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
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'up',
                        enabled: item.id > 0,
                        child: const Text('上移并同步标签'),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: item.id < classController.classes.length - 1,
                        child: const Text('下移并同步标签'),
                      ),
                      const PopupMenuItem(value: 'rename', child: Text('重命名')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除未使用类别'),
                      ),
                    ],
                  ),
                  onTap: () => annotationController.selectClass(item.id),
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
