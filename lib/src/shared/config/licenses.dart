import 'package:flutter/foundation.dart';

class _LfmLicenseEntry extends LicenseEntry {
  const _LfmLicenseEntry();

  @override
  Iterable<String> get packages => const [
        'liquid_ai_lfm2_5_vl',
        'lfm_open_license',
      ];

  @override
  Iterable<LicenseParagraph> get paragraphs sync* {
    yield const LicenseParagraph(
      'LFM Open License v1.0\n'
      'Copyright (c) 2025-2026 Liquid AI, Inc. All rights reserved.\n\n'
      '1. Definitions\n'
      '"Model" means the machine learning model, weights, parameters, and associated software artifacts provided by Liquid AI under this License.\n'
      '"You" means an individual or Legal Entity exercising permissions granted by this License.\n\n'
      '2. Grant of Rights\n'
      'Subject to the terms and conditions of this License, Liquid AI hereby grants You a perpetual, worldwide, non-exclusive, no-charge, royalty-free copyright license to reproduce, prepare derivative works of, publicly display, publicly perform, sublicense, and distribute the Model and Derivative Works.\n\n'
      '3. Conditions and Restrictions\n'
      'a. Commercial Revenue Threshold: Use of the Model or Derivative Works by or on behalf of any commercial entity whose aggregate annual gross revenue exceeds \$10,000,000 USD (or equivalent in other currencies) requires a separate commercial license from Liquid AI (contact sales@liquid.ai).\n'
      'b. Attribution: You must retain all copyright, patent, trademark, and attribution notices from the source form of the Model.\n'
      'c. Notice: You must cause any work that You distribute to include a prominent notice stating that You modified the files if any modifications were made, and provide a copy of this License.\n'
      'd. Acceptable Use: You agree not to use the Model for any illegal, hazardous, or harmful purposes.\n\n'
      '4. Disclaimer of Warranty\n'
      'THE MODEL IS PROVIDED "AS IS", WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.\n\n'
      '5. Limitation of Liability\n'
      'IN NO EVENT SHALL LIQUID AI BE LIABLE FOR ANY DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE MODEL.',
      0,
    );
  }
}

class _LlamaCppLicenseEntry extends LicenseEntry {
  const _LlamaCppLicenseEntry();

  @override
  Iterable<String> get packages => const [
        'llama_cpp',
        'ggml',
      ];

  @override
  Iterable<LicenseParagraph> get paragraphs sync* {
    yield const LicenseParagraph(
      'llama.cpp & ggml\n'
      'MIT License\n\n'
      'Copyright (c) 2013-2024 Georgi Gerganov and contributors\n\n'
      'Permission is hereby granted, free of charge, to any person obtaining a '
      'copy of this software and associated documentation files (the '
      '"Software"), to deal in the Software without restriction, including '
      'without limitation the rights to use, copy, modify, merge, publish, '
      'distribute, sublicense, and/or sell copies of the Software, and to '
      'permit persons to whom the Software is furnished to do so, subject to '
      'the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be included '
      'in all copies or substantial portions of the Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS '
      'OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
      'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. '
      'IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY '
      'CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, '
      'TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE '
      'SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
      0,
    );
  }
}

class _SpeechLicenseEntry extends LicenseEntry {
  const _SpeechLicenseEntry();

  @override
  Iterable<String> get packages => const [
        'sherpa-onnx',
        'onnxruntime',
        'whisper',
        'silero-vad',
        'supertonic',
      ];

  @override
  Iterable<LicenseParagraph> get paragraphs sync* {
    yield const LicenseParagraph(
      'On-device speech recognition and spoken replies\n\n'
      'sherpa-onnx (k2-fsa): Apache License 2.0. '
      'https://github.com/k2-fsa/sherpa-onnx\n'
      'ONNX Runtime (Microsoft): MIT License. '
      'https://github.com/microsoft/onnxruntime\n'
      'Whisper (OpenAI), the speech model: MIT License, Copyright (c) 2022 '
      'OpenAI. https://github.com/openai/whisper\n'
      'Silero VAD: MIT License, Copyright (c) 2020-present Silero Team. '
      'https://github.com/snakers4/silero-vad\n'
      'Supertonic 3 (Supertone Inc.), the voice model: BigScience OpenRAIL-M '
      'License; its sample code, from which the text handling is derived, is '
      'MIT License, Copyright (c) 2025 Supertone Inc. '
      'https://huggingface.co/supertone-oss-archive/supertonic-3\n\n'
      'The Supertonic model is used under its OpenRAIL-M licence, which allows '
      'commercial use and requires that it is not used for the purposes the '
      'licence restricts, among them: generating or spreading disinformation, '
      'impersonating a person without their consent, harassment, and '
      'discrimination. FinnAI uses it only to read replies aloud, with four '
      'built-in voices, and never clones a voice. Whoever receives the model '
      'is bound by the same restrictions. The full licence is at '
      'https://huggingface.co/supertone-oss-archive/supertonic-3/blob/main/LICENSE.\n\n'
      'The speech library is built from the sherpa-onnx source with its '
      'text-to-speech part switched off, so it contains no espeak-ng.',
      0,
    );
  }
}

/// v86 is an asset (JavaScript and WebAssembly), not a Dart package, so
/// showLicensePage() would not list it; the Linux image it boots is
/// downloaded, not shipped, and is named here with its licences.
class _ContainerLicenseEntry extends LicenseEntry {
  const _ContainerLicenseEntry();

  @override
  Iterable<String> get packages => const ['v86'];

  @override
  Iterable<LicenseParagraph> get paragraphs sync* {
    yield const LicenseParagraph(
      'FinnAI Code Linux container\n\n'
      'v86, the PC emulator: BSD 2-Clause License. '
      'https://github.com/copy/v86\n\nCopyright (c) 2012, The v86 '
      'contributors All rights reserved.\n\nRedistribution and use in '
      'source and binary forms, with or without modification, are '
      'permitted provided that the following conditions are met:\n\n1. '
      'Redistributions of source code must retain the above copyright '
      'notice, this list of conditions and the following disclaimer. 2. '
      'Redistributions in binary form must reproduce the above copyright '
      'notice, this list of conditions and the following disclaimer in '
      'the documentation and/or other materials provided with the '
      'distribution.\n\nTHIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS '
      'AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, '
      'INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF '
      'MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE '
      'DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS '
      'BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, '
      'EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED '
      'TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, '
      'DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON '
      'ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR'
      ' TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT '
      'OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF'
      ' SUCH DAMAGE.\n\n'
      'Downloaded on request from the v86 project, not part of this app: the '
      'Linux kernel and BusyBox (GPL-2.0) and SeaBIOS (LGPL-3.0).',
      0,
    );
  }
}

/// Registers third-party AI model licenses and open-source notices.
void registerModelLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const _LfmLicenseEntry();
    // The native llama.cpp/ggml .so libraries ship inside
    // android/app/libs/llama-cpp-dart.aar and are not visible to
    // showLicensePage(), so their MIT license is registered manually here.
    yield const _LlamaCppLicenseEntry();
    // sherpa-onnx and ONNX Runtime are native libraries inside the
    // sherpa_onnx Android packages, also invisible to showLicensePage().
    yield const _SpeechLicenseEntry();
    yield const _ContainerLicenseEntry();
  });
}
