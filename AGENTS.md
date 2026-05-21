# AGENTS.md

## 项目事实

- 这是 Windows 优先的 Flutter 桌面应用；`.metadata` 只登记了 `root` 和 `windows` 平台。
- Dart SDK 约束是 `>=3.11.1 <4.0.0`，分析规则来自 `package:flutter_lints/flutter.yaml`。
- 根目录没有 CI、任务运行器或自定义脚本；不要猜 `make`/`npm`/`melos` 命令。

## 常用命令

- 初次同步依赖：`flutter pub get`。
- 静态检查：`flutter analyze`。
- 全量测试：`flutter test`。
- 单文件测试：`flutter test test/app/services/project_service_test.dart`，把路径替换成目标测试文件。
- 修改 Drift 表或 `AppDatabase` 后重新生成：`dart run build_runner build --delete-conflicting-outputs`。
- Windows 原生链路校验：`flutter build windows`；本地运行用 `flutter run -d windows`。

## 入口与结构

- 应用入口是 `lib/main.dart`，初始化 `MediaKit`、`ToastificationWrapper`、`GetMaterialApp`、`AppDatabase`、`AppRunLogService`
  和应用配置控制器。
- 路由表在 `lib/app/routes/app_pages.dart`；新增页面时同时保持 `part` 文件 `app_routes.dart` 的常量和 `GetPage` 列表一致。
- 主要目录按 GetX 分层：`pages/` 放视图，`controllers/` 放状态与流程，`bindings/` 注入依赖，`services/` 放文件/数据库/原生调用逻辑，
  `models/` 放数据结构。
- 全局单例优先通过 GetX 注册；测试里通常设置 `Get.testMode = true` 并在 `tearDown(Get.reset)` 清理。

## 数据库与生成代码

- Drift 数据库入口是 `lib/app/database/database.dart`，生成文件是 `lib/app/database/database.g.dart`，不要手改 `.g.dart`。
- 改表结构时同步提升 `AppDatabase._schemaVersion` 并补充 `MigrationStrategy.onUpgrade`，否则已有本地
  `flutter_label.sqlite` 无法迁移。
- 图片索引缓存表按 `{datasetRoot, scanMode, relativePath}` 去重；修改扫描逻辑时检查 `ImageIndexScanMode` 和缓存失效路径。

## 原生后端

- `windows/CMakeLists.txt` 会把 `native/` 作为 `native_core` 子项目构建，并把 `native_core.dll`、FFmpeg、ONNX Runtime
  以及可发现的 CUDA/cuDNN DLL 复制到 exe 同级的 `lib/` 目录。
- FFmpeg SDK 固定使用 `native/third_party/ffmpeg/{include,lib,bin}`；README 明确不要把 DLL 放回项目根目录
  `runtime/`，开发运行时如需手动放置，应使用 `runtime/lib/`。
- ONNX Runtime 当前是 `native/third_party/onnxruntime` 下的 Windows x64 GPU SDK `v1.26.0`；CUDA Provider 失败时应用应降级
  CPU，不要恢复为 shell `ffmpeg`、`yolo` 或 Python `ultralytics` 调用。
- CUDA/cuDNN DLL 查找依赖 `CUDA_PATH`、`CUDA_HOME`、`CUDNN_HOME`、`FLUTTER_LABEL_CUDA_RUNTIME_DIR`、
  `FLUTTER_LABEL_CUDNN_RUNTIME_DIR` 或 `native/third_party/cuda|cudnn/.../bin`。
- `native_core` 的模型 Session 是全局状态；新增 Dart FFI 推理路径必须通过 `NativeModelLock.run` 串行化
  `init_model -> detect_* -> release_model`。

## 数据与测试约定

- 数据集根目录由 `ProjectService` 维护：`data.yaml`、`project.json`、`images/{train,val,test}`、
  `labels/{train,val,test}`。
- `project.json` 是内部缓存，打开已有项目以 `data.yaml` 的 `names` 为准；损坏缓存会重建，不要把它当唯一真源。
- Widget 测试使用 `test/support/test_app.dart` 的 `buildTestApp` 包装 `ToastificationWrapper` + `GetMaterialApp`；布局回归用
  `setTestViewport` 设置桌面或窄屏尺寸。
- 原生/模型相关单测通过注入 runner 模拟 `native_core`，不要让单测依赖真实 ONNX、CUDA 或视频文件。
