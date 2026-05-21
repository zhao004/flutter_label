#include "window/window_capture.h"

#include "common/native_common.h"

#include <cstdlib>
#include <cstring>
#include <sstream>
#include <string>

#ifdef _WIN32
#include <chrono>
#include <mutex>
#include <unordered_map>
#include <windows.h>
#include <dwmapi.h>
#endif

namespace {

using flutter_label::native::duplicate_c_string;
using flutter_label::native::json_escape;

#ifdef _WIN32
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_COLOR_DEFAULT
#define DWMWA_COLOR_DEFAULT 0xFFFFFFFF
#endif

constexpr COLORREF kWindowHighlightBorderColor = RGB(255, 0, 0);
constexpr COLORREF kWindowDefaultBorderColor =
    static_cast<COLORREF>(DWMWA_COLOR_DEFAULT);
constexpr DWORD kWindowBorderFlashPauseMs = 140;
constexpr UINT kPrintWindowRenderFullContent = 0x00000002;

std::mutex g_border_color_mutex;
std::unordered_map<std::uintptr_t, COLORREF> g_original_border_colors;

std::string wide_to_utf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int size = WideCharToMultiByte(
      CP_UTF8,
      0,
      value.c_str(),
      static_cast<int>(value.size()),
      nullptr,
      0,
      nullptr,
      nullptr);
  if (size <= 0) {
    return "";
  }
  std::string result(static_cast<std::size_t>(size), '\0');
  WideCharToMultiByte(
      CP_UTF8,
      0,
      value.c_str(),
      static_cast<int>(value.size()),
      result.data(),
      size,
      nullptr,
      nullptr);
  return result;
}

std::string window_title(HWND hwnd) {
  const int length = GetWindowTextLengthW(hwnd);
  if (length <= 0) {
    return "";
  }
  std::wstring title(static_cast<std::size_t>(length + 1), L'\0');
  const int copied = GetWindowTextW(hwnd, title.data(), length + 1);
  if (copied <= 0) {
    return "";
  }
  title.resize(static_cast<std::size_t>(copied));
  return wide_to_utf8(title);
}

HWND root_window_from_point(const POINT& point) {
  HWND hwnd = WindowFromPoint(point);
  if (hwnd == nullptr) {
    return nullptr;
  }
  HWND root = GetAncestor(hwnd, GA_ROOT);
  return root == nullptr ? hwnd : root;
}

bool try_get_visible_window_rect(HWND hwnd, RECT* rect) {
  if (hwnd == nullptr || !IsWindow(hwnd) || !IsWindowVisible(hwnd)) {
    return false;
  }
  if (IsIconic(hwnd)) {
    return false;
  }
  RECT window_rect{};
  if (!GetWindowRect(hwnd, &window_rect)) {
    return false;
  }
  const int width = window_rect.right - window_rect.left;
  const int height = window_rect.bottom - window_rect.top;
  if (width <= 0 || height <= 0) {
    return false;
  }
  if (rect != nullptr) {
    *rect = window_rect;
  }
  return true;
}

bool is_selectable_window(HWND hwnd, RECT* rect, std::string* title) {
  RECT window_rect{};
  if (!try_get_visible_window_rect(hwnd, &window_rect)) {
    return false;
  }
  const std::string current_title = window_title(hwnd);
  if (current_title.empty()) {
    return false;
  }
  if (rect != nullptr) {
    *rect = window_rect;
  }
  if (title != nullptr) {
    *title = current_title;
  }
  return true;
}

COLORREF current_border_color_or_default(HWND hwnd) {
  COLORREF color = kWindowDefaultBorderColor;
  DwmGetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &color, sizeof(color));
  return color;
}

bool set_window_border_color(HWND hwnd, COLORREF color) {
  const HRESULT result = DwmSetWindowAttribute(
      hwnd,
      DWMWA_BORDER_COLOR,
      &color,
      sizeof(color));
  return SUCCEEDED(result);
}

std::uintptr_t window_key(HWND hwnd) {
  return reinterpret_cast<std::uintptr_t>(hwnd);
}

void remember_original_border_color(HWND hwnd, COLORREF color) {
  std::lock_guard<std::mutex> lock(g_border_color_mutex);
  g_original_border_colors.try_emplace(window_key(hwnd), color);
}

COLORREF take_original_border_color(HWND hwnd) {
  std::lock_guard<std::mutex> lock(g_border_color_mutex);
  const auto key = window_key(hwnd);
  const auto found = g_original_border_colors.find(key);
  if (found == g_original_border_colors.end()) {
    return kWindowDefaultBorderColor;
  }
  const COLORREF color = found->second;
  g_original_border_colors.erase(found);
  return color;
}

CapturedWindowFrame* allocate_frame(
    int width,
    int height,
    double capture_ms,
    const void* bgra) {
  if (width <= 0 || height <= 0 || bgra == nullptr) {
    return nullptr;
  }
  constexpr int kBytesPerPixel = 4;
  const int stride = width * kBytesPerPixel;
  const std::size_t byte_count =
      static_cast<std::size_t>(stride) * static_cast<std::size_t>(height);
  auto* frame =
      static_cast<CapturedWindowFrame*>(std::malloc(sizeof(CapturedWindowFrame)));
  if (frame == nullptr) {
    return nullptr;
  }
  frame->bgra = static_cast<unsigned char*>(std::malloc(byte_count));
  if (frame->bgra == nullptr) {
    std::free(frame);
    return nullptr;
  }
  frame->width = width;
  frame->height = height;
  frame->stride = stride;
  frame->capture_ms = capture_ms;
  std::memcpy(frame->bgra, bgra, byte_count);
  return frame;
}
#endif

}  // namespace

