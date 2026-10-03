cmake_minimum_required(VERSION 3.22.1)
project(finn_tts LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ONNX Runtime (MIT): the headers are vendored, the library is the one the
# sherpa_onnx package already ships, so the app carries a single copy.
set(ORT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party)
add_library(onnxruntime SHARED IMPORTED)
set_target_properties(onnxruntime PROPERTIES IMPORTED_LOCATION
  ${ORT_ROOT}/sherpa_onnx_android_arm64/android/src/main/jniLibs/${ANDROID_ABI}/libonnxruntime.so)

add_library(finn_tts SHARED finn_supertonic.cc)
target_include_directories(finn_tts PRIVATE ${ORT_ROOT}/onnxruntime/include)
target_link_libraries(finn_tts onnxruntime log)
# 16 KB page alignment, as the rest of the app's native code (Android 15+).
target_link_options(finn_tts PRIVATE -Wl,-z,max-page-size=16384)
