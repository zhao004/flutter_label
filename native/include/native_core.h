#pragma once

#include <stdint.h>

#ifdef _WIN32
#define EXPORT_API __declspec(dllexport)
#else
#define EXPORT_API __attribute__((visibility("default")))
#endif

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

extern "C" {

// 初始化 YOLO ONNX 模型。当前 C++ 骨架未链接 ONNX Runtime 时返回负数。
EXPORT_API int init_model(
    const char* model_path,
    int imgsz);

// 单张图片检测，返回 JSON 字符串；当前骨架未链接 ONNX Runtime 时返回空指针。
EXPORT_API char* detect_image(
    const char* image_path,
    float conf_threshold,
    float iou_threshold);

// 单张图片检测，class_count 用于区分 YOLOv8/YOLOv5 输出布局。
EXPORT_API char* detect_image_with_class_count(
    const char* image_path,
    float conf_threshold,
    float iou_threshold,
    int class_count);

// BGRA 内存帧检测，frame_stride 为每行字节数，class_count 用于区分 YOLO 输出布局。
EXPORT_API char* detect_bgra_frame_with_class_count(
    const unsigned char* bgra,
    int frame_width,
    int frame_height,
    int frame_stride,
    float conf_threshold,
    float iou_threshold,
    int class_count);

// 批量图片检测并写出 YOLO 标签；当前骨架未链接 ONNX Runtime 时返回负数。
EXPORT_API int detect_folder(
    const char* image_dir,
    const char* label_dir,
    float conf_threshold,
    float iou_threshold);

// 批量图片检测并写出 YOLO 标签，class_count 用于区分 YOLOv8/YOLOv5 输出布局。
EXPORT_API int detect_folder_with_class_count(
    const char* image_dir,
    const char* label_dir,
    float conf_threshold,
    float iou_threshold,
    int class_count);

// 按每秒 N 张抽帧，返回 0 表示成功，负数表示参数或执行错误。
EXPORT_API int extract_frames_by_fps(
    const char* video_path,
    const char* output_dir,
    double fps);

// 按每秒 N 张抽帧并按时间戳命名，output_prefix 为空时使用 video 前缀。
EXPORT_API int extract_frames_by_fps_with_options(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    double fps);

// 每 N 帧抽一张，返回 0 表示成功，负数表示参数或执行错误。
EXPORT_API int extract_frames_by_interval(
    const char* video_path,
    const char* output_dir,
    int frame_interval);

// 每 N 帧抽一张并按时间戳命名，output_prefix 为空时使用 video 前缀。
EXPORT_API int extract_frames_by_interval_with_options(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    int frame_interval);

// 请求停止当前视频抽帧任务。该接口是协作式取消，FFmpeg 解码循环会在下一次检查时退出。
EXPORT_API void cancel_video_extract();

// 释放字符串。当前阶段预留给后续 JSON 返回接口使用。
EXPORT_API void free_string(char* ptr);

// 释放模型。当前骨架无状态，保留接口用于后续 ONNX Runtime 扩展。
EXPORT_API void release_model();

// 获取最近一次 YOLO ONNX 后端错误码，用于 Dart 侧展示精确失败原因。
EXPORT_API int get_last_error_code();

// 获取当前模型实际输入尺寸。固定输入模型会返回模型尺寸，动态输入模型返回用户 imgsz。
EXPORT_API int get_model_input_size();

// 获取当前模型推理 Provider，返回值需通过 free_string 释放。
EXPORT_API char* get_model_provider();

// 返回当前鼠标下方可选择窗口信息 JSON，失败时返回 `{}`。
EXPORT_API char* get_window_under_cursor();

// 捕获指定窗口当前画面，返回 BGRA 顶向下像素缓冲区。
EXPORT_API CapturedWindowFrame* capture_window_frame(uint64_t window_handle);

// 闪烁并保持指定窗口边框为红色，返回 1 表示成功，0 表示系统或窗口不支持。
EXPORT_API int flash_window_border(uint64_t window_handle);

// 恢复 flash_window_border 修改过的窗口边框颜色。
EXPORT_API int restore_window_border(uint64_t window_handle);

// 释放 capture_window_frame 返回的窗口帧。
EXPORT_API void free_window_frame(CapturedWindowFrame* frame);

}