char* window_get_under_cursor_impl() {
#ifdef _WIN32
  POINT point{};
  if (!GetCursorPos(&point)) {
    return duplicate_c_string("{}");
  }
  HWND hwnd = root_window_from_point(point);
  RECT rect{};
  std::string title;
  if (!is_selectable_window(hwnd, &rect, &title)) {
    return duplicate_c_string("{}");
  }
  std::ostringstream json;
  json << "{\"handle\":" << reinterpret_cast<std::uintptr_t>(hwnd)
       << ",\"title\":\"" << json_escape(title) << "\""
       << ",\"left\":" << rect.left
       << ",\"top\":" << rect.top
       << ",\"width\":" << (rect.right - rect.left)
       << ",\"height\":" << (rect.bottom - rect.top)
       << '}';
  return duplicate_c_string(json.str());
#else
  return duplicate_c_string("{}");
#endif
}

CapturedWindowFrame* window_capture_frame_impl(uint64_t window_handle) {
#ifdef _WIN32
  HWND hwnd = reinterpret_cast<HWND>(static_cast<std::uintptr_t>(window_handle));
  RECT rect{};
  std::string title;
  if (!is_selectable_window(hwnd, &rect, &title)) {
    return nullptr;
  }
  const int width = rect.right - rect.left;
  const int height = rect.bottom - rect.top;

  HDC window_dc = GetWindowDC(hwnd);
  if (window_dc == nullptr) {
    return nullptr;
  }
  HDC memory_dc = CreateCompatibleDC(window_dc);
  if (memory_dc == nullptr) {
    ReleaseDC(hwnd, window_dc);
    return nullptr;
  }

  BITMAPINFO bitmap_info{};
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = width;
  bitmap_info.bmiHeader.biHeight = -height;
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  HBITMAP bitmap = CreateDIBSection(
      memory_dc,
      &bitmap_info,
      DIB_RGB_COLORS,
      &bits,
      nullptr,
      0);
  if (bitmap == nullptr || bits == nullptr) {
    DeleteDC(memory_dc);
    ReleaseDC(hwnd, window_dc);
    return nullptr;
  }
  HGDIOBJ previous = SelectObject(memory_dc, bitmap);

  const auto start = std::chrono::steady_clock::now();
  BOOL captured = PrintWindow(hwnd, memory_dc, kPrintWindowRenderFullContent);
  if (!captured) {
    captured = BitBlt(
        memory_dc,
        0,
        0,
        width,
        height,
        window_dc,
        0,
        0,
        SRCCOPY | CAPTUREBLT);
  }
  const auto end = std::chrono::steady_clock::now();
  const double capture_ms =
      std::chrono::duration<double, std::milli>(end - start).count();

  CapturedWindowFrame* frame =
      captured ? allocate_frame(width, height, capture_ms, bits) : nullptr;
  SelectObject(memory_dc, previous);
  DeleteObject(bitmap);
  DeleteDC(memory_dc);
  ReleaseDC(hwnd, window_dc);
  return frame;
#else
  (void)window_handle;
  return nullptr;
#endif
}

int window_flash_border_impl(uint64_t window_handle) {
#ifdef _WIN32
  HWND hwnd = reinterpret_cast<HWND>(static_cast<std::uintptr_t>(window_handle));
  if (!try_get_visible_window_rect(hwnd, nullptr)) {
    return 0;
  }

  const COLORREF original_color = current_border_color_or_default(hwnd);
  remember_original_border_color(hwnd, original_color);
  const COLORREF flash_off_color = original_color == kWindowHighlightBorderColor
      ? kWindowDefaultBorderColor
      : original_color;

  // 这里直接使用 DWM 边框色，避免创建额外置顶窗口影响目标应用的输入焦点。
  const bool first_highlight =
      set_window_border_color(hwnd, kWindowHighlightBorderColor);
  if (!first_highlight) {
    return 0;
  }
  Sleep(kWindowBorderFlashPauseMs);
  const bool restored_for_flash = set_window_border_color(hwnd, flash_off_color);
  Sleep(kWindowBorderFlashPauseMs);
  const bool final_highlight =
      set_window_border_color(hwnd, kWindowHighlightBorderColor);
  return restored_for_flash && final_highlight ? 1 : 0;
#else
  (void)window_handle;
  return 0;
#endif
}

int window_restore_border_impl(uint64_t window_handle) {
#ifdef _WIN32
  HWND hwnd = reinterpret_cast<HWND>(static_cast<std::uintptr_t>(window_handle));
  if (hwnd == nullptr || !IsWindow(hwnd)) {
    return 0;
  }

  const COLORREF original_color = take_original_border_color(hwnd);
  return set_window_border_color(hwnd, original_color) ? 1 : 0;
#else
  (void)window_handle;
  return 0;
#endif
}

void window_free_frame_impl(CapturedWindowFrame* frame) {
  if (frame == nullptr) {
    return;
  }
  std::free(frame->bgra);
  frame->bgra = nullptr;
  std::free(frame);
}
