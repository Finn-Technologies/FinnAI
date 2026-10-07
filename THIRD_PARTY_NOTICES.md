# Third-Party Licences & Notices

FinnAI relies on open-source software and model weights. This document contains third-party notices and license terms for primary components.

*Note: Complete license texts for all transitive Flutter packages can be viewed in-app via `showLicensePage()` in app Settings under Open-Source Licences.*

---

## 1. llama.cpp & ggml
- **Project**: `llama.cpp` and `ggml`
- **License**: MIT License
```text
MIT License

Copyright (c) 2013-2024 Georgi Gerganov and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 2. LFM2.5-VL 1.6B and 3B Models (Liquid AI)
- **Model**: LFM2.5-VL 1.6B or, on capable devices, LFM2.5-VL 3B (GGUF format, Q4_0 weights + F16 vision projector)
- **Creator**: Liquid AI, Inc.
- **Source**: Downloaded at runtime from Hugging Face (`LiquidAI/LFM2.5-VL-1.6B-GGUF`, `LiquidAI/LFM2.5-VL-3B-GGUF`)
- **License**: LFM Open License v1.0

```text
LFM Open License v1.0
Copyright (c) 2025-2026 Liquid AI, Inc. All rights reserved.

1. Definitions
"Model" means the machine learning model, weights, parameters, and associated
software artifacts provided by Liquid AI under this License.
"You" means an individual or Legal Entity exercising permissions granted by
this License.

2. Grant of Rights
Subject to the terms and conditions of this License, Liquid AI hereby grants
You a perpetual, worldwide, non-exclusive, no-charge, royalty-free copyright
license to reproduce, prepare derivative works of, publicly display, publicly
perform, sublicense, and distribute the Model and Derivative Works.

3. Conditions and Restrictions
a. Commercial Revenue Threshold: Use of the Model or Derivative Works by or on
   behalf of any commercial entity whose aggregate annual gross revenue exceeds
   $10,000,000 USD (or equivalent in other currencies) requires a separate
   commercial license from Liquid AI (contact sales@liquid.ai).
b. Attribution: You must retain all copyright, patent, trademark, and
   attribution notices from the source form of the Model.
c. Notice: You must cause any work that You distribute to include a prominent
   notice stating that You modified the files if any modifications were made,
   and provide a copy of this License.
d. Acceptable Use: You agree not to use the Model for any illegal, hazardous,
   or harmful purposes.

4. Disclaimer of Warranty
THE MODEL IS PROVIDED "AS IS", WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
EITHER EXPRESS OR IMPLIED.

5. Limitation of Liability
IN NO EVENT SHALL LIQUID AI BE LIABLE FOR ANY DAMAGES ARISING OUT OF THE USE
OR INABILITY TO USE THE MODEL.
```

---

## 3. Vendored `llama_cpp_dart` Dart Package
- **Project**: `llama_cpp_dart` (vendored under `third_party/llama_cpp_dart`)
- **License**: MIT License
- **Modifications**: FinnAI carries local modifications to the upstream package (worker-protocol prefill operation, native runtime audit metadata). See `third_party/llama_cpp_dart/FINNAI_PATCH.md`.
```text
MIT License

Copyright (c) 2024 adel boussaken

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 4. Cryptography Package (`package:cryptography`)
- **License**: Apache License, Version 2.0
```text
Copyright 2019-2026 Gohilla.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## 5. Flutter & Dart SDK Packages
- **Flutter Framework**: BSD 3-Clause License
- **flutter_secure_storage**: BSD 3-Clause License
- **package_info_plus**: BSD 3-Clause License
- **path_provider**: BSD 3-Clause License
- **url_launcher**: BSD 3-Clause License
- **http**: BSD 3-Clause License
- **crypto**: BSD 3-Clause License
- **image_picker**: BSD 3-Clause License
- **intl**: BSD 3-Clause License
- **flutter_svg**: MIT License
- **hugeicons**: MIT License
- **cupertino_icons**: MIT License
- **file_picker**: MIT License

```text
BSD 3-Clause License

Copyright 2014 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of Google Inc. nor the names of its contributors may be
      used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

---

