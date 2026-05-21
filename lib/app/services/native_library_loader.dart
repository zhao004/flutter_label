import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef _SetDllDirectoryNative = Int32 Function(Pointer<Utf16>);
typedef _SetDllDirectoryDart = int Function(Pointer<Utf16>);

final Set<String> _configuredWindowsDllDirectories = <String>{};

/// 返回 native_core 的加载路径，并在 Windows 上准备依赖 DLL 搜索目录。
///
/// Windows 打包后原生运行时 DLL 位于 exe 同级的 lib 目录。加载 native_core
/// 前需要把该目录加入 DLL 搜索路径，否则 FFmpeg、ONNX Runtime 或 CUDA
/// 依赖可能在 native_core 初始化前被系统加载器判定为缺失。
String nativeCoreLibraryPath() {
  if (Platform.isWindows) {
    final libraryPath = _windowsNativeCoreLibraryPath();
    _configureWindowsDllSearchDirectory(p.dirname(libraryPath));
    return libraryPath;
  }
  if (Platform.isLinux) {
    return p.join(Directory.current.path, 'runtime', 'libnative_core.so');
  }
  if (Platform.isMacOS) {
    return p.join(Directory.current.path, 'runtime', 'libnative_core.dylib');
  }
  throw UnsupportedError('当前平台不支持 native_core 动态库');
}

String _windowsNativeCoreLibraryPath() {
  final executableLibPath = p.join(
    p.dirname(Platform.resolvedExecutable),
    'lib',
    'native_core.dll',
  );
  final runtimeLibPath = p.join(
    Directory.current.path,
    'runtime',
    'lib',
    'native_core.dll',
  );
  final currentLibPath = p.join(
    Directory.current.path,
    'lib',
    'native_core.dll',
  );

  for (final candidate in <String>[
    executableLibPath,
    runtimeLibPath,
    currentLibPath,
  ]) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return executableLibPath;
}

void _configureWindowsDllSearchDirectory(String directoryPath) {
  if (!Platform.isWindows || directoryPath.isEmpty) {
    return;
  }
  final normalizedPath = p.normalize(directoryPath);
  if (!_configuredWindowsDllDirectories.add(normalizedPath)) {
    return;
  }
  if (!Directory(normalizedPath).existsSync()) {
    _configuredWindowsDllDirectories.remove(normalizedPath);
    return;
  }

  Pointer<Utf16>? nativeDirectory;
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final setDllDirectory = kernel32
        .lookupFunction<_SetDllDirectoryNative, _SetDllDirectoryDart>(
          'SetDllDirectoryW',
        );
    nativeDirectory = normalizedPath.toNativeUtf16();
    if (setDllDirectory(nativeDirectory) == 0) {
      _configuredWindowsDllDirectories.remove(normalizedPath);
    }
  } catch (_) {
    // 搜索路径配置失败时仍返回显式 DLL 路径，让调用方保留原始加载错误。
    _configuredWindowsDllDirectories.remove(normalizedPath);
  } finally {
    if (nativeDirectory != null) {
      malloc.free(nativeDirectory);
    }
  }
}
