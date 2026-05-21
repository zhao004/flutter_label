#pragma once

#include <string>
#include <string_view>

namespace flutter_label::native {

/// 判断 C 字符串是否为空，统一处理 FFI 入口常见的 nullptr 与空值。
bool is_blank(const char* value);

/// 复制为 malloc 分配的 C 字符串，由公开 ABI 的 free_string 负责释放。
char* duplicate_c_string(std::string_view value);

/// 转义 JSON 字符串字段，避免窗口标题和类别名破坏返回结构。
std::string json_escape(std::string_view value);

}  // namespace flutter_label::native
