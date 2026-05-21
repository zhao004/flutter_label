import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'app_run_log_service.dart';

/// 统一管理全局 Toast，保证所有短提示的位置、颜色与异常策略一致。
class AppToast {
  const AppToast._();

  static const Color successColor = Color(0xFF2E7D32);
  static const Color errorColor = Color(0xFFC62828);
  static const Duration _autoCloseDuration = Duration(seconds: 4);
  static const Duration _animationDuration = Duration(milliseconds: 240);
  static const double _toastRadius = 12;
  static const EdgeInsetsGeometry _toastPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
  static const EdgeInsetsGeometry _toastMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  /// 展示绿色成功提示；空消息会回退为通用成功文案。
  static void success(Object? message) {
    _show(
      message: message,
      fallbackMessage: '操作成功',
      type: ToastificationType.success,
      color: successColor,
      icon: Icons.check_circle_outline,
    );
  }

  /// 展示红色错误提示；异常对象会转成可读文本，空消息会回退为通用失败文案。
  static void error(Object? message, {String source = '系统', Object? details}) {
    final normalizedMessage = normalizeMessage(message, '操作失败');
    _recordError(source: source, message: normalizedMessage, details: details);
    _show(
      message: normalizedMessage,
      fallbackMessage: '操作失败',
      type: ToastificationType.error,
      color: errorColor,
      icon: Icons.error_outline,
    );
  }

  static void _recordError({
    required String source,
    required String message,
    Object? details,
  }) {
    try {
      if (!Get.isRegistered<AppRunLogService>()) {
        return;
      }
      unawaited(
        Get.find<AppRunLogService>().recordError(
          source: source,
          message: message,
          details: details,
        ),
      );
    } catch (_) {
      // 日志写入失败不能影响 Toast 展示和主流程。
    }
  }

  @visibleForTesting
  static String normalizeMessage(Object? message, String fallbackMessage) {
    final normalized = message?.toString().trim() ?? '';
    return normalized.isEmpty ? fallbackMessage : normalized;
  }

  static void _show({
    required Object? message,
    required String fallbackMessage,
    required ToastificationType type,
    required Color color,
    required IconData icon,
  }) {
    final normalizedMessage = normalizeMessage(message, fallbackMessage);
    try {
      if (Get.testMode || _isFlutterTestBinding()) {
        return;
      }
      toastification.show(
        context: Get.context,
        type: type,
        style: ToastificationStyle.flatColored,
        alignment: Alignment.topRight,
        autoCloseDuration: _autoCloseDuration,
        animationDuration: _animationDuration,
        title: Text(normalizedMessage),
        icon: Icon(icon, color: color),
        primaryColor: color,
        padding: _toastPadding,
        margin: _toastMargin,
        borderRadius: BorderRadius.circular(_toastRadius),
        showProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        dragToClose: true,
      );
    } catch (_) {
      // Toast 只是提示通道，失败时不能反向影响文件操作、模型推理等主流程。
    }
  }

  static bool _isFlutterTestBinding() {
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }
}
