#pragma once

#include <vector>

#include "yolo/yolo_types.h"

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
#include <onnxruntime_cxx_api.h>
#endif

namespace flutter_label::yolo {

std::vector<BoxCandidate> nms_by_class(
    std::vector<BoxCandidate> candidates,
    float iou_threshold);

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
std::vector<BoxCandidate> parse_onnx_outputs(
    const std::vector<Ort::Value>& outputs,
    const PreprocessResult& preprocess,
    int original_width,
    int original_height,
    int class_count,
    bool* has_supported_output_layout);
#endif

}  // namespace flutter_label::yolo
