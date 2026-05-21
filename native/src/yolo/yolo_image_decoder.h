#pragma once

#include <filesystem>

#include "yolo/yolo_types.h"

namespace flutter_label::yolo {

/// 解码图片为 RGB24；Windows 优先 WIC，失败后按构建能力回退 FFmpeg。
int decode_image(const std::filesystem::path& image_path, ImageBuffer* output);

}  // namespace flutter_label::yolo
