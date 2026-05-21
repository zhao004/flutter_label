#pragma once

#include <cstdint>
#include <vector>

namespace flutter_label::yolo {

inline constexpr int kSuccess = 0;
inline constexpr int kInvalidArgument = -1;
inline constexpr int kFileNotFound = -2;
inline constexpr int kDirectoryError = -3;
inline constexpr int kModelUnavailable = -11;
inline constexpr int kModelLoadFailed = -12;
inline constexpr int kInferFailed = -13;
inline constexpr int kUnsupportedOutput = -14;
inline constexpr int kImageDecodeFailed = -15;
inline constexpr int kUnsupportedInput = -16;
inline constexpr int kInputSizeMismatch = -17;
inline constexpr int kInputInfoUnavailable = -18;

inline constexpr int kRgbChannels = 3;
inline constexpr float kLetterboxPadValue = 114.0f / 255.0f;
inline constexpr float kMinConfidence = 0.001f;

/// 单个模型候选框，坐标使用原图归一化后的左上宽高。
struct BoxCandidate {
  int class_id = 0;
  float confidence = 0.0f;
  float left = 0.0f;
  float top = 0.0f;
  float width = 0.0f;
  float height = 0.0f;
};

/// RGB24 图片缓冲区，供图片文件和窗口截图推理共用。
struct ImageBuffer {
  int width = 0;
  int height = 0;
  std::vector<uint8_t> rgb;
};

/// letterbox 预处理结果，保留缩放与 padding 用于坐标反算。
struct PreprocessResult {
  std::vector<float> tensor;
  float scale = 1.0f;
  float pad_x = 0.0f;
  float pad_y = 0.0f;
  int resized_width = 0;
  int resized_height = 0;
};

}  // namespace flutter_label::yolo
