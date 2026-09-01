import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Edit action
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Back navigation
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Next button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Continue action
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Clipboard confirmation
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get commonCopiedToClipboard;

  /// Open action
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// Stop action
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// Download action
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// Resend action
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get commonResend;

  /// Save skill button
  ///
  /// In en, this message translates to:
  /// **'Save skill'**
  String get commonSaveSkill;

  /// Keep creating action
  ///
  /// In en, this message translates to:
  /// **'Keep creating'**
  String get commonKeepCreating;

  /// Not now action
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// Purge action
  ///
  /// In en, this message translates to:
  /// **'Purge'**
  String get commonPurge;

  /// Clear all action
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get commonClearAll;

  /// Delete everything action
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get commonDeleteEverything;

  /// App title
  ///
  /// In en, this message translates to:
  /// **'Finn AI'**
  String get appTitle;

  /// Product name
  ///
  /// In en, this message translates to:
  /// **'FinnAI'**
  String get appBrandFinnAI;

  /// Unsupported device title
  ///
  /// In en, this message translates to:
  /// **'Finn AI cannot run on this device'**
  String get unsupportedTitle;

  /// Unsupported device body
  ///
  /// In en, this message translates to:
  /// **'Finn AI requires at least 3 GB of RAM and a 64-bit ARM processor to run local models reliably. No model has been downloaded.'**
  String get unsupportedBody;

  /// Welcome heading
  ///
  /// In en, this message translates to:
  /// **'Welcome to Finn AI!'**
  String get onboardingWelcome;

  /// Swipe to start hint
  ///
  /// In en, this message translates to:
  /// **'Swipe to start'**
  String get onboardingSwipeToStart;

  /// Privacy page title
  ///
  /// In en, this message translates to:
  /// **'Finn AI is Privacy-First'**
  String get onboardingPrivacyTitle;

  /// Privacy page body
  ///
  /// In en, this message translates to:
  /// **'Finn AI is designed to respect your privacy.\n\nAI processing and conversation history stay on this device. When a request needs fresh information, Finn AI may send only that request as a web search query and will show the sources it used. Your history and personal profile are never included.\n\nFinn AI is proprietary software and is not open source.'**
  String get onboardingPrivacyBody;

  /// Precautions title
  ///
  /// In en, this message translates to:
  /// **'Before starting, read precautions'**
  String get onboardingPrecautionsTitle;

  /// Precaution 1
  ///
  /// In en, this message translates to:
  /// **'On-device AI prompt processing'**
  String get onboardingPrecautionOne;

  /// Precaution 2
  ///
  /// In en, this message translates to:
  /// **'Offline chat after model download'**
  String get onboardingPrecautionTwo;

  /// Precaution 3
  ///
  /// In en, this message translates to:
  /// **'Encrypted conversation storage'**
  String get onboardingPrecautionThree;

  /// Precaution 4
  ///
  /// In en, this message translates to:
  /// **'Designed for battery efficiency'**
  String get onboardingPrecautionFour;

  /// Install title in progress
  ///
  /// In en, this message translates to:
  /// **'Installing Qwen 3.5 2B'**
  String get onboardingInstallTitleInstalling;

  /// Install title ready
  ///
  /// In en, this message translates to:
  /// **'Qwen 3.5 2B ready'**
  String get onboardingInstallTitleReady;

  /// Preparing message
  ///
  /// In en, this message translates to:
  /// **'Preparing Qwen 3.5 2B for this device…'**
  String get onboardingInstallPreparing;

  /// Ready subtitle
  ///
  /// In en, this message translates to:
  /// **'Ready for private text chat on this device'**
  String get onboardingInstallReadyForChat;

  /// Model + component · size
  ///
  /// In en, this message translates to:
  /// **'{modelName} + multimodal component · {size}'**
  String onboardingInstallModelWithComponent(String modelName, String size);

  /// Model ready label
  ///
  /// In en, this message translates to:
  /// **'Model ready'**
  String get onboardingInstallModelReady;

  /// Progress status
  ///
  /// In en, this message translates to:
  /// **'{status} · {percent}%'**
  String onboardingInstallProgressStatus(String status, String percent);

  /// Bytes progress
  ///
  /// In en, this message translates to:
  /// **'{received} of {total}'**
  String onboardingInstallBytesOf(String received, String total);

  /// Bytes remaining
  ///
  /// In en, this message translates to:
  /// **'{remaining} left'**
  String onboardingInstallBytesLeft(String remaining);

  /// Retry download
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get onboardingInstallRetry;

  /// Retry semantic label
  ///
  /// In en, this message translates to:
  /// **'Retry model download'**
  String get onboardingInstallRetryLabel;

  /// Verification error
  ///
  /// In en, this message translates to:
  /// **'Model verification failed'**
  String get onboardingInstallVerificationFailed;

  /// Upgrade title
  ///
  /// In en, this message translates to:
  /// **'FinnAI Software Upgrade'**
  String get onboardingUpgradeTitle;

  /// Upgrade body
  ///
  /// In en, this message translates to:
  /// **'Finn AI now runs a newer on-device model. Download it to continue chatting privately.'**
  String get onboardingUpgradeBody;

  /// Ready title
  ///
  /// In en, this message translates to:
  /// **'Finn AI is ready!'**
  String get onboardingReadyTitle;

  /// Ready subtitle
  ///
  /// In en, this message translates to:
  /// **'You\'re all set. Finn AI is ready.'**
  String get onboardingReadySubtitle;

  /// You label on final page
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get onboardingYouLabel;

  /// New chat button
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNewChat;

  /// Chat history header
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get chatHistory;

  /// Empty history
  ///
  /// In en, this message translates to:
  /// **'No history'**
  String get chatNoHistory;

  /// Generating indicator
  ///
  /// In en, this message translates to:
  /// **'Finn is generating…'**
  String get chatFinnGenerating;

  /// Typing indicator
  ///
  /// In en, this message translates to:
  /// **'Finn is typing…'**
  String get chatFinnTyping;

  /// Welcome ask anything
  ///
  /// In en, this message translates to:
  /// **'Ask me anything — I run entirely on this device, so your\nchats stay private.'**
  String get chatAskAnything;

  /// Try asking heading
  ///
  /// In en, this message translates to:
  /// **'Try asking'**
  String get chatTryAsking;

  /// Composer hint
  ///
  /// In en, this message translates to:
  /// **'Message Finn…'**
  String get chatMessageHint;

  /// Send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// Stop generation
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get chatStopGeneration;

  /// Copy action
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// Edit message
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatEditMessage;

  /// Rename dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename chat'**
  String get chatRenameTitle;

  /// Rename hint
  ///
  /// In en, this message translates to:
  /// **'Chat title'**
  String get chatRenameHint;

  /// Delete chat title
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get chatDeleteTitle;

  /// Delete chat body
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed. This cannot be undone.'**
  String chatDeleteBody(String title);

  /// Continue generation
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get chatContinue;

  /// Sources heading
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get chatSources;

  /// Offline notice
  ///
  /// In en, this message translates to:
  /// **'Offline — answer may be less accurate. Connect for cited sources.'**
  String get chatOfflineNotice;

  /// Busy snackbar
  ///
  /// In en, this message translates to:
  /// **'Finn AI is finishing another local task.'**
  String get chatFinishingTask;

  /// Prepare error
  ///
  /// In en, this message translates to:
  /// **'Could not prepare chat. Check the model and storage, then try again.'**
  String get chatCouldNotPrepare;

  /// Generating in creation
  ///
  /// In en, this message translates to:
  /// **'Generating in {title}'**
  String chatGeneratingIn(String title);

  /// Download prompt title
  ///
  /// In en, this message translates to:
  /// **'Download the AI model for offline chat?'**
  String get chatDownloadModelTitle;

  /// Download body
  ///
  /// In en, this message translates to:
  /// **'{size} downloads once and is verified before use. The download continues in the background.'**
  String chatDownloadModelBody(String size);

  /// Hi prefix
  ///
  /// In en, this message translates to:
  /// **'Hi, I’m Finn'**
  String get chatHiPrefix;

  /// Finn AI label
  ///
  /// In en, this message translates to:
  /// **'Finn AI'**
  String get chatFinnAI;

  /// Settings title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// AI model section
  ///
  /// In en, this message translates to:
  /// **'AI MODEL'**
  String get settingsAiModel;

  /// Storage section
  ///
  /// In en, this message translates to:
  /// **'STORAGE & DATA'**
  String get settingsStorageData;

  /// Privacy section
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & LEGAL'**
  String get settingsPrivacyLegal;

  /// About section
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsAbout;

  /// Saved conversations count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chat (Encrypted)} other{{count} chats (Encrypted)}}'**
  String settingsSavedConversations(int count);

  /// Releasing memory
  ///
  /// In en, this message translates to:
  /// **'Releasing Memory…'**
  String get settingsReleasingMemory;

  /// Purge memory row
  ///
  /// In en, this message translates to:
  /// **'Purge AI Memory'**
  String get settingsPurgeMemory;

  /// Purge dialog title
  ///
  /// In en, this message translates to:
  /// **'Purge AI Memory?'**
  String get settingsPurgeMemoryTitle;

  /// Purge body
  ///
  /// In en, this message translates to:
  /// **'This will unload the AI model from RAM. It will be reloaded automatically on the next message.'**
  String get settingsPurgeMemoryBody;

  /// Purge success
  ///
  /// In en, this message translates to:
  /// **'AI model memory released.'**
  String get settingsPurgeMemoryReleased;

  /// Clear history row
  ///
  /// In en, this message translates to:
  /// **'Clear All Chat History'**
  String get settingsClearHistory;

  /// Clear title
  ///
  /// In en, this message translates to:
  /// **'Clear All Conversations?'**
  String get settingsClearHistoryTitle;

  /// Clear body
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all chat history. This action cannot be undone.'**
  String get settingsClearHistoryBody;

  /// Clear success
  ///
  /// In en, this message translates to:
  /// **'All conversations cleared.'**
  String get settingsClearHistorySuccess;

  /// Clear failure
  ///
  /// In en, this message translates to:
  /// **'Could not clear conversations. Check storage and try again.'**
  String get settingsClearHistoryFailure;

  /// Delete all row
  ///
  /// In en, this message translates to:
  /// **'Delete All Local Data'**
  String get settingsDeleteAllData;

  /// Delete all title
  ///
  /// In en, this message translates to:
  /// **'Delete All Local Data?'**
  String get settingsDeleteAllDataTitle;

  /// Delete all body
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes encrypted conversations and keys, downloaded AI models, creations, profile preferences, skills, and onboarding state. Finn AI will return to a clean first run.'**
  String get settingsDeleteAllDataBody;

  /// Deleting progress
  ///
  /// In en, this message translates to:
  /// **'Deleting All Local Data…'**
  String get settingsDeleteAllDataDeleting;

  /// Delete success
  ///
  /// In en, this message translates to:
  /// **'All local data deleted. Returning to onboarding.'**
  String get settingsDeleteAllDataSuccess;

  /// Partial failure
  ///
  /// In en, this message translates to:
  /// **'Partial deletion failure: Failed to delete {items}.'**
  String settingsDeleteAllDataPartialFailure(String items);

  /// Privacy policy row
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// Unconfigured
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy URL is unconfigured (set FINN_PRIVACY_POLICY_URL).'**
  String get settingsPrivacyPolicyUnconfigured;

  /// Launch failed
  ///
  /// In en, this message translates to:
  /// **'Could not launch {url}'**
  String settingsPrivacyPolicyLaunchFailed(String url);

  /// Terms row
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get settingsTermsOfUse;

  /// Terms unconfigured
  ///
  /// In en, this message translates to:
  /// **'Terms of Use URL is unconfigured (set FINN_TERMS_URL).'**
  String get settingsTermsUnconfigured;

  /// Terms launch failed
  ///
  /// In en, this message translates to:
  /// **'Could not launch {url}'**
  String settingsTermsLaunchFailed(String url);

  /// Support row
  ///
  /// In en, this message translates to:
  /// **'Support Contact'**
  String get settingsSupportContact;

  /// Support unavailable
  ///
  /// In en, this message translates to:
  /// **'Support contact is unavailable.'**
  String get settingsSupportUnavailable;

  /// Support email
  ///
  /// In en, this message translates to:
  /// **'Support email: {email}'**
  String settingsSupportEmailLabel(String email);

  /// Support launch
  ///
  /// In en, this message translates to:
  /// **'Could not launch {url}'**
  String settingsSupportLaunchFailed(String url);

  /// Licenses row
  ///
  /// In en, this message translates to:
  /// **'Open-Source Licences'**
  String get settingsOpenSourceLicenses;

  /// App version row
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsAppVersion;

  /// Engine row
  ///
  /// In en, this message translates to:
  /// **'Inference Engine'**
  String get settingsInferenceEngine;

  /// Engine value
  ///
  /// In en, this message translates to:
  /// **'llama.cpp · GGUF'**
  String get settingsInferenceEngineValue;

  /// Privacy mode row
  ///
  /// In en, this message translates to:
  /// **'Privacy Mode'**
  String get settingsPrivacyMode;

  /// Privacy mode value
  ///
  /// In en, this message translates to:
  /// **'Encrypted On-Device'**
  String get settingsPrivacyModeValue;

  /// Model arch row
  ///
  /// In en, this message translates to:
  /// **'Model Architecture'**
  String get settingsModelArchitecture;

  /// Model arch value
  ///
  /// In en, this message translates to:
  /// **'LFM2.5-VL 1.6B (Liquid)'**
  String get settingsModelArchitectureValue;

  /// Language row
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// You page title
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youTitle;

  /// You intro title
  ///
  /// In en, this message translates to:
  /// **'Make Finn feel like yours'**
  String get youIntroTitle;

  /// You intro body
  ///
  /// In en, this message translates to:
  /// **'Your preferences stay on this device and shape future replies.'**
  String get youIntroBody;

  /// About you section
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get youAboutYou;

  /// Name label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get youNameLabel;

  /// Name hint
  ///
  /// In en, this message translates to:
  /// **'What should Finn call you?'**
  String get youNameHint;

  /// About label
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get youAboutLabel;

  /// About hint
  ///
  /// In en, this message translates to:
  /// **'Interests, work, or context Finn should remember'**
  String get youAboutHint;

  /// Instructions label
  ///
  /// In en, this message translates to:
  /// **'Custom instructions'**
  String get youInstructionsLabel;

  /// Instructions hint
  ///
  /// In en, this message translates to:
  /// **'How should Finn respond? Tone, length, style…'**
  String get youInstructionsHint;

  /// Response style
  ///
  /// In en, this message translates to:
  /// **'Response style'**
  String get youResponseStyle;

  /// Balanced
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get youResponseStyleBalanced;

  /// Concise
  ///
  /// In en, this message translates to:
  /// **'Concise'**
  String get youResponseStyleConcise;

  /// Detailed
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get youResponseStyleDetailed;

  /// Creative
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get youResponseStyleCreative;

  /// Save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get youSave;

  /// Saved
  ///
  /// In en, this message translates to:
  /// **'Personalization saved locally.'**
  String get youSaved;

  /// Save failed
  ///
  /// In en, this message translates to:
  /// **'Could not save changes.'**
  String get youSaveFailed;

  /// Skills title
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsTitle;

  /// Skills subtitle
  ///
  /// In en, this message translates to:
  /// **'{count} available · skills guide relevant replies'**
  String skillsSubtitle(String count);

  /// New skill
  ///
  /// In en, this message translates to:
  /// **'New skill'**
  String get skillsNewSkill;

  /// Empty skills
  ///
  /// In en, this message translates to:
  /// **'No custom skills yet. Create one for a workflow you repeat.'**
  String get skillsNoSkills;

  /// Instruction hint
  ///
  /// In en, this message translates to:
  /// **'Write a reusable instruction Finn should apply when relevant.'**
  String get skillsInstructionHint;

  /// Delete skill title
  ///
  /// In en, this message translates to:
  /// **'Delete this skill?'**
  String get skillsDeleteTitle;

  /// Delete body
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be removed from this device.'**
  String skillsDeleteBody(String name);

  /// Limit
  ///
  /// In en, this message translates to:
  /// **'Skill limit reached (4). Delete one to add another.'**
  String get skillsLimitReached;

  /// Name label
  ///
  /// In en, this message translates to:
  /// **'Skill name'**
  String get skillsNameLabel;

  /// Instruction label
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get skillsInstructionLabel;

  /// Creations title
  ///
  /// In en, this message translates to:
  /// **'Creations'**
  String get creationsTitle;

  /// Creations subtitle
  ///
  /// In en, this message translates to:
  /// **'Turn an idea into a structured plan, entirely on device.'**
  String get creationsSubtitle;

  /// What making
  ///
  /// In en, this message translates to:
  /// **'What are we making?'**
  String get creationsWhatAreWeMaking;

  /// Original brief
  ///
  /// In en, this message translates to:
  /// **'Original brief'**
  String get creationsOriginalBrief;

  /// Finn adapts
  ///
  /// In en, this message translates to:
  /// **'Finn adapts the structure to the format.'**
  String get creationsFinnAdapts;

  /// Composer hint
  ///
  /// In en, this message translates to:
  /// **'Describe what you want to make…'**
  String get creationsComposerHint;

  /// Stop title
  ///
  /// In en, this message translates to:
  /// **'Stop this creation?'**
  String get creationsStopTitle;

  /// Stop body
  ///
  /// In en, this message translates to:
  /// **'The unfinished result will be discarded. Your prompt will stay here.'**
  String get creationsStopBody;

  /// Delete title
  ///
  /// In en, this message translates to:
  /// **'Delete this creation?'**
  String get creationsDeleteTitle;

  /// Delete body
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed from this device.'**
  String creationsDeleteBody(String title);

  /// Opening
  ///
  /// In en, this message translates to:
  /// **'Opening creations'**
  String get creationsOpening;

  /// Generating
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get creationsGenerating;

  /// Discarded
  ///
  /// In en, this message translates to:
  /// **'Creation discarded'**
  String get creationsDiscarded;

  /// Story
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get creationsKindStory;

  /// Plan
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get creationsKindPlan;

  /// Email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get creationsKindEmail;

  /// Report title
  ///
  /// In en, this message translates to:
  /// **'Report AI Response'**
  String get reportTitle;

  /// Report subtitle
  ///
  /// In en, this message translates to:
  /// **'Help us maintain safe and accurate AI responses. Reports are reviewed to improve FinnAI safeguards.'**
  String get reportSubtitle;

  /// Reason label
  ///
  /// In en, this message translates to:
  /// **'Reason for report'**
  String get reportReasonLabel;

  /// Include prompt
  ///
  /// In en, this message translates to:
  /// **'Include my prompt in this report'**
  String get reportIncludePrompt;

  /// Preview
  ///
  /// In en, this message translates to:
  /// **'Reported response preview'**
  String get reportResponsePreview;

  /// Continue hint
  ///
  /// In en, this message translates to:
  /// **'Continue opens a complete report addressed to finn_org@proton.me. Nothing is sent until you review and send it in your email app.'**
  String get reportContinueHint;

  /// Continue to email
  ///
  /// In en, this message translates to:
  /// **'Continue to Email'**
  String get reportContinueToEmail;

  /// Review
  ///
  /// In en, this message translates to:
  /// **'Review the report in your email app, then send it.'**
  String get reportReviewInEmail;

  /// Not configured
  ///
  /// In en, this message translates to:
  /// **'The report email address is not configured.'**
  String get reportNotConfigured;

  /// Harmful
  ///
  /// In en, this message translates to:
  /// **'Harmful or unsafe'**
  String get reportCategoryHarmful;

  /// Incorrect
  ///
  /// In en, this message translates to:
  /// **'Incorrect or misleading'**
  String get reportCategoryIncorrect;

  /// Biased
  ///
  /// In en, this message translates to:
  /// **'Biased or unfair'**
  String get reportCategoryBiased;

  /// Other
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportCategoryOther;

  /// Snack
  ///
  /// In en, this message translates to:
  /// **'AI model memory released.'**
  String get snackModelMemoryReleased;

  /// Saved conversations row label
  ///
  /// In en, this message translates to:
  /// **'Saved Conversations'**
  String get settingsSavedConversationsLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
