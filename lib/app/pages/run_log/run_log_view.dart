import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/run_log_controller.dart';
import '../../database/database.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/fluent_app_shell.dart';
import '../../widgets/fluent_card.dart';

class RunLogView extends GetView<RunLogController> {
  const RunLogView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentAppShell(
      title: '运行日志',
      child: ColoredBox(
        color: palette.appBackground,
        child: ListView(
          padding: FluentDesignTokens.pagePadding,
          children: [
            FluentCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '错误记录',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 112,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: controller.clearLogs,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('清空'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: palette.border),
                  StreamBuilder<List<RunLogRecord>>(
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
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _RunLogTile(
                          record: logs[index],
                          warning: index == 0,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunLogTile extends StatelessWidget {
  const _RunLogTile({required this.record, required this.warning});

  final RunLogRecord record;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final details = record.details;
    final palette = FluentDesignTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: warning ? palette.warningBackground : palette.fieldBackground,
        border: Border.all(
          color: warning ? palette.warningBorder : palette.fieldBorder,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: warning ? palette.warningText : palette.errorRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.source,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _formatRunLogTime(record.createdAt),
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(record.message),
            if (details != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                details,
                style: TextStyle(color: palette.textSecondary),
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
    final palette = FluentDesignTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: palette.textSecondary)),
        ],
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
