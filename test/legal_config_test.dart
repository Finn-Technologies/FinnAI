import 'package:finn_ai/src/config/legal_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegalConfig Environment Variable Tests', () {
    test('Production website links are available by default', () {
      expect(LegalConfig.hasSupportEmail, isTrue);
      expect(LegalConfig.hasSupportUrl, isTrue);
      expect(LegalConfig.hasPrivacyPolicyUrl, isTrue);
      expect(LegalConfig.hasTermsUrl, isTrue);

      expect(LegalConfig.resolvedSupportEmail, 'finn_org@proton.me');
      expect(
        LegalConfig.resolvedSupportUrl,
        'https://finn-org.vercel.app/support',
      );
      expect(
        LegalConfig.resolvedPrivacyPolicyUrl,
        'https://finn-org.vercel.app/privacy',
      );
      expect(LegalConfig.resolvedTermsUrl, 'https://finn-org.vercel.app/terms');
    });
  });
}
