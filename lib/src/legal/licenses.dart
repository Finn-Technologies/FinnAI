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

/// Registers third-party AI model licenses and open-source notices.
void registerModelLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const _LfmLicenseEntry();
  });
}
