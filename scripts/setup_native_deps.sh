#!/usr/bin/env bash
set -euo pipefail

# 在 WSL / Linux / Git Bash 下准备 native_core 需要的 Windows x64 SDK。
# native/third_party 被 Git 忽略，本脚本只写入本地依赖，避免把大体积二进制提交到仓库。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
THIRD_PARTY_DIR="${REPO_ROOT}/native/third_party"
DOWNLOAD_DIR="${THIRD_PARTY_DIR}/.downloads"

FFMPEG_DIR="${THIRD_PARTY_DIR}/ffmpeg"
FFMPEG_SOURCE_DIR="${DOWNLOAD_DIR}/ffmpeg-source"
FFMPEG_STAGE_DIR="${DOWNLOAD_DIR}/ffmpeg-stage"
FFMPEG_SDK_ROOT="${FFMPEG_DIR}"
FFMPEG_REPOSITORY_URL="${FFMPEG_REPOSITORY_URL:-https://github.com/FFmpeg/FFmpeg.git}"
FFMPEG_REF="${FFMPEG_REF:-n8.0}"

ONNXRUNTIME_VERSION="${ONNXRUNTIME_VERSION:-1.26.0}"
ONNXRUNTIME_PACKAGE="${ONNXRUNTIME_PACKAGE:-onnxruntime-win-x64-gpu-${ONNXRUNTIME_VERSION}}"
ONNXRUNTIME_URL="${ONNXRUNTIME_URL:-https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/${ONNXRUNTIME_PACKAGE}.zip}"
ONNXRUNTIME_DIR="${THIRD_PARTY_DIR}/onnxruntime"
ONNXRUNTIME_FETCH_SCRIPT="${ONNXRUNTIME_DIR}/fetch_onnxruntime.sh"

NATIVE_DEPS_FORCE="${NATIVE_DEPS_FORCE:-0}"
SKIP_FFMPEG="${SKIP_FFMPEG:-0}"
SKIP_ONNXRUNTIME="${SKIP_ONNXRUNTIME:-0}"

shopt -s nullglob

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '缺少依赖命令：%s\n' "$1" >&2
    exit 1
  fi
}

