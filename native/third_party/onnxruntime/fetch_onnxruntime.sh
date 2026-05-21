#!/usr/bin/env bash
set -euo pipefail

# 下载并安装 ONNX Runtime Windows x64 GPU SDK 到当前目录。
# 只清理 SDK 产物本身，保留本脚本和项目说明文件，避免误删仓库文件。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD_PARTY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOWNLOAD_DIR="${THIRD_PARTY_DIR}/.downloads"

ONNXRUNTIME_VERSION="${ONNXRUNTIME_VERSION:-1.26.0}"
ONNXRUNTIME_PACKAGE="${ONNXRUNTIME_PACKAGE:-onnxruntime-win-x64-gpu-${ONNXRUNTIME_VERSION}}"
ONNXRUNTIME_URL="${ONNXRUNTIME_URL:-https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/${ONNXRUNTIME_PACKAGE}.zip}"
NATIVE_DEPS_FORCE="${NATIVE_DEPS_FORCE:-0}"

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

safe_remove_file() {
  local path="$1"
  ensure_inside_third_party "${path}"
  if [[ -f "${path}" ]]; then
    rm -f "${path}"
  fi
}

onnxruntime_sdk_ready() {
  [[ -f "${SCRIPT_DIR}/include/onnxruntime_cxx_api.h" ]] &&
    [[ -f "${SCRIPT_DIR}/lib/onnxruntime.lib" ]] &&
    [[ -f "${SCRIPT_DIR}/lib/onnxruntime.dll" ]]
}

download_file() {
  local url="$1"
  local target="$2"
  printf '下载：%s\n' "${url}"
  curl --fail --location --retry 3 --output "${target}" "${url}"
}

reset_sdk_payload() {
  safe_remove_dir "${SCRIPT_DIR}/include"
  safe_remove_dir "${SCRIPT_DIR}/lib"
  safe_remove_dir "${SCRIPT_DIR}/bin"
  for file_name in \
    GIT_COMMIT_ID \
    LICENSE \
    Privacy.md \
    README.md \
    ThirdPartyNotices.txt \
    VERSION_NUMBER; do
    safe_remove_file "${SCRIPT_DIR}/${file_name}"
  done
}

install_sdk_payload() {
  local extracted="$1"
  if [[ ! -f "${extracted}/include/onnxruntime_cxx_api.h" || \
        ! -f "${extracted}/lib/onnxruntime.lib" || \
        ! -f "${extracted}/lib/onnxruntime.dll" ]]; then
    printf 'ONNX Runtime 压缩包结构不符合预期：%s\n' "${extracted}" >&2
    exit 1
  fi

  reset_sdk_payload
  cp -a "${extracted}/include" "${SCRIPT_DIR}/"
  cp -a "${extracted}/lib" "${SCRIPT_DIR}/"
  if [[ -d "${extracted}/bin" ]]; then
    cp -a "${extracted}/bin" "${SCRIPT_DIR}/"
  fi
  for file_name in \
    GIT_COMMIT_ID \
    LICENSE \
    Privacy.md \
    README.md \
    ThirdPartyNotices.txt \
    VERSION_NUMBER; do
    if [[ -f "${extracted}/${file_name}" ]]; then
      cp -f "${extracted}/${file_name}" "${SCRIPT_DIR}/"
    fi
  done
}

main() {
  if onnxruntime_sdk_ready && ! is_truthy "${NATIVE_DEPS_FORCE}"; then
    printf 'ONNX Runtime SDK 已存在：%s\n' "${SCRIPT_DIR}"
    return
  fi

  require_tool curl
  require_tool unzip
  mkdir -p "${DOWNLOAD_DIR}"

  local archive="${DOWNLOAD_DIR}/${ONNXRUNTIME_PACKAGE}.zip"
  local extracted="${DOWNLOAD_DIR}/${ONNXRUNTIME_PACKAGE}"
  if [[ ! -f "${archive}" ]] || is_truthy "${NATIVE_DEPS_FORCE}"; then
    download_file "${ONNXRUNTIME_URL}" "${archive}"
  fi

  safe_remove_dir "${extracted}"
  unzip -q "${archive}" -d "${DOWNLOAD_DIR}"
  install_sdk_payload "${extracted}"
  if ! onnxruntime_sdk_ready; then
    printf 'ONNX Runtime SDK 安装校验失败：%s\n' "${SCRIPT_DIR}" >&2
    exit 1
  fi
  printf 'ONNX Runtime SDK 已准备：%s\n' "${SCRIPT_DIR}"
}

main "$@"
