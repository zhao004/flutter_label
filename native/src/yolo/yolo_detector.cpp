#include "yolo/yolo_detector.h"

#include "common/native_common.h"
#include "yolo/yolo_image_decoder.h"
#include "yolo/yolo_metadata.h"
#include "yolo/yolo_output_parser.h"
#include "yolo/yolo_preprocess.h"
#include "yolo/yolo_types.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <limits>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
#include <vector>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
#include <onnxruntime_cxx_api.h>
#endif

namespace {

using flutter_label::native::duplicate_c_string;
using flutter_label::native::is_blank;
using flutter_label::native::json_escape;
using flutter_label::yolo::BoxCandidate;
using flutter_label::yolo::ImageBuffer;
using flutter_label::yolo::PreprocessResult;
using flutter_label::yolo::class_name_for_id;
using flutter_label::yolo::clamp01;
using flutter_label::yolo::decode_image;
using flutter_label::yolo::kDirectoryError;
using flutter_label::yolo::kFileNotFound;
using flutter_label::yolo::kInferFailed;
using flutter_label::yolo::kInputInfoUnavailable;
using flutter_label::yolo::kInputSizeMismatch;
using flutter_label::yolo::kInvalidArgument;
using flutter_label::yolo::kModelLoadFailed;
using flutter_label::yolo::kModelUnavailable;
using flutter_label::yolo::kRgbChannels;
using flutter_label::yolo::kSuccess;
using flutter_label::yolo::kUnsupportedInput;
using flutter_label::yolo::kUnsupportedOutput;
using flutter_label::yolo::letterbox_to_tensor;
using flutter_label::yolo::nms_by_class;
using flutter_label::yolo::parse_model_class_names;
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
using flutter_label::yolo::parse_onnx_outputs;
#endif

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
struct YoloModelState {
  std::mutex mutex;
  bool initialized = false;
  int input_size = 0;
  std::filesystem::path model_path;
  Ort::Env env{ORT_LOGGING_LEVEL_WARNING, "flutter_label"};
  std::unique_ptr<Ort::Session> session;
  Ort::AllocatorWithDefaultOptions allocator;
  std::string input_name;
  std::vector<std::string> output_names;
  std::vector<const char*> output_name_ptrs;
  std::vector<std::string> class_names;
  std::vector<int64_t> input_dims;
  std::vector<std::vector<int64_t>> output_dims;
  std::string provider_name = "cpu";
  int last_error_code = kSuccess;
};

YoloModelState& model_state() {
  static YoloModelState state;
  return state;
}

#if defined(_WIN32) && FLUTTER_LABEL_HAS_ONNXRUNTIME_CUDA
constexpr std::wstring_view kCudaRuntimeDlls[] = {
    L"onnxruntime_providers_cuda.dll",
    L"onnxruntime_providers_shared.dll",
    L"cublasLt64_12.dll",
    L"cublas64_12.dll",
    L"cudart64_12.dll",
    L"cudnn64_9.dll",
    L"cudnn_adv64_9.dll",
    L"cudnn_cnn64_9.dll",
    L"cudnn_graph64_9.dll",
    L"cudnn_ops64_9.dll",
};

std::filesystem::path current_module_directory() {
  HMODULE module = nullptr;
  if (GetModuleHandleExW(
          GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
              GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
          reinterpret_cast<LPCWSTR>(&current_module_directory),
          &module) == 0) {
    return {};
  }

  std::wstring module_path(32768, L'\0');
  const DWORD size = GetModuleFileNameW(
      module,
      module_path.data(),
      static_cast<DWORD>(module_path.size()));
  if (size == 0 || size >= static_cast<DWORD>(module_path.size())) {
    return {};
  }
  module_path.resize(size);
  return std::filesystem::path(module_path).parent_path();
}

bool dll_exists_in_directory(
    const std::filesystem::path& directory,
    std::wstring_view dll_name) {
  if (directory.empty() || dll_name.empty()) {
    return false;
  }
  std::error_code error;
  return std::filesystem::exists(
      directory / std::filesystem::path(std::wstring(dll_name)),
      error);
}

bool windows_dll_available(std::wstring_view dll_name) {
  if (dll_name.empty()) {
    return false;
  }

  if (dll_exists_in_directory(current_module_directory(), dll_name)) {
    return true;
  }

  const std::wstring dll_text(dll_name);
  return SearchPathW(
             nullptr,
             dll_text.c_str(),
             nullptr,
             0,
             nullptr,
             nullptr) > 0;
}

bool cuda_runtime_dependencies_available() {
  // 先做静态依赖名预检，避免 Windows Loader 在缺少 CUDA/cuDNN 时输出 Error 126。
  for (const std::wstring_view dll_name : kCudaRuntimeDlls) {
    if (!windows_dll_available(dll_name)) {
      return false;
    }
  }
  return true;
}
#endif
#endif

[[maybe_unused]] std::filesystem::path utf8_path(const char* value) {
  return std::filesystem::u8path(value);
}

bool is_image_file(const std::filesystem::path& path) {
  const auto extension = path.extension().u8string();
  std::string lowered(extension.begin(), extension.end());
  std::transform(lowered.begin(), lowered.end(), lowered.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return lowered == ".jpg" || lowered == ".jpeg" || lowered == ".png" ||
         lowered == ".bmp" || lowered == ".webp";
}

[[maybe_unused]] std::vector<std::filesystem::path> list_image_files(
    const std::filesystem::path& root) {
  std::vector<std::filesystem::path> files;
  if (!std::filesystem::exists(root)) {
    return files;
  }

  for (const auto& entry : std::filesystem::recursive_directory_iterator(root)) {
    if (!entry.is_regular_file()) {
      continue;
    }
    if (is_image_file(entry.path())) {
      files.push_back(entry.path());
    }
  }
  std::sort(files.begin(), files.end());
  return files;
}

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
Ort::SessionOptions create_base_session_options() {
  Ort::SessionOptions session_options;
  session_options.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_EXTENDED);
  session_options.SetIntraOpNumThreads(1);
  session_options.SetInterOpNumThreads(1);
  session_options.SetExecutionMode(ExecutionMode::ORT_SEQUENTIAL);
  return session_options;
}

bool create_session_with_provider(YoloModelState* state, bool prefer_cuda) {
  if (state == nullptr) {
    return false;
  }
  try {
    Ort::SessionOptions session_options = create_base_session_options();
    bool use_cuda = false;
#if FLUTTER_LABEL_HAS_ONNXRUNTIME_CUDA
    if (prefer_cuda) {
#if defined(_WIN32)
      if (!cuda_runtime_dependencies_available()) {
        return false;
      }
#endif
      OrtCUDAProviderOptions cuda_options{};
      cuda_options.device_id = 0;
      cuda_options.cudnn_conv_algo_search = OrtCudnnConvAlgoSearchExhaustive;
      cuda_options.gpu_mem_limit = SIZE_MAX;
      cuda_options.do_copy_in_default_stream = 1;
      session_options.AppendExecutionProvider_CUDA(cuda_options);
      use_cuda = true;
    }
#else
    (void)prefer_cuda;
#endif

#ifdef _WIN32
    const std::wstring model_path_text = state->model_path.wstring();
#else
    const std::string model_path_text = state->model_path.u8string();
#endif
    state->session = std::make_unique<Ort::Session>(
        state->env,
        model_path_text.c_str(),
        session_options);
    state->provider_name = use_cuda ? "cuda" : "cpu";
    return true;
  } catch (const Ort::Exception&) {
    state->session.reset();
    return false;
  }
}

bool is_dynamic_dim(int64_t dim) {
  return dim <= 0;
}

int resolve_model_input_size(
    const std::vector<int64_t>& dims,
    int requested_input_size,
    int* resolved_input_size) {
  if (requested_input_size <= 0 || resolved_input_size == nullptr) {
    return kInvalidArgument;
  }
  *resolved_input_size = 0;
  if (dims.empty()) {
    return kInputInfoUnavailable;
  }
  if (dims.size() != 4) {
    return kUnsupportedInput;
  }

  const int64_t batch = dims[0];
  const int64_t channels = dims[1];
  const int64_t height = dims[2];
  const int64_t width = dims[3];
  if (!(batch == 1 || is_dynamic_dim(batch)) || channels != kRgbChannels) {
    return kUnsupportedInput;
  }

  const bool dynamic_height = is_dynamic_dim(height);
  const bool dynamic_width = is_dynamic_dim(width);
  if (dynamic_height && dynamic_width) {
    *resolved_input_size = requested_input_size;
    return kSuccess;
  }
  if (dynamic_height != dynamic_width || height != width ||
      height > static_cast<int64_t>(std::numeric_limits<int>::max())) {
    return kUnsupportedInput;
  }

  *resolved_input_size = static_cast<int>(height);
  if (requested_input_size != *resolved_input_size) {
    return kInputSizeMismatch;
  }
  return kSuccess;
}

#if FLUTTER_LABEL_HAS_ONNXRUNTIME
std::vector<std::string> read_model_class_names(YoloModelState* state) {
  if (state == nullptr || state->session == nullptr) {
    return {};
  }
  try {
    Ort::ModelMetadata metadata = state->session->GetModelMetadata();
    Ort::AllocatedStringPtr names = metadata.LookupCustomMetadataMapAllocated(
        "names",
        state->allocator);
    if (names == nullptr || names.get() == nullptr) {
      return {};
    }
    std::vector<std::string> class_names;
    if (parse_model_class_names(names.get(), &class_names)) {
      return class_names;
    }
  } catch (const Ort::Exception&) {
    // 类别元数据不是推理必需项，读取失败时保持旧的 ID 兜底显示。
  }
  return {};
}
#endif

std::string boxes_to_json(
    const std::vector<BoxCandidate>& boxes,
    int image_width,
    int image_height,
    const std::vector<std::string>& class_names) {
  std::ostringstream json;
  json << std::fixed << std::setprecision(6);
  json << '[';
  for (std::size_t index = 0; index < boxes.size(); ++index) {
    const auto& box = boxes[index];
    if (index > 0) {
      json << ',';
    }
    json << "{\"class_id\":" << box.class_id
         << ",\"class_name\":\""
         << json_escape(class_name_for_id(box.class_id, class_names)) << '"'
         << ",\"confidence\":" << box.confidence
         << ",\"x\":" << clamp01(box.left) * static_cast<float>(image_width)
         << ",\"y\":" << clamp01(box.top) * static_cast<float>(image_height)
         << ",\"w\":" << clamp01(box.width) * static_cast<float>(image_width)
         << ",\"h\":" << clamp01(box.height) * static_cast<float>(image_height)
         << ",\"image_width\":" << image_width
         << ",\"image_height\":" << image_height
         << '}';
  }
  json << ']';
  return json.str();
}

class YoloDetector {
 public:
  int init(const char* model_path, int imgsz) {
    std::lock_guard<std::mutex> lock(model_state().mutex);
    auto& state = model_state();
    state.last_error_code = kSuccess;
    if (is_blank(model_path) || imgsz <= 0) {
      state.last_error_code = kInvalidArgument;
      return kInvalidArgument;
    }

    state.session.reset();
    state.output_names.clear();
    state.output_name_ptrs.clear();
    state.class_names.clear();
    state.output_dims.clear();
    state.input_dims.clear();
    state.input_name.clear();
    state.model_path = utf8_path(model_path);
    state.input_size = 0;
    state.provider_name = "cpu";

    if (!std::filesystem::exists(state.model_path)) {
      state.last_error_code = kFileNotFound;
      return kFileNotFound;
    }

    const bool session_created =
        create_session_with_provider(&state, true) ||
        create_session_with_provider(&state, false);
    if (!session_created) {
      state.initialized = false;
      state.last_error_code = kModelLoadFailed;
      return kModelLoadFailed;
    }

    try {
      Ort::TypeInfo input_type_info = state.session->GetInputTypeInfo(0);
      auto tensor_info = input_type_info.GetTensorTypeAndShapeInfo();
      state.input_dims = tensor_info.GetShape();
      Ort::AllocatedStringPtr input_name = state.session->GetInputNameAllocated(0, state.allocator);
      state.input_name = input_name.get();

      int resolved_input_size = 0;
      const int input_result = resolve_model_input_size(
          state.input_dims,
          imgsz,
          &resolved_input_size);
      state.input_size = resolved_input_size;
      if (input_result != kSuccess) {
        state.session.reset();
        state.initialized = false;
        state.last_error_code = input_result;
        return input_result;
      }

      const std::size_t output_count = state.session->GetOutputCount();
      state.output_names.reserve(output_count);
      state.output_name_ptrs.reserve(output_count);
      state.output_dims.reserve(output_count);
      for (std::size_t i = 0; i < output_count; ++i) {
        Ort::AllocatedStringPtr output_name = state.session->GetOutputNameAllocated(i, state.allocator);
        state.output_names.emplace_back(output_name.get());
        state.output_name_ptrs.push_back(state.output_names.back().c_str());
        Ort::TypeInfo output_type_info = state.session->GetOutputTypeInfo(i);
        auto output_tensor_info = output_type_info.GetTensorTypeAndShapeInfo();
        state.output_dims.push_back(output_tensor_info.GetShape());
      }
      state.class_names = read_model_class_names(&state);
      state.initialized = true;
      state.last_error_code = kSuccess;
      return kSuccess;
    } catch (const Ort::Exception&) {
      state.session.reset();
      state.initialized = false;
      state.class_names.clear();
      state.last_error_code = kModelLoadFailed;
      return kModelLoadFailed;
    }
  }

