class LegalConfig {
  const LegalConfig._();

  static const String supportUrl = String.fromEnvironment(
    'FINN_SUPPORT_URL',
    defaultValue: 'https://finn-org.vercel.app/support',
  );

  static const String supportEmail = String.fromEnvironment(
    'FINN_SUPPORT_EMAIL',
    defaultValue: '',
  );

  static const String privacyPolicyUrl = String.fromEnvironment(
    'FINN_PRIVACY_POLICY_URL',
    defaultValue: 'https://finn-org.vercel.app/privacy',
  );

  static const String termsUrl = String.fromEnvironment(
    'FINN_TERMS_URL',
    defaultValue: 'https://finn-org.vercel.app/terms',
  );

  static bool get hasSupportUrl => supportUrl.trim().isNotEmpty;
  static bool get hasSupportEmail => supportEmail.trim().isNotEmpty;
  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.trim().isNotEmpty;
  static bool get hasTermsUrl => termsUrl.trim().isNotEmpty;

  static String get resolvedSupportEmail => hasSupportEmail
      ? supportEmail.trim()
      : 'Unconfigured (set FINN_SUPPORT_EMAIL)';

  static String get resolvedSupportUrl =>
      hasSupportUrl ? supportUrl.trim() : 'Unconfigured (set FINN_SUPPORT_URL)';

  static String get resolvedPrivacyPolicyUrl => hasPrivacyPolicyUrl
      ? privacyPolicyUrl.trim()
      : 'Unconfigured (set FINN_PRIVACY_POLICY_URL)';

  static String get resolvedTermsUrl =>
      hasTermsUrl ? termsUrl.trim() : 'Unconfigured (set FINN_TERMS_URL)';
}
