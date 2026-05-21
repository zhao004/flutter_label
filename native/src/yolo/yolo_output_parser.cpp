#include "yolo/yolo_output_parser.h"

#include <algorithm>

#include "yolo/yolo_preprocess.h"

namespace flutter_label::yolo {
namespace {

float iou(const BoxCandidate& left, const BoxCandidate& right) {
  const float left_x1 = left.left;
  const float left_y1 = left.top;
  const float left_x2 = left.left + left.width;
  const float left_y2 = left.top + left.height;
  const float right_x1 = right.left;
  const float right_y1 = right.top;
  const float right_x2 = right.left + right.width;
  const float right_y2 = right.top + right.height;

  const float intersection_left = std::max(left_x1, right_x1);
  const float intersection_top = std::max(left_y1, right_y1);
  const float intersection_right = std::min(left_x2, right_x2);
  const float intersection_bottom = std::min(left_y2, right_y2);
  const float intersection_width =
      std::max(0.0f, intersection_right - intersection_left);
  const float intersection_height =
      std::max(0.0f, intersection_bottom - intersection_top);
  const float intersection_area = intersection_width * intersection_height;
  const float left_area =
      std::max(0.0f, left.width) * std::max(0.0f, left.height);
  const float right_area =
      std::max(0.0f, right.width) * std::max(0.0f, right.height);
  const float union_area = left_area + right_area - intersection_area;
  if (union_area <= 0.0f) {
    return 0.0f;
  }
  return intersection_area / union_area;
}

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
void append_candidates_from_row(
    const float* row,
    std::size_t cols,
    bool allow_objectness,
    const PreprocessResult& preprocess,
    int original_width,
    int original_height,
    int class_count,
    std::vector<BoxCandidate>* candidates) {
  if (row == nullptr || cols < 5 || candidates == nullptr) {
    return;
  }

  const float cx = row[0];
  const float cy = row[1];
  const float width = row[2];
  const float height = row[3];

  float confidence = 0.0f;
  int class_id = 0;
  const bool has_known_class_count = class_count > 0;
  const std::size_t known_class_count =
      has_known_class_count ? static_cast<std::size_t>(class_count) : 0;
  const bool has_objectness =
      allow_objectness && has_known_class_count &&
      cols == static_cast<std::size_t>(5 + class_count);
  if (has_objectness) {
    const float objectness = row[4];
    std::size_t best_index = 5;
    float best_class_score = row[5];
    const std::size_t score_end = std::min(cols, 5 + known_class_count);
    for (std::size_t index = 6; index < score_end; ++index) {
      if (row[index] > best_class_score) {
        best_class_score = row[index];
        best_index = index;
      }
    }
    confidence = objectness * best_class_score;
    class_id = static_cast<int>(best_index - 5);
  } else {
    std::size_t best_index = 4;
    float best_class_score = row[4];
    const std::size_t score_end =
        has_known_class_count ? std::min(cols, 4 + known_class_count) : cols;
    for (std::size_t index = 5; index < score_end; ++index) {
      if (row[index] > best_class_score) {
        best_class_score = row[index];
        best_index = index;
      }
    }
    confidence = best_class_score;
    class_id = static_cast<int>(best_index - 4);
  }

  if (confidence <= kMinConfidence || width <= 0.0f || height <= 0.0f) {
    return;
  }
  if (class_count > 0 && class_id >= class_count) {
    return;
  }

  BoxCandidate candidate = convert_box(
      cx,
      cy,
      width,
      height,
      confidence,
      class_id,
      preprocess,
      original_width,
      original_height);
  if (candidate.width <= 0.0f || candidate.height <= 0.0f) {
    return;
  }
  candidates->push_back(candidate);
}

void parse_2d_output(
    const float* data,
    std::size_t rows,
    std::size_t cols,
    const PreprocessResult& preprocess,
    int original_width,
    int original_height,
    int class_count,
    std::vector<BoxCandidate>* candidates) {
  if (rows == 0 || cols < 5 || candidates == nullptr) {
    return;
  }
  for (std::size_t row = 0; row < rows; ++row) {
    const float* row_ptr = data + row * cols;
    append_candidates_from_row(
        row_ptr,
        cols,
        false,
        preprocess,
        original_width,
        original_height,
        class_count,
        candidates);
  }
}

void parse_transposed_output(
    const float* data,
    std::size_t attrs,
    std::size_t count,
    bool transposed,
    const PreprocessResult& preprocess,
    int original_width,
    int original_height,
    int class_count,
    std::vector<BoxCandidate>* candidates) {
  if (attrs < 5 || count == 0 || candidates == nullptr) {
    return;
  }
  for (std::size_t index = 0; index < count; ++index) {
    std::vector<float> row(attrs, 0.0f);
    if (transposed) {
      for (std::size_t attr = 0; attr < attrs; ++attr) {
        row[attr] = data[attr * count + index];
      }
    } else {
      const float* row_ptr = data + index * attrs;
      std::copy(row_ptr, row_ptr + attrs, row.begin());
    }
    append_candidates_from_row(
        row.data(),
        attrs,
        true,
        preprocess,
        original_width,
        original_height,
        class_count,
        candidates);
  }
}
#endif

}  // namespace

std::vector<BoxCandidate> nms_by_class(
    std::vector<BoxCandidate> candidates,
    float iou_threshold) {
  std::sort(
      candidates.begin(),
      candidates.end(),
      [](const BoxCandidate& left, const BoxCandidate& right) {
        if (left.class_id != right.class_id) {
          return left.class_id < right.class_id;
        }
        return left.confidence > right.confidence;
      });

  std::vector<BoxCandidate> result;
  std::size_t index = 0;
  while (index < candidates.size()) {
    const int class_id = candidates[index].class_id;
    std::vector<BoxCandidate> class_boxes;
    while (index < candidates.size() && candidates[index].class_id == class_id) {
      class_boxes.push_back(candidates[index]);
      ++index;
    }

    std::sort(
        class_boxes.begin(),
        class_boxes.end(),
        [](const BoxCandidate& left, const BoxCandidate& right) {
          return left.confidence > right.confidence;
        });

    std::vector<bool> suppressed(class_boxes.size(), false);
    for (std::size_t i = 0; i < class_boxes.size(); ++i) {
      if (suppressed[i]) {
        continue;
      }
      result.push_back(class_boxes[i]);
      for (std::size_t j = i + 1; j < class_boxes.size(); ++j) {
        if (!suppressed[j] && iou(class_boxes[i], class_boxes[j]) > iou_threshold) {
          suppressed[j] = true;
        }
      }
    }
  }

  return result;
}

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
std::vector<BoxCandidate> parse_onnx_outputs(
    const std::vector<Ort::Value>& outputs,
    const PreprocessResult& preprocess,
    int original_width,
    int original_height,
    int class_count,
    bool* has_supported_output_layout) {
  std::vector<BoxCandidate> candidates;
  if (has_supported_output_layout != nullptr) {
    *has_supported_output_layout = false;
  }
  for (const auto& output : outputs) {
    if (!output.IsTensor()) {
      continue;
    }
    auto type_info = output.GetTensorTypeAndShapeInfo();
    const auto shape = type_info.GetShape();
    if (shape.empty()) {
      continue;
    }
    const float* data = output.GetTensorData<float>();
    if (data == nullptr) {
      continue;
    }
    const std::size_t element_count = type_info.GetElementCount();
    if (element_count == 0) {
      continue;
    }

    if (shape.size() == 3) {
      const std::size_t dim1 =
          static_cast<std::size_t>(shape[1] < 0 ? 0 : shape[1]);
      const std::size_t dim2 =
          static_cast<std::size_t>(shape[2] < 0 ? 0 : shape[2]);
      if (dim1 >= 5 && dim2 >= 1 && dim1 <= 512 && dim2 > dim1) {
        if (has_supported_output_layout != nullptr) {
          *has_supported_output_layout = true;
        }
        parse_transposed_output(
            data,
            dim1,
            dim2,
            true,
            preprocess,
            original_width,
            original_height,
            class_count,
            &candidates);
        continue;
      }
      if (dim2 >= 5) {
        if (has_supported_output_layout != nullptr) {
          *has_supported_output_layout = true;
        }
        parse_transposed_output(
            data,
            dim1,
            dim2,
            false,
            preprocess,
            original_width,
            original_height,
            class_count,
            &candidates);
        continue;
      }
    }

    if (shape.size() == 2 && shape[1] >= 5) {
      if (has_supported_output_layout != nullptr) {
        *has_supported_output_layout = true;
      }
      parse_2d_output(
          data,
          static_cast<std::size_t>(shape[0]),
          static_cast<std::size_t>(shape[1]),
          preprocess,
          original_width,
          original_height,
          class_count,
          &candidates);
    }
  }
  return candidates;
}
#endif

}  // namespace flutter_label::yolo
