#pragma once

int yolo_init_model_impl(const char* model_path, int imgsz);

char* yolo_detect_image_with_class_count_impl(
    const char* image_path,
    float conf_threshold,
    float iou_threshold,
    int class_count);

char* yolo_detect_bgra_frame_with_class_count_impl(
    const unsigned char* bgra,
    int frame_width,
    int frame_height,
    int frame_stride,
    float conf_threshold,
    float iou_threshold,
    int class_count);

int yolo_detect_folder_impl(
    const char* image_dir,
    const char* label_dir,
    float conf_threshold,
    float iou_threshold,
    int class_count);

void yolo_release_model_impl();

int yolo_get_last_error_code_impl();

int yolo_get_model_input_size_impl();

char* yolo_get_model_provider_impl();