## 6. On-device speech recognition
Used by voice mode; the model files are downloaded on first use.
- **sherpa-onnx** (`sherpa_onnx` Dart package and native libraries): Apache License 2.0. https://github.com/k2-fsa/sherpa-onnx
- **ONNX Runtime** (bundled with sherpa-onnx): MIT License. https://github.com/microsoft/onnxruntime
- **Whisper base**, multilingual, int8 ONNX export by the sherpa-onnx project (`csukuangfj/sherpa-onnx-whisper-base`): MIT License, Copyright (c) 2022 OpenAI. https://github.com/openai/whisper
- **Silero VAD**: MIT License, Copyright (c) 2020-present Silero Team. https://github.com/snakers4/silero-vad
- **Supertonic 3** (Supertone Inc.), the spoken-reply voice, downloaded on first use from `supertone-oss-archive/supertonic-3` on Hugging Face: model weights under the **BigScience OpenRAIL-M** License; sample code (from which FinnAI's text handling is derived) under the MIT License, Copyright (c) 2025 Supertone Inc. https://huggingface.co/supertone-oss-archive/supertonic-3
  - OpenRAIL-M permits commercial use and redistribution, and passes its **use restrictions** on to everyone who receives the model (for example: no disinformation, no impersonation of a person without consent, no harassment or discrimination, no use that harms minors). FinnAI reads replies aloud with four built-in styles and never clones a voice. The licence text is at https://huggingface.co/supertone-oss-archive/supertonic-3/blob/main/LICENSE.
  - It reads characters directly, so it needs **no phonemizer**. FinnAI runs it with its own C++ layer (`android/app/src/main/cpp/finn_supertonic.cc`) over ONNX Runtime (MIT).
- **sherpa-onnx is built from source** (`tool/rebuild_sherpa_android.sh`, Apache License 2.0) with text-to-speech switched off, so the shipped library does **not** contain espeak-ng (GPL-3.0); speech *recognition* is unaffected. The earlier Piper voices, which needed espeak-ng, are removed.
- **flutter_pcm_sound** (speaker output): MIT License. **archive** (unpacking the speech-recognition model): MIT License.
- **record** (microphone capture): BSD-style licence; the full text is in the in-app Open-Source Licences page.

---

## 6a. FinnAI Code Linux container
- **v86** (`assets/code_container/libv86.js`, `v86.wasm`, version 0.5.470, commit `6db8b15`): BSD 2-Clause License, Copyright (c) 2012, The v86 contributors. https://github.com/copy/v86 — the licence text is bundled as `assets/code_container/LICENSE.v86`.
- Downloaded on request from the v86 project, not shipped in the app: the **Linux kernel** and **BusyBox** userland in its Buildroot image (GPL-2.0; sources at https://kernel.org and https://busybox.net, build configuration in the v86 repository), and **SeaBIOS** with its VGA BIOS (LGPL-3.0; https://www.seabios.org). FinnAI does not modify or redistribute them; each file is checked against a pinned SHA-256 (ADR 0011).
- **webview_flutter** (hosts the emulator): BSD 3-Clause License.

---

## 7. Typography & Fonts
- **Geist** (the app's typeface): SIL Open Font License, Version 1.1. Copyright 2024 The Geist Project Authors. Licence text: `assets/fonts/Geist-OFL.txt`.
- **Hugeicons** icons (`hugeicons_pro`, Solid style): MIT License, Copyright (c) 2024 GB coder.
- **JetBrains Mono** (FinnAI Code: code, commands, output): SIL Open Font License, Version 1.1. Copyright 2020 The JetBrains Mono Project Authors. Licence text: `assets/fonts/JetBrainsMono-OFL.txt`.

## FinnAI Code: Linux sandbox (Android)

- **proot** (https://github.com/termux/proot, commit a179d3e8a4e045aaa1fb8cc3284f23509d96d353): GNU General Public License, version 2. Shipped as `libproot.so` and `libproot-loader.so`, built by `tool/build_proot_android.sh` from that exact commit; the corresponding source is available at that address and on request.
- **talloc 2.4.2** (https://www.samba.org/ftp/talloc/): GNU Lesser General Public License, version 3, linked statically into proot. Source: the pinned archive in the build script.
- **Alpine Linux minirootfs 3.24.2** (https://alpinelinux.org): downloaded on the user's request, not shipped in the app; busybox (GPL-2.0), musl (MIT) and the other packages under their own licences. Packages the user installs come from Alpine's repositories under theirs.
