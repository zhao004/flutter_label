#include "yolo/yolo_metadata.h"

#include <cctype>
#include <cstdint>
#include <limits>
#include <unordered_map>
#include <utility>

namespace flutter_label::yolo {
namespace {

void skip_whitespace(std::string_view value, std::size_t* index) {
  if (index == nullptr) {
    return;
  }
  while (*index < value.size() &&
         std::isspace(static_cast<unsigned char>(value[*index]))) {
    ++(*index);
  }
}

bool parse_nonnegative_int(std::string_view value, int* output) {
  if (output == nullptr) {
    return false;
  }
  const std::string trimmed = trim_copy(value);
  if (trimmed.empty()) {
    return false;
  }
  int result = 0;
  for (const unsigned char ch : trimmed) {
    if (!std::isdigit(ch)) {
      return false;
    }
    const int digit = static_cast<int>(ch - '0');
    if (result > (std::numeric_limits<int>::max() - digit) / 10) {
      return false;
    }
    result = result * 10 + digit;
  }
  *output = result;
  return true;
}

int hex_value(char ch) {
  if (ch >= '0' && ch <= '9') {
    return ch - '0';
  }
  if (ch >= 'a' && ch <= 'f') {
    return ch - 'a' + 10;
  }
  if (ch >= 'A' && ch <= 'F') {
    return ch - 'A' + 10;
  }
  return -1;
}

bool read_hex4(std::string_view value, std::size_t* index, uint32_t* output) {
  if (index == nullptr || output == nullptr || *index + 4 > value.size()) {
    return false;
  }
  uint32_t result = 0;
  for (int i = 0; i < 4; ++i) {
    const int digit = hex_value(value[*index + static_cast<std::size_t>(i)]);
    if (digit < 0) {
      return false;
    }
    result = (result << 4) | static_cast<uint32_t>(digit);
  }
  *index += 4;
  *output = result;
  return true;
}

void append_utf8_codepoint(uint32_t codepoint, std::string* output) {
  if (output == nullptr) {
    return;
  }
  if (codepoint <= 0x7F) {
    output->push_back(static_cast<char>(codepoint));
    return;
  }
  if (codepoint <= 0x7FF) {
    output->push_back(static_cast<char>(0xC0 | (codepoint >> 6)));
    output->push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
    return;
  }
  if (codepoint <= 0xFFFF) {
    output->push_back(static_cast<char>(0xE0 | (codepoint >> 12)));
    output->push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
    output->push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
    return;
  }
  if (codepoint <= 0x10FFFF) {
    output->push_back(static_cast<char>(0xF0 | (codepoint >> 18)));
    output->push_back(static_cast<char>(0x80 | ((codepoint >> 12) & 0x3F)));
    output->push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F)));
    output->push_back(static_cast<char>(0x80 | (codepoint & 0x3F)));
  }
}

bool parse_quoted_string(
    std::string_view value,
    std::size_t* index,
    std::string* output) {
  if (index == nullptr || output == nullptr) {
    return false;
  }
  skip_whitespace(value, index);
  if (*index >= value.size() ||
      (value[*index] != '\'' && value[*index] != '"')) {
    return false;
  }
  const char quote = value[*index];
  ++(*index);
  output->clear();
  while (*index < value.size()) {
    const unsigned char ch = static_cast<unsigned char>(value[*index]);
    ++(*index);
    if (ch == static_cast<unsigned char>(quote)) {
      return true;
    }
    if (ch != '\\') {
      output->push_back(static_cast<char>(ch));
      continue;
    }
    if (*index >= value.size()) {
      return false;
    }
    const char escaped = value[*index];
    ++(*index);
    switch (escaped) {
      case '"':
      case '\'':
      case '\\':
      case '/':
        output->push_back(escaped);
        break;
      case 'b':
        output->push_back('\b');
        break;
      case 'f':
        output->push_back('\f');
        break;
      case 'n':
        output->push_back('\n');
        break;
      case 'r':
        output->push_back('\r');
        break;
      case 't':
        output->push_back('\t');
        break;
      case 'u': {
        uint32_t codepoint = 0;
        if (!read_hex4(value, index, &codepoint)) {
          return false;
        }
        append_utf8_codepoint(codepoint, output);
        break;
      }
      default:
        return false;
    }
  }
  return false;
}

bool parse_unquoted_token(
    std::string_view value,
    std::size_t* index,
    std::string* output) {
  if (index == nullptr || output == nullptr) {
    return false;
  }
  skip_whitespace(value, index);
  const std::size_t start = *index;
  while (*index < value.size() && value[*index] != ',' && value[*index] != '}' &&
         value[*index] != ']') {
    ++(*index);
  }
  *output = trim_copy(value.substr(start, *index - start));
  return !output->empty();
}

bool parse_metadata_name_value(
    std::string_view value,
    std::size_t* index,
    std::string* output) {
  if (index == nullptr || output == nullptr) {
    return false;
  }
  skip_whitespace(value, index);
  if (*index < value.size() &&
      (value[*index] == '\'' || value[*index] == '"')) {
    return parse_quoted_string(value, index, output) &&
           !trim_copy(*output).empty();
  }
  return parse_unquoted_token(value, index, output);
}

