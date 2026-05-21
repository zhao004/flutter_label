import 'dart:async';

/// 串行化 native_core 的全局模型状态访问。
///
/// native_core 当前以单例 Session 保存模型，Dart 侧必须保证
/// `init_model -> detect_* -> release_model` 不会和另一条检测任务交错。
class NativeModelLock {
  NativeModelLock._();

  static Future<void> _lastOperation = Future.value();

  static Future<T> run<T>(FutureOr<T> Function() action) async {
    final previousOperation = _lastOperation;
    final currentOperation = Completer<void>();
    _lastOperation = currentOperation.future;

    try {
      await previousOperation.catchError((_) {
        // 前一个任务的异常已由调用方处理；锁只负责继续释放后续任务。
      });
      return await action();
    } finally {
      if (!currentOperation.isCompleted) {
        currentOperation.complete();
      }
    }
  }
}