  int detect_folder(
      const char* image_dir,
      const char* label_dir,
      float conf_threshold,
      float iou_threshold,
      int class_count) {
    if (is_blank(image_dir) || is_blank(label_dir) ||
        conf_threshold < 0.0f || iou_threshold < 0.0f) {
      return kInvalidArgument;
    }

    std::lock_guard<std::mutex> lock(model_state().mutex);
    auto& state = model_state();
    state.last_error_code = kSuccess;
    if (!state.initialized || state.session == nullptr) {
      state.last_error_code = kModelUnavailable;
      return kModelUnavailable;
    }

    const std::filesystem::path image_root = utf8_path(image_dir);
    const std::filesystem::path label_root = utf8_path(label_dir);
    if (!std::filesystem::exists(image_root)) {
      state.last_error_code = kFileNotFound;
      return kFileNotFound;
    }

    std::error_code error_code;
    std::filesystem::create_directories(label_root, error_code);
    if (error_code) {
      state.last_error_code = kDirectoryError;
      return kDirectoryError;
    }

    const auto image_files = list_image_files(image_root);
    for (const auto& image_path : image_files) {
      std::vector<BoxCandidate> boxes;
      const int infer_result = infer_image(
          image_path,
          iou_threshold,
          class_count,
          &boxes);
      if (infer_result != kSuccess) {
        state.last_error_code = infer_result;
        return infer_result;
      }

      const std::vector<BoxCandidate> filtered = filter_by_confidence(
          boxes,
          conf_threshold);
      const std::filesystem::path relative = std::filesystem::relative(image_path, image_root, error_code);
      if (error_code) {
        state.last_error_code = kDirectoryError;
        return kDirectoryError;
      }
      std::filesystem::path label_path = label_root / relative;
      label_path.replace_extension(".txt");
      std::filesystem::create_directories(label_path.parent_path(), error_code);
      if (error_code) {
        state.last_error_code = kDirectoryError;
        return kDirectoryError;
      }

      std::ofstream output_file(label_path, std::ios::binary | std::ios::trunc);
      if (!output_file.is_open()) {
        state.last_error_code = kDirectoryError;
        return kDirectoryError;
      }
      for (const auto& box : filtered) {
        const float left = clamp01(box.left);
        const float top = clamp01(box.top);
        const float width = clamp01(box.width);
        const float height = clamp01(box.height);
        if (width <= 0.0f || height <= 0.0f) {
          continue;
        }
        const float center_x = clamp01(left + width * 0.5f);
        const float center_y = clamp01(top + height * 0.5f);
        output_file << box.class_id << ' '
                    << center_x << ' '
                    << center_y << ' '
                    << width << ' '
                    << height << '\n';
      }
      if (!output_file.good()) {
        state.last_error_code = kDirectoryError;
        return kDirectoryError;
      }
    }

    state.last_error_code = kSuccess;
    return kSuccess;
  }

