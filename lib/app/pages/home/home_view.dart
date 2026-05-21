import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/fluent_app_shell.dart';
import '../../widgets/fluent_card.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentAppShell(
      child: ColoredBox(
        color: FluentDesignTokens.appBackground,
        child: ListView(
          padding: FluentDesignTokens.pagePadding,
          children: [
            const FluentPageHeader(
              title: '项目工作台',
              description: '管理 YOLO 数据集项目；打开或新建项目后进入图片标注，其他处理工具通过左侧导航进入。',
            ),
            const SizedBox(height: FluentDesignTokens.pageGap),
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 960;
                if (!useTwoColumns) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProjectEntryCard(controller: controller),
                      const SizedBox(height: 16),
                      _HistoryPanel(controller: controller, shrinkWrap: true),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 460,
                      child: _ProjectEntryCard(controller: controller),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _HistoryPanel(controller: controller)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectEntryCard extends StatelessWidget {
  const _ProjectEntryCard({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return FluentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据集项目',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            '选择包含 data.yaml 的项目根目录，读取类别并进入图片标注；也可以新建空项目目录。',
            style: TextStyle(
              color: FluentDesignTokens.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: FluentDesignTokens.fieldBackground,
              border: Border.fromBorderSide(
                BorderSide(color: FluentDesignTokens.fieldBorder),
              ),
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '也可以新建数据集项目，自动生成 images/labels/train/val/test 目录。',
                style: TextStyle(
                  color: FluentDesignTokens.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Obx(
                () => SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: controller.isPicking.value
                        ? null
                        : controller.openDatasetProject,
                    icon: controller.isPicking.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open, size: 18),
                    label: const Text('打开数据集项目'),
                  ),
                ),
              ),
              Obx(
                () => SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: controller.isPicking.value
                        ? null
                        : controller.createDatasetProject,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                    label: const Text('新建数据集项目'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.controller, this.shrinkWrap = false});

  final HomeController controller;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return FluentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '项目历史',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: controller.clearHistory,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<HistoryRecord>>(
            stream: controller.recentHistoryStream,
            initialData: const <HistoryRecord>[],
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _HistoryMessage(
                  icon: Icons.error_outline,
                  message: '读取历史记录失败：${snapshot.error}',
                );
              }

              final records = snapshot.data ?? const <HistoryRecord>[];
              if (records.isEmpty) {
                return const _HistoryMessage(
                  icon: Icons.history_toggle_off,
                  message: '暂无历史记录',
                );
              }

              final listView = ListView.separated(
                shrinkWrap: shrinkWrap,
                physics: shrinkWrap
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _HistoryTile(record: records[index]);
                },
              );

              if (shrinkWrap) {
                return listView;
              }
              return SizedBox(height: 360, child: listView);
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final description = record.description;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FluentDesignTokens.fieldBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                _formatHistoryTime(record.createdAt),
                style: const TextStyle(
                  color: FluentDesignTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                description == null || description.isEmpty
                    ? record.title
                    : '${record.title} · $description',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              record.actionType.label,
              style: const TextStyle(
                color: FluentDesignTokens.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: FluentDesignTokens.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: FluentDesignTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _formatHistoryTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
