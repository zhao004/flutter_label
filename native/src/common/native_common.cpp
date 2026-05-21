#include "common/native_common.h"

#include <cstdlib>
#include <cstring>
#include <sstream>

namespace flutter_label::native {

bool is_blank(const char* value) {
  return value == nullptr || std::string_view(value).empty();
}

char* duplicate_c_string(std::string_view value) {
  char* result = static_cast<char*>(std::malloc(value.size() + 1));
  if (result == nullptr) {
    return nullptr;
  }
  if (!value.empty()) {
    std::memcpy(result, value.data(), value.size());
  }
  result[value.size()] = '\0';
  return result;
}

std::string json_escape(std::string_view value) {
  std::ostringstream escaped;
  for (const unsigned char ch : value) {
    switch (ch) {
      case '"':
        escaped << "\\\"";
        break;
      case '\\':
        escaped << "\\\\";
        break;
      case '\b':
        escaped << "\\b";
        break;
      case '\f':
        escaped << "\\f";
        break;
      case '\n':
        escaped << "\\n";
        break;
      case '\r':
        escaped << "\\r";
        break;
      case '\t':
        escaped << "\\t";
        break;
      default:
        if (ch < 0x20) {
          constexpr char kHexDigits[] = "0123456789abcdef";
          escaped << "\\u00" << kHexDigits[(ch >> 4) & 0x0F]
                  << kHexDigits[ch & 0x0F];
        } else {
          escaped << static_cast<char>(ch);
        }
        break;
    }
  }
  return escaped.str();
}

}  // namespace flutter_label::native