  char* detect_image(
      const char* image_path,
      float conf_threshold,
      float iou_threshold,
      int class_count) {
    std::lock_guard<std::mutex> lock(model_state().mutex);
    auto& state = model_state();
    state.last_error_code = kSuccess;
    if (is_blank(image_path) || conf_threshold < 0.0f || iou_threshold < 0.0f ||
        class_count < 0) {
      state.last_error_code = kInvalidArgument;
      return nullptr;
    }

    if (!state.initialized || state.session == nullptr) {
      state.last_error_code = kModelUnavailable;
      return nullptr;
    }

    std::vector<BoxCandidate> boxes;
    int image_width = 0;
    int image_height = 0;
    const int result = infer_image(
        utf8_path(image_path),
        iou_threshold,
        class_count,
        &boxes,
        &image_width,
        &image_height);
    if (result != kSuccess) {
      state.last_error_code = result;
      return nullptr;
    }

    const std::vector<BoxCandidate> filtered = filter_by_confidence(
        boxes,
        conf_threshold);
    const std::string json = boxes_to_json(
        filtered,
        image_width,
        image_height,
        state.class_names);
    char* output = duplicate_c_string(json);
    state.last_error_code = output == nullptr ? kDirectoryError : kSuccess;
    return output;
  }

  char* detect_bgra_frame(
      const unsigned char* bgra,
      int frame_width,
      int frame_height,
      int frame_stride,
      float conf_threshold,
      float iou_threshold,
      int class_count) {
    std::lock_guard<std::mutex> lock(model_state().mutex);
    auto& state = model_state();
    state.last_error_code = kSuccess;
    if (bgra == nullptr || frame_width <= 0 || frame_height <= 0 ||
        frame_stride < frame_width * 4 || conf_threshold < 0.0f ||
        iou_threshold < 0.0f || class_count < 0) {
      state.last_error_code = kInvalidArgument;
      return nullptr;
    }
    if (!state.initialized || state.session == nullptr) {
      state.last_error_code = kModelUnavailable;
      return nullptr;
    }

    ImageBuffer image;
    image.width = frame_width;
    image.height = frame_height;
    image.rgb.resize(static_cast<std::size_t>(frame_width) *
                     static_cast<std::size_t>(frame_height) * kRgbChannels);
    for (int y = 0; y < frame_height; ++y) {
      const unsigned char* source_row = bgra + static_cast<std::size_t>(y) * frame_stride;
      for (int x = 0; x < frame_width; ++x) {
        const unsigned char* pixel = source_row + static_cast<std::size_t>(x) * 4;
        const std::size_t target =
            (static_cast<std::size_t>(y) * frame_width + static_cast<std::size_t>(x)) * kRgbChannels;
        image.rgb[target] = pixel[2];
        image.rgb[target + 1] = pixel[1];
        image.rgb[target + 2] = pixel[0];
      }
    }

    std::vector<BoxCandidate> boxes;
    const int result = infer_buffer(image, iou_threshold, class_count, &boxes);
    if (result != kSuccess) {
      state.last_error_code = result;
      return nullptr;
    }
    const std::vector<BoxCandidate> filtered = filter_by_confidence(
        boxes,
        conf_threshold);
    const std::string json = boxes_to_json(
        filtered,
        frame_width,
        frame_height,
        state.class_names);
    char* output = duplicate_c_string(json);
    state.last_error_code = output == nullptr ? kDirectoryError : kSuccess;
    return output;
  }

