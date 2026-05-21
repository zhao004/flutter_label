#pragma once

int extract_frames_by_fps_impl(
    const char* video_path,
    const char* output_dir,
    double fps);

int extract_frames_by_fps_with_options_impl(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    double fps);

int extract_frames_by_interval_impl(
    const char* video_path,
    const char* output_dir,
    int frame_interval);

int extract_frames_by_interval_with_options_impl(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    int frame_interval);

void cancel_video_extract_impl();
