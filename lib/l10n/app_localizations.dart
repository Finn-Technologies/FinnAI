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
    Locale('it')
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
  /// **'Installing LFM2.5-VL 1.6B'**
  String get onboardingInstallTitleInstalling;

  /// Install title ready
  ///
  /// In en, this message translates to:
  /// **'LFM2.5-VL 1.6B ready'**
  String get onboardingInstallTitleReady;

  /// Preparing message
  ///
  /// In en, this message translates to:
  /// **'Preparing LFM2.5-VL 1.6B for this device…'**
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
  /// **'Ask me anything — I run entirely on this device, so your\nconversations never leave your phone.'**
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

  /// Shown in the chat when the saved history file cannot be opened, so replies are kept in memory only for this session.
  ///
  /// In en, this message translates to:
  /// **'Finn couldn\'t open your chat history on this device, so new replies won\'t be saved.'**
  String get chatHistoryUnavailableNotice;

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

  /// Attachment picker failure snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the picker. Please try again.'**
  String get chatAttachmentPickFailed;

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
  /// **'{size} downloads once and is verified before use. The download resumes safely after an interrupted connection, and your chats stay on this device.'**
  String chatDownloadModelBody(String size);

  /// Hi prefix
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m Finn.'**
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
  /// **'This permanently deletes encrypted conversations and keys, downloaded AI models, creations, profile preferences, skills, and onboarding state. FinnAI will return to a clean first run.'**
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

  /// Spoken responses toggle label
  ///
  /// In en, this message translates to:
  /// **'Spoken responses'**
  String get settingsSpokenResponses;

  /// Spoken responses toggle description
  ///
  /// In en, this message translates to:
  /// **'Finn reads replies aloud in voice mode. Your voice transcript is processed by your device\'s speech recognition, which may need internet.'**
  String get settingsSpokenResponsesBody;

  /// Mic button semantics
  ///
  /// In en, this message translates to:
  /// **'Talk to Finn'**
  String get voiceMicSemantic;

  /// Voice sheet listening state
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// Voice sheet idle prompt
  ///
  /// In en, this message translates to:
  /// **'Tap the mic and speak'**
  String get voiceTapToSpeak;

  /// Voice sheet transcript received
  ///
  /// In en, this message translates to:
  /// **'Heard you'**
  String get voiceHeardYou;

  /// Voice sheet empty result message
  ///
  /// In en, this message translates to:
  /// **'Didn\'t catch that — try again'**
  String get voiceDidNotCatch;

  /// Voice sheet thinking state
  ///
  /// In en, this message translates to:
  /// **'Finn is thinking…'**
  String get voiceThinking;

  /// Voice sheet speaking state
  ///
  /// In en, this message translates to:
  /// **'Finn is speaking — tap to interrupt'**
  String get voiceSpeaking;

  /// Voice mic denied message
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Enable it in system Settings to use voice mode.'**
  String get voiceMicDenied;

  /// Voice STT unavailable message
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn\'t available right now. Type your message instead.'**
  String get voiceUnavailable;

  /// Voice stop button semantics
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get voiceStopSemantic;

  /// Voice close button semantics
  ///
  /// In en, this message translates to:
  /// **'Close voice mode'**
  String get voiceCloseSemantic;

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
  String skillsSubtitle(int count);

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

  /// Tooltip on the browse toggle in the composer
  ///
  /// In en, this message translates to:
  /// **'Browse the web for this message'**
  String get chatBrowseTooltip;

  /// Accessibility label when browsing is enabled
  ///
  /// In en, this message translates to:
  /// **'Web browsing on'**
  String get chatBrowseOnSemantic;

  /// Accessibility label when browsing is disabled
  ///
  /// In en, this message translates to:
  /// **'Web browsing off'**
  String get chatBrowseOffSemantic;

  /// Header of the live browser activity panel
  ///
  /// In en, this message translates to:
  /// **'Browsing the web'**
  String get chatBrowsingTitle;

  /// Inline indicator shown while a web search is running
  ///
  /// In en, this message translates to:
  /// **'Searching the web…'**
  String get chatSearchingInline;

  /// Collapsed indicator attached to a reply that used a web search
  ///
  /// In en, this message translates to:
  /// **'Searched the web'**
  String get chatSearchedInline;

  /// Accessibility label for expanding the inline search steps
  ///
  /// In en, this message translates to:
  /// **'Show search steps'**
  String get chatShowSearchSteps;

  /// Collapse action in the browser activity panel
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chatBrowsingHide;

  /// Expand action showing how many browser steps ran
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String chatBrowsingSteps(int count);

  /// A completed web search tool call
  ///
  /// In en, this message translates to:
  /// **'Searched the web for “{query}”'**
  String chatBrowsingSearch(String query);

  /// A completed page-open tool call
  ///
  /// In en, this message translates to:
  /// **'Read “{title}”'**
  String chatBrowsingOpen(String title);

  /// A completed find-on-page tool call
  ///
  /// In en, this message translates to:
  /// **'Looked for “{query}” on the page'**
  String chatBrowsingFind(String query);

  /// Creations title
  ///
  /// In en, this message translates to:
  /// **'Creations'**
  String get creationsTitle;

  /// Creations subtitle
  ///
  /// In en, this message translates to:
  /// **'Describe what you want. Finn builds it on device.'**
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

  /// Builder question asking which kind of creation to make
  ///
  /// In en, this message translates to:
  /// **'Is your new Creation an app, a widget or a presentation?'**
  String get creationsAskKind;

  /// Builder prompt once a kind is chosen
  ///
  /// In en, this message translates to:
  /// **'Tell me what your {kind} should do.'**
  String creationsDescribeKind(String kind);

  /// Creation progress: designing
  ///
  /// In en, this message translates to:
  /// **'Designing…'**
  String get creationsStageDesigning;

  /// Creation progress: writing the spec
  ///
  /// In en, this message translates to:
  /// **'Writing…'**
  String get creationsStageWriting;

  /// Creation progress: validating
  ///
  /// In en, this message translates to:
  /// **'Checking the result…'**
  String get creationsStageValidating;

  /// Creation progress: repair round
  ///
  /// In en, this message translates to:
  /// **'Fixing a detail…'**
  String get creationsStageRepairing;

  /// Shown when a deterministic starter creation was substituted
  ///
  /// In en, this message translates to:
  /// **'Finn couldn\'t finish that design, so here is a working starter you can build on.'**
  String get creationsFallbackNote;

  /// Button starting a new creation from the gallery
  ///
  /// In en, this message translates to:
  /// **'New creation'**
  String get creationsNewCreation;

  /// Accessibility label for the composer's choose-type button
  ///
  /// In en, this message translates to:
  /// **'Choose what to create'**
  String get creationsChooseKindSemantic;

  /// No description provided for @creationsFailed.
  ///
  /// In en, this message translates to:
  /// **'Finn could not finish that creation. Please try again.'**
  String get creationsFailed;

  /// No description provided for @creationsHomeScreenUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Home screen widgets aren\'t available on this device.'**
  String get creationsHomeScreenUnsupported;

  /// No description provided for @creationsHomeScreenAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to your home screen.'**
  String get creationsHomeScreenAdded;

  /// No description provided for @creationsHomeScreenFailed.
  ///
  /// In en, this message translates to:
  /// **'That couldn\'t be added to your home screen.'**
  String get creationsHomeScreenFailed;

  /// Confirmation naming the exported file
  ///
  /// In en, this message translates to:
  /// **'Saved {fileName}'**
  String creationsExportedTo(String fileName);

  /// No description provided for @creationsExportDeck.
  ///
  /// In en, this message translates to:
  /// **'Export as PowerPoint'**
  String get creationsExportDeck;

  /// No description provided for @creationsAddToHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Add to home screen'**
  String get creationsAddToHomeScreen;

  /// No description provided for @creationsWidgetPreview.
  ///
  /// In en, this message translates to:
  /// **'This is how it will look on your home screen.'**
  String get creationsWidgetPreview;

  /// No description provided for @creationsKindApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get creationsKindApp;

  /// No description provided for @creationsKindWidget.
  ///
  /// In en, this message translates to:
  /// **'Widget'**
  String get creationsKindWidget;

  /// No description provided for @creationsKindPresentation.
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get creationsKindPresentation;

  /// No description provided for @creationsFilterApps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get creationsFilterApps;

  /// No description provided for @creationsFilterWidgets.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get creationsFilterWidgets;

  /// No description provided for @creationsFilterPresentations.
  ///
  /// In en, this message translates to:
  /// **'Presentations'**
  String get creationsFilterPresentations;

  /// No description provided for @skillsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'That skill could not be saved.'**
  String get skillsSaveFailed;

  /// No description provided for @skillsBuiltForFinn.
  ///
  /// In en, this message translates to:
  /// **'Built for Finn'**
  String get skillsBuiltForFinn;

  /// No description provided for @skillsBuiltForFinnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable only what you need for each kind of work.'**
  String get skillsBuiltForFinnSubtitle;

  /// No description provided for @skillsYourSkills.
  ///
  /// In en, this message translates to:
  /// **'Your skills'**
  String get skillsYourSkills;

  /// No description provided for @skillsYourSkillsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create reusable instructions for your own workflows.'**
  String get skillsYourSkillsSubtitle;

  /// No description provided for @skillsNoneActive.
  ///
  /// In en, this message translates to:
  /// **'No skills active'**
  String get skillsNoneActive;

  /// Summary active count
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String skillsActiveCount(int count);

  /// Confirmation when the export was handed to the share sheet
  ///
  /// In en, this message translates to:
  /// **'Presentation ready to share.'**
  String get creationsExportedShared;

  /// Shown when writing the pptx failed
  ///
  /// In en, this message translates to:
  /// **'That presentation couldn\'t be exported.'**
  String get creationsExportFailed;

  /// Action clearing a mini app's state
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get creationsResetApp;

  /// Deck viewer previous control
  ///
  /// In en, this message translates to:
  /// **'Previous slide'**
  String get creationsPreviousSlide;

  /// Deck viewer next control
  ///
  /// In en, this message translates to:
  /// **'Next slide'**
  String get creationsNextSlide;

  /// Deck viewer position
  ///
  /// In en, this message translates to:
  /// **'Slide {index} of {count}'**
  String creationsSlideOf(int index, int count);

  /// Descriptor for a mini app
  ///
  /// In en, this message translates to:
  /// **'{count} elements'**
  String creationsElementCount(int count);

  /// Descriptor for a home screen widget
  ///
  /// In en, this message translates to:
  /// **'{count} rows'**
  String creationsRowCount(int count);

  /// Descriptor for a presentation
  ///
  /// In en, this message translates to:
  /// **'{count} slides'**
  String creationsSlideCount(int count);

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

  /// Close action
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Retry after failure
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Dismiss a notice
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// Bootstrap failure title
  ///
  /// In en, this message translates to:
  /// **'FinnAI could not start'**
  String get bootstrapErrorTitle;

  /// Bootstrap failure body
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while initializing the AI engine. Your conversations are safe.'**
  String get bootstrapErrorBody;

  /// HEIC snackbar
  ///
  /// In en, this message translates to:
  /// **'HEIC images are not supported. Please share as JPEG or PNG.'**
  String get chatHeicNotSupported;

  /// Multimodal missing snackbar
  ///
  /// In en, this message translates to:
  /// **'Image analysis unavailable: install the image component in Settings.'**
  String get chatImageAnalysisUnavailable;

  /// Attachment menu camera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachmentCamera;

  /// Attachment menu photos
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get attachmentPhotos;

  /// Attachment menu files
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get attachmentFiles;

  /// Attachment button semantics
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get chatAddAttachmentSemantic;

  /// Default prompt for an attached image
  ///
  /// In en, this message translates to:
  /// **'Please analyze this attached image in detail.'**
  String get chatImagePromptDefault;

  /// Default prompt for an attached file
  ///
  /// In en, this message translates to:
  /// **'Please summarize the attached file and highlight its key points.'**
  String get chatFilePromptDefault;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Summarize a web article for me'**
  String get suggestionSummarizeArticle;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Explain a complex topic simply'**
  String get suggestionExplainSimply;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Plan my day in three steps'**
  String get suggestionPlanDay;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Draft a short email'**
  String get suggestionDraftEmail;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Brainstorm names for my new project'**
  String get suggestionBrainstormNames;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Turn a rough idea into a step-by-step plan'**
  String get suggestionIdeaToPlan;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Help me debug a confusing error'**
  String get suggestionDebugError;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Write a quick goodbye note'**
  String get suggestionGoodbyeNote;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Compare two options before I decide'**
  String get suggestionCompareOptions;

  /// Welcome suggestion
  ///
  /// In en, this message translates to:
  /// **'Give me a fresh perspective on a problem'**
  String get suggestionFreshPerspective;

  /// Fallback title for another chat
  ///
  /// In en, this message translates to:
  /// **'another chat'**
  String get chatAnotherChatFallback;

  /// Context menu select action
  ///
  /// In en, this message translates to:
  /// **'Select Text'**
  String get chatSelectText;

  /// Context menu report action
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReportAction;

  /// Bubble semantics hint
  ///
  /// In en, this message translates to:
  /// **'Press and hold for message actions'**
  String get chatMessageActionsHint;

  /// Other-chat notice semantics
  ///
  /// In en, this message translates to:
  /// **'Generating in another chat'**
  String get chatGeneratingInOtherChat;

  /// Reply action tooltip
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get chatRegenerate;

  /// Sources list semantics collapsed
  ///
  /// In en, this message translates to:
  /// **'Hide sources'**
  String get chatHideSources;

  /// Sources list semantics expanded
  ///
  /// In en, this message translates to:
  /// **'Show sources'**
  String get chatShowSources;

  /// Edit message field hint
  ///
  /// In en, this message translates to:
  /// **'Rewrite your message'**
  String get chatRewriteHint;

  /// Composer hint
  ///
  /// In en, this message translates to:
  /// **'Ask anything'**
  String get chatAskAnythingHint;

  /// Composer field semantics
  ///
  /// In en, this message translates to:
  /// **'Message to Finn'**
  String get chatMessageToFinnSemantic;

  /// Stop button semantics
  ///
  /// In en, this message translates to:
  /// **'Stop generating'**
  String get chatStopGeneratingSemantic;

  /// Send button semantics
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSendMessageSemantic;

  /// Header menu tooltip
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get chatOpenMenuTooltip;

  /// Conversation context menu rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRenameAction;

  /// Rename field hint
  ///
  /// In en, this message translates to:
  /// **'Enter chat title'**
  String get chatRenameEnterTitleHint;

  /// Delete dialog body while generating
  ///
  /// In en, this message translates to:
  /// **'Stop the active generation before deleting this chat. Its partial response will be preserved.'**
  String get chatDeleteActiveGenerationBody;

  /// Delete dialog body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this chat history? This action cannot be undone.'**
  String get chatDeleteConfirmBody;

  /// Model status pill
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsModelActive;

  /// Model status pill
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get settingsModelInstalled;

  /// Model status pill
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get settingsModelPartial;

  /// Model status pill
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get settingsModelNotInstalled;

  /// Filter chip for every kind
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get creationsAll;

  /// Filter chip semantics
  ///
  /// In en, this message translates to:
  /// **'{kind} creations'**
  String creationsFilterSemantic(String kind);

  /// Empty state with a filter
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get creationsEmptyFilteredTitle;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Make something useful'**
  String get creationsEmptyTitle;

  /// Empty state body with a filter
  ///
  /// In en, this message translates to:
  /// **'Try another category or create a new one.'**
  String get creationsEmptyFilteredBody;

  /// Empty state body
  ///
  /// In en, this message translates to:
  /// **'Describe an app, widget or presentation below. Finn will shape it into a practical plan.'**
  String get creationsEmptyBody;

  /// Composer hint
  ///
  /// In en, this message translates to:
  /// **'Describe a creation'**
  String get creationsDescribeHint;

  /// Skill card menu tooltip
  ///
  /// In en, this message translates to:
  /// **'Skill actions'**
  String get skillsActionsTooltip;

  /// Skill toggle semantics
  ///
  /// In en, this message translates to:
  /// **'{name} skill'**
  String skillsNameSemantic(String name);

  /// Editor title for an existing skill
  ///
  /// In en, this message translates to:
  /// **'Edit skill'**
  String get skillsEditTitle;

  /// Editor field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get skillsEditorName;

  /// Editor field hint
  ///
  /// In en, this message translates to:
  /// **'What does this skill do?'**
  String get skillsEditorNameHint;

  /// Editor field label
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get skillsEditorDescription;

  /// Editor field hint
  ///
  /// In en, this message translates to:
  /// **'A quick reminder for you'**
  String get skillsEditorDescriptionHint;

  /// Editor field label
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get skillsEditorInstructions;

  /// Editor field hint
  ///
  /// In en, this message translates to:
  /// **'Tell Finn how to approach this kind of task'**
  String get skillsEditorInstructionsHint;

  /// Skill category label
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get skillsCategoryWriting;

  /// Skill category label
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get skillsCategoryDevelopment;

  /// Skill category label
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get skillsCategoryLearning;

  /// Skill category label
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get skillsCategoryPlanning;

  /// Skill category label
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get skillsCategoryCustom;

  /// Name field hint
  ///
  /// In en, this message translates to:
  /// **'Preferred name'**
  String get youNamePlaceholder;

  /// About field label
  ///
  /// In en, this message translates to:
  /// **'Anything Finn should know?'**
  String get youAboutQuestion;

  /// About field hint
  ///
  /// In en, this message translates to:
  /// **'Your work, interests, goals, or context'**
  String get youAboutPlaceholder;

  /// Instructions field label
  ///
  /// In en, this message translates to:
  /// **'How should Finn respond?'**
  String get youInstructionsQuestion;

  /// Instructions field hint
  ///
  /// In en, this message translates to:
  /// **'For example: explain technical terms, use metric units…'**
  String get youInstructionsPlaceholder;

  /// Save button while saving
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get youSaving;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get youSavePreferences;

  /// Style chip semantics
  ///
  /// In en, this message translates to:
  /// **'{style} response style'**
  String youStyleSemantic(String style);

  /// Response style label
  ///
  /// In en, this message translates to:
  /// **'Conversational'**
  String get youResponseStyleConversational;

  /// HTTP submit success snackbar
  ///
  /// In en, this message translates to:
  /// **'Report sent. Thank you for helping keep FinnAI safe.'**
  String get reportSentThanks;

  /// No mail app error
  ///
  /// In en, this message translates to:
  /// **'No email app could be opened. Email finn_org@proton.me directly.'**
  String get reportNoEmailApp;

  /// Details field hint
  ///
  /// In en, this message translates to:
  /// **'Optional additional details...'**
  String get reportDetailsHint;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'Harmful or dangerous'**
  String get reportCategoryHarmfulOrDangerous;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'Hate or harassment'**
  String get reportCategoryHateOrHarassment;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'Sexual content'**
  String get reportCategorySexualContent;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'Child-safety concern'**
  String get reportCategoryChildSafety;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'Self-harm concern'**
  String get reportCategorySelfHarm;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'Illegal or deceptive guidance'**
  String get reportCategoryIllegalOrDeceptive;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'False or misleading response'**
  String get reportCategoryFalseOrMisleading;

  /// Report category
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get reportCategorySpamOrScam;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Optimized automatically'**
  String get statusOptimizedAutomatically;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'AI model is ready'**
  String get statusModelReady;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Download paused'**
  String get statusDownloadPaused;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Model removed'**
  String get statusModelRemoved;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Checking web…'**
  String get statusCheckingWeb;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Searching browser…'**
  String get statusSearchingBrowser;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Thinking on this device'**
  String get statusThinkingOnDevice;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Generated locally'**
  String get statusGeneratedLocally;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get statusStopped;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Ready after runtime reset'**
  String get statusReadyAfterRuntimeReset;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Setting up FinnAI for optimal performance…'**
  String get statusOptimizingForDevice;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'FinnAI is optimized for this device'**
  String get statusOptimizedForDevice;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Checking the download'**
  String get statusCheckingDownload;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Downloading the AI model'**
  String get statusDownloadingModel;

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Downloading {artifact}'**
  String statusDownloadingArtifact(String artifact);

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Verifying {artifact}'**
  String statusVerifyingArtifact(String artifact);

  /// Engine status
  ///
  /// In en, this message translates to:
  /// **'Loading the AI model'**
  String get statusLoadingModel;

  /// Page title for the device actions screen
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get deviceActionsTitle;

  /// One-line explanation of what the Actions page does
  ///
  /// In en, this message translates to:
  /// **'Ask Finn to do something on your phone — set an alarm, start a timer, or open a setting.'**
  String get deviceActionsIntro;

  /// Heading above the example request chips
  ///
  /// In en, this message translates to:
  /// **'Try one of these'**
  String get deviceActionsExamples;

  /// Placeholder inside the action request field
  ///
  /// In en, this message translates to:
  /// **'What should Finn do?'**
  String get deviceActionsHint;

  /// Button that submits an action request
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get deviceActionsRun;

  /// Shown while the request is being resolved
  ///
  /// In en, this message translates to:
  /// **'Working out what to do…'**
  String get deviceActionsResolving;

  /// Shown when a request could not be turned into an action
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t turn that into an action. Try naming the setting or app directly.'**
  String get deviceActionsUnresolved;

  /// Button that runs the resolved action
  ///
  /// In en, this message translates to:
  /// **'Do it'**
  String get deviceActionsConfirm;

  /// Button that dismisses the pending action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deviceActionsCancel;

  /// Button that clears the result and starts over
  ///
  /// In en, this message translates to:
  /// **'Do something else'**
  String get deviceActionsAgain;

  /// Explains that some settings cannot be toggled by an app
  ///
  /// In en, this message translates to:
  /// **'Android doesn\'t let apps change wireless settings on their own, so Finn opens the right screen and you flip the switch.'**
  String get deviceActionsOpenNotice;

  /// Result line after opening a screen
  ///
  /// In en, this message translates to:
  /// **'Opened {detail}'**
  String deviceActionsResultOpened(String detail);

  /// Result line after a completed action
  ///
  /// In en, this message translates to:
  /// **'Done — {detail}'**
  String deviceActionsResultPerformed(String detail);

  /// Result when the device cannot perform the action
  ///
  /// In en, this message translates to:
  /// **'Your device can\'t do that'**
  String get deviceActionsResultUnavailable;

  /// Result when the action failed
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work'**
  String get deviceActionsResultFailed;

  /// Result when the action failed, with the reason
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work — {error}'**
  String deviceActionsResultFailedDetail(String error);

  /// Example request chip
  ///
  /// In en, this message translates to:
  /// **'Set an alarm for 7am'**
  String get deviceActionsExampleAlarm;

  /// Example request chip
  ///
  /// In en, this message translates to:
  /// **'Start a 10 minute timer'**
  String get deviceActionsExampleTimer;

  /// Example request chip
  ///
  /// In en, this message translates to:
  /// **'Open Wi-Fi settings'**
  String get deviceActionsExampleWifi;

  /// Example request chip
  ///
  /// In en, this message translates to:
  /// **'Turn on the flashlight'**
  String get deviceActionsExampleFlashlight;

  /// Example request chip
  ///
  /// In en, this message translates to:
  /// **'Open Bluetooth settings'**
  String get deviceActionsExampleBluetooth;

  /// Confirmation line for setting an alarm
  ///
  /// In en, this message translates to:
  /// **'Set an alarm for {time}'**
  String deviceActionSetAlarm(String time);

  /// Confirmation line for starting a timer
  ///
  /// In en, this message translates to:
  /// **'Start a {duration} timer'**
  String deviceActionSetTimer(String duration);

  /// Confirmation line for opening the alarm clock
  ///
  /// In en, this message translates to:
  /// **'Open the alarm clock'**
  String get deviceActionShowAlarms;

  /// Confirmation line for turning the flashlight on
  ///
  /// In en, this message translates to:
  /// **'Turn the flashlight on'**
  String get deviceActionTorchOn;

  /// Confirmation line for turning the flashlight off
  ///
  /// In en, this message translates to:
  /// **'Turn the flashlight off'**
  String get deviceActionTorchOff;

  /// Confirmation line for a media transport command
  ///
  /// In en, this message translates to:
  /// **'Music player: {action}'**
  String deviceActionMedia(String action);

  /// Confirmation line for a volume change
  ///
  /// In en, this message translates to:
  /// **'Volume {direction}'**
  String deviceActionVolume(String direction);

  /// Confirmation line for opening a settings screen
  ///
  /// In en, this message translates to:
  /// **'Open {screen} settings'**
  String deviceActionOpenSettings(String screen);

  /// Confirmation line for launching an app
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String deviceActionOpenApp(String name);

  /// Confirmation line for opening the dialer
  ///
  /// In en, this message translates to:
  /// **'Open the dialer with {number}'**
  String deviceActionDial(String number);

  /// Confirmation line for drafting a text message
  ///
  /// In en, this message translates to:
  /// **'Open a new text message'**
  String get deviceActionComposeSms;

  /// Confirmation line for drafting an email
  ///
  /// In en, this message translates to:
  /// **'Open a new email'**
  String get deviceActionComposeEmail;

  /// Confirmation line for opening the camera
  ///
  /// In en, this message translates to:
  /// **'Open the camera'**
  String get deviceActionTakePhoto;

  /// Confirmation line for opening a web address
  ///
  /// In en, this message translates to:
  /// **'Open {url}'**
  String deviceActionOpenUrl(String url);

  /// Confirmation line for opening directions
  ///
  /// In en, this message translates to:
  /// **'Get directions to {query}'**
  String deviceActionNavigate(String query);

  /// Confirmation line for sharing text
  ///
  /// In en, this message translates to:
  /// **'Share text through another app'**
  String get deviceActionShare;

  /// Media transport label
  ///
  /// In en, this message translates to:
  /// **'play'**
  String get deviceActionMediaPlay;

  /// Media transport label
  ///
  /// In en, this message translates to:
  /// **'pause'**
  String get deviceActionMediaPause;

  /// Media transport label
  ///
  /// In en, this message translates to:
  /// **'skip to the next track'**
  String get deviceActionMediaNext;

  /// Media transport label
  ///
  /// In en, this message translates to:
  /// **'go back a track'**
  String get deviceActionMediaPrevious;

  /// Volume direction label
  ///
  /// In en, this message translates to:
  /// **'up'**
  String get deviceActionVolumeUp;

  /// Volume direction label
  ///
  /// In en, this message translates to:
  /// **'down'**
  String get deviceActionVolumeDown;

  /// Volume direction label
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get deviceActionVolumeMute;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get deviceScreenWifi;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get deviceScreenBluetooth;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Airplane mode'**
  String get deviceScreenAirplane;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Hotspot'**
  String get deviceScreenHotspot;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Mobile data'**
  String get deviceScreenMobileData;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Battery saver'**
  String get deviceScreenBatterySaver;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Battery usage'**
  String get deviceScreenBatteryUsage;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb'**
  String get deviceScreenDnd;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get deviceScreenDisplay;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get deviceScreenSound;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get deviceScreenLocation;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get deviceScreenStorage;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get deviceScreenDateTime;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get deviceScreenKeyboard;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get deviceScreenLanguage;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get deviceScreenAccessibility;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get deviceScreenApplications;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'NFC'**
  String get deviceScreenNfc;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get deviceScreenCast;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'VPN'**
  String get deviceScreenVpn;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Developer options'**
  String get deviceScreenDeveloper;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get deviceScreenHome;

  /// Result line when the action completed and has nothing more to name
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get deviceActionsResultDone;

  /// Settings section holding device actions
  ///
  /// In en, this message translates to:
  /// **'Actions on your device'**
  String get settingsActionsSection;

  /// Settings row that opens the device actions screen
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get settingsActionsRow;

  /// Settings screen name
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get deviceScreenSystem;

  /// Left in the conversation when a proposed action is dismissed
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get deviceActionsDismissed;

  /// Left in the transcript when the user stops a generation
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get creationsStopped;

  /// Shown when saved creations could not be read from disk
  ///
  /// In en, this message translates to:
  /// **'Finn couldn\'t open your saved creations. Please try again.'**
  String get creationsLoadFailed;

  /// Shown when deleting a creation could not be saved
  ///
  /// In en, this message translates to:
  /// **'That creation couldn\'t be deleted. Please try again.'**
  String get creationsDeleteFailed;
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
      'that was used.');
}
