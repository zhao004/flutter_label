#include "yolo/yolo_preprocess.h"

#include <algorithm>
#include <cmath>

namespace flutter_label::yolo {
namespace {

float sample_channel(
    const ImageBuffer& image,
    int channel,
    float x,
    float y) {
  const float clamped_x =
      std::max(0.0f, std::min(x, static_cast<float>(image.width - 1)));
  const float clamped_y =
      std::max(0.0f, std::min(y, static_cast<float>(image.height - 1)));
  const int x0 = static_cast<int>(std::floor(clamped_x));
  const int y0 = static_cast<int>(std::floor(clamped_y));
  const int x1 = std::min(x0 + 1, image.width - 1);
  const int y1 = std::min(y0 + 1, image.height - 1);
  const float dx = clamped_x - static_cast<float>(x0);
  const float dy = clamped_y - static_cast<float>(y0);

  const auto pixel = [&](int px, int py) -> float {
    const std::size_t index =
        (static_cast<std::size_t>(py) * static_cast<std::size_t>(image.width) +
         static_cast<std::size_t>(px)) *
            kRgbChannels +
        static_cast<std::size_t>(channel);
    return static_cast<float>(image.rgb[index]) / 255.0f;
  };

  const float top_left = pixel(x0, y0);
  const float top_right = pixel(x1, y0);
  const float bottom_left = pixel(x0, y1);
  const float bottom_right = pixel(x1, y1);
  const float top = top_left + (top_right - top_left) * dx;
  const float bottom = bottom_left + (bottom_right - bottom_left) * dx;
  return top + (bottom - top) * dy;
}

}  // namespace

float clamp01(float value) {
  return std::max(0.0f, std::min(1.0f, value));
}

PreprocessResult letterbox_to_tensor(const ImageBuffer& image, int input_size) {
  PreprocessResult result;
  result.scale = std::min(
      static_cast<float>(input_size) / static_cast<float>(image.width),
      static_cast<float>(input_size) / static_cast<float>(image.height));
  result.resized_width =
      std::max(1, static_cast<int>(std::round(image.width * result.scale)));
  result.resized_height =
      std::max(1, static_cast<int>(std::round(image.height * result.scale)));
  result.pad_x =
      (static_cast<float>(input_size) - static_cast<float>(result.resized_width)) *
      0.5f;
  result.pad_y =
      (static_cast<float>(input_size) - static_cast<float>(result.resized_height)) *
      0.5f;

  result.tensor.assign(
      static_cast<std::size_t>(input_size) * static_cast<std::size_t>(input_size) *
          kRgbChannels,
      kLetterboxPadValue);

  for (int y = 0; y < result.resized_height; ++y) {
    const float source_y =
        (static_cast<float>(y) + 0.5f) / result.scale - 0.5f;
    const int dest_y = static_cast<int>(std::floor(result.pad_y)) + y;
    if (dest_y < 0 || dest_y >= input_size) {
      continue;
    }
    for (int x = 0; x < result.resized_width; ++x) {
      const float source_x =
          (static_cast<float>(x) + 0.5f) / result.scale - 0.5f;
      const int dest_x = static_cast<int>(std::floor(result.pad_x)) + x;
      if (dest_x < 0 || dest_x >= input_size) {
        continue;
      }
      const std::size_t pixel_index =
          static_cast<std::size_t>(dest_y) * static_cast<std::size_t>(input_size) +
          static_cast<std::size_t>(dest_x);
      const std::size_t plane_size =
          static_cast<std::size_t>(input_size) * static_cast<std::size_t>(input_size);
      for (int channel = 0; channel < kRgbChannels; ++channel) {
        result.tensor[static_cast<std::size_t>(channel) * plane_size + pixel_index] =
            sample_channel(image, channel, source_x, source_y);
      }
    }
  }
  return result;
}

BoxCandidate convert_box(
    float cx,
    float cy,
    float width,
    float height,
    float confidence,
    int class_id,
    const PreprocessResult& preprocess,
    int original_width,
    int original_height) {
  const float x1 = cx - width * 0.5f;
  const float y1 = cy - height * 0.5f;
  const float x2 = cx + width * 0.5f;
  const float y2 = cy + height * 0.5f;

  const float unclipped_left = (x1 - preprocess.pad_x) / preprocess.scale;
  const float unclipped_top = (y1 - preprocess.pad_y) / preprocess.scale;
  const float unclipped_right = (x2 - preprocess.pad_x) / preprocess.scale;
  const float unclipped_bottom = (y2 - preprocess.pad_y) / preprocess.scale;

  const float left = std::max(
      0.0f,
      std::min(unclipped_left, static_cast<float>(original_width)));
  const float top = std::max(
      0.0f,
      std::min(unclipped_top, static_cast<float>(original_height)));
  const float right = std::max(
      0.0f,
      std::min(unclipped_right, static_cast<float>(original_width)));
  const float bottom = std::max(
      0.0f,
      std::min(unclipped_bottom, static_cast<float>(original_height)));

  BoxCandidate candidate;
  candidate.class_id = class_id;
  candidate.confidence = confidence;
  candidate.left = left / static_cast<float>(original_width);
  candidate.top = top / static_cast<float>(original_height);
  candidate.width =
      std::max(0.0f, right - left) / static_cast<float>(original_width);
  candidate.height =
      std::max(0.0f, bottom - top) / static_cast<float>(original_height);
  return candidate;
}

}  // namespace flutter_label::yolo