  int last_error_code() {
    std::lock_guard<std::mutex> lock(model_state().mutex);
    return model_state().last_error_code;
  }

  int model_input_size() {
    std::lock_guard<std::mutex> lock(model_state().mutex);
    return model_state().input_size;
  }

  char* model_provider() {
    std::lock_guard<std::mutex> lock(model_state().mutex);
    return duplicate_c_string(model_state().provider_name);
  }

  void release() {
    std::lock_guard<std::mutex> lock(model_state().mutex);
    auto& state = model_state();
    state.session.reset();
    state.initialized = false;
    state.output_names.clear();
    state.output_name_ptrs.clear();
    state.class_names.clear();
    state.output_dims.clear();
    state.input_dims.clear();
    state.input_name.clear();
    state.input_size = 0;
    state.provider_name = "cpu";
  }

 private:
  std::vector<BoxCandidate> filter_by_confidence(
      const std::vector<BoxCandidate>& boxes,
      float conf_threshold) {
    std::vector<BoxCandidate> filtered;
    filtered.reserve(boxes.size());
    for (const auto& box : boxes) {
      if (box.confidence >= conf_threshold) {
        filtered.push_back(box);
      }
    }
    return filtered;
  }

  int infer_image(
      const std::filesystem::path& image_path,
      float iou_threshold,
      int class_count,
      std::vector<BoxCandidate>* boxes,
      int* original_width = nullptr,
      int* original_height = nullptr) {
    if (boxes == nullptr) {
      return kInvalidArgument;
    }
    boxes->clear();

    ImageBuffer image;
    const int decode_result = decode_image(image_path, &image);
    if (decode_result != kSuccess) {
      return decode_result;
    }
    if (original_width != nullptr) {
      *original_width = image.width;
    }
    if (original_height != nullptr) {
      *original_height = image.height;
    }

    return infer_buffer(image, iou_threshold, class_count, boxes);
  }

