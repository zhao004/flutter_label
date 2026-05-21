# FFmpeg 官方源码与 SDK 说明

本目录只保留 Windows 构建实际需要的最小 SDK 文件：

```text
include/ -> FFmpeg 头文件，供 C++ 编译使用
lib/     -> MSVC 可链接的 import library，供 native_core.dll 链接使用
bin/     -> FFmpeg 运行时 DLL，随 Windows 应用复制到 exe 同级 lib 目录
```

注意：官方 GitHub 仓库提供的是源码，不是可直接链接的 Windows SDK。当前 `native_core` 只会在 Windows 平台识别下面这种结构：

```text
native/third_party/ffmpeg/
├─ include/
│  ├─ libavcodec/
│  ├─ libavformat/
│  ├─ libavutil/
│  └─ libswscale/
├─ lib/
│  ├─ avcodec.lib
│  ├─ avformat.lib
│  ├─ avutil.lib
│  └─ swscale.lib
└─ bin/
   ├─ avcodec-*.dll
   ├─ avformat-*.dll
   ├─ avutil-*.dll
   └─ swscale-*.dll
```

Windows 打包时，`windows/CMakeLists.txt` 会把 `bin/*.dll` 复制到应用 exe 同级的 `lib/` 目录。不要把这些 DLL 放回项目根目录的 `runtime/`，否则源码布局会再次变得混乱。

为了减少仓库体积，官方源码目录 `source/` 和完整安装目录只作为脚本运行时的临时文件。需要重新生成 SDK 时运行：

```bash
native/third_party/ffmpeg/build_windows_mingw.sh
```

脚本会自动处理源码：

- 缺少 `source/` 时，从官方 GitHub 仓库浅克隆源码。
- `source/` 已存在且是 Git 仓库时，从官方仓库更新到指定 ref。
- `source/` 已存在但不是 Git 仓库时，直接停止，避免误删用户文件。
- 编译完成后只保留 `include/`、`lib/`、`bin/`，并清理 `source/` 和临时安装目录。

默认使用官方仓库和 `master` 分支，也可以通过环境变量指定：

```bash
FFMPEG_REPOSITORY_URL=https://github.com/FFmpeg/FFmpeg.git FFMPEG_REF=master native/third_party/ffmpeg/build_windows_mingw.sh
```

`build_windows_msvc.ps1` 仅适合在纯 Windows + MSVC 环境里使用。
