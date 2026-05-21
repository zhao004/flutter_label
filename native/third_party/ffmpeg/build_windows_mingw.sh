#!/usr/bin/env bash
set -euo pipefail

# 在 WSL / Linux 下使用 mingw-w64 交叉编译 FFmpeg，生成 Windows 可用的 SDK。
# 设计目标：
# 1. 只生成项目需要的最小组件，避免引入不必要的依赖。
# 2. 自动导出 include / lib / runtime DLL，方便 Flutter Windows 直接使用。
# 3. 失败时立即退出，避免留下半成品 SDK。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/source"
WORK_DIR="${SCRIPT_DIR}/.work"
STAGE_DIR="${WORK_DIR}/sdk-mingw"
SDK_ROOT="${SCRIPT_DIR}"
FFMPEG_REPOSITORY_URL="${FFMPEG_REPOSITORY_URL:-https://github.com/FFmpeg/FFmpeg.git}"
FFMPEG_REF="${FFMPEG_REF:-master}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '缺少依赖命令：%s\n' "$1" >&2
    exit 1
  fi
}

require_tool x86_64-w64-mingw32-gcc
require_tool x86_64-w64-mingw32-objdump
require_tool git

copy_required_file() {
  local target_dir="$1"
  shift
  local matches=("$@")
  if [[ ${#matches[@]} -ne 1 || ! -f "${matches[0]}" ]]; then
    printf '缺少必需的 FFmpeg 产物：%s\n' "${matches[*]}" >&2
    exit 1
  fi
  cp -f "${matches[0]}" "${target_dir}/"
}

prepare_source() {
  if [[ ! -d "${SOURCE_DIR}" ]]; then
    printf '未找到 FFmpeg 源码目录，开始从官方仓库浅克隆：%s\n' "${SOURCE_DIR}"
    git clone --depth 1 --branch "${FFMPEG_REF}" "${FFMPEG_REPOSITORY_URL}" "${SOURCE_DIR}"
    return
  fi

  if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    printf '源码目录已存在但不是 Git 仓库，已停止以避免误删文件：%s\n' "${SOURCE_DIR}" >&2
    exit 1
  fi

  printf '发现 FFmpeg 源码目录，开始从官方仓库更新：%s\n' "${SOURCE_DIR}"
  git -C "${SOURCE_DIR}" remote set-url origin "${FFMPEG_REPOSITORY_URL}"
  git -C "${SOURCE_DIR}" fetch --depth 1 origin "${FFMPEG_REF}"
  git -C "${SOURCE_DIR}" checkout --detach FETCH_HEAD

  if [[ ! -x "${SOURCE_DIR}/configure" ]]; then
    printf '源码目录缺少 configure，无法编译：%s\n' "${SOURCE_DIR}" >&2
    exit 1
  fi
}

prepare_source
mkdir -p "${WORK_DIR}" "${SDK_ROOT}"

cleanup() {
  rm -rf "${STAGE_DIR}"
}

trap cleanup EXIT

pushd "${SOURCE_DIR}" >/dev/null
make distclean >/dev/null 2>&1 || true

./configure \
  --prefix="${STAGE_DIR}" \
  --target-os=mingw32 \
  --arch=x86_64 \
  --cross-prefix=x86_64-w64-mingw32- \
  --enable-cross-compile \
  --enable-shared \
  --disable-static \
  --disable-programs \
  --disable-doc \
  --disable-debug \
  --disable-autodetect \
  --disable-x86asm \
  --disable-network \
  --disable-everything \
  --enable-protocol=file \
  --enable-demuxer=mov \
  --enable-demuxer=matroska \
  --enable-demuxer=avi \
  --enable-demuxer=flv \
  --enable-decoder=h264 \
  --enable-decoder=hevc \
  --enable-decoder=mpeg4 \
  --enable-decoder=mjpeg \
  --enable-decoder=vp8 \
  --enable-decoder=vp9 \
  --enable-parser=h264 \
  --enable-parser=hevc \
  --enable-parser=mpeg4video \
  --enable-parser=mjpeg \
  --enable-parser=vp8 \
  --enable-parser=vp9 \
  --enable-encoder=mjpeg \
  --enable-avcodec \
  --enable-avformat \
  --enable-avutil \
  --enable-swscale

make -j"$(nproc)"
make install
popd >/dev/null

# SDK 直接放在 ffmpeg 目录下，保留 README 和脚本，避免再产生 windows-x64 包装目录。
rm -rf "${SDK_ROOT}/include" "${SDK_ROOT}/lib" "${SDK_ROOT}/bin"
mkdir -p "${SDK_ROOT}/include" "${SDK_ROOT}/lib" "${SDK_ROOT}/bin"

cp -a "${STAGE_DIR}/include/." "${SDK_ROOT}/include/"

copy_required_file "${SDK_ROOT}/lib" "${STAGE_DIR}/bin/avcodec.lib"
copy_required_file "${SDK_ROOT}/lib" "${STAGE_DIR}/bin/avformat.lib"
copy_required_file "${SDK_ROOT}/lib" "${STAGE_DIR}/bin/avutil.lib"
copy_required_file "${SDK_ROOT}/lib" "${STAGE_DIR}/bin/swscale.lib"

copy_required_file "${SDK_ROOT}/bin" "${STAGE_DIR}"/bin/avcodec-*.dll
copy_required_file "${SDK_ROOT}/bin" "${STAGE_DIR}"/bin/avformat-*.dll
copy_required_file "${SDK_ROOT}/bin" "${STAGE_DIR}"/bin/avutil-*.dll
copy_required_file "${SDK_ROOT}/bin" "${STAGE_DIR}"/bin/swscale-*.dll

rm -rf "${SOURCE_DIR}"

printf 'FFmpeg Windows SDK 已生成：%s\n' "${SDK_ROOT}"
