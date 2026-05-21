#include "native_core.h"

#include <cstdlib>

#include "video/ffmpeg_extractor.h"
#include "window/window_capture.h"
#include "yolo/yolo_detector.h"

extern "C" {

EXPORT_API int init_model(
    const char* model_path,
    int imgsz) {
  if (model_path == nullptr || imgsz <= 0) {
    return -1;
  }
  return yolo_init_model_impl(model_path, imgsz);
}

EXPORT_API char* detect_image(
    const char* image_path,
    float conf_threshold,
    float iou_threshold) {
  if (image_path == nullptr || conf_threshold < 0.0f || iou_threshold < 0.0f) {
    return nullptr;
  }
  return yolo_detect_image_with_class_count_impl(
      image_path,
      conf_threshold,
      iou_threshold,
      0);
}

EXPORT_API char* detect_image_with_class_count(
    const char* image_path,
    float conf_threshold,
    float iou_threshold,
    int class_count) {
  if (image_path == nullptr || conf_threshold < 0.0f || iou_threshold < 0.0f) {
    return nullptr;
  }
  if (class_count < 0) {
    return nullptr;
  }
  return yolo_detect_image_with_class_count_impl(
      image_path,
      conf_threshold,
      iou_threshold,
      class_count);
}

EXPORT_API char* detect_bgra_frame_with_class_count(
    const unsigned char* bgra,
    int frame_width,
    int frame_height,
    int frame_stride,
    float conf_threshold,
    float iou_threshold,
    int class_count) {
  if (bgra == nullptr || frame_width <= 0 || frame_height <= 0 ||
      frame_stride < frame_width * 4 || conf_threshold < 0.0f ||
      iou_threshold < 0.0f || class_count < 0) {
    return nullptr;
  }
  return yolo_detect_bgra_frame_with_class_count_impl(
      bgra,
      frame_width,
      frame_height,
      frame_stride,
      conf_threshold,
      iou_threshold,
      class_count);
}

EXPORT_API int detect_folder(
    const char* image_dir,
    const char* label_dir,
    float conf_threshold,
    float iou_threshold) {
  return detect_folder_with_class_count(
      image_dir,
      label_dir,
      conf_threshold,
      iou_threshold,
      0);
}

EXPORT_API int detect_folder_with_class_count(
    const char* image_dir,
    const char* label_dir,
    float conf_threshold,
    float iou_threshold,
    int class_count) {
  if (image_dir == nullptr || label_dir == nullptr ||
      conf_threshold < 0.0f || iou_threshold < 0.0f || class_count < 0) {
    return -1;
  }
  return yolo_detect_folder_impl(
      image_dir,
      label_dir,
      conf_threshold,
      iou_threshold,
      class_count);
}

EXPORT_API int extract_frames_by_fps(
    const char* video_path,
    const char* output_dir,
    double fps) {
  return extract_frames_by_fps_impl(video_path, output_dir, fps);
}

EXPORT_API int extract_frames_by_fps_with_options(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    double fps) {
  return extract_frames_by_fps_with_options_impl(
      video_path,
      output_dir,
      output_prefix,
      overwrite_existing,
      fps);
}

EXPORT_API int extract_frames_by_interval(
    const char* video_path,
    const char* output_dir,
    int frame_interval) {
  return extract_frames_by_interval_impl(video_path, output_dir, frame_interval);
}

EXPORT_API int extract_frames_by_interval_with_options(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    int frame_interval) {
  return extract_frames_by_interval_with_options_impl(
      video_path,
      output_dir,
      output_prefix,
      overwrite_existing,
      frame_interval);
}

EXPORT_API void cancel_video_extract() {
  cancel_video_extract_impl();
}

EXPORT_API void free_string(char* ptr) {
  std::free(ptr);
}

EXPORT_API void release_model() {
  yolo_release_model_impl();
}

EXPORT_API int get_last_error_code() {
  return yolo_get_last_error_code_impl();
}

EXPORT_API int get_model_input_size() {
  return yolo_get_model_input_size_impl();
}

EXPORT_API char* get_model_provider() {
  return yolo_get_model_provider_impl();
}

EXPORT_API char* get_window_under_cursor() {
  return window_get_under_cursor_impl();
}

EXPORT_API CapturedWindowFrame* capture_window_frame(uint64_t window_handle) {
  if (window_handle == 0) {
    return nullptr;
  }
  return window_capture_frame_impl(window_handle);
}

EXPORT_API int flash_window_border(uint64_t window_handle) {
  if (window_handle == 0) {
    return 0;
  }
  return window_flash_border_impl(window_handle);
}

EXPORT_API int restore_window_border(uint64_t window_handle) {
  if (window_handle == 0) {
    return 0;
  }
  return window_restore_border_impl(window_handle);
}

EXPORT_API void free_window_frame(CapturedWindowFrame* frame) {
  window_free_frame_impl(frame);
}

}
