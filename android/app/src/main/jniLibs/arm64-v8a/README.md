# Accelerator backends

Drop the ggml backend shared libraries for the silicon you want to accelerate
into this directory. Android Gradle Plugin auto-packages everything under
`src/main/jniLibs/<abi>`, and `LlamaLibrary.load` discovers them at runtime via
`ggml_backend_load_all_from_path(applicationInfo.nativeLibraryDir)`.

The app selects automatically (in `lib/src/inference/adaptive/adaptive.dart`):

1. **Hexagon NPU** — `libggml-hexagon.so` plus the FastRPC skeleton libs
   `libggml-htp-v*.so`. FastRPC locates the skeleton libs through
   `ADSP_LIBRARY_PATH` (already set to this directory at load time).
2. **Vulkan GPU** — `libggml-vulkan.so`.
3. **OpenCL GPU** — `libggml-opencl.so` (Adreno/Mali fallback).
4. **CPU** — always present via `libggml-cpu-android_*.so` from the AAR.

Build the backends with the matching llama.cpp flags (e.g. `-DGGML_HEXAGON=ON`,
`-DGGML_VULKAN=ON`, `-DGGML_OPENCL=ON`) against the same llama.cpp commit the
vendored `llama_cpp_dart` pins, then place the produced `.so` files here and
rebuild the APK. No Dart changes are required — the selector upgrades from CPU
as soon as the libraries are present, and falls back to CPU if an accelerated
engine fails to spawn.