  int infer_buffer(
      const ImageBuffer& image,
      float iou_threshold,
      int class_count,
      std::vector<BoxCandidate>* boxes) {
    if (boxes == nullptr || image.width <= 0 || image.height <= 0 || image.rgb.empty()) {
      return kInvalidArgument;
    }
    auto& state = model_state();

    const PreprocessResult preprocess = letterbox_to_tensor(image, state.input_size);
    std::vector<float> input_data = preprocess.tensor;
    std::vector<int64_t> input_shape = {1, kRgbChannels, state.input_size, state.input_size};
    Ort::Value input_tensor = Ort::Value::CreateTensor<float>(
        Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault),
        input_data.data(),
        input_data.size(),
        input_shape.data(),
        input_shape.size());

    std::vector<Ort::Value> output_tensors;
    try {
      const char* input_name_ptr = state.input_name.c_str();
      output_tensors = state.session->Run(
          Ort::RunOptions{nullptr},
          &input_name_ptr,
          &input_tensor,
          1,
          state.output_name_ptrs.data(),
          state.output_name_ptrs.size());
    } catch (const Ort::Exception&) {
      return kInferFailed;
    }

    if (output_tensors.empty()) {
      return kUnsupportedOutput;
    }

    bool has_supported_output_layout = false;
    *boxes = parse_onnx_outputs(
        output_tensors,
        preprocess,
        image.width,
        image.height,
        class_count,
        &has_supported_output_layout);
    if (!has_supported_output_layout) {
      return kUnsupportedOutput;
    }
    *boxes = nms_by_class(std::move(*boxes), iou_threshold);
    return kSuccess;
  }

};

