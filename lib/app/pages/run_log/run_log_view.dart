import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/run_log_controller.dart';
import '../../database/database.dart';

class RunLogView extends GetView<RunLogController> {
  const RunLogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          TextButton.icon(
            onPressed: controller.clearLogs,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清空'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<RunLogRecord>>(
        stream: controller.logsStream,
        initialData: const <RunLogRecord>[],
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _RunLogMessage(
              icon: Icons.error_outline,
              message: '读取运行日志失败：${snapshot.error}',
            );
          }

          final logs = snapshot.data ?? const <RunLogRecord>[];
          if (logs.isEmpty) {
            return const _RunLogMessage(
              icon: Icons.fact_check_outlined,
              message: '暂无错误日志',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _RunLogTile(record: logs[index]),
          );
        },
      ),
    );
  }
}

class _RunLogTile extends StatelessWidget {
  const _RunLogTile({required this.record});

  final RunLogRecord record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = record.details;
    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.source,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  _formatRunLogTime(record.createdAt),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(record.message),
            if (details != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                details,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RunLogMessage extends StatelessWidget {
  const _RunLogMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRunLogTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute:$second';
}
