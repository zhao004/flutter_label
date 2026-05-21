#pragma once

#include "yolo/yolo_types.h"

namespace flutter_label::yolo {

float clamp01(float value);

PreprocessResult letterbox_to_tensor(const ImageBuffer& image, int input_size);

BoxCandidate convert_box(
    float cx,
    float cy,
    float width,
    float height,
    float confidence,
    int class_id,
    const PreprocessResult& preprocess,
    int original_width,
    int original_height);

}  // namespace flutter_label::yolo