YoloDetector& detector() {
  static YoloDetector instance;
  return instance;
}
#endif

}  // namespace

int yolo_init_model_impl(const char* model_path, int imgsz) {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  return detector().init(model_path, imgsz);
#else
  (void)model_path;
  (void)imgsz;
  return kModelUnavailable;
#endif
}

char* yolo_detect_image_with_class_count_impl(
    const char* image_path,
    float conf_threshold,
    float iou_threshold,
    int class_count) {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  return detector().detect_image(image_path, conf_threshold, iou_threshold, class_count);
#else
  (void)image_path;
  (void)conf_threshold;
  (void)iou_threshold;
  (void)class_count;
  return nullptr;
#endif
}

char* yolo_detect_bgra_frame_with_class_count_impl(
    const unsigned char* bgra,
    int frame_width,
    int frame_height,
    int frame_stride,
    float conf_threshold,
    float iou_threshold,
    int class_count) {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  return detector().detect_bgra_frame(
      bgra,
      frame_width,
      frame_height,
      frame_stride,
      conf_threshold,
      iou_threshold,
      class_count);
#else
  (void)bgra;
  (void)frame_width;
  (void)frame_height;
  (void)frame_stride;
  (void)conf_threshold;
  (void)iou_threshold;
  (void)class_count;
  return nullptr;
#endif
}

int yolo_detect_folder_impl(
    const char* image_dir,
    const char* label_dir,
    float conf_threshold,
    float iou_threshold,
    int class_count) {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  return detector().detect_folder(
      image_dir,
      label_dir,
      conf_threshold,
      iou_threshold,
      class_count);
#else
  (void)image_dir;
  (void)label_dir;
  (void)conf_threshold;
  (void)iou_threshold;
  (void)class_count;
  return kModelUnavailable;
#endif
}

void yolo_release_model_impl() {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  detector().release();
#endif
}

int yolo_get_last_error_code_impl() {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  return detector().last_error_code();
#else
  return kModelUnavailable;
#endif
}

int yolo_get_model_input_size_impl() {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  return detector().model_input_size();
#else
  return 0;
#endif
}

char* yolo_get_model_provider_impl() {
#if FLUTTER_LABEL_HAS_ONNXRUNTIME
  return detector().model_provider();
#else
  return nullptr;
#endif
}
