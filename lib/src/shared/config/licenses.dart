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
        'piper',
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
      'Piper (Rhasspy), the voice models: MIT License. '
      'https://github.com/rhasspy/piper\n\n'
      'Voice data: English "LJ Speech", public domain. German "Thorsten-Voice", '
      'Spanish (davefx), Italian (Paola Persico) and Russian (denis), CC0 1.0. '
      'French "SIWIS", University of Edinburgh, CC BY 4.0 '
      '(https://datashare.is.ed.ac.uk/handle/10283/2353).',
      0,
    );
  }
}

class _EspeakLicenseEntry extends LicenseEntry {
  const _EspeakLicenseEntry();

  @override
  Iterable<String> get packages => const ['espeak-ng'];

  @override
  Iterable<LicenseParagraph> get paragraphs sync* {
    yield const LicenseParagraph(
      'espeak-ng\n'
      'GNU General Public License, version 3 or later\n\n'
      'FinnAI\'s on-device speech library (sherpa-onnx) includes espeak-ng, '
      'which turns text into phonemes for the spoken-reply voices. espeak-ng is '
      'free software licensed under the GNU General Public License, version 3 '
      'or (at your option) any later version: you can redistribute it and/or '
      'modify it under the terms of that licence, published at '
      'https://www.gnu.org/licenses/gpl-3.0.html. It is distributed in the hope '
      'that it will be useful, but WITHOUT ANY WARRANTY; without even the '
      'implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR '
      'PURPOSE.\n\n'
      'The source code of espeak-ng is available at '
      'https://github.com/espeak-ng/espeak-ng and of the sherpa-onnx build that '
      'contains it at https://github.com/k2-fsa/sherpa-onnx. To ask for a copy '
      'of the corresponding source, write to finn_org@proton.me.',
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
    // sherpa-onnx, ONNX Runtime and espeak-ng are native libraries inside the
    // sherpa_onnx Android packages, also invisible to showLicensePage().
    yield const _SpeechLicenseEntry();
    yield const _EspeakLicenseEntry();
  });
}
