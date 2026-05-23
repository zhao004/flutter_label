# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(YoloLabel LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "YoloLabel")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Native video/model backend. 当前阶段先构建抽帧 DLL，后续 ONNX 和窗口捕获继续扩展该目标。
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../native" "${CMAKE_CURRENT_BINARY_DIR}/native")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# 支持文件会随 exe 安装。Flutter 引擎 DLL 保持在 exe 同目录，避免进程启动
# 阶段找不到导入库；项目原生运行时 DLL 统一放入 exe 同级 lib 目录。
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")
set(INSTALL_BUNDLE_NATIVE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

# 旧版本曾把 native_core 及其原生依赖复制到 exe 根目录。安装前清理这些
# 旧位置文件，避免输出目录同时存在根目录和 lib 目录两份原生运行时 DLL。
install(CODE "
  file(GLOB _flutter_label_stale_native_dlls
    \"${CMAKE_INSTALL_PREFIX}/native_core.dll\"
    \"${CMAKE_INSTALL_PREFIX}/avcodec-*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/avformat-*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/avutil-*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/swscale-*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/onnxruntime*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/cublas*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/cudart*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/cudnn*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/cufft*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/curand*.dll\"
    \"${CMAKE_INSTALL_PREFIX}/nvrtc*.dll\")
  if(_flutter_label_stale_native_dlls)
    file(REMOVE \${_flutter_label_stale_native_dlls})
  endif()
  " COMPONENT Runtime)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

install(TARGETS native_core RUNTIME DESTINATION "${INSTALL_BUNDLE_NATIVE_LIB_DIR}"
  COMPONENT Runtime)

# native_core 通过动态链接调用 FFmpeg。Dart 加载 native_core 前会把 lib
# 目录加入 Windows DLL 搜索路径，因此这里把原生依赖统一安装到 lib 目录。
set(FFMPEG_RUNTIME_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native/third_party/ffmpeg/bin")
file(GLOB FFMPEG_RUNTIME_DLLS CONFIGURE_DEPENDS "${FFMPEG_RUNTIME_DIR}/*.dll")
if(FFMPEG_RUNTIME_DLLS)
  install(FILES ${FFMPEG_RUNTIME_DLLS}
    DESTINATION "${INSTALL_BUNDLE_NATIVE_LIB_DIR}"
    COMPONENT Runtime)
else()
  message(WARNING "FFmpeg runtime DLLs not found in ${FFMPEG_RUNTIME_DIR}. native_core may fail to load at runtime.")
endif()

if(FLUTTER_LABEL_ONNXRUNTIME_RUNTIME_DIR)
  file(GLOB ONNXRUNTIME_RUNTIME_DLLS CONFIGURE_DEPENDS "${FLUTTER_LABEL_ONNXRUNTIME_RUNTIME_DIR}/*.dll")
  if(ONNXRUNTIME_RUNTIME_DLLS)
    install(FILES ${ONNXRUNTIME_RUNTIME_DLLS}
      DESTINATION "${INSTALL_BUNDLE_NATIVE_LIB_DIR}"
      COMPONENT Runtime)
  else()
    message(WARNING "ONNX Runtime runtime DLLs not found in ${FLUTTER_LABEL_ONNXRUNTIME_RUNTIME_DIR}. native_core may fail to load at runtime.")
  endif()
endif()

if(WIN32 AND FLUTTER_LABEL_ONNXRUNTIME_RUNTIME_DIR AND EXISTS "${FLUTTER_LABEL_ONNXRUNTIME_RUNTIME_DIR}/onnxruntime_providers_cuda.dll")
  # CUDA EP 只随 ONNX Runtime 提供 Provider DLL，NVIDIA CUDA/cuDNN 运行时仍需从
  # 本机安装目录或项目约定目录复制；缺失时保留 CPU fallback，并在配置阶段给出明确提示。
  set(FLUTTER_LABEL_CUDA_RUNTIME_DIR "" CACHE PATH "Optional directory containing CUDA runtime DLLs")
  set(FLUTTER_LABEL_CUDNN_RUNTIME_DIR "" CACHE PATH "Optional directory containing cuDNN runtime DLLs")
  set(FLUTTER_LABEL_CUDA_RUNTIME_DIRS "")
  foreach(_runtime_dir
      "${FLUTTER_LABEL_CUDA_RUNTIME_DIR}"
      "${FLUTTER_LABEL_CUDNN_RUNTIME_DIR}"
      "${CMAKE_CURRENT_SOURCE_DIR}/../native/third_party/cuda/windows-x64/bin"
      "${CMAKE_CURRENT_SOURCE_DIR}/../native/third_party/cuda/bin"
      "${CMAKE_CURRENT_SOURCE_DIR}/../native/third_party/cudnn/windows-x64/bin"
      "${CMAKE_CURRENT_SOURCE_DIR}/../native/third_party/cudnn/bin")
    if(_runtime_dir AND EXISTS "${_runtime_dir}")
      list(APPEND FLUTTER_LABEL_CUDA_RUNTIME_DIRS "${_runtime_dir}")
    endif()
  endforeach()
  foreach(_runtime_env CUDA_PATH CUDA_HOME CUDNN_HOME)
    if(DEFINED ENV{${_runtime_env}})
      if(EXISTS "$ENV{${_runtime_env}}/bin")
        list(APPEND FLUTTER_LABEL_CUDA_RUNTIME_DIRS "$ENV{${_runtime_env}}/bin")
      elseif(EXISTS "$ENV{${_runtime_env}}")
        list(APPEND FLUTTER_LABEL_CUDA_RUNTIME_DIRS "$ENV{${_runtime_env}}")
      endif()
    endif()
  endforeach()
  if(FLUTTER_LABEL_CUDA_RUNTIME_DIRS)
    list(REMOVE_DUPLICATES FLUTTER_LABEL_CUDA_RUNTIME_DIRS)
  endif()

  set(FLUTTER_LABEL_REQUIRED_CUDA_DLL_NAMES
    cublasLt64_12.dll
    cublas64_12.dll
    cudart64_12.dll
    cudnn64_9.dll
    cudnn_adv64_9.dll
    cudnn_cnn64_9.dll
    cudnn_graph64_9.dll
    cudnn_ops64_9.dll)
  set(FLUTTER_LABEL_OPTIONAL_CUDA_DLL_PATTERNS
    cufft64_11.dll
    curand64_10.dll
    nvrtc64_120_0.dll
    cudnn*64_9.dll)
  set(FLUTTER_LABEL_CUDA_RUNTIME_DLLS "")
  set(FLUTTER_LABEL_MISSING_CUDA_DLLS "")
  foreach(_dll_name IN LISTS FLUTTER_LABEL_REQUIRED_CUDA_DLL_NAMES)
    set(_dll_path "")
    foreach(_runtime_dir IN LISTS FLUTTER_LABEL_CUDA_RUNTIME_DIRS)
      if(EXISTS "${_runtime_dir}/${_dll_name}")
        set(_dll_path "${_runtime_dir}/${_dll_name}")
        break()
      endif()
    endforeach()
    if(_dll_path)
      list(APPEND FLUTTER_LABEL_CUDA_RUNTIME_DLLS "${_dll_path}")
    else()
      list(APPEND FLUTTER_LABEL_MISSING_CUDA_DLLS "${_dll_name}")
    endif()
  endforeach()
  foreach(_runtime_dir IN LISTS FLUTTER_LABEL_CUDA_RUNTIME_DIRS)
    foreach(_dll_pattern IN LISTS FLUTTER_LABEL_OPTIONAL_CUDA_DLL_PATTERNS)
      file(GLOB _matched_cuda_dlls CONFIGURE_DEPENDS "${_runtime_dir}/${_dll_pattern}")
      if(_matched_cuda_dlls)
        list(APPEND FLUTTER_LABEL_CUDA_RUNTIME_DLLS ${_matched_cuda_dlls})
      endif()
    endforeach()
  endforeach()
  if(FLUTTER_LABEL_CUDA_RUNTIME_DLLS)
    list(REMOVE_DUPLICATES FLUTTER_LABEL_CUDA_RUNTIME_DLLS)
    install(FILES ${FLUTTER_LABEL_CUDA_RUNTIME_DLLS}
      DESTINATION "${INSTALL_BUNDLE_NATIVE_LIB_DIR}"
      COMPONENT Runtime)
  endif()
  if(FLUTTER_LABEL_MISSING_CUDA_DLLS)
    message(WARNING "CUDA Runtime DLLs missing for ONNX Runtime CUDA EP: ${FLUTTER_LABEL_MISSING_CUDA_DLLS}. Install CUDA 12.x Runtime and cuDNN 9.x, set CUDA_PATH/CUDNN_HOME, or pass FLUTTER_LABEL_CUDA_RUNTIME_DIR/FLUTTER_LABEL_CUDNN_RUNTIME_DIR. The app will fall back to CPU inference when these DLLs are unavailable.")
  endif()
endif()

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