ensure_inside_third_party() {
  local path="$1"
  case "${path}" in
    "${THIRD_PARTY_DIR}"|"${THIRD_PARTY_DIR}"/*) return 0 ;;
    *)
      printf '拒绝操作 third_party 之外的路径：%s\n' "${path}" >&2
      exit 1
      ;;
  esac
}

safe_remove_dir() {
  local path="$1"
  ensure_inside_third_party "${path}"
  if [[ -d "${path}" ]]; then
    rm -rf "${path}"
  fi
}

has_file_match() {
  local directory="$1"
  local pattern="$2"
  local match=""
  match="$(find "${directory}" -maxdepth 1 -type f -name "${pattern}" -print -quit 2>/dev/null || true)"
  [[ -n "${match}" ]]
}

ffmpeg_sdk_ready() {
  [[ -f "${FFMPEG_SDK_ROOT}/include/libavformat/avformat.h" ]] &&
    [[ -f "${FFMPEG_SDK_ROOT}/include/libavcodec/avcodec.h" ]] &&
    [[ -f "${FFMPEG_SDK_ROOT}/include/libavutil/avutil.h" ]] &&
    [[ -f "${FFMPEG_SDK_ROOT}/include/libswscale/swscale.h" ]] &&
    [[ -f "${FFMPEG_SDK_ROOT}/lib/avformat.lib" ]] &&
    [[ -f "${FFMPEG_SDK_ROOT}/lib/avcodec.lib" ]] &&
    [[ -f "${FFMPEG_SDK_ROOT}/lib/avutil.lib" ]] &&
    [[ -f "${FFMPEG_SDK_ROOT}/lib/swscale.lib" ]] &&
    has_file_match "${FFMPEG_SDK_ROOT}/bin" 'avformat-*.dll' &&
    has_file_match "${FFMPEG_SDK_ROOT}/bin" 'avcodec-*.dll' &&
    has_file_match "${FFMPEG_SDK_ROOT}/bin" 'avutil-*.dll' &&
    has_file_match "${FFMPEG_SDK_ROOT}/bin" 'swscale-*.dll'
}

install_onnxruntime() {
  if is_truthy "${SKIP_ONNXRUNTIME}"; then
    printf '跳过 ONNX Runtime。\n'
    return
  fi
  if [[ ! -f "${ONNXRUNTIME_FETCH_SCRIPT}" ]]; then
    printf '缺少 ONNX Runtime 拉取脚本：%s\n' "${ONNXRUNTIME_FETCH_SCRIPT}" >&2
    exit 1
  fi
  ONNXRUNTIME_VERSION="${ONNXRUNTIME_VERSION}" \
    ONNXRUNTIME_PACKAGE="${ONNXRUNTIME_PACKAGE}" \
    ONNXRUNTIME_URL="${ONNXRUNTIME_URL}" \
    NATIVE_DEPS_FORCE="${NATIVE_DEPS_FORCE}" \
    bash "${ONNXRUNTIME_FETCH_SCRIPT}"
}

prepare_ffmpeg_source() {
  require_tool git
  if [[ ! -d "${FFMPEG_SOURCE_DIR}" ]]; then
    printf '开始浅克隆 FFmpeg 源码：%s\n' "${FFMPEG_REF}"
    git clone --depth 1 --branch "${FFMPEG_REF}" "${FFMPEG_REPOSITORY_URL}" "${FFMPEG_SOURCE_DIR}"
    return
  fi

  if [[ ! -d "${FFMPEG_SOURCE_DIR}/.git" ]]; then
    printf 'FFmpeg 源码目录已存在但不是 Git 仓库，已停止以避免误删用户文件：%s\n' "${FFMPEG_SOURCE_DIR}" >&2
    exit 1
  fi

  printf '更新 FFmpeg 源码：%s\n' "${FFMPEG_REF}"
  git -C "${FFMPEG_SOURCE_DIR}" remote set-url origin "${FFMPEG_REPOSITORY_URL}"
  git -C "${FFMPEG_SOURCE_DIR}" fetch --depth 1 origin "${FFMPEG_REF}"
  git -C "${FFMPEG_SOURCE_DIR}" checkout --detach FETCH_HEAD
}

copy_required_file() {
  local target_dir="$1"
  shift
  local matches=("$@")
  if [[ ${#matches[@]} -ne 1 || ! -f "${matches[0]}" ]]; then
    printf '缺少必需的 FFmpeg 产物：%s\n' "${matches[*]:-<none>}" >&2
    exit 1
  fi
  cp -f "${matches[0]}" "${target_dir}/"
}

reset_ffmpeg_sdk_root() {
  safe_remove_dir "${FFMPEG_SDK_ROOT}/include"
  safe_remove_dir "${FFMPEG_SDK_ROOT}/lib"
  safe_remove_dir "${FFMPEG_SDK_ROOT}/bin"
  mkdir -p "${FFMPEG_SDK_ROOT}/include" "${FFMPEG_SDK_ROOT}/lib" "${FFMPEG_SDK_ROOT}/bin"
}

make_jobs() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
    return
  fi
  if command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN
    return
  fi
  printf '2\n'
}

install_ffmpeg() {
  if is_truthy "${SKIP_FFMPEG}"; then
    printf '跳过 FFmpeg。\n'
    return
  fi
  if ffmpeg_sdk_ready && ! is_truthy "${NATIVE_DEPS_FORCE}"; then
    printf 'FFmpeg SDK 已存在：%s\n' "${FFMPEG_SDK_ROOT}"
    return
  fi

  require_tool x86_64-w64-mingw32-gcc
  require_tool x86_64-w64-mingw32-objdump
  require_tool make
  prepare_ffmpeg_source
  if [[ ! -x "${FFMPEG_SOURCE_DIR}/configure" ]]; then
    printf 'FFmpeg 源码缺少 configure：%s\n' "${FFMPEG_SOURCE_DIR}" >&2
    exit 1
  fi

  safe_remove_dir "${FFMPEG_STAGE_DIR}"
  mkdir -p "${FFMPEG_STAGE_DIR}"

  pushd "${FFMPEG_SOURCE_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  ./configure \
    --prefix="${FFMPEG_STAGE_DIR}" \
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
  make -j"$(make_jobs)"
  make install
  popd >/dev/null

  reset_ffmpeg_sdk_root
  cp -a "${FFMPEG_STAGE_DIR}/include/." "${FFMPEG_SDK_ROOT}/include/"
  copy_required_file "${FFMPEG_SDK_ROOT}/lib" "${FFMPEG_STAGE_DIR}"/bin/avcodec.lib
  copy_required_file "${FFMPEG_SDK_ROOT}/lib" "${FFMPEG_STAGE_DIR}"/bin/avformat.lib
  copy_required_file "${FFMPEG_SDK_ROOT}/lib" "${FFMPEG_STAGE_DIR}"/bin/avutil.lib
  copy_required_file "${FFMPEG_SDK_ROOT}/lib" "${FFMPEG_STAGE_DIR}"/bin/swscale.lib
  copy_required_file "${FFMPEG_SDK_ROOT}/bin" "${FFMPEG_STAGE_DIR}"/bin/avcodec-*.dll
  copy_required_file "${FFMPEG_SDK_ROOT}/bin" "${FFMPEG_STAGE_DIR}"/bin/avformat-*.dll
  copy_required_file "${FFMPEG_SDK_ROOT}/bin" "${FFMPEG_STAGE_DIR}"/bin/avutil-*.dll
  copy_required_file "${FFMPEG_SDK_ROOT}/bin" "${FFMPEG_STAGE_DIR}"/bin/swscale-*.dll

  safe_remove_dir "${FFMPEG_SOURCE_DIR}"
  safe_remove_dir "${FFMPEG_STAGE_DIR}"
  if ! ffmpeg_sdk_ready; then
    printf 'FFmpeg SDK 安装校验失败：%s\n' "${FFMPEG_SDK_ROOT}" >&2
    exit 1
  fi
  printf 'FFmpeg SDK 已准备：%s\n' "${FFMPEG_SDK_ROOT}"
}

main() {
  mkdir -p "${THIRD_PARTY_DIR}" "${DOWNLOAD_DIR}"
  install_onnxruntime
  install_ffmpeg
  printf '原生第三方依赖已准备完成。\n'
}

main "$@"
