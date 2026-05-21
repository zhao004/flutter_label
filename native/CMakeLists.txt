cmake_minimum_required(VERSION 3.20)

project(native_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVE_CORE_SOURCES
  src/api/native_core.cpp
  src/common/native_common.cpp
  src/video/ffmpeg_extractor.cpp
  src/window/window_capture.cpp
  src/yolo/yolo_detector.cpp
  src/yolo/yolo_image_decoder.cpp
  src/yolo/yolo_metadata.cpp
  src/yolo/yolo_output_parser.cpp
  src/yolo/yolo_preprocess.cpp
)

add_library(native_core SHARED ${NATIVE_CORE_SOURCES})

target_include_directories(native_core PRIVATE include src)
source_group(TREE "${CMAKE_CURRENT_SOURCE_DIR}/src" PREFIX "native" FILES ${NATIVE_CORE_SOURCES})

set(FFMPEG_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/ffmpeg" CACHE PATH "FFmpeg SDK root")
set(FFMPEG_INCLUDE_DIR "")
set(FFMPEG_LIBRARY_DIR "")

if (WIN32 AND EXISTS "${FFMPEG_ROOT}/include/libavformat/avformat.h")
  set(FFMPEG_INCLUDE_DIR "${FFMPEG_ROOT}/include")
  if (CMAKE_SIZEOF_VOID_P EQUAL 8 AND EXISTS "${FFMPEG_ROOT}/lib")
    set(FFMPEG_LIBRARY_DIR "${FFMPEG_ROOT}/lib")
  endif()
endif()

if (FFMPEG_INCLUDE_DIR AND FFMPEG_LIBRARY_DIR)
  target_include_directories(native_core SYSTEM PRIVATE "${FFMPEG_INCLUDE_DIR}")
  target_link_directories(native_core PRIVATE "${FFMPEG_LIBRARY_DIR}")
  target_link_libraries(native_core PRIVATE avformat avcodec avutil swscale)
  target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_FFMPEG=1)
  message(STATUS "FFmpeg SDK enabled: ${FFMPEG_ROOT}")
else()
  find_package(PkgConfig QUIET)
  if (PkgConfig_FOUND)
    pkg_check_modules(FFMPEG QUIET IMPORTED_TARGET
      libavformat
      libavcodec
      libavutil
      libswscale
    )
  endif()
  if (FFMPEG_FOUND)
    target_link_libraries(native_core PRIVATE PkgConfig::FFMPEG)
    target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_FFMPEG=1)
    message(STATUS "FFmpeg pkg-config libraries enabled")
  else()
    target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_FFMPEG=0)
    message(WARNING "FFmpeg SDK not found. native_core will build, but frame extraction returns -5.")
  endif()
endif()

set(ONNXRUNTIME_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/onnxruntime" CACHE PATH "ONNX Runtime SDK root")
set(ONNXRUNTIME_INCLUDE_DIR "")
set(ONNXRUNTIME_LIBRARY_DIR "")
set(ONNXRUNTIME_RUNTIME_DIR "")

if (EXISTS "${ONNXRUNTIME_ROOT}/include/onnxruntime_cxx_api.h")
  set(ONNXRUNTIME_INCLUDE_DIR "${ONNXRUNTIME_ROOT}/include")
  if (WIN32 AND EXISTS "${ONNXRUNTIME_ROOT}/lib/onnxruntime.lib")
    set(ONNXRUNTIME_LIBRARY_DIR "${ONNXRUNTIME_ROOT}/lib")
    if (EXISTS "${ONNXRUNTIME_ROOT}/bin/onnxruntime.dll")
      set(ONNXRUNTIME_RUNTIME_DIR "${ONNXRUNTIME_ROOT}/bin")
    elseif (EXISTS "${ONNXRUNTIME_ROOT}/lib/onnxruntime.dll")
      set(ONNXRUNTIME_RUNTIME_DIR "${ONNXRUNTIME_ROOT}/lib")
    endif()
  elseif (UNIX AND EXISTS "${ONNXRUNTIME_ROOT}/lib/libonnxruntime.so")
    set(ONNXRUNTIME_LIBRARY_DIR "${ONNXRUNTIME_ROOT}/lib")
  endif()
elseif (WIN32 AND EXISTS "${ONNXRUNTIME_ROOT}/windows-x64/include/onnxruntime_cxx_api.h")
  set(ONNXRUNTIME_INCLUDE_DIR "${ONNXRUNTIME_ROOT}/windows-x64/include")
  if (EXISTS "${ONNXRUNTIME_ROOT}/windows-x64/lib/onnxruntime.lib")
    set(ONNXRUNTIME_LIBRARY_DIR "${ONNXRUNTIME_ROOT}/windows-x64/lib")
  endif()
  if (EXISTS "${ONNXRUNTIME_ROOT}/windows-x64/bin/onnxruntime.dll")
    set(ONNXRUNTIME_RUNTIME_DIR "${ONNXRUNTIME_ROOT}/windows-x64/bin")
  elseif (EXISTS "${ONNXRUNTIME_ROOT}/windows-x64/lib/onnxruntime.dll")
    set(ONNXRUNTIME_RUNTIME_DIR "${ONNXRUNTIME_ROOT}/windows-x64/lib")
  endif()
endif()

if (ONNXRUNTIME_INCLUDE_DIR AND ONNXRUNTIME_LIBRARY_DIR)
  target_include_directories(native_core SYSTEM PRIVATE "${ONNXRUNTIME_INCLUDE_DIR}")
  target_link_directories(native_core PRIVATE "${ONNXRUNTIME_LIBRARY_DIR}")
  target_link_libraries(native_core PRIVATE onnxruntime)
  target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_ONNXRUNTIME=1)
  if (WIN32 AND EXISTS "${ONNXRUNTIME_LIBRARY_DIR}/onnxruntime_providers_cuda.dll")
    target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_ONNXRUNTIME_CUDA=1)
  else()
    target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_ONNXRUNTIME_CUDA=0)
  endif()
  set(FLUTTER_LABEL_ONNXRUNTIME_RUNTIME_DIR "${ONNXRUNTIME_RUNTIME_DIR}" CACHE PATH "ONNX Runtime runtime DLL directory" FORCE)
  message(STATUS "ONNX Runtime enabled: ${ONNXRUNTIME_ROOT}")
else()
  target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_ONNXRUNTIME=0)
  target_compile_definitions(native_core PRIVATE FLUTTER_LABEL_HAS_ONNXRUNTIME_CUDA=0)
  set(FLUTTER_LABEL_ONNXRUNTIME_RUNTIME_DIR "" CACHE PATH "ONNX Runtime runtime DLL directory" FORCE)
  message(WARNING "ONNX Runtime SDK not found. native_core will build, but YOLO ONNX inference will be unavailable at runtime.")
endif()

if (MSVC)
  target_compile_options(native_core PRIVATE /W4 /permissive- /utf-8 /EHsc)
  target_link_libraries(native_core PRIVATE windowscodecs ole32 user32 gdi32 dwmapi)
else()
  target_compile_options(native_core PRIVATE -Wall -Wextra -Wpedantic)
endif()
