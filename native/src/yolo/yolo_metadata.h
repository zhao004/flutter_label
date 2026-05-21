#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace flutter_label::yolo {

std::string trim_copy(std::string_view value);

bool parse_model_class_names(
    std::string_view metadata_names,
    std::vector<std::string>* output);

std::string class_name_for_id(
    int class_id,
    const std::vector<std::string>& class_names);

}  // namespace flutter_label::yolo
