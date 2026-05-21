#pragma once

#include <cstdint>

#ifndef FLUTTER_LABEL_CAPTURED_WINDOW_FRAME_DEFINED
#define FLUTTER_LABEL_CAPTURED_WINDOW_FRAME_DEFINED
typedef struct CapturedWindowFrame {
  int width;
  int height;
  int stride;
  double capture_ms;
  unsigned char* bgra;
} CapturedWindowFrame;
#endif

char* window_get_under_cursor_impl();

CapturedWindowFrame* window_capture_frame_impl(uint64_t window_handle);

int window_flash_border_impl(uint64_t window_handle);

int window_restore_border_impl(uint64_t window_handle);

void window_free_frame_impl(CapturedWindowFrame* frame);
