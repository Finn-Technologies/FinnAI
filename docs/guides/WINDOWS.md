# FinnAI on Windows

FinnAI runs on Windows (x64) as a native Win32/DirectX Flutter desktop application. The model, download pipeline,
encrypted history, web search, flows, creations, and FinnAI Code all run directly on the PC. The window adapts to its
size using the exact same responsive layout: docked sidebar at $\ge 900\text{ px}$, compact overlay drawer below $900\text{ px}$,
and centered chat columns capped at $760\text{ px}$.

## Build

### Prerequisites
1. **Visual Studio 2022 / 2026** with the *Desktop development with C++* workload installed.
2. **Flutter 3.x+** with Windows desktop enabled:
   ```powershell
   flutter config --enable-windows-desktop
   ```
3. **CMake** and **Git** (included with Visual Studio or installed on PATH).

### 1. Build the Native Model Runtime (llama.cpp)
Compile the pinned `llama_cpp_dart` native libraries (`v0.9.0-dev.9` / llama.cpp `d6d0ce82`) for Windows x64:
```powershell
powershell -ExecutionPolicy Bypass -File tool/rebuild_llama_windows.ps1
```
This builds `llama.dll`, `ggml-base.dll`, `llama-common.dll`, `mtmd.dll`, and architecture-specific AVX/AVX2/AVX-512 GGML kernels into `windows/native/x64/`.

### 2. Build & Run the Flutter Application
```powershell
flutter pub get
flutter run -d windows
```

To create a release distribution:
```powershell
flutter build windows --release
```
The output lands in `build/windows/x64/runner/Release/`, containing `finn_ai.exe`, the Flutter engine runtime, all Windows plugin DLLs, and the native `llama.cpp` dynamic libraries beside the executable.

## Where things are on Windows

| Component | Location / Mechanism |
|---|---|
| Model and projector | `%LOCALAPPDATA%\com.abhiflex\finn_ai\models\` (`getApplicationSupportDirectory`) |
| Conversation key | Windows Credential Manager via `flutter_secure_storage_windows` |
| Native runtime | Beside executable: `llama.dll`, `ggml-base.dll`, etc. (`bundledLlamaLibrary` / `DeviceProfile.llamaLibraryPath`) |
| RAM & Disk telemetry | Native Win32 APIs: `GlobalMemoryStatusEx` and `GetDiskFreeSpaceExW` via `package:ffi` |
| Shell Sandbox (FinnAI Code) | `powershell.exe` / `cmd.exe` execution sandbox |
| Window sizing & minimum constraints | `windows/runner/main.cpp` ($1100 \times 750$ default) and `flutter_window.cpp` ($420 \times 550$ minimum via `WM_GETMINMAXINFO`) |

## What works, what does not

| Feature | Windows |
|---|---|
| Chat, streaming, history, search, flows, creations, FinnAI Code | Yes |
| Image attachments | Yes, desktop file dialog via `file_picker` / `image_picker` |
| Read aloud | Yes, Windows SAPI / OneCore voices through `flutter_tts` |
| Voice mode (speech in, Supertonic speech out) | Speech recognition supported; Supertonic on-device neural TTS currently Android-only |
| Desktop keyboard shortcuts | Yes: Enter sends, Shift+Enter newline, Ctrl+N new chat, Ctrl+B toggle sidebar, Ctrl+, settings |
