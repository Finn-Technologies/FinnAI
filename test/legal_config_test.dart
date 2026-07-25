import 'package:finn_ai/src/config/legal_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegalConfig Environment Variable Tests', () {
    test('Default unconfigured state returns safe fallbacks', () {
      expect(LegalConfig.hasSupportEmail, isFalse);
      expect(LegalConfig.hasPrivacyPolicyUrl, isFalse);
      expect(LegalConfig.hasTermsUrl, isFalse);

      expect(LegalConfig.resolvedSupportEmail, contains('Unconfigured'));
      expect(LegalConfig.resolvedPrivacyPolicyUrl, contains('Unconfigured'));
      expect(LegalConfig.resolvedTermsUrl, contains('Unconfigured'));
    });
  });
}