bool validate_contiguous_names(
    const std::unordered_map<int, std::string>& names_by_id,
    std::vector<std::string>* output) {
  if (output == nullptr || names_by_id.empty()) {
    return false;
  }
  std::vector<std::string> names;
  names.reserve(names_by_id.size());
  for (std::size_t index = 0; index < names_by_id.size(); ++index) {
    const auto match = names_by_id.find(static_cast<int>(index));
    if (match == names_by_id.end()) {
      return false;
    }
    const std::string name = trim_copy(match->second);
    if (name.empty()) {
      return false;
    }
    names.push_back(name);
  }
  *output = std::move(names);
  return true;
}

bool parse_map_metadata_names(
    std::string_view value,
    std::vector<std::string>* output) {
  if (output == nullptr) {
    return false;
  }
  std::size_t index = 0;
  skip_whitespace(value, &index);
  if (index >= value.size() || value[index] != '{') {
    return false;
  }
  ++index;
  std::unordered_map<int, std::string> names_by_id;
  while (true) {
    skip_whitespace(value, &index);
    if (index >= value.size()) {
      return false;
    }
    if (value[index] == '}') {
      ++index;
      break;
    }

    int class_id = -1;
    if (value[index] == '\'' || value[index] == '"') {
      std::string key;
      if (!parse_quoted_string(value, &index, &key) ||
          !parse_nonnegative_int(key, &class_id)) {
        return false;
      }
    } else {
      const std::size_t key_start = index;
      while (index < value.size() && value[index] != ':') {
        ++index;
      }
      if (index >= value.size() ||
          !parse_nonnegative_int(
              value.substr(key_start, index - key_start),
              &class_id)) {
        return false;
      }
    }

    skip_whitespace(value, &index);
    if (index >= value.size() || value[index] != ':') {
      return false;
    }
    ++index;
    std::string class_name;
    if (!parse_metadata_name_value(value, &index, &class_name)) {
      return false;
    }
    if (!names_by_id.emplace(class_id, class_name).second) {
      return false;
    }

    skip_whitespace(value, &index);
    if (index < value.size() && value[index] == ',') {
      ++index;
      continue;
    }
    if (index < value.size() && value[index] == '}') {
      ++index;
      break;
    }
    return false;
  }
  skip_whitespace(value, &index);
  if (index != value.size()) {
    return false;
  }
  return validate_contiguous_names(names_by_id, output);
}

bool parse_array_metadata_names(
    std::string_view value,
    std::vector<std::string>* output) {
  if (output == nullptr) {
    return false;
  }
  std::size_t index = 0;
  skip_whitespace(value, &index);
  if (index >= value.size() || value[index] != '[') {
    return false;
  }
  ++index;
  std::vector<std::string> names;
  while (true) {
    skip_whitespace(value, &index);
    if (index >= value.size()) {
      return false;
    }
    if (value[index] == ']') {
      ++index;
      break;
    }
    std::string class_name;
    if (!parse_metadata_name_value(value, &index, &class_name)) {
      return false;
    }
    class_name = trim_copy(class_name);
    if (class_name.empty()) {
      return false;
    }
    names.push_back(class_name);
    skip_whitespace(value, &index);
    if (index < value.size() && value[index] == ',') {
      ++index;
      continue;
    }
    if (index < value.size() && value[index] == ']') {
      ++index;
      break;
    }
    return false;
  }
  skip_whitespace(value, &index);
  if (index != value.size() || names.empty()) {
    return false;
  }
  *output = std::move(names);
  return true;
}

}  // namespace

std::string trim_copy(std::string_view value) {
  std::size_t start = 0;
  while (start < value.size() &&
         std::isspace(static_cast<unsigned char>(value[start]))) {
    ++start;
  }
  std::size_t end = value.size();
  while (end > start &&
         std::isspace(static_cast<unsigned char>(value[end - 1]))) {
    --end;
  }
  return std::string(value.substr(start, end - start));
}

bool parse_model_class_names(
    std::string_view metadata_names,
    std::vector<std::string>* output) {
  if (output == nullptr) {
    return false;
  }
  const std::string value = trim_copy(metadata_names);
  if (value.empty()) {
    return false;
  }
  if (value.front() == '{') {
    return parse_map_metadata_names(value, output);
  }
  if (value.front() == '[') {
    return parse_array_metadata_names(value, output);
  }
  return false;
}

std::string class_name_for_id(
    int class_id,
    const std::vector<std::string>& class_names) {
  if (class_id >= 0 &&
      static_cast<std::size_t>(class_id) < class_names.size()) {
    const std::string name =
        trim_copy(class_names[static_cast<std::size_t>(class_id)]);
    if (!name.empty()) {
      return name;
    }
  }
  return std::to_string(class_id);
}

}  // namespace flutter_label::yolo
