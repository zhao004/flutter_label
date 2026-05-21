# Flutter Label ONNX Runtime 说明

当前目录放置的是 ONNX Runtime `v1.26.0` Windows x64 GPU SDK：

```text
onnxruntime-win-x64-gpu-1.26.0.zip
```

需要重新拉取 SDK 时，在 WSL / Linux / Git Bash 中运行：

```bash
bash native/third_party/onnxruntime/fetch_onnxruntime.sh
```

脚本默认下载 `onnxruntime-win-x64-gpu-1.26.0.zip`，只会清理当前目录中的 SDK 产物，保留本脚本和项目说明文件。需要强制重新下载或覆盖时使用：

```bash
NATIVE_DEPS_FORCE=1 bash native/third_party/onnxruntime/fetch_onnxruntime.sh
```

## 运行要求

- Windows x64。
- NVIDIA 显卡驱动正常安装。
- CUDA / cuDNN 运行时可被系统加载。ONNX Runtime GPU 包不等于完整 CUDA 安装包。

## 执行策略

`native_core` 初始化模型时会优先尝试 CUDA Execution Provider；如果 CUDA provider 初始化失败，会自动创建 CPU Session。CPU 也失败时，Dart 侧直接返回 native 错误，不再调用 `yolo` 命令或 Python 的 `ultralytics` 模块。

## 覆盖范围

- 自动预标注：批量图片直接通过 ONNX Runtime 推理，并输出 YOLO txt。
- 模型验证：单图验证通过同一套 ONNX Runtime 推理后端输出检测 JSON。
