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

/// Registers third-party AI model licenses and open-source notices.
void registerModelLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const _LfmLicenseEntry();
    // The native llama.cpp/ggml .so libraries ship inside
    // android/app/libs/llama-cpp-dart.aar and are not visible to
    // showLicensePage(), so their MIT license is registered manually here.
    yield const _LlamaCppLicenseEntry();
  });
}
