#include "video/ffmpeg_extractor.h"

#include "common/native_common.h"

#include <atomic>
#include <filesystem>

#if FLUTTER_LABEL_HAS_FFMPEG
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/error.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

#include <cmath>
#include <cstdio>
#include <memory>
#include <vector>
#endif

namespace {

constexpr int kSuccess = 0;
constexpr int kInvalidArgument = -1;
constexpr int kFileNotFound = -2;
constexpr int kDirectoryError = -3;
constexpr int kFfmpegFailed = -4;
constexpr int kFfmpegUnavailable = -5;
constexpr int kCanceled = -6;

std::atomic_bool g_cancel_requested{false};

using flutter_label::native::is_blank;

std::string output_prefix_or_default(const char* value) {
  if (is_blank(value)) {
    return "video";
  }
  return std::string(value);
}

void reset_cancel_request() {
  g_cancel_requested.store(false, std::memory_order_relaxed);
}

int prepare_paths(const char* video_path, const char* output_dir) {
  if (is_blank(video_path) || is_blank(output_dir)) {
    return kInvalidArgument;
  }
  if (!std::filesystem::exists(video_path)) {
    return kFileNotFound;
  }

  std::error_code error_code;
  std::filesystem::create_directories(output_dir, error_code);
  if (error_code) {
    return kDirectoryError;
  }
  return kSuccess;
}

#if FLUTTER_LABEL_HAS_FFMPEG

bool is_cancel_requested() {
  return g_cancel_requested.load(std::memory_order_relaxed);
}

long long frame_timestamp_milliseconds(
    AVFrame* frame,
    AVRational stream_time_base,
    int decoded_frame_index,
    double fallback_frame_rate) {
  double timestamp_seconds = 0.0;
  if (frame != nullptr && frame->best_effort_timestamp != AV_NOPTS_VALUE) {
    timestamp_seconds =
        static_cast<double>(frame->best_effort_timestamp) * av_q2d(stream_time_base);
  } else if (fallback_frame_rate > 0.0) {
    timestamp_seconds = static_cast<double>(decoded_frame_index) / fallback_frame_rate;
  }
  if (timestamp_seconds < 0.0) {
    timestamp_seconds = 0.0;
  }
  return static_cast<long long>(std::llround(timestamp_seconds * 1000.0));
}

double stream_frame_rate(const AVStream* stream) {
  if (stream == nullptr) {
    return 25.0;
  }
  const AVRational average_rate = stream->avg_frame_rate;
  if (average_rate.num > 0 && average_rate.den > 0) {
    return av_q2d(average_rate);
  }
  const AVRational raw_rate = stream->r_frame_rate;
  if (raw_rate.num > 0 && raw_rate.den > 0) {
    return av_q2d(raw_rate);
  }
  return 25.0;
}

std::filesystem::path output_path(
    const char* output_dir,
    const std::string& output_prefix,
    long long timestamp_milliseconds,
    int duplicate_index) {
  char suffix[32] = {};
  if (duplicate_index <= 1) {
    std::snprintf(
        suffix,
        sizeof(suffix),
        "_%010lldms.jpg",
        timestamp_milliseconds);
  } else {
    std::snprintf(
        suffix,
        sizeof(suffix),
        "_%010lldms_%02d.jpg",
        timestamp_milliseconds,
        duplicate_index);
  }
  return std::filesystem::path(output_dir) / (output_prefix + suffix);
}

std::filesystem::path unique_output_path(
    const char* output_dir,
    const std::string& output_prefix,
    long long timestamp_milliseconds) {
  for (int duplicate_index = 1; duplicate_index <= 999; ++duplicate_index) {
    const std::filesystem::path candidate = output_path(
        output_dir,
        output_prefix,
        timestamp_milliseconds,
        duplicate_index);
    if (!std::filesystem::exists(candidate)) {
      return candidate;
    }
  }
  return output_path(output_dir, output_prefix, timestamp_milliseconds, 1000);
}

template <typename T, void (*Deleter)(T**)>
struct AvDeleter {
  void operator()(T* ptr) const {
    if (ptr != nullptr) {
      Deleter(&ptr);
    }
  }
};

struct PacketDeleter {
  void operator()(AVPacket* ptr) const {
    if (ptr != nullptr) {
      av_packet_free(&ptr);
    }
  }
};

struct FrameDeleter {
  void operator()(AVFrame* ptr) const {
    if (ptr != nullptr) {
      av_frame_free(&ptr);
    }
  }
};

struct SwsContextDeleter {
  void operator()(SwsContext* ptr) const {
    if (ptr != nullptr) {
      sws_freeContext(ptr);
    }
  }
};

using FormatContextPtr =
    std::unique_ptr<AVFormatContext, AvDeleter<AVFormatContext, avformat_close_input>>;
using CodecContextPtr =
    std::unique_ptr<AVCodecContext, AvDeleter<AVCodecContext, avcodec_free_context>>;
using PacketPtr = std::unique_ptr<AVPacket, PacketDeleter>;
using FramePtr = std::unique_ptr<AVFrame, FrameDeleter>;
using SwsContextPtr = std::unique_ptr<SwsContext, SwsContextDeleter>;

int open_input(
    const char* video_path,
    FormatContextPtr* format_context,
    CodecContextPtr* decoder_context,
    int* video_stream_index) {
  AVFormatContext* raw_format_context = nullptr;
  if (avformat_open_input(&raw_format_context, video_path, nullptr, nullptr) < 0) {
    return kFfmpegFailed;
  }
  format_context->reset(raw_format_context);

  if (avformat_find_stream_info(format_context->get(), nullptr) < 0) {
    return kFfmpegFailed;
  }

  const int stream_index = av_find_best_stream(
      format_context->get(), AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
  if (stream_index < 0) {
    return kFfmpegFailed;
  }

  AVStream* stream = format_context->get()->streams[stream_index];
  const AVCodec* decoder = avcodec_find_decoder(stream->codecpar->codec_id);
  if (decoder == nullptr) {
    return kFfmpegFailed;
  }

  AVCodecContext* raw_decoder_context = avcodec_alloc_context3(decoder);
  if (raw_decoder_context == nullptr) {
    return kFfmpegFailed;
  }
  decoder_context->reset(raw_decoder_context);

  if (avcodec_parameters_to_context(decoder_context->get(), stream->codecpar) < 0) {
    return kFfmpegFailed;
  }
  if (avcodec_open2(decoder_context->get(), decoder, nullptr) < 0) {
    return kFfmpegFailed;
  }

  *video_stream_index = stream_index;
  return kSuccess;
}

CodecContextPtr create_mjpeg_encoder(int width, int height) {
  const AVCodec* encoder = avcodec_find_encoder(AV_CODEC_ID_MJPEG);
  if (encoder == nullptr) {
    return CodecContextPtr(nullptr);
  }

  AVCodecContext* raw_encoder_context = avcodec_alloc_context3(encoder);
  if (raw_encoder_context == nullptr) {
    return CodecContextPtr(nullptr);
  }
  CodecContextPtr encoder_context(raw_encoder_context);
  encoder_context->width = width;
  encoder_context->height = height;
  encoder_context->time_base = AVRational{1, 25};
  encoder_context->framerate = AVRational{25, 1};
  encoder_context->pix_fmt = AV_PIX_FMT_YUVJ420P;
  encoder_context->color_range = AVCOL_RANGE_JPEG;

  if (avcodec_open2(encoder_context.get(), encoder, nullptr) < 0) {
    return CodecContextPtr(nullptr);
  }
  return encoder_context;
}

FramePtr create_encoder_frame(const AVCodecContext* encoder_context) {
  FramePtr frame(av_frame_alloc());
  if (frame == nullptr) {
    return FramePtr(nullptr);
  }

  frame->format = encoder_context->pix_fmt;
  frame->width = encoder_context->width;
  frame->height = encoder_context->height;
  frame->color_range = AVCOL_RANGE_JPEG;
  if (av_frame_get_buffer(frame.get(), 32) < 0) {
    return FramePtr(nullptr);
  }
  return frame;
}

int write_jpeg(
    AVCodecContext* encoder_context,
    AVFrame* frame,
    const std::filesystem::path& path) {
  PacketPtr packet(av_packet_alloc());
  if (packet == nullptr) {
    return kFfmpegFailed;
  }

  if (avcodec_send_frame(encoder_context, frame) < 0) {
    return kFfmpegFailed;
  }

  const int receive_result = avcodec_receive_packet(encoder_context, packet.get());
  if (receive_result < 0) {
    return kFfmpegFailed;
  }

  FILE* file = nullptr;
#ifdef _WIN32
  if (_wfopen_s(&file, path.wstring().c_str(), L"wb") != 0) {
    file = nullptr;
  }
#else
  file = std::fopen(path.string().c_str(), "wb");
#endif
  if (file == nullptr) {
    return kDirectoryError;
  }

  const size_t written =
      std::fwrite(packet->data, 1, static_cast<size_t>(packet->size), file);
  std::fclose(file);
  return written == static_cast<size_t>(packet->size) ? kSuccess : kDirectoryError;
}

bool should_extract_by_fps(
    AVFrame* frame,
    AVRational stream_time_base,
    int decoded_frame_index,
    double fallback_frame_rate,
    double fps,
    double* next_timestamp_seconds) {
  const double timestamp_seconds =
      frame_timestamp_milliseconds(
          frame,
          stream_time_base,
          decoded_frame_index,
          fallback_frame_rate) / 1000.0;
  if (timestamp_seconds + 0.000001 < *next_timestamp_seconds) {
    return false;
  }
  *next_timestamp_seconds += 1.0 / fps;
  return true;
}

int extract_frames(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    double fps,
    int frame_interval,
    bool use_fps_mode) {
  FormatContextPtr format_context(nullptr);
  CodecContextPtr decoder_context(nullptr);
  int video_stream_index = -1;
  int result = open_input(
      video_path, &format_context, &decoder_context, &video_stream_index);
  if (result != kSuccess) {
    return result;
  }

  AVStream* video_stream = format_context->streams[video_stream_index];
  const double fallback_frame_rate = stream_frame_rate(video_stream);
  const std::string safe_output_prefix = output_prefix_or_default(output_prefix);
  CodecContextPtr encoder_context =
      create_mjpeg_encoder(decoder_context->width, decoder_context->height);
  if (encoder_context == nullptr) {
    return kFfmpegFailed;
  }

  SwsContextPtr sws_context(sws_getContext(
      decoder_context->width,
      decoder_context->height,
      decoder_context->pix_fmt,
      encoder_context->width,
      encoder_context->height,
      encoder_context->pix_fmt,
      SWS_BILINEAR,
      nullptr,
      nullptr,
      nullptr));
  if (sws_context == nullptr) {
    return kFfmpegFailed;
  }

  PacketPtr packet(av_packet_alloc());
  FramePtr decoded_frame(av_frame_alloc());
  FramePtr encoded_frame = create_encoder_frame(encoder_context.get());
  if (packet == nullptr || decoded_frame == nullptr || encoded_frame == nullptr) {
    return kFfmpegFailed;
  }

  int decoded_frame_index = 0;
  int output_frame_index = 1;
  double next_timestamp_seconds = 0.0;

  auto handle_decoded_frame = [&]() -> int {
    if (is_cancel_requested()) {
      return kCanceled;
    }

    bool should_extract = false;
    if (use_fps_mode) {
      should_extract = should_extract_by_fps(
          decoded_frame.get(),
          video_stream->time_base,
          decoded_frame_index,
          fallback_frame_rate,
          fps,
          &next_timestamp_seconds);
    } else {
      should_extract = decoded_frame_index % frame_interval == 0;
    }
    if (!should_extract) {
      decoded_frame_index++;
      return kSuccess;
    }

    const long long timestamp_milliseconds = frame_timestamp_milliseconds(
        decoded_frame.get(),
        video_stream->time_base,
        decoded_frame_index,
        fallback_frame_rate);
    decoded_frame_index++;

    if (av_frame_make_writable(encoded_frame.get()) < 0) {
      return kFfmpegFailed;
    }
    sws_scale(
        sws_context.get(),
        decoded_frame->data,
        decoded_frame->linesize,
        0,
        decoder_context->height,
        encoded_frame->data,
        encoded_frame->linesize);
    encoded_frame->pts = output_frame_index - 1;
    output_frame_index++;
    const std::filesystem::path target_path = overwrite_existing != 0
        ? output_path(output_dir, safe_output_prefix, timestamp_milliseconds, 1)
        : unique_output_path(output_dir, safe_output_prefix, timestamp_milliseconds);
    return write_jpeg(
        encoder_context.get(),
        encoded_frame.get(),
        target_path);
  };

  while (av_read_frame(format_context.get(), packet.get()) >= 0) {
    if (is_cancel_requested()) {
      return kCanceled;
    }

    if (packet->stream_index == video_stream_index) {
      result = avcodec_send_packet(decoder_context.get(), packet.get());
      if (result < 0) {
        return kFfmpegFailed;
      }
      while (true) {
        if (is_cancel_requested()) {
          return kCanceled;
        }

        result = avcodec_receive_frame(decoder_context.get(), decoded_frame.get());
        if (result == AVERROR(EAGAIN) || result == AVERROR_EOF) {
          break;
        }
        if (result < 0) {
          return kFfmpegFailed;
        }
        const int write_result = handle_decoded_frame();
        if (write_result != kSuccess) {
          return write_result;
        }
        av_frame_unref(decoded_frame.get());
      }
    }
    av_packet_unref(packet.get());
  }

  if (is_cancel_requested()) {
    return kCanceled;
  }

  if (avcodec_send_packet(decoder_context.get(), nullptr) < 0) {
    return kFfmpegFailed;
  }
  while (true) {
    if (is_cancel_requested()) {
      return kCanceled;
    }

    result = avcodec_receive_frame(decoder_context.get(), decoded_frame.get());
    if (result == AVERROR_EOF || result == AVERROR(EAGAIN)) {
      break;
    }
    if (result < 0) {
      return kFfmpegFailed;
    }
    const int write_result = handle_decoded_frame();
    if (write_result != kSuccess) {
      return write_result;
    }
    av_frame_unref(decoded_frame.get());
  }

  return output_frame_index > 1 ? kSuccess : kFfmpegFailed;
}

#endif

}  // namespace

int extract_frames_by_fps_impl(
    const char* video_path,
    const char* output_dir,
    double fps) {
  return extract_frames_by_fps_with_options_impl(
      video_path,
      output_dir,
      "video",
      1,
      fps);
}

int extract_frames_by_fps_with_options_impl(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    double fps) {
  reset_cancel_request();
  if (fps <= 0.0) {
    return kInvalidArgument;
  }
  const int path_result = prepare_paths(video_path, output_dir);
  if (path_result != kSuccess) {
    return path_result;
  }

#if FLUTTER_LABEL_HAS_FFMPEG
  return extract_frames(
      video_path,
      output_dir,
      output_prefix,
      overwrite_existing,
      fps,
      0,
      true);
#else
  return kFfmpegUnavailable;
#endif
}

int extract_frames_by_interval_impl(
    const char* video_path,
    const char* output_dir,
    int frame_interval) {
  return extract_frames_by_interval_with_options_impl(
      video_path,
      output_dir,
      "video",
      1,
      frame_interval);
}

int extract_frames_by_interval_with_options_impl(
    const char* video_path,
    const char* output_dir,
    const char* output_prefix,
    int overwrite_existing,
    int frame_interval) {
  reset_cancel_request();
  if (frame_interval <= 0) {
    return kInvalidArgument;
  }
  const int path_result = prepare_paths(video_path, output_dir);
  if (path_result != kSuccess) {
    return path_result;
  }

#if FLUTTER_LABEL_HAS_FFMPEG
  return extract_frames(
      video_path,
      output_dir,
      output_prefix,
      overwrite_existing,
      0.0,
      frame_interval,
      false);
#else
  return kFfmpegUnavailable;
#endif
}

void cancel_video_extract_impl() {
  g_cancel_requested.store(true, std::memory_order_relaxed);
}
