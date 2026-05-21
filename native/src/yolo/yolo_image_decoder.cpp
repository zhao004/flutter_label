#include "yolo/yolo_image_decoder.h"

#include <memory>
#include <string>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <objbase.h>
#include <windows.h>
#include <wincodec.h>
#endif

#if FLUTTER_LABEL_HAS_FFMPEG
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/error.h>
#include <libswscale/swscale.h>
}
#endif

namespace flutter_label::yolo {
namespace {

#if FLUTTER_LABEL_HAS_FFMPEG
struct FormatContextDeleter {
  void operator()(AVFormatContext* ptr) const {
    if (ptr != nullptr) {
      avformat_close_input(&ptr);
    }
  }
};

struct CodecContextDeleter {
  void operator()(AVCodecContext* ptr) const {
    if (ptr != nullptr) {
      avcodec_free_context(&ptr);
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
#endif

#if defined(_WIN32)
template <typename T>
void release_com(T** ptr) {
  if (ptr != nullptr && *ptr != nullptr) {
    (*ptr)->Release();
    *ptr = nullptr;
  }
}

int decode_image_with_wic(
    const std::filesystem::path& image_path,
    ImageBuffer* output) {
  if (output == nullptr) {
    return kInvalidArgument;
  }

  const HRESULT com_result = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  const bool should_uninitialize_com = SUCCEEDED(com_result);
  if (FAILED(com_result) && com_result != RPC_E_CHANGED_MODE) {
    return kImageDecodeFailed;
  }

  IWICImagingFactory* factory = nullptr;
  IWICBitmapDecoder* decoder = nullptr;
  IWICBitmapFrameDecode* frame = nullptr;
  IWICFormatConverter* converter = nullptr;
  int result = kImageDecodeFailed;

  const auto cleanup = [&]() {
    release_com(&converter);
    release_com(&frame);
    release_com(&decoder);
    release_com(&factory);
    if (should_uninitialize_com) {
      CoUninitialize();
    }
  };

  HRESULT hr = CoCreateInstance(
      CLSID_WICImagingFactory,
      nullptr,
      CLSCTX_INPROC_SERVER,
      IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    cleanup();
    return result;
  }

  const std::wstring path_text = image_path.wstring();
  hr = factory->CreateDecoderFromFilename(
      path_text.c_str(),
      nullptr,
      GENERIC_READ,
      WICDecodeMetadataCacheOnDemand,
      &decoder);
  if (FAILED(hr)) {
    cleanup();
    return result;
  }

  hr = decoder->GetFrame(0, &frame);
  if (FAILED(hr)) {
    cleanup();
    return result;
  }

  UINT width = 0;
  UINT height = 0;
  hr = frame->GetSize(&width, &height);
  if (FAILED(hr) || width == 0 || height == 0) {
    cleanup();
    return result;
  }

  hr = factory->CreateFormatConverter(&converter);
  if (FAILED(hr)) {
    cleanup();
    return result;
  }

  hr = converter->Initialize(
      frame,
      GUID_WICPixelFormat24bppRGB,
      WICBitmapDitherTypeNone,
      nullptr,
      0.0,
      WICBitmapPaletteTypeCustom);
  if (FAILED(hr)) {
    cleanup();
    return result;
  }

  constexpr UINT bytes_per_pixel = 3;
  const UINT stride = width * bytes_per_pixel;
  const std::size_t buffer_size =
      static_cast<std::size_t>(stride) * static_cast<std::size_t>(height);
  output->rgb.assign(buffer_size, 0);
  hr = converter->CopyPixels(
      nullptr,
      stride,
      static_cast<UINT>(output->rgb.size()),
      output->rgb.data());
  if (SUCCEEDED(hr)) {
    output->width = static_cast<int>(width);
    output->height = static_cast<int>(height);
    result = kSuccess;
  }

  cleanup();
  return result;
}
#endif

}  // namespace

int decode_image(const std::filesystem::path& image_path, ImageBuffer* output) {
#if defined(_WIN32)
  const int wic_result = decode_image_with_wic(image_path, output);
  if (wic_result == kSuccess) {
    return kSuccess;
  }
#endif
#if FLUTTER_LABEL_HAS_FFMPEG
  if (output == nullptr) {
    return kInvalidArgument;
  }

  const std::string image_path_text = image_path.u8string();
  AVFormatContext* format_context_raw = nullptr;
  if (avformat_open_input(
          &format_context_raw,
          image_path_text.c_str(),
          nullptr,
          nullptr) < 0) {
    return kImageDecodeFailed;
  }
  std::unique_ptr<AVFormatContext, FormatContextDeleter> format_context(
      format_context_raw);

  if (avformat_find_stream_info(format_context.get(), nullptr) < 0) {
    return kImageDecodeFailed;
  }

  const int stream_index = av_find_best_stream(
      format_context.get(), AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
  if (stream_index < 0) {
    return kImageDecodeFailed;
  }

  AVStream* stream = format_context.get()->streams[stream_index];
  const AVCodec* decoder = avcodec_find_decoder(stream->codecpar->codec_id);
  if (decoder == nullptr) {
    return kImageDecodeFailed;
  }

  AVCodecContext* decoder_raw = avcodec_alloc_context3(decoder);
  if (decoder_raw == nullptr) {
    return kImageDecodeFailed;
  }
  std::unique_ptr<AVCodecContext, CodecContextDeleter> decoder_context(
      decoder_raw);

  if (avcodec_parameters_to_context(decoder_context.get(), stream->codecpar) <
      0) {
    return kImageDecodeFailed;
  }
  if (avcodec_open2(decoder_context.get(), decoder, nullptr) < 0) {
    return kImageDecodeFailed;
  }

  AVPacket* packet_raw = av_packet_alloc();
  if (packet_raw == nullptr) {
    return kImageDecodeFailed;
  }
  std::unique_ptr<AVPacket, PacketDeleter> packet(packet_raw);

  AVFrame* frame_raw = av_frame_alloc();
  if (frame_raw == nullptr) {
    return kImageDecodeFailed;
  }
  std::unique_ptr<AVFrame, FrameDeleter> frame(frame_raw);

  bool frame_decoded = false;
  while (!frame_decoded && av_read_frame(format_context.get(), packet.get()) >= 0) {
    if (packet->stream_index != stream_index) {
      av_packet_unref(packet.get());
      continue;
    }
    if (avcodec_send_packet(decoder_context.get(), packet.get()) < 0) {
      av_packet_unref(packet.get());
      return kImageDecodeFailed;
    }
    av_packet_unref(packet.get());

    const int receive_result =
        avcodec_receive_frame(decoder_context.get(), frame.get());
    if (receive_result == AVERROR(EAGAIN)) {
      continue;
    }
    if (receive_result < 0) {
      return kImageDecodeFailed;
    }
    frame_decoded = true;
  }

  if (!frame_decoded) {
    if (avcodec_send_packet(decoder_context.get(), nullptr) < 0) {
      return kImageDecodeFailed;
    }
    if (avcodec_receive_frame(decoder_context.get(), frame.get()) < 0) {
      return kImageDecodeFailed;
    }
    frame_decoded = true;
  }

  if (!frame_decoded) {
    return kImageDecodeFailed;
  }

  const int width = frame->width;
  const int height = frame->height;
  if (width <= 0 || height <= 0) {
    return kImageDecodeFailed;
  }

  const AVPixelFormat target_format = AV_PIX_FMT_RGB24;
  SwsContext* sws_raw = sws_getContext(
      width,
      height,
      static_cast<AVPixelFormat>(frame->format),
      width,
      height,
      target_format,
      SWS_BILINEAR,
      nullptr,
      nullptr,
      nullptr);
  if (sws_raw == nullptr) {
    return kImageDecodeFailed;
  }
  std::unique_ptr<SwsContext, SwsContextDeleter> sws_context(sws_raw);

  output->width = width;
  output->height = height;
  output->rgb.resize(
      static_cast<std::size_t>(width) * static_cast<std::size_t>(height) *
      kRgbChannels);
  uint8_t* dst_data[4] = {output->rgb.data(), nullptr, nullptr, nullptr};
  int dst_linesize[4] = {width * kRgbChannels, 0, 0, 0};
  if (sws_scale(
          sws_context.get(),
          frame->data,
          frame->linesize,
          0,
          height,
          dst_data,
          dst_linesize) <= 0) {
    return kImageDecodeFailed;
  }
  return kSuccess;
#else
  (void)image_path;
  (void)output;
  return kModelUnavailable;
#endif
}

}  // namespace flutter_label::yolo
