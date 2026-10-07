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

  /// Affirmative consent answer
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// Negative consent answer
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

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

  /// Save flow button
  ///
  /// In en, this message translates to:
  /// **'Save flow'**
  String get commonSaveFlow;

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
  /// **'Free up'**
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
  /// **'Welcome to FinnAI'**
  String get onboardingWelcome;

  /// Swipe to start hint
  ///
  /// In en, this message translates to:
  /// **'Swipe to start'**
  String get onboardingSwipeToStart;

  /// Privacy page title
  ///
  /// In en, this message translates to:
  /// **'FinnAI values your privacy'**
  String get onboardingPrivacyTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'FinnAI takes your privacy at its core.'**
  String get onboardingPrivacyLead;

  /// Privacy page body
  ///
  /// In en, this message translates to:
  /// **'We do not track or store your data, every request is processed locally on your device. '**
  String get onboardingPrivacyBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'View more on our Privacy Policy.'**
  String get onboardingPrivacyLink;

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
  /// **'Downloading FinnAI Foundation'**
  String get onboardingInstallTitleInstalling;

  /// Install title ready
  ///
  /// In en, this message translates to:
  /// **'FinnAI Foundation ready'**
  String get onboardingInstallTitleReady;

  ///
  ///
  /// In en, this message translates to:
  /// **'Setting up FinnAI,'**
  String get onboardingDownloadLead;

  ///
  ///
  /// In en, this message translates to:
  /// **'the first run takes a few minutes.'**
  String get onboardingDownloadNote;

  ///
  ///
  /// In en, this message translates to:
  /// **'{percent}% done.'**
  String onboardingProgressPercent(Object percent);

  ///
  ///
  /// In en, this message translates to:
  /// **'left.'**
  String get onboardingProgressEtaTail;

  /// Whole-minute download estimate. Replaces the m:ss clock read-out plus onboardingProgressEtaTail, which rendered as '0:05 minutes'.
  ///
  /// In en, this message translates to:
  /// **'About {minutes, plural, =1{1 minute} other{{minutes} minutes}} left.'**
  String onboardingProgressEtaAbout(int minutes);

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
  /// **'{modelName} + image support · {size}'**
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
  /// **'FinnAI is ready!'**
  String get onboardingReadyTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'FinnAI is ready for use!'**
  String get onboardingReadyLead;

  ///
  ///
  /// In en, this message translates to:
  /// **'You can now use FinnAI, both online and offline.\nWe hope you enjoy using it!'**
  String get onboardingReadyBody;

  /// Ready subtitle
  ///
  /// In en, this message translates to:
  /// **'You\'re all set. Finn AI is ready.'**
  String get onboardingReadySubtitle;

  /// Consent step question
  ///
  /// In en, this message translates to:
  /// **'Do you allow FinnAI to get context on your device?'**
  String get onboardingConsentTitle;

  /// Explains what on-device context means before the user answers
  ///
  /// In en, this message translates to:
  /// **'This lets FinnAI read things like your calendar, notes and photos so its answers fit you better. It only reads on this device, and nothing is sent anywhere.'**
  String get onboardingConsentBody;

  /// Shown above a disabled Next until the consent question is answered
  ///
  /// In en, this message translates to:
  /// **'Choose Yes or No to continue'**
  String get onboardingConsentRequiredHint;

  /// Final onboarding button
  ///
  /// In en, this message translates to:
  /// **'Start using FinnAI'**
  String get onboardingStartUsing;

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
  /// **'Chats'**
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
  /// **'Ask me anything — I run entirely on this device, so your\nconversations never leave your device.'**
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

  /// Shown when the model produced no answer, next to a Retry button
  ///
  /// In en, this message translates to:
  /// **'Finn didn\'t come up with an answer that time. Tap Retry to ask again.'**
  String get chatEmptyReply;

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

  /// Settings row title for on-device context
  ///
  /// In en, this message translates to:
  /// **'On-device context'**
  String get settingsContextTitle;

  /// Settings row subtitle for on-device context
  ///
  /// In en, this message translates to:
  /// **'Let FinnAI use context from this device'**
  String get settingsContextSubtitle;

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
  /// **'Freeing up memory…'**
  String get settingsReleasingMemory;

  /// Explains that freeing model memory is reversible, unlike the two rows below it.
  ///
  /// In en, this message translates to:
  /// **'Frees RAM. The model reloads on your next message.'**
  String get settingsPurgeMemorySubtitle;

  /// States the irreversible consequence of clearing chat history before the tap.
  ///
  /// In en, this message translates to:
  /// **'Deletes every saved chat. Cannot be undone.'**
  String get settingsClearHistorySubtitle;

  /// Lists what a full wipe removes, so it is not confused with clearing history.
  ///
  /// In en, this message translates to:
  /// **'Chats, models, creations and preferences — back to a first run.'**
  String get settingsDeleteAllDataSubtitle;

  /// Purge memory row
  ///
  /// In en, this message translates to:
  /// **'Free up memory'**
  String get settingsPurgeMemory;

  /// Purge dialog title
  ///
  /// In en, this message translates to:
  /// **'Free up memory?'**
  String get settingsPurgeMemoryTitle;

  /// Purge body
  ///
  /// In en, this message translates to:
  /// **'This closes the AI model to free up memory. It will open again on your next message.'**
  String get settingsPurgeMemoryBody;

  /// Purge success
  ///
  /// In en, this message translates to:
  /// **'Memory freed up.'**
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
  /// **'This permanently deletes encrypted conversations and keys, downloaded AI models, creations, profile preferences, flows, and onboarding state. FinnAI will return to a clean first run.'**
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
  /// **'The privacy policy link isn\'t available in this build.'**
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
  /// **'The terms of use link isn\'t available in this build.'**
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
  /// **'How Finn runs'**
  String get settingsInferenceEngine;

  /// Engine value
  ///
  /// In en, this message translates to:
  /// **'Entirely on this device'**
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
  /// **'Finn reads replies aloud in voice mode. What you say is turned into text on this device and never leaves it.'**
  String get settingsSpokenResponsesBody;

  /// Mic button semantics
  ///
  /// In en, this message translates to:
  /// **'Talk to Finn'**
  String get voiceMicSemantic;

  /// Dismiss the inline voice session
  ///
  /// In en, this message translates to:
  /// **'Cancel voice input'**
  String get voiceCancelSemantic;

  /// Accessibility label for expanding inline voice
  ///
  /// In en, this message translates to:
  /// **'Open full voice mode'**
  String get voiceExpandSemantic;

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

  /// Voice sheet: the speech model must be downloaded once
  ///
  /// In en, this message translates to:
  /// **'Voice mode needs a one-time {size} download. Your voice is turned into text on this device and never leaves it.'**
  String voiceModelNeeded(String size);

  /// Button to download the speech model
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get voiceModelDownload;

  /// Voice sheet: speech model download progress
  ///
  /// In en, this message translates to:
  /// **'Downloading speech model… {percent}%'**
  String voiceModelDownloading(int percent);

  /// Voice sheet: speech model download failed
  ///
  /// In en, this message translates to:
  /// **'The download didn\'t finish. Check your connection and try again.'**
  String get voiceModelFailed;

  /// Button to retry the speech model download
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get voiceModelRetry;

  /// Live voice: Finn is speaking the reply
  ///
  /// In en, this message translates to:
  /// **'Speaking…'**
  String get voiceSpeakingLive;

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

  /// Flows title
  ///
  /// In en, this message translates to:
  /// **'Flows'**
  String get flowsTitle;

  /// Flows subtitle
  ///
  /// In en, this message translates to:
  /// **'{count} available · flows guide relevant replies'**
  String flowsSubtitle(int count);

  /// Delete flow title
  ///
  /// In en, this message translates to:
  /// **'Delete this flow?'**
  String get flowsDeleteTitle;

  /// Delete body
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be removed from this device.'**
  String flowsDeleteBody(String name);

  /// Name label
  ///
  /// In en, this message translates to:
  /// **'Flow name'**
  String get flowsNameLabel;

  /// Runs a flow once, on the spot
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get flowsRunAction;

  /// Shown on the run button while a flow is running
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get flowsRunRunning;

  /// Standing permission for a scheduled flow to act on the device
  ///
  /// In en, this message translates to:
  /// **'Let this run by itself'**
  String get flowsGrantLabel;

  /// Explains the standing grant
  ///
  /// In en, this message translates to:
  /// **'A flow that changes your phone needs this before it can run without you. You can turn it off at any time.'**
  String get flowsGrantExplain;

  /// A scheduled run that stopped because it had no grant
  ///
  /// In en, this message translates to:
  /// **'Needs your permission to run by itself'**
  String get flowsNeedsGrant;

  /// Heading for a flow's run history
  ///
  /// In en, this message translates to:
  /// **'Recent runs'**
  String get flowsHistoryTitle;

  /// No runs recorded for a flow
  ///
  /// In en, this message translates to:
  /// **'This flow has not run yet.'**
  String get flowsHistoryEmpty;

  /// A run that completed
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get flowsRunCompleted;

  /// A run the user declined
  ///
  /// In en, this message translates to:
  /// **'You said no'**
  String get flowsRunDeclined;

  /// A run that failed
  ///
  /// In en, this message translates to:
  /// **'Stopped early'**
  String get flowsRunFailed;

  /// A run that was interrupted
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get flowsRunInterrupted;

  /// How a scheduled run is labelled in the log
  ///
  /// In en, this message translates to:
  /// **'Ran by itself'**
  String get flowsRunBySchedule;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Automations'**
  String get flowsAutomationsTitle;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Things Finn does for you on a schedule. Nothing runs unless you turn it on.'**
  String get flowsAutomationsSubtitle;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'New automation'**
  String get flowsNewAutomation;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'No automations yet. Start with a morning brief.'**
  String get flowsNoAutomations;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Morning brief'**
  String get flowsTemplateMorningBrief;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'News you care about and the weather, in a few lines.'**
  String get flowsTemplateMorningBriefBody;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Web check'**
  String get flowsTemplateWebCheck;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Checks one topic and tells you what\'s new.'**
  String get flowsTemplateWebCheckBody;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get flowsTemplateReminder;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'A notification with your own words.'**
  String get flowsTemplateReminderBody;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'What to follow'**
  String get flowsSlotTopics;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'City for the weather (optional)'**
  String get flowsSlotCity;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get flowsSlotTopic;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get flowsSlotMessage;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get flowsScheduleHeading;

  /// Schedule label for Monday to Friday
  ///
  /// In en, this message translates to:
  /// **'Weekdays at {time}'**
  String flowsScheduleWeekdaysAt(String time);

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get flowsScheduleEveryDay;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get flowsScheduleWeekdaysOnly;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get flowsScheduleTime;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Allow notifications?'**
  String get flowsNotifyWhyTitle;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Finn sends a notification when this automation is due. Without it, the automation can only run when you tap Run.'**
  String get flowsNotifyWhyBody;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get flowsNotifyAllow;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Notifications are off, so this won\'t run by itself.'**
  String get flowsNotifyOff;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Running {name}…'**
  String flowsRunning(String name);

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'{name} is ready'**
  String flowsRunReady(String name);

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'{name} couldn\'t finish'**
  String flowsRunCouldNotFinish(String name);

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Open result'**
  String get flowsOpenResult;

  /// Flows automation text
  ///
  /// In en, this message translates to:
  /// **'Next: {when}'**
  String flowsNextRun(String when);

  /// How a manual run is labelled in the log
  ///
  /// In en, this message translates to:
  /// **'Run by you'**
  String get flowsRunByYou;

  /// How many steps a flow has
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get flowsStepsLabel;

  /// A flow's step count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 step} other{{count} steps}}'**
  String flowsStepCount(int count);

  /// A prompt step in the flow editor
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get flowsStepPrompt;

  /// A device-action step in the flow editor
  ///
  /// In en, this message translates to:
  /// **'Act on phone'**
  String get flowsStepDeviceAction;

  /// A notify step in the flow editor
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get flowsStepNotify;

  /// A browse step in the flow editor
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get flowsStepBrowse;

  /// Label for a flow's trigger
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get flowsScheduleLabel;

  /// Manual trigger
  ///
  /// In en, this message translates to:
  /// **'Only when you run it'**
  String get flowsScheduleManual;

  /// Daily trigger
  ///
  /// In en, this message translates to:
  /// **'Every day at {time}'**
  String flowsScheduleDaily(String time);

  /// Weekly trigger
  ///
  /// In en, this message translates to:
  /// **'Days {days} at {time}'**
  String flowsScheduleWeekly(String days, String time);

  /// Turns a flow into a scheduled one
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get flowsScheduleAdd;

  /// Turns a scheduled flow back to manual
  ///
  /// In en, this message translates to:
  /// **'Run it only when I ask'**
  String get flowsScheduleRemove;

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

  /// Creations empty title
  ///
  /// In en, this message translates to:
  /// **'No Creations yet.'**
  String get creationsNoneTitle;

  /// Creations empty body
  ///
  /// In en, this message translates to:
  /// **'Your creativity lives here.\nTry making something with FinnAI Creations.'**
  String get creationsNoneBody;

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

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Let Finn choose'**
  String get creationsTemplateAuto;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Want a starting point? Pick one, or just describe what you want.'**
  String get creationsTemplateQuestion;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get creationsTemplateCounter;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get creationsTemplateChecklist;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get creationsTemplateList;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get creationsTemplateScoreboard;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Big number'**
  String get creationsTemplateStat;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get creationsTemplateRows;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get creationsEdit;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get creationsEditTitle;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get creationsSlotTitle;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'What you count'**
  String get creationsSlotUnit;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get creationsSlotGoal;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get creationsSlotEmoji;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get creationsSlotAccent;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get creationsSlotItems;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Input hint'**
  String get creationsSlotHint;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Empty message'**
  String get creationsSlotEmpty;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get creationsSlotNameA;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Second name'**
  String get creationsSlotNameB;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get creationsSlotLabel;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get creationsSlotValue;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get creationsSlotFooter;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get creationsSlotRows;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'One per line'**
  String get creationsSlotOnePerLine;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'One per line, like “Water: 3”'**
  String get creationsSlotRowFormat;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get creationsAccentMint;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get creationsAccentBlue;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get creationsAccentLime;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get creationsAccentAmber;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get creationsAccentRose;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get creationsAccentViolet;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get creationsAccentSky;

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

  /// No description provided for @flowsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'That flow could not be saved.'**
  String get flowsSaveFailed;

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
  /// **'Memory freed up.'**
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
  /// **'Looking at images isn\'t set up yet. Add image support in Settings.'**
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

  /// Tooltip for the reply overflow menu
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get chatMoreActions;

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

  /// Empty chat greeting
  ///
  /// In en, this message translates to:
  /// **'Hi, what\'s on your mind?'**
  String get chatGreeting;

  ///
  ///
  /// In en, this message translates to:
  /// **'What\'s up?'**
  String get voiceGreeting;

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

  /// Flow card menu tooltip
  ///
  /// In en, this message translates to:
  /// **'Flow actions'**
  String get flowsActionsTooltip;

  /// Flow toggle semantics
  ///
  /// In en, this message translates to:
  /// **'{name} flow'**
  String flowsNameSemantic(String name);

  /// Editor field hint
  ///
  /// In en, this message translates to:
  /// **'What does this flow do?'**
  String get flowsEditorNameHint;

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

  /// hubModelTitle
  ///
  /// In en, this message translates to:
  /// **'FinnAI Foundation'**
  String get hubModelTitle;

  /// hubModelSub
  ///
  /// In en, this message translates to:
  /// **'On this device, {size}'**
  String hubModelSub(String size);

  /// hubVoiceTitle
  ///
  /// In en, this message translates to:
  /// **'Voice and language'**
  String get hubVoiceTitle;

  /// hubVoiceSub
  ///
  /// In en, this message translates to:
  /// **'{speed} speed, {language}'**
  String hubVoiceSub(String speed, String language);

  /// hubAccessTitle
  ///
  /// In en, this message translates to:
  /// **'Device access'**
  String get hubAccessTitle;

  /// hubAccessSub
  ///
  /// In en, this message translates to:
  /// **'Calendar, contacts, files'**
  String get hubAccessSub;

  /// hubYouTitle
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get hubYouTitle;

  /// hubYouSub
  ///
  /// In en, this message translates to:
  /// **'What FinnAI learns and uses'**
  String get hubYouSub;

  /// hubDataTitle
  ///
  /// In en, this message translates to:
  /// **'Privacy and data'**
  String get hubDataTitle;

  /// hubDataSub
  ///
  /// In en, this message translates to:
  /// **'Storage, export, erase'**
  String get hubDataSub;

  /// hubAboutTitle
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get hubAboutTitle;

  /// hubAboutSub
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String hubAboutSub(String version);

  /// modelVersion
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String modelVersion(String version);

  /// modelStored
  ///
  /// In en, this message translates to:
  /// **'{size} of your storage, downloaded on {date}.'**
  String modelStored(String size, String date);

  /// modelStoredNoDate
  ///
  /// In en, this message translates to:
  /// **'{size} of your storage.'**
  String modelStoredNoDate(String size);

  /// modelNotInstalled
  ///
  /// In en, this message translates to:
  /// **'Not downloaded yet.'**
  String get modelNotInstalled;

  /// modelOffline
  ///
  /// In en, this message translates to:
  /// **'Work offline'**
  String get modelOffline;

  /// modelOfflineSub
  ///
  /// In en, this message translates to:
  /// **'Everything runs on this device'**
  String get modelOfflineSub;

  /// modelLookups
  ///
  /// In en, this message translates to:
  /// **'Look things up online'**
  String get modelLookups;

  /// modelLookupsSub
  ///
  /// In en, this message translates to:
  /// **'Only when a question needs it. Your chats and You stay here.'**
  String get modelLookupsSub;

  /// modelUpdates
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get modelUpdates;

  /// modelUpToDate
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get modelUpToDate;

  /// modelRemove
  ///
  /// In en, this message translates to:
  /// **'Remove the model'**
  String get modelRemove;

  /// modelRemoveSub
  ///
  /// In en, this message translates to:
  /// **'Frees {size}'**
  String modelRemoveSub(String size);

  /// modelRemoveTitle
  ///
  /// In en, this message translates to:
  /// **'Remove the model?'**
  String get modelRemoveTitle;

  /// modelRemoveBody
  ///
  /// In en, this message translates to:
  /// **'FinnAI has to download it again before you can chat. Your chats stay.'**
  String get modelRemoveBody;

  /// modelRemoveConfirm
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get modelRemoveConfirm;

  /// voiceReadAloud
  ///
  /// In en, this message translates to:
  /// **'Read replies aloud'**
  String get voiceReadAloud;

  /// voiceReadAloudSub
  ///
  /// In en, this message translates to:
  /// **'In voice chats'**
  String get voiceReadAloudSub;

  /// voiceTranscript
  ///
  /// In en, this message translates to:
  /// **'Show live transcript'**
  String get voiceTranscript;

  /// voiceTranscriptSub
  ///
  /// In en, this message translates to:
  /// **'While you speak'**
  String get voiceTranscriptSub;

  /// voiceSpeed
  ///
  /// In en, this message translates to:
  /// **'Speaking speed'**
  String get voiceSpeed;

  /// voiceSpeedSlow
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get voiceSpeedSlow;

  /// voiceSpeedNormal
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get voiceSpeedNormal;

  /// voiceSpeedFast
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get voiceSpeedFast;

  /// voiceLanguage
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get voiceLanguage;

  /// voiceLanguageSub
  ///
  /// In en, this message translates to:
  /// **'Follows your device'**
  String get voiceLanguageSub;

  /// accessIntro
  ///
  /// In en, this message translates to:
  /// **'FinnAI only reads what you allow, and only on this device.'**
  String get accessIntro;

  /// accessMaster
  ///
  /// In en, this message translates to:
  /// **'Use context from this device'**
  String get accessMaster;

  /// accessMasterSub
  ///
  /// In en, this message translates to:
  /// **'Turn off to stop FinnAI reading anything'**
  String get accessMasterSub;

  /// accessActions
  ///
  /// In en, this message translates to:
  /// **'Actions on your device'**
  String get accessActions;

  /// accessActionsSub
  ///
  /// In en, this message translates to:
  /// **'Alarms, timers, settings'**
  String get accessActionsSub;

  /// ctxCalendar
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get ctxCalendar;

  /// ctxCalendarSub
  ///
  /// In en, this message translates to:
  /// **'Events and free time'**
  String get ctxCalendarSub;

  /// ctxContacts
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get ctxContacts;

  /// ctxContactsSub
  ///
  /// In en, this message translates to:
  /// **'Names and relationships'**
  String get ctxContactsSub;

  /// ctxNotifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get ctxNotifications;

  /// ctxNotificationsSub
  ///
  /// In en, this message translates to:
  /// **'What needs your attention'**
  String get ctxNotificationsSub;

  /// ctxPhotos
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get ctxPhotos;

  /// ctxPhotosSub
  ///
  /// In en, this message translates to:
  /// **'Only when you attach them'**
  String get ctxPhotosSub;

  /// ctxFiles
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get ctxFiles;

  /// ctxFilesSub
  ///
  /// In en, this message translates to:
  /// **'Documents you open with FinnAI'**
  String get ctxFilesSub;

  /// ctxLocation
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get ctxLocation;

  /// ctxLocationSub
  ///
  /// In en, this message translates to:
  /// **'Only while the app is open'**
  String get ctxLocationSub;

  /// dataStoredHere
  ///
  /// In en, this message translates to:
  /// **'Stored on this device'**
  String get dataStoredHere;

  /// dataChats
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get dataChats;

  /// dataCreations
  ///
  /// In en, this message translates to:
  /// **'Creations'**
  String get dataCreations;

  /// dataYou
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get dataYou;

  /// dataModel
  ///
  /// In en, this message translates to:
  /// **'FinnAI Foundation'**
  String get dataModel;

  /// dataExport
  ///
  /// In en, this message translates to:
  /// **'Export everything'**
  String get dataExport;

  /// dataExportSub
  ///
  /// In en, this message translates to:
  /// **'Chats, creations, flows and You'**
  String get dataExportSub;

  /// dataDeleteChats
  ///
  /// In en, this message translates to:
  /// **'Delete all chats'**
  String get dataDeleteChats;

  /// dataDeleteChatsSub
  ///
  /// In en, this message translates to:
  /// **'You stays as it is'**
  String get dataDeleteChatsSub;

  /// dataErase
  ///
  /// In en, this message translates to:
  /// **'Erase everything'**
  String get dataErase;

  /// dataEraseSub
  ///
  /// In en, this message translates to:
  /// **'Resets FinnAI on this device'**
  String get dataEraseSub;

  /// dataExportFailed
  ///
  /// In en, this message translates to:
  /// **'Could not export. Try again.'**
  String get dataExportFailed;

  /// aboutBlurb
  ///
  /// In en, this message translates to:
  /// **'A private assistant that runs on your device.'**
  String get aboutBlurb;

  /// aboutPrivacy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get aboutPrivacy;

  /// aboutTerms
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get aboutTerms;

  /// aboutLicences
  ///
  /// In en, this message translates to:
  /// **'Open source licences'**
  String get aboutLicences;

  /// aboutFeedback
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get aboutFeedback;

  /// chatUsedFromYou
  ///
  /// In en, this message translates to:
  /// **'Used {count, plural, =1{1 thing} other{{count} things}} from You'**
  String chatUsedFromYou(int count);

  /// youAboutTitle
  ///
  /// In en, this message translates to:
  /// **'What FinnAI knows about you'**
  String get youAboutTitle;

  /// youUpdated
  ///
  /// In en, this message translates to:
  /// **'Updated {when}'**
  String youUpdated(String when);

  /// youReviewTitle
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new thing to review} other{{count} new things to review}}'**
  String youReviewTitle(int count);

  /// youReviewSub
  ///
  /// In en, this message translates to:
  /// **'Noticed in your recent chats'**
  String get youReviewSub;

  /// youCount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing} other{{count} things}}'**
  String youCount(int count);

  /// youStoredOnly
  ///
  /// In en, this message translates to:
  /// **'Stored only on this device'**
  String get youStoredOnly;

  /// youCatPeople
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get youCatPeople;

  /// youCatWork
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get youCatWork;

  /// youCatRoutines
  ///
  /// In en, this message translates to:
  /// **'Routines'**
  String get youCatRoutines;

  /// youCatPreferences
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get youCatPreferences;

  /// youCatPlaces
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get youCatPlaces;

  /// youCatInterests
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get youCatInterests;

  /// youEmptyTitle
  ///
  /// In en, this message translates to:
  /// **'Still getting to know you'**
  String get youEmptyTitle;

  /// youEmptyBody
  ///
  /// In en, this message translates to:
  /// **'As you chat, FinnAI learns what helps and keeps it here, on this device. You can also write something yourself.'**
  String get youEmptyBody;

  /// youTellFinn
  ///
  /// In en, this message translates to:
  /// **'Tell FinnAI about you'**
  String get youTellFinn;

  /// youPrivacyTitle
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get youPrivacyTitle;

  /// youCategoryIntro
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 thing FinnAI remembers. Tap one to see where it came from.} other{{count} things FinnAI remembers. Tap one to see where it came from.}}'**
  String youCategoryIntro(int count);

  /// youCategoryEmpty
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Tap plus to add something.'**
  String get youCategoryEmpty;

  /// youSeenIn
  ///
  /// In en, this message translates to:
  /// **'Seen in {where}'**
  String youSeenIn(String where);

  /// youSeenInLabel
  ///
  /// In en, this message translates to:
  /// **'Seen in'**
  String get youSeenInLabel;

  /// youAddedByYou
  ///
  /// In en, this message translates to:
  /// **'Added by you'**
  String get youAddedByYou;

  /// youLearnedOn
  ///
  /// In en, this message translates to:
  /// **'Learned {when}. Stored on this device.'**
  String youLearnedOn(String when);

  /// youEdit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get youEdit;

  /// youDoNotUse
  ///
  /// In en, this message translates to:
  /// **'Do not use in chats'**
  String get youDoNotUse;

  /// youForgetThis
  ///
  /// In en, this message translates to:
  /// **'Forget this'**
  String get youForgetThis;

  /// youForgetTitle
  ///
  /// In en, this message translates to:
  /// **'Forget this?'**
  String get youForgetTitle;

  /// youForgetBody
  ///
  /// In en, this message translates to:
  /// **'FinnAI stops using it in chats. If you bring it up again, it can be learned again.'**
  String get youForgetBody;

  /// youForgetConfirm
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get youForgetConfirm;

  /// youAddLabel
  ///
  /// In en, this message translates to:
  /// **'In your own words'**
  String get youAddLabel;

  /// youAddHint
  ///
  /// In en, this message translates to:
  /// **'Something FinnAI should remember, like how you like to work or who matters to you.'**
  String get youAddHint;

  /// youWhereBelongs
  ///
  /// In en, this message translates to:
  /// **'Where it belongs'**
  String get youWhereBelongs;

  /// youUseEveryChat
  ///
  /// In en, this message translates to:
  /// **'Use in every chat'**
  String get youUseEveryChat;

  /// youUseEveryChatSub
  ///
  /// In en, this message translates to:
  /// **'Turn off to keep it for when you ask'**
  String get youUseEveryChatSub;

  /// youSaveToYou
  ///
  /// In en, this message translates to:
  /// **'Save to You'**
  String get youSaveToYou;

  /// youReviewTitleBar
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get youReviewTitleBar;

  /// youReviewIntro
  ///
  /// In en, this message translates to:
  /// **'FinnAI noticed these in recent chats. Keep what is right and forget the rest.'**
  String get youReviewIntro;

  /// youReviewEmpty
  ///
  /// In en, this message translates to:
  /// **'Nothing to review right now.'**
  String get youReviewEmpty;

  /// youKeep
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get youKeep;

  /// youFrom
  ///
  /// In en, this message translates to:
  /// **'{category}, from {chat}'**
  String youFrom(String category, String chat);

  /// youPrivacyNote
  ///
  /// In en, this message translates to:
  /// **'Everything in You is stored on this device. FinnAI never sends it anywhere.'**
  String get youPrivacyNote;

  /// youLearn
  ///
  /// In en, this message translates to:
  /// **'Learn from conversations'**
  String get youLearn;

  /// youLearnSub
  ///
  /// In en, this message translates to:
  /// **'FinnAI suggests things to add after you chat'**
  String get youLearnSub;

  /// youUseInChats
  ///
  /// In en, this message translates to:
  /// **'Use You in new chats'**
  String get youUseInChats;

  /// youUseInChatsSub
  ///
  /// In en, this message translates to:
  /// **'You can turn it off per chat'**
  String get youUseInChatsSub;

  /// youLearnAbout
  ///
  /// In en, this message translates to:
  /// **'Learn about'**
  String get youLearnAbout;

  /// youExport
  ///
  /// In en, this message translates to:
  /// **'Export You'**
  String get youExport;

  /// youExportSub
  ///
  /// In en, this message translates to:
  /// **'Save a copy as a file'**
  String get youExportSub;

  /// youErase
  ///
  /// In en, this message translates to:
  /// **'Erase everything in You'**
  String get youErase;

  /// youEraseSub
  ///
  /// In en, this message translates to:
  /// **'Removes {count, plural, =1{1 thing} other{{count} things}}'**
  String youEraseSub(int count);

  /// youEraseTitle
  ///
  /// In en, this message translates to:
  /// **'Erase everything in You?'**
  String get youEraseTitle;

  /// youEraseBody
  ///
  /// In en, this message translates to:
  /// **'Everything FinnAI remembers is removed from this device. Your chats stay.'**
  String get youEraseBody;

  /// youEraseConfirm
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get youEraseConfirm;

  /// youPersonalise
  ///
  /// In en, this message translates to:
  /// **'Reply style and instructions'**
  String get youPersonalise;

  /// youPersonaliseSub
  ///
  /// In en, this message translates to:
  /// **'Name, tone and custom instructions'**
  String get youPersonaliseSub;

  /// youRemembered
  ///
  /// In en, this message translates to:
  /// **'Saved to You'**
  String get youRemembered;

  /// youWhenToday
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get youWhenToday;

  /// youWhenMinutes
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String youWhenMinutes(int count);

  /// youWhenHours
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String youWhenHours(int count);

  /// youWhenDays
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String youWhenDays(int count);

  /// youWhenJustNow
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get youWhenJustNow;

  /// searchHint
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// searchChatsHeading
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get searchChatsHeading;

  /// searchCreationsHeading
  ///
  /// In en, this message translates to:
  /// **'Creations'**
  String get searchCreationsHeading;

  /// searchNothing
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get searchNothing;

  /// searchPrompt
  ///
  /// In en, this message translates to:
  /// **'Search your chats, creations and You.'**
  String get searchPrompt;

  /// chatReadAloud
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get chatReadAloud;

  /// chatRememberInYou
  ///
  /// In en, this message translates to:
  /// **'Remember in You'**
  String get chatRememberInYou;

  /// chatShare
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get chatShare;

  /// plusCreate
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get plusCreate;

  /// plusWidget
  ///
  /// In en, this message translates to:
  /// **'Widget'**
  String get plusWidget;

  /// plusWidgetSub
  ///
  /// In en, this message translates to:
  /// **'For your home screen'**
  String get plusWidgetSub;

  /// plusMiniApp
  ///
  /// In en, this message translates to:
  /// **'Mini app'**
  String get plusMiniApp;

  /// plusMiniAppSub
  ///
  /// In en, this message translates to:
  /// **'A small tool'**
  String get plusMiniAppSub;

  /// plusPresentation
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get plusPresentation;

  /// plusPresentationSub
  ///
  /// In en, this message translates to:
  /// **'Slides to share'**
  String get plusPresentationSub;

  /// plusFlow
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get plusFlow;

  /// plusFlowSub
  ///
  /// In en, this message translates to:
  /// **'Runs on its own'**
  String get plusFlowSub;

  /// plusAddToChat
  ///
  /// In en, this message translates to:
  /// **'Add to chat'**
  String get plusAddToChat;

  /// plusPhoto
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get plusPhoto;

  /// optionsStarted
  ///
  /// In en, this message translates to:
  /// **'Started {when}. Stored on this device.'**
  String optionsStarted(String when);

  /// optionsPin
  ///
  /// In en, this message translates to:
  /// **'Pin chat'**
  String get optionsPin;

  /// optionsUnpin
  ///
  /// In en, this message translates to:
  /// **'Unpin chat'**
  String get optionsUnpin;

  /// optionsExport
  ///
  /// In en, this message translates to:
  /// **'Export as text'**
  String get optionsExport;

  /// optionsDelete
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get optionsDelete;

  /// deleteChatTitle
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get deleteChatTitle;

  /// deleteChatBody
  ///
  /// In en, this message translates to:
  /// **'It is removed from this device. What FinnAI learned from it stays in You until you forget it.'**
  String get deleteChatBody;

  /// fromYouTitle
  ///
  /// In en, this message translates to:
  /// **'From You'**
  String get fromYouTitle;

  /// fromYouSub
  ///
  /// In en, this message translates to:
  /// **'FinnAI used these in this chat. Nothing leaves your device.'**
  String get fromYouSub;

  /// fromYouUse
  ///
  /// In en, this message translates to:
  /// **'Use You in this chat'**
  String get fromYouUse;

  /// fromYouOpen
  ///
  /// In en, this message translates to:
  /// **'Open You'**
  String get fromYouOpen;

  /// chatRenamePrompt
  ///
  /// In en, this message translates to:
  /// **'Rename chat'**
  String get chatRenamePrompt;

  /// Shown under the Flows search field when no flow matches
  ///
  /// In en, this message translates to:
  /// **'No flows match that search.'**
  String get flowsSearchEmpty;

  /// Flow step picker: flowsPickerDevice
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get flowsPickerDevice;

  /// Flow step picker: flowsPickerLogic
  ///
  /// In en, this message translates to:
  /// **'Logic'**
  String get flowsPickerLogic;

  /// Flow step picker: flowsPickerEmpty
  ///
  /// In en, this message translates to:
  /// **'No step matches that search.'**
  String get flowsPickerEmpty;

  /// flowsFilterAll
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get flowsFilterAll;

  /// flowsFilterActive
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get flowsFilterActive;

  /// flowsFilterPaused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get flowsFilterPaused;

  /// flowsPhoneOn
  ///
  /// In en, this message translates to:
  /// **'Flows run on this device, so your phone needs to be on.'**
  String get flowsPhoneOn;

  /// flowsOnlyWhenAsked
  ///
  /// In en, this message translates to:
  /// **'Only when I ask'**
  String get flowsOnlyWhenAsked;

  /// flowsLastRunLine
  ///
  /// In en, this message translates to:
  /// **'Last run {when}, {result}'**
  String flowsLastRunLine(String when, String result);

  /// flowsNeverRun
  ///
  /// In en, this message translates to:
  /// **'Not run yet'**
  String get flowsNeverRun;

  /// flowsPausedLine
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get flowsPausedLine;

  /// flowsResultDone
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get flowsResultDone;

  /// flowsResultFailed
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get flowsResultFailed;

  /// flowsResultStopped
  ///
  /// In en, this message translates to:
  /// **'stopped'**
  String get flowsResultStopped;

  /// flowsWhenToday
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get flowsWhenToday;

  /// flowsWhenYesterday
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get flowsWhenYesterday;

  /// flowsEmptyTitle
  ///
  /// In en, this message translates to:
  /// **'No flows yet'**
  String get flowsEmptyTitle;

  /// flowsEmptyBody
  ///
  /// In en, this message translates to:
  /// **'A flow does a task for you on a schedule, or when something happens. Describe one in chat.'**
  String get flowsEmptyBody;

  /// flowsEmptyCreate
  ///
  /// In en, this message translates to:
  /// **'Create a flow'**
  String get flowsEmptyCreate;

  /// flowsNewTitle
  ///
  /// In en, this message translates to:
  /// **'New flow'**
  String get flowsNewTitle;

  /// flowsNewSub
  ///
  /// In en, this message translates to:
  /// **'Start with words, a time, or an event.'**
  String get flowsNewSub;

  /// flowsNewDescribe
  ///
  /// In en, this message translates to:
  /// **'Describe it'**
  String get flowsNewDescribe;

  /// flowsNewDescribeSub
  ///
  /// In en, this message translates to:
  /// **'Tell FinnAI what should happen'**
  String get flowsNewDescribeSub;

  /// flowsNewTime
  ///
  /// In en, this message translates to:
  /// **'At a set time'**
  String get flowsNewTime;

  /// flowsNewTimeSub
  ///
  /// In en, this message translates to:
  /// **'Every day, week or month'**
  String get flowsNewTimeSub;

  /// flowsNewEvent
  ///
  /// In en, this message translates to:
  /// **'When something happens'**
  String get flowsNewEvent;

  /// flowsNewEventSub
  ///
  /// In en, this message translates to:
  /// **'Charging, arriving, a notification'**
  String get flowsNewEventSub;

  /// flowsDetailOn
  ///
  /// In en, this message translates to:
  /// **'On, next run {when}'**
  String flowsDetailOn(String when);

  /// flowsDetailOnManual
  ///
  /// In en, this message translates to:
  /// **'On, runs when you ask'**
  String get flowsDetailOnManual;

  /// flowsDetailPaused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get flowsDetailPaused;

  /// flowsWhen
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get flowsWhen;

  /// flowsThen
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get flowsThen;

  /// flowsRecentRuns
  ///
  /// In en, this message translates to:
  /// **'Recent runs'**
  String get flowsRecentRuns;

  /// flowsNoRunsYet
  ///
  /// In en, this message translates to:
  /// **'No runs yet'**
  String get flowsNoRunsYet;

  /// flowsRunStatusDone
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get flowsRunStatusDone;

  /// flowsRunStatusFailed
  ///
  /// In en, this message translates to:
  /// **'Could not finish'**
  String get flowsRunStatusFailed;

  /// flowsRunStatusDeclined
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get flowsRunStatusDeclined;

  /// flowsRunStatusNeedsGrant
  ///
  /// In en, this message translates to:
  /// **'Needs your permission'**
  String get flowsRunStatusNeedsGrant;

  /// flowsRunStatusStopped
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get flowsRunStatusStopped;

  /// flowsMenuEdit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get flowsMenuEdit;

  /// flowsMenuPause
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get flowsMenuPause;

  /// flowsMenuResume
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get flowsMenuResume;

  /// flowsMenuDuplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get flowsMenuDuplicate;

  /// flowsMenuDelete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get flowsMenuDelete;

  /// flowsRunFinished
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get flowsRunFinished;

  /// flowsRunFinishedIn
  ///
  /// In en, this message translates to:
  /// **'Finished in {seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String flowsRunFinishedIn(int seconds);

  /// flowsRunAgain
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get flowsRunAgain;

  /// flowsBuilderHint
  ///
  /// In en, this message translates to:
  /// **'Describe what should happen'**
  String get flowsBuilderHint;

  /// flowsBuilderHere
  ///
  /// In en, this message translates to:
  /// **'Here is the flow. Check it, then turn it on.'**
  String get flowsBuilderHere;

  /// flowsBuilderNoMatch
  ///
  /// In en, this message translates to:
  /// **'I can not build that one yet. Pick one of these and I will set it up.'**
  String get flowsBuilderNoMatch;

  /// flowsBuilderTurnOn
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get flowsBuilderTurnOn;

  /// flowsStartWhen
  ///
  /// In en, this message translates to:
  /// **'Start when'**
  String get flowsStartWhen;

  /// flowsTriggerTime
  ///
  /// In en, this message translates to:
  /// **'At a set time'**
  String get flowsTriggerTime;

  /// flowsTriggerTimeSub
  ///
  /// In en, this message translates to:
  /// **'Every day, week or month'**
  String get flowsTriggerTimeSub;

  /// flowsTriggerPlace
  ///
  /// In en, this message translates to:
  /// **'Arriving or leaving'**
  String get flowsTriggerPlace;

  /// flowsTriggerPlaceSub
  ///
  /// In en, this message translates to:
  /// **'A place you choose'**
  String get flowsTriggerPlaceSub;

  /// flowsTriggerCharging
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get flowsTriggerCharging;

  /// flowsTriggerChargingSub
  ///
  /// In en, this message translates to:
  /// **'When plugged in or unplugged'**
  String get flowsTriggerChargingSub;

  /// flowsTriggerBattery
  ///
  /// In en, this message translates to:
  /// **'Battery level'**
  String get flowsTriggerBattery;

  /// flowsTriggerBatterySub
  ///
  /// In en, this message translates to:
  /// **'Below or above a level'**
  String get flowsTriggerBatterySub;

  /// flowsTriggerNotification
  ///
  /// In en, this message translates to:
  /// **'A notification'**
  String get flowsTriggerNotification;

  /// flowsTriggerNotificationSub
  ///
  /// In en, this message translates to:
  /// **'When one arrives from an app'**
  String get flowsTriggerNotificationSub;

  /// flowsTriggerManual
  ///
  /// In en, this message translates to:
  /// **'Only when I ask'**
  String get flowsTriggerManual;

  /// flowsTriggerManualSub
  ///
  /// In en, this message translates to:
  /// **'Start it yourself'**
  String get flowsTriggerManualSub;

  /// flowsTriggerSoon
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get flowsTriggerSoon;

  /// flowsScheduleSheetTitle
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get flowsScheduleSheetTitle;

  /// flowsScheduleSave
  ///
  /// In en, this message translates to:
  /// **'Save schedule'**
  String get flowsScheduleSave;

  /// flowsAllowTitle
  ///
  /// In en, this message translates to:
  /// **'Allow {name} to act on your phone?'**
  String flowsAllowTitle(String name);

  /// flowsAllowConfirm
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get flowsAllowConfirm;

  /// flowsDeleteNamed
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String flowsDeleteNamed(String name);

  /// flowsDeleteNamedBody
  ///
  /// In en, this message translates to:
  /// **'Its past runs are removed too. This can not be undone.'**
  String get flowsDeleteNamedBody;

  /// flowsStepLookUp
  ///
  /// In en, this message translates to:
  /// **'Look up {query}'**
  String flowsStepLookUp(String query);

  /// flowsStepWrite
  ///
  /// In en, this message translates to:
  /// **'Write the answer'**
  String get flowsStepWrite;

  /// creationsNewSheetSub
  ///
  /// In en, this message translates to:
  /// **'Describe it in chat. FinnAI builds it on this device.'**
  String get creationsNewSheetSub;

  /// creationsNewWidgetSub
  ///
  /// In en, this message translates to:
  /// **'Small tools for your home screen'**
  String get creationsNewWidgetSub;

  /// creationsNewAppSub
  ///
  /// In en, this message translates to:
  /// **'A simple tool that runs inside FinnAI'**
  String get creationsNewAppSub;

  /// creationsNewDeckSub
  ///
  /// In en, this message translates to:
  /// **'Slides you can present or share'**
  String get creationsNewDeckSub;

  /// creationsMenuEditWithFinn
  ///
  /// In en, this message translates to:
  /// **'Edit with FinnAI'**
  String get creationsMenuEditWithFinn;

  /// creationsMenuDuplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get creationsMenuDuplicate;

  /// creationsMenuShare
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get creationsMenuShare;

  /// creationsDeleteNamed
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String creationsDeleteNamed(String name);

  /// creationsDeleteNamedBody
  ///
  /// In en, this message translates to:
  /// **'It is removed from Creations and from your home screen. This can not be undone.'**
  String get creationsDeleteNamedBody;

  /// creationsSizeSmall
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get creationsSizeSmall;

  /// creationsSizeMedium
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get creationsSizeMedium;

  /// creationsSizeLarge
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get creationsSizeLarge;

  /// creationsUpdatesOnDevice
  ///
  /// In en, this message translates to:
  /// **'Updates on this device. Nothing leaves your device.'**
  String get creationsUpdatesOnDevice;

  /// creationsMadeInChat
  ///
  /// In en, this message translates to:
  /// **'Made in chat'**
  String get creationsMadeInChat;

  /// creationsDataLabel
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get creationsDataLabel;

  /// creationsDataSub
  ///
  /// In en, this message translates to:
  /// **'Stored inside this widget'**
  String get creationsDataSub;

  /// creationsAddHomeTitle
  ///
  /// In en, this message translates to:
  /// **'Add {name} to your home screen?'**
  String creationsAddHomeTitle(String name);

  /// creationsAddHomeBody
  ///
  /// In en, this message translates to:
  /// **'It sits like any other widget. You can move or remove it later.'**
  String get creationsAddHomeBody;

  /// creationsAddHomeConfirm
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get creationsAddHomeConfirm;

  /// creationsBuilderTitleWidget
  ///
  /// In en, this message translates to:
  /// **'New widget'**
  String get creationsBuilderTitleWidget;

  /// creationsBuilderTitleApp
  ///
  /// In en, this message translates to:
  /// **'New mini app'**
  String get creationsBuilderTitleApp;

  /// creationsBuilderTitleDeck
  ///
  /// In en, this message translates to:
  /// **'New presentation'**
  String get creationsBuilderTitleDeck;

  /// creationsBuilderHint
  ///
  /// In en, this message translates to:
  /// **'Describe what to build'**
  String get creationsBuilderHint;

  /// creationsBuilderChangeHint
  ///
  /// In en, this message translates to:
  /// **'Ask for changes'**
  String get creationsBuilderChangeHint;

  /// creationsBuilderGotIt
  ///
  /// In en, this message translates to:
  /// **'Got it. I will build it on this device.'**
  String get creationsBuilderGotIt;

  /// creationsBuilderReady
  ///
  /// In en, this message translates to:
  /// **'Here it is. Open it, or keep editing.'**
  String get creationsBuilderReady;

  /// creationsSaveToCreations
  ///
  /// In en, this message translates to:
  /// **'Save to Creations'**
  String get creationsSaveToCreations;

  /// creationsKeepEditing
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get creationsKeepEditing;

  /// creationsSpeakerNotes
  ///
  /// In en, this message translates to:
  /// **'Speaker notes'**
  String get creationsSpeakerNotes;

  /// creationsPresent
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get creationsPresent;

  /// creationsDuplicated
  ///
  /// In en, this message translates to:
  /// **'Duplicated.'**
  String get creationsDuplicated;

  /// onboardingChooseTitle
  ///
  /// In en, this message translates to:
  /// **'Choose what FinnAI can see'**
  String get onboardingChooseTitle;

  /// onboardingChooseBody
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Settings. All of it stays on this device.'**
  String get onboardingChooseBody;

  /// onboardingDownloadPausedTitle
  ///
  /// In en, this message translates to:
  /// **'Download paused'**
  String get onboardingDownloadPausedTitle;

  /// onboardingDownloadPausedBody
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection, your progress is saved.'**
  String get onboardingDownloadPausedBody;

  /// onboardingDownloadPausedNote
  ///
  /// In en, this message translates to:
  /// **'It continues when you are back online.'**
  String get onboardingDownloadPausedNote;

  /// flowsStepNotifyMe
  ///
  /// In en, this message translates to:
  /// **'Notify me'**
  String get flowsStepNotifyMe;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Tracker'**
  String get creationsTemplateTracker;

  /// Creations template/editor label
  ///
  /// In en, this message translates to:
  /// **'Added per tap'**
  String get creationsSlotStep;

  /// Title of the confirmation before a mini app forgets what it holds
  ///
  /// In en, this message translates to:
  /// **'Reset this app?'**
  String get creationsResetAppTitle;

  /// Body of the confirmation before a mini app forgets what it holds
  ///
  /// In en, this message translates to:
  /// **'Everything you added to it is cleared. This cannot be undone.'**
  String get creationsResetAppBody;

  /// Confirmation line for the vibrate device action
  ///
  /// In en, this message translates to:
  /// **'Vibrate the phone'**
  String get deviceActionVibrate;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Only when I start it'**
  String get flowsTrigManual;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'At a set time'**
  String get flowsTrigTimeOfDay;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Every {n} minutes'**
  String flowsTrigEveryMinutes(int n);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Every {n} hours'**
  String flowsTrigEveryHours(int n);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get flowsTrigEveryHour;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Repeating'**
  String get flowsTrigInterval;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Charger connected'**
  String get flowsTrigChargerOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Charger disconnected'**
  String get flowsTrigChargerOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Battery drops to {n}%'**
  String flowsTrigBatteryLow(int n);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Headphones connected'**
  String get flowsTrigHeadsetOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Headphones disconnected'**
  String get flowsTrigHeadsetOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi connected'**
  String get flowsTrigWifiOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi disconnected'**
  String get flowsTrigWifiOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Airplane mode turns on'**
  String get flowsTrigAirplaneOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Airplane mode turns off'**
  String get flowsTrigAirplaneOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Phone starts up'**
  String get flowsTrigBoot;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Screen unlocked'**
  String get flowsTrigUnlock;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get flowsTrigGroupTime;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'On the phone'**
  String get flowsTrigGroupPhone;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'By hand'**
  String get flowsTrigGroupHand;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Battery below {n}%'**
  String flowsCondBatteryBelow(int n);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Battery above {n}%'**
  String flowsCondBatteryAbove(int n);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get flowsCondCharging;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Not charging'**
  String get flowsCondNotCharging;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Between {from} and {to}'**
  String flowsCondTimeBetween(String from, String to);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'On {days}'**
  String flowsCondDays(String days);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi connected'**
  String get flowsCondWifiOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi not connected'**
  String get flowsCondWifiOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Headphones connected'**
  String get flowsCondHeadsetOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Headphones not connected'**
  String get flowsCondHeadsetOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Airplane mode on'**
  String get flowsCondAirplaneOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Airplane mode off'**
  String get flowsCondAirplaneOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'The answer mentions “{text}”'**
  String flowsCondAnswer(String text);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Ask FinnAI'**
  String get flowsBlockAsk;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Write something with the on-device model'**
  String get flowsBlockAskSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get flowsBlockWeb;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'News, weather or the web'**
  String get flowsBlockWebSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Notify me'**
  String get flowsBlockNotify;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Show a notification'**
  String get flowsBlockNotifySub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Say it out loud'**
  String get flowsBlockSpeak;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Speak with the phone’s voice'**
  String get flowsBlockSpeakSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Do on the phone'**
  String get flowsBlockAction;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Flashlight, volume, alarm, open an app'**
  String get flowsBlockActionSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get flowsBlockWait;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Pause for a few seconds'**
  String get flowsBlockWaitSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'If … then'**
  String get flowsBlockBranch;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Do one thing or another'**
  String get flowsBlockBranchSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Save to chat'**
  String get flowsBlockSave;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Keep the answer as a chat'**
  String get flowsBlockSaveSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Stop here'**
  String get flowsBlockStop;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'End the flow'**
  String get flowsBlockStopSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Ask: {text}'**
  String flowsSumAsk(String text);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Look up {text}'**
  String flowsSumWeb(String text);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Show the answer'**
  String get flowsSumNotifyAnswer;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Read the answer aloud'**
  String get flowsSumSpeakAnswer;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Wait {n} s'**
  String flowsSumWait(int n);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'If {condition}'**
  String flowsSumIf(String condition);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get flowsEdWhen;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Only if'**
  String get flowsEdOnlyIf;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get flowsEdThen;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get flowsEdOr;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get flowsEdYes;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Otherwise'**
  String get flowsEdOtherwise;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get flowsEdEnd;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Add a trigger'**
  String get flowsEdAddTrigger;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Add a condition'**
  String get flowsEdAddCondition;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Add a step'**
  String get flowsEdAddStep;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Add a step here'**
  String get flowsEdInsertHere;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Nothing to do yet. Add the first step.'**
  String get flowsEdNoSteps;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Starts when you tap Run'**
  String get flowsEdManualStart;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get flowsEdMoveUp;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get flowsEdMoveDown;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get flowsEdRemove;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get flowsEdDone;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What should happen?'**
  String get flowsEdChooseStep;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What starts it?'**
  String get flowsEdChooseTrigger;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Only when…'**
  String get flowsEdChooseCondition;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'If this is not true, the flow does not run when something else starts it.'**
  String get flowsEdConditionNote;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What should FinnAI write?'**
  String get flowsFieldPrompt;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Use {input} for the last answer'**
  String flowsFieldPromptHint(String input);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What to look up'**
  String get flowsFieldQuery;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get flowsFieldSource;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'The web'**
  String get flowsSourceWeb;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get flowsSourceNews;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get flowsSourceWeather;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get flowsFieldTitle;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get flowsFieldMessage;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Leave empty to show the last answer'**
  String get flowsFieldMessageHint;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What to say'**
  String get flowsFieldSay;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Leave empty to read the last answer'**
  String get flowsFieldSayHint;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'How many seconds'**
  String get flowsFieldSeconds;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get flowsFieldAction;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get flowsFieldCondition;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Battery level'**
  String get flowsFieldLevel;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get flowsFieldFrom;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get flowsFieldTo;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get flowsFieldDays;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Contains'**
  String get flowsFieldContains;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get flowsFieldEveryMinutes;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get flowsUnitMinutes;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get flowsUnitHours;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Works in the background'**
  String get flowsBgWorks;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Needs you to tap a notification'**
  String get flowsBgNeedsScreen;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Let it run by itself'**
  String get flowsAutoTitle;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'This flow changes your phone. Allow it to run when you are not looking.'**
  String get flowsAutoNeedsAllow;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'FinnAI is listening for these in the background.'**
  String get flowsListenerOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications so FinnAI can keep listening.'**
  String get flowsListenerNeedsNotify;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Conditions not met'**
  String get flowsRunStatusSkipped;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get flowsRunStatusNeedsScreen;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get flowsRunSkipped;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Tap to finish'**
  String get flowsRunNeedsScreen;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Ran by itself'**
  String get flowsRunByEvent;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Run from chat'**
  String get flowsRunByChat;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Tap to finish “{name}” — it needs the screen.'**
  String flowsNeedsScreenBody(String name);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'“{name}” wanted to run but needs your permission first.'**
  String flowsNeedsGrantBody(String name);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get flowsStepWaiting;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Step {n}'**
  String flowsPathStep(int n);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Describe your flow'**
  String get flowsDescribeTitle;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'For example: when I plug in my charger, turn on the flashlight'**
  String get flowsDescribeHint;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Build it'**
  String get flowsDescribeBuild;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Working it out…'**
  String get flowsDescribeThinking;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'I could not turn that into a flow. Try saying when it starts and what it should do.'**
  String get flowsDescribeFailed;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'I did not understand: {parts}'**
  String flowsDescribeMissed(String parts);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Try one of these'**
  String get flowsDescribeExamples;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'When I plug in my charger, turn on the flashlight'**
  String get flowsExampleCharger;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'When the battery is below 15%, remind me to charge'**
  String get flowsExampleBattery;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Every morning at 7 tell me the news'**
  String get flowsExampleNews;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'When I connect headphones, play music'**
  String get flowsExampleHeadset;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Start from scratch'**
  String get flowsNewBlank;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Build it step by step'**
  String get flowsNewBlankSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'From a template'**
  String get flowsNewTemplates;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'News brief, reminder, low battery…'**
  String get flowsNewTemplatesSub;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Low battery alert'**
  String get flowsTemplateLowBattery;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Tells you once when the battery gets low.'**
  String get flowsTemplateLowBatteryBody;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Headphones and music'**
  String get flowsTemplateHeadset;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Plays or pauses when headphones connect.'**
  String get flowsTemplateHeadsetBody;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Warn at (%)'**
  String get flowsSlotLevel;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What to do'**
  String get flowsSlotWhat;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get flowsSlotPlay;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get flowsSlotPause;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get flowsRunsTitle;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'See all runs'**
  String get flowsRunsAll;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Rename flow'**
  String get flowsRenameTitle;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get flowsSavedToast;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get flowsStepOutcomeSkipped;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'I made a flow: “{name}”. Check it, then turn it on.'**
  String flowsChatCreated(String name);

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Open flow'**
  String get flowsChatOpen;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get flowsChatTurnOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Turned on'**
  String get flowsChatIsOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get flowsChatDiscard;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Set an alarm'**
  String get flowsActSetAlarm;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Start a timer'**
  String get flowsActSetTimer;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Show my alarms'**
  String get flowsActShowAlarms;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get flowsActTorch;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Control music'**
  String get flowsActMedia;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Change the volume'**
  String get flowsActVolume;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Vibrate'**
  String get flowsActVibrate;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Open a settings screen'**
  String get flowsActOpenSettings;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Open an app'**
  String get flowsActOpenApp;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Start a call'**
  String get flowsActDial;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Write a text message'**
  String get flowsActSms;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Write an email'**
  String get flowsActEmail;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Open the camera'**
  String get flowsActPhoto;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Open a web address'**
  String get flowsActUrl;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get flowsActNavigate;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Share text'**
  String get flowsActShare;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get flowsOn;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get flowsOff;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get flowsParamState;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get flowsParamDirection;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get flowsParamScreen;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get flowsParamTime;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get flowsParamSeconds;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Milliseconds'**
  String get flowsParamMilliseconds;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get flowsParamLabel;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'App name'**
  String get flowsParamName;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get flowsParamNumber;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get flowsParamTo;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get flowsParamBody;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get flowsParamSubject;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Web address'**
  String get flowsParamUrl;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Place or address'**
  String get flowsParamQuery;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get flowsParamText;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'What should the phone do?'**
  String get flowsPickAction;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get flowsEveryHowLong;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'The phone groups timers to save battery, so it can be a few minutes late.'**
  String get flowsIntervalNote;

  /// Flows editor label
  ///
  /// In en, this message translates to:
  /// **'Runs once when the battery falls to this level.'**
  String get flowsBatteryLevelNote;

  /// Reply after FinnAI built something from a chat message
  ///
  /// In en, this message translates to:
  /// **'Here it is. Open it, or put it on your home screen.'**
  String get chatCreationReady;

  /// Reply while FinnAI builds something from a chat message
  ///
  /// In en, this message translates to:
  /// **'Building it…'**
  String get chatCreationBuilding;

  /// Status line of a flow that something else starts
  ///
  /// In en, this message translates to:
  /// **'On, starts by itself'**
  String get flowsDetailOnEvent;

  /// Settings voice page: speaking voice row title
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceStyle;

  /// Speaking voice style name
  ///
  /// In en, this message translates to:
  /// **'Female 1'**
  String get voiceStyleF1;

  /// Speaking voice style name
  ///
  /// In en, this message translates to:
  /// **'Female 2'**
  String get voiceStyleF2;

  /// Speaking voice style name
  ///
  /// In en, this message translates to:
  /// **'Male 1'**
  String get voiceStyleM1;

  /// Speaking voice style name
  ///
  /// In en, this message translates to:
  /// **'Male 2'**
  String get voiceStyleM2;

  /// Product name of the coding app inside FinnAI
  ///
  /// In en, this message translates to:
  /// **'FinnAI Code'**
  String get appBrandFinnAICode;

  /// Screen-reader hint on the brand row that switches apps
  ///
  /// In en, this message translates to:
  /// **'Switch between FinnAI and FinnAI Code'**
  String get appModeSwitchSemantic;

  /// Empty-state greeting in FinnAI Code
  ///
  /// In en, this message translates to:
  /// **'What shall we build?'**
  String get codeGreeting;

  /// Caption under the empty-state greeting
  ///
  /// In en, this message translates to:
  /// **'Your project lives in a private folder on this device.'**
  String get codeGreetingCaption;

  /// Placeholder of the FinnAI Code message field
  ///
  /// In en, this message translates to:
  /// **'Describe a task'**
  String get codeComposerHint;

  /// New coding session button
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get codeNewSession;

  /// Sidebar heading for coding sessions
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get codeSessionsTitle;

  /// Empty sessions list
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get codeNoSessions;

  /// Sidebar destination: project files
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get codeFilesTitle;

  /// Sidebar destination: shell
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get codeTerminalTitle;

  /// Sidebar destination: model picker
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get codeModelsTitle;

  /// Title of FinnAI Code settings
  ///
  /// In en, this message translates to:
  /// **'Code settings'**
  String get codeSettingsTitle;

  /// Model chip text when the on-device model is selected
  ///
  /// In en, this message translates to:
  /// **'FinnAI · on device'**
  String get codeLocalLabel;

  /// Screen-reader label of the model chip
  ///
  /// In en, this message translates to:
  /// **'Choose a model. Current: {model}'**
  String codeModelChipSemantic(String model);

  /// Permission chip: ask before everything
  ///
  /// In en, this message translates to:
  /// **'Ask first'**
  String get codePermissionAsk;

  /// Permission chip: files are written automatically
  ///
  /// In en, this message translates to:
  /// **'Auto-edit'**
  String get codePermissionEdits;

  /// Permission chip: everything runs automatically
  ///
  /// In en, this message translates to:
  /// **'Auto-run'**
  String get codePermissionAuto;

  /// Screen-reader label of the permission chip
  ///
  /// In en, this message translates to:
  /// **'Change what the agent may do. Current: {mode}'**
  String codePermissionSemantic(String mode);

  /// Shown while the model is writing
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get codeThinking;

  /// Title of a proposed shell command
  ///
  /// In en, this message translates to:
  /// **'Run command'**
  String get codeActionRunCommand;

  /// Title of a proposed file write
  ///
  /// In en, this message translates to:
  /// **'Write {path}'**
  String codeActionWriteFile(String path);

  /// Button that lets a command run
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get codeActionRun;

  /// Button that lets a file write happen
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get codeActionAllow;

  /// Button that declines a proposed action
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get codeActionSkip;

  /// Status of a running command
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get codeActionRunning;

  /// Status of a finished action
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get codeActionDone;

  /// Status of a command that exited with an error
  ///
  /// In en, this message translates to:
  /// **'Failed (exit {code})'**
  String codeActionFailedExit(String code);

  /// FinnAI Code session list: codeSessionsPinned
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get codeSessionsPinned;

  /// FinnAI Code session list: codeSessionsToday
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get codeSessionsToday;

  /// FinnAI Code session list: codeSessionsEarlier
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get codeSessionsEarlier;

  /// FinnAI Code session list: codeSessionWorking
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get codeSessionWorking;

  /// FinnAI Code session list: codeSessionNeedsYou
  ///
  /// In en, this message translates to:
  /// **'Needs you'**
  String get codeSessionNeedsYou;

  /// FinnAI Code session list: codeSessionNoChanges
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get codeSessionNoChanges;

  /// FinnAI Code session list: codeSessionOneFile
  ///
  /// In en, this message translates to:
  /// **'1 file'**
  String get codeSessionOneFile;

  /// How many files a Code session changed (two or more)
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String codeSessionFileCount(int count);

  /// Status of an action that failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get codeActionFailed;

  /// Status of a command that ran too long
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get codeActionTimedOut;

  /// Status of an action the user declined
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get codeActionSkipped;

  /// Status of an action the safety policy refused
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get codeActionDenied;

  /// Heading of a command’s output
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get codeActionOutput;

  /// Shown when a command printed nothing
  ///
  /// In en, this message translates to:
  /// **'No output'**
  String get codeActionNoOutput;

  /// Note under a long command output
  ///
  /// In en, this message translates to:
  /// **'Output was cut short'**
  String get codeActionOutputCut;

  /// Why a command was blocked
  ///
  /// In en, this message translates to:
  /// **'“{program}” is not allowed here.'**
  String codeDeniedBlockedProgram(String program);

  /// Why a command was blocked
  ///
  /// In en, this message translates to:
  /// **'Network commands are turned off.'**
  String get codeDeniedNetwork;

  /// Why a command or file was blocked
  ///
  /// In en, this message translates to:
  /// **'{path} is outside the project folder.'**
  String codeDeniedOutside(String path);

  /// Why a command was blocked
  ///
  /// In en, this message translates to:
  /// **'“..” is not allowed in paths.'**
  String get codeDeniedParent;

  /// Why a command was blocked
  ///
  /// In en, this message translates to:
  /// **'That command is not allowed.'**
  String get codeDeniedOther;

  /// Shown when a request used up its steps
  ///
  /// In en, this message translates to:
  /// **'Stopped at the step limit.'**
  String get codeErrorStepLimit;

  /// Shown when the model loops
  ///
  /// In en, this message translates to:
  /// **'Stopped: the model kept repeating the same step.'**
  String get codeErrorRepeating;

  /// Shown when the model says nothing
  ///
  /// In en, this message translates to:
  /// **'The model sent an empty reply.'**
  String get codeErrorEmpty;

  /// Shown when a reply ended inside its action
  ///
  /// In en, this message translates to:
  /// **'The reply was cut off before the step finished, so nothing ran.'**
  String get codeErrorCutOff;

  /// Generic failure with a short detail
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {detail}'**
  String codeErrorEngine(String detail);

  /// Provider error: bad key
  ///
  /// In en, this message translates to:
  /// **'The provider rejected the key. Check it in Code settings.'**
  String get codeErrorAuth;

  /// Provider error: Command Code Go plan
  ///
  /// In en, this message translates to:
  /// **'Command Code’s Go plan has no API access. Upgrade to GOAT or higher to use it here.'**
  String get codeErrorPlanNoApi;

  /// Provider error: no credit
  ///
  /// In en, this message translates to:
  /// **'Out of credit with this provider.'**
  String get codeErrorPayment;

  /// Provider error: rate limit
  ///
  /// In en, this message translates to:
  /// **'Rate limited. Try again in a moment.'**
  String get codeErrorRate;

  /// Provider error: model not available
  ///
  /// In en, this message translates to:
  /// **'This provider could not serve that model.'**
  String get codeErrorWrongEndpoint;

  /// Provider error: bad request
  ///
  /// In en, this message translates to:
  /// **'The provider could not accept the request.'**
  String get codeErrorBadRequest;

  /// Provider error: server
  ///
  /// In en, this message translates to:
  /// **'The provider had a problem. Try again.'**
  String get codeErrorServer;

  /// Provider error: network
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach the provider. Check your connection.'**
  String get codeErrorNetwork;

  /// Provider error: timeout
  ///
  /// In en, this message translates to:
  /// **'The provider took too long to answer.'**
  String get codeErrorTimeout;

  /// Provider error: malformed reply
  ///
  /// In en, this message translates to:
  /// **'The provider sent a reply that couldn’t be read.'**
  String get codeErrorMalformed;

  /// Provider error: unknown
  ///
  /// In en, this message translates to:
  /// **'Something went wrong with the provider.'**
  String get codeErrorUnknown;

  /// Session menu
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get codeSessionRename;

  /// Rename dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get codeSessionRenameTitle;

  /// Session menu
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get codeSessionPin;

  /// Session menu
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get codeSessionUnpin;

  /// Session menu
  ///
  /// In en, this message translates to:
  /// **'Project files'**
  String get codeSessionFiles;

  /// Session menu
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get codeSessionDelete;

  /// Delete dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get codeSessionDeleteTitle;

  /// Delete dialog body
  ///
  /// In en, this message translates to:
  /// **'The conversation and its project files are removed from this device.'**
  String get codeSessionDeleteBody;

  /// Disclosure before the first cloud model
  ///
  /// In en, this message translates to:
  /// **'Use {provider}?'**
  String codeCloudTitle(String provider);

  /// Disclosure body: cloud providers receive the conversation
  ///
  /// In en, this message translates to:
  /// **'{provider} runs in the cloud. What you type, and any file contents or command output the agent reads, is sent to {provider} and handled under its terms. FinnAI on this device keeps everything on the phone.'**
  String codeCloudBody(String provider);

  /// Confirm button of the disclosure
  ///
  /// In en, this message translates to:
  /// **'Use {provider}'**
  String codeCloudConfirm(String provider);

  /// Search field on the models page
  ///
  /// In en, this message translates to:
  /// **'Search models'**
  String get codeModelsSearchHint;

  /// On-device model row title
  ///
  /// In en, this message translates to:
  /// **'FinnAI'**
  String get codeModelsOnDeviceTitle;

  /// On-device model row subtitle
  ///
  /// In en, this message translates to:
  /// **'Runs on this device. Private, free and works offline.'**
  String get codeModelsOnDeviceSub;

  /// Row that leads to provider setup
  ///
  /// In en, this message translates to:
  /// **'Add a provider to use more models'**
  String get codeModelsAddProvider;

  /// Shown while a model list loads
  ///
  /// In en, this message translates to:
  /// **'Loading models…'**
  String get codeModelsLoading;

  /// Button that fetches a provider’s models
  ///
  /// In en, this message translates to:
  /// **'Load models'**
  String get codeModelsLoad;

  /// Empty search result
  ///
  /// In en, this message translates to:
  /// **'No models match'**
  String get codeModelsNone;

  /// Badge on a free model
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get codeModelsFree;

  /// Context window of a model, e.g. 128K
  ///
  /// In en, this message translates to:
  /// **'{size} context'**
  String codeModelsContext(String size);

  /// Price of a model per million tokens
  ///
  /// In en, this message translates to:
  /// **'{input} in · {output} out per 1M'**
  String codeModelsPrice(String input, String output);

  /// Shown when listing models failed
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load models. {reason}'**
  String codeModelsFetchFailed(String reason);

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get codeSettingsProviders;

  /// Settings row subtitle with no provider added
  ///
  /// In en, this message translates to:
  /// **'FinnAI on this device'**
  String get codeSettingsProvidersSubNone;

  /// Settings row subtitle with providers added
  ///
  /// In en, this message translates to:
  /// **'FinnAI plus {count} connected'**
  String codeSettingsProvidersSub(String count);

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get codeSettingsModel;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get codeSettingsAgent;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Project folders'**
  String get codeSettingsWorkspace;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'{size} on this device'**
  String codeSettingsWorkspaceSub(String size);

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'Privacy and data'**
  String get codeSettingsData;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Keys, sessions and project files'**
  String get codeSettingsDataSub;

  /// Settings row
  ///
  /// In en, this message translates to:
  /// **'About FinnAI Code'**
  String get codeSettingsAbout;

  /// Page title
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get codeProvidersTitle;

  /// Intro on the providers page
  ///
  /// In en, this message translates to:
  /// **'FinnAI on your phone is the default. Add your own API key to use a cloud model in FinnAI Code. Keys stay in your phone’s secure storage.'**
  String get codeProvidersIntro;

  /// Provider status
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get codeProviderStatusLocal;

  /// Provider status with the last four characters of the key
  ///
  /// In en, this message translates to:
  /// **'Connected · ••••{hint}'**
  String codeProviderStatusConnected(String hint);

  /// Provider status when no key is needed
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get codeProviderStatusConnectedNoKey;

  /// Provider status
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get codeProviderStatusNotSet;

  /// Provider description
  ///
  /// In en, this message translates to:
  /// **'One key for hundreds of models, free ones included.'**
  String get codeProviderDescOpenRouter;

  /// Provider description
  ///
  /// In en, this message translates to:
  /// **'Command Code’s models, through your own key.'**
  String get codeProviderDescCommandCode;

  /// Provider description
  ///
  /// In en, this message translates to:
  /// **'OpenCode Zen: pay-as-you-go models chosen for coding.'**
  String get codeProviderDescZen;

  /// Provider description
  ///
  /// In en, this message translates to:
  /// **'OpenCode Go: a flat monthly plan of open coding models.'**
  String get codeProviderDescGo;

  /// Provider description
  ///
  /// In en, this message translates to:
  /// **'Any server that speaks the OpenAI API: your own, Ollama, LM Studio and more.'**
  String get codeProviderDescCustom;

  /// Name of the custom provider
  ///
  /// In en, this message translates to:
  /// **'Custom (OpenAI compatible)'**
  String get codeProviderCustomName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get codeProviderKeyLabel;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Paste your key'**
  String get codeProviderKeyHint;

  /// Field hint for a custom server
  ///
  /// In en, this message translates to:
  /// **'Paste a key if your server needs one'**
  String get codeProviderKeyOptionalHint;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get codeProviderKeySave;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Replace key'**
  String get codeProviderKeyReplace;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get codeProviderKeyRemove;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove this key?'**
  String get codeProviderKeyRemoveTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'FinnAI Code will stop using {provider} until you add a key again.'**
  String codeProviderKeyRemoveBody(String provider);

  /// Caption under the key field
  ///
  /// In en, this message translates to:
  /// **'Stored securely on this device'**
  String get codeProviderKeyStored;

  /// Button that opens the provider’s key page
  ///
  /// In en, this message translates to:
  /// **'Get a key'**
  String get codeProviderGetKey;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Test key'**
  String get codeProviderTest;

  /// Shown while a key is tested
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get codeProviderTesting;

  /// Result of a key test
  ///
  /// In en, this message translates to:
  /// **'The key works.'**
  String get codeProviderTestOk;

  /// Result of a key test
  ///
  /// In en, this message translates to:
  /// **'Test failed. {reason}'**
  String codeProviderTestFail(String reason);

  /// Hint when no model is available for a test
  ///
  /// In en, this message translates to:
  /// **'Load the models first, then test.'**
  String get codeProviderTestNeedsModel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get codeProviderAddressLabel;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'https://your-server/v1'**
  String get codeProviderAddressHint;

  /// Validation message
  ///
  /// In en, this message translates to:
  /// **'Use an https address, or http for a server on your own network.'**
  String get codeProviderAddressInvalid;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get codeProviderAddressSave;

  /// Note on the Command Code page
  ///
  /// In en, this message translates to:
  /// **'Requires the GOAT plan or higher. The Go plan has no API access and can’t be used here.'**
  String get codeProviderPlanNote;

  /// Privacy note on a provider page
  ///
  /// In en, this message translates to:
  /// **'When you use one of its models, your messages, file contents and command output are sent to {provider}.'**
  String codeProviderPrivacy(String provider);

  /// Section heading
  ///
  /// In en, this message translates to:
  /// **'Allowance'**
  String get codeProviderAllowance;

  /// Allowance with a cap
  ///
  /// In en, this message translates to:
  /// **'{remaining} left of {limit}'**
  String codeProviderAllowanceRemaining(String remaining, String limit);

  /// Allowance without a cap
  ///
  /// In en, this message translates to:
  /// **'No spending limit on this key'**
  String get codeProviderAllowanceUnlimited;

  /// Spend so far
  ///
  /// In en, this message translates to:
  /// **'{used} used'**
  String codeProviderAllowanceUsed(String used);

  /// Spend today
  ///
  /// In en, this message translates to:
  /// **'{amount} today'**
  String codeProviderAllowanceToday(String amount);

  /// Spend this month
  ///
  /// In en, this message translates to:
  /// **'{amount} this month'**
  String codeProviderAllowanceMonth(String amount);

  /// Account balance
  ///
  /// In en, this message translates to:
  /// **'Account credit {balance}'**
  String codeProviderAllowanceBalance(String balance);

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Free-tier key'**
  String get codeProviderAllowanceFree;

  /// Shown for providers with no usage endpoint
  ///
  /// In en, this message translates to:
  /// **'{provider} doesn’t offer a usage API. Check your balance on its dashboard.'**
  String codeProviderAllowanceNoApi(String provider);

  /// Button that opens the provider’s billing page
  ///
  /// In en, this message translates to:
  /// **'Open dashboard'**
  String get codeProviderOpenDashboard;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get codeProviderRefresh;

  /// Number of models fetched
  ///
  /// In en, this message translates to:
  /// **'{count} models available'**
  String codeProviderModelsCount(String count);

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Refresh model list'**
  String get codeProviderModelsRefresh;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get codeProviderChooseModel;

  /// Caption under the model count
  ///
  /// In en, this message translates to:
  /// **'Fetched live from {provider}'**
  String codeProviderModelsLive(String provider);

  /// Page title
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get codeAgentTitle;

  /// Section heading
  ///
  /// In en, this message translates to:
  /// **'When the agent acts'**
  String get codeAgentPermissionTitle;

  /// Permission option
  ///
  /// In en, this message translates to:
  /// **'Ask before everything'**
  String get codeAgentAsk;

  /// Permission option subtitle
  ///
  /// In en, this message translates to:
  /// **'Every command and file write waits for your tap.'**
  String get codeAgentAskSub;

  /// Permission option
  ///
  /// In en, this message translates to:
  /// **'Write files, ask for commands'**
  String get codeAgentEdits;

  /// Permission option subtitle
  ///
  /// In en, this message translates to:
  /// **'Files are written as it goes. Commands wait for your tap.'**
  String get codeAgentEditsSub;

  /// Permission option
  ///
  /// In en, this message translates to:
  /// **'Run everything'**
  String get codeAgentAuto;

  /// Permission option subtitle
  ///
  /// In en, this message translates to:
  /// **'Nothing waits for you. Commands still stay inside the project folder.'**
  String get codeAgentAutoSub;

  /// Setting
  ///
  /// In en, this message translates to:
  /// **'Steps per request'**
  String get codeAgentSteps;

  /// Setting description
  ///
  /// In en, this message translates to:
  /// **'How many actions the agent may take before it stops and asks to continue.'**
  String get codeAgentStepsSub;

  /// Setting value
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get codeAgentStepsAuto;

  /// Setting value
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String codeAgentStepsValue(String count);

  /// Setting
  ///
  /// In en, this message translates to:
  /// **'Allow network commands'**
  String get codeAgentNetwork;

  /// Setting description
  ///
  /// In en, this message translates to:
  /// **'Lets commands like curl reach the internet. Off keeps your project from being uploaded by mistake.'**
  String get codeAgentNetworkSub;

  /// Setting
  ///
  /// In en, this message translates to:
  /// **'Command time limit'**
  String get codeAgentTimeout;

  /// Setting value in seconds
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String codeAgentTimeoutValue(String seconds);

  /// Honest description of the command sandbox
  ///
  /// In en, this message translates to:
  /// **'Commands run in a private folder on this phone, as the app’s own user, with a time limit. This is not a full Linux system: there is no python, git or compiler, and nothing can be installed.'**
  String get codeSandboxNote;

  /// Page title
  ///
  /// In en, this message translates to:
  /// **'Project folders'**
  String get codeWorkspaceTitle;

  /// Storage summary
  ///
  /// In en, this message translates to:
  /// **'{size} in {count} project folders'**
  String codeWorkspaceUsed(String size, String count);

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Delete all project files'**
  String get codeWorkspaceClear;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete all project files?'**
  String get codeWorkspaceClearTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Every session’s project folder is emptied. Conversations stay.'**
  String get codeWorkspaceClearBody;

  /// Page title
  ///
  /// In en, this message translates to:
  /// **'Privacy and data'**
  String get codeDataTitle;

  /// Where Code data lives
  ///
  /// In en, this message translates to:
  /// **'Sessions and project files are stored in this app’s private storage on your phone. API keys are kept in the system’s secure storage. With FinnAI on this device, nothing leaves the phone.'**
  String get codeDataNote;

  /// Row
  ///
  /// In en, this message translates to:
  /// **'Delete FinnAI Code data'**
  String get codeDataDelete;

  /// Row subtitle
  ///
  /// In en, this message translates to:
  /// **'Sessions, project files, saved keys and settings'**
  String get codeDataDeleteSub;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete FinnAI Code data?'**
  String get codeDataDeleteTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Every session, project folder, saved key and Code setting is deleted. FinnAI chats are not touched.'**
  String get codeDataDeleteBody;

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'FinnAI Code data deleted.'**
  String get codeDataDeleted;

  /// About page body
  ///
  /// In en, this message translates to:
  /// **'FinnAI Code is a coding agent. It works with the model on your phone, or with your own provider keys, and can read and write files in a private project folder and run simple commands there.'**
  String get codeAboutBody;

  /// Empty file list
  ///
  /// In en, this message translates to:
  /// **'No files yet. Ask the agent to create something.'**
  String get codeFilesEmpty;

  /// Shown when no session is open
  ///
  /// In en, this message translates to:
  /// **'Start a session to get a project folder.'**
  String get codeFilesNoSession;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get codeFileCopy;

  /// Confirmation
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get codeFileCopied;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get codeFileDelete;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String codeFileDeleteTitle(String name);

  /// Shown for an empty file
  ///
  /// In en, this message translates to:
  /// **'This file is empty.'**
  String get codeFileEmpty;

  /// Terminal input hint
  ///
  /// In en, this message translates to:
  /// **'Run a command'**
  String get codeTerminalHint;

  /// Terminal caption
  ///
  /// In en, this message translates to:
  /// **'Runs in this session’s project folder.'**
  String get codeTerminalIntro;

  /// Shown where no shell exists
  ///
  /// In en, this message translates to:
  /// **'Commands can’t run on this device.'**
  String get codeTerminalUnsupported;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get codeTerminalClear;

  /// Shown when a reply held an action block that could not be used
  ///
  /// In en, this message translates to:
  /// **'The model wrote an action it couldn’t use, so nothing ran.'**
  String get codeErrorMalformedAction;

  /// Disclosure title for a user’s own server
  ///
  /// In en, this message translates to:
  /// **'Use this server?'**
  String get codeCloudTitleCustom;

  /// Disclosure body for a user’s own server
  ///
  /// In en, this message translates to:
  /// **'What you type, and any file contents or command output the agent reads, is sent to {address}. FinnAI on this device keeps everything on the phone.'**
  String codeCloudBodyCustom(String address);

  /// Disclosure confirm button for a user’s own server
  ///
  /// In en, this message translates to:
  /// **'Use this server'**
  String get codeCloudConfirmCustom;

  /// Title bar button: minimize the window
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// Title bar button: maximize the window
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// Title bar button: restore the window to its previous size
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get windowRestore;

  /// Welcome screen button on desktop and tablet, where there is no swipe
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Linux container'**
  String get codeSettingsContainer;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Commands run in Linux'**
  String get codeSettingsContainerSubReady;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get codeSettingsContainerSubMissing;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Linux container'**
  String get codeContainerTitle;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Commands run in a small Linux computer that FinnAI emulates on this device. It works the same on every phone and computer, and it can’t see or change anything outside the project. It has the busybox tools (sh, sed, awk, vi, tar…) but no python, git, compiler or network.'**
  String get codeContainerIntro;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Downloaded and verified'**
  String get codeContainerStatusReady;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get codeContainerStatusRunning;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get codeContainerStatusStarting;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Not downloaded ({size})'**
  String codeContainerStatusMissing(String size);

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String codeContainerStatusDownloading(String percent);

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'The download failed. Check your connection and try again.'**
  String get codeContainerErrorNetwork;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'The download didn’t match its checksum, so it was discarded. Try again.'**
  String get codeContainerErrorVerification;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'There isn’t enough room to save it.'**
  String get codeContainerErrorStorage;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'This device can’t run the container, so commands use its own shell.'**
  String get codeContainerUnsupported;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Download ({size})'**
  String codeContainerDownload(String size);

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get codeContainerCancel;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Run commands in the container'**
  String get codeContainerUse;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Off runs them in this device’s own shell instead.'**
  String get codeContainerUseSub;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Restart container'**
  String get codeContainerRestart;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Project files are kept; they live on this device.'**
  String get codeContainerRestartSub;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Remove container'**
  String get codeContainerRemove;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Remove the Linux container?'**
  String get codeContainerRemoveTitle;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Your project files stay. Commands will run in this device’s shell until you download it again.'**
  String get codeContainerRemoveBody;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'The emulator is v86 (BSD licence). The Linux kernel, busybox and SeaBIOS are downloaded from the v86 project under their GPL and LGPL licences.'**
  String get codeContainerLicence;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Runs in this session’s project folder, inside the Linux container. The first command starts it.'**
  String get codeTerminalIntroContainer;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Set up the Linux container'**
  String get codeTerminalSetUpContainer;

  /// FinnAI Code Linux container
  ///
  /// In en, this message translates to:
  /// **'Commands run on this device for now. The container isolates them and works the same everywhere.'**
  String get codeTerminalSetUpContainerSub;

  /// FinnAI Code attachments
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get codeAttachFiles;

  /// FinnAI Code attachments
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String codeAttachmentRemove(String name);

  /// FinnAI Code attachments
  ///
  /// In en, this message translates to:
  /// **'Couldn’t add {names}'**
  String codeAttachFailed(String names);

  /// Tool row verb for a command
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get codeVerbRun;

  /// Tool row verb for a file write
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get codeVerbWrite;

  /// Tool row verb for a file edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get codeVerbEdit;

  /// Marks a write that created a file
  ///
  /// In en, this message translates to:
  /// **'new file'**
  String get codeNewFile;

  /// Expands clipped code or output
  ///
  /// In en, this message translates to:
  /// **'Show {count} more lines'**
  String codeShowMoreLines(String count);

  /// Collapses code or output
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get codeShowLess;

  /// A folded run in a diff
  ///
  /// In en, this message translates to:
  /// **'{count} unchanged lines'**
  String codeUnchangedLines(String count);

  /// Inline approval prompt for a command
  ///
  /// In en, this message translates to:
  /// **'Run this command?'**
  String get codeApproveRun;

  /// Inline approval prompt for a write
  ///
  /// In en, this message translates to:
  /// **'Write this file?'**
  String get codeApproveWrite;

  /// Inline approval prompt for an edit
  ///
  /// In en, this message translates to:
  /// **'Apply this edit?'**
  String get codeApproveEdit;

  /// Rejects a proposed action
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get codeReject;

  /// Approves a proposed write or edit
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get codeApply;

  /// A command's non-zero exit code, in a tool row
  ///
  /// In en, this message translates to:
  /// **'exit {code}'**
  String codeExitCode(String code);

  /// Copies code or output
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get codeCopy;

  /// Status line: nothing running
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get codeStatusIdle;

  /// Status line: waiting on the model
  ///
  /// In en, this message translates to:
  /// **'thinking'**
  String get codeStatusThinking;

  /// Status line: a command runs
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get codeStatusRunning;

  /// Status line: an action needs approval
  ///
  /// In en, this message translates to:
  /// **'waiting for you'**
  String get codeStatusWaiting;

  /// Status line: commands run in the Linux sandbox
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get codeEnvLinux;

  /// Status line: commands run in the device shell
  ///
  /// In en, this message translates to:
  /// **'shell'**
  String get codeEnvDevice;

  /// Status line: no commands can run
  ///
  /// In en, this message translates to:
  /// **'files only'**
  String get codeEnvNone;

  /// Slash command /new
  ///
  /// In en, this message translates to:
  /// **'Start a new session'**
  String get codeSlashNewDesc;

  /// Slash command /files
  ///
  /// In en, this message translates to:
  /// **'Browse the project files'**
  String get codeSlashFilesDesc;

  /// Slash command /terminal
  ///
  /// In en, this message translates to:
  /// **'Open the terminal'**
  String get codeSlashTerminalDesc;

  /// Slash command /model
  ///
  /// In en, this message translates to:
  /// **'Choose the model'**
  String get codeSlashModelDesc;

  /// Slash command /mode
  ///
  /// In en, this message translates to:
  /// **'Change what the agent may do'**
  String get codeSlashModeDesc;

  /// Slash command /retry
  ///
  /// In en, this message translates to:
  /// **'Continue or retry the last request'**
  String get codeSlashRetryDesc;

  /// Slash command /settings
  ///
  /// In en, this message translates to:
  /// **'Open Code settings'**
  String get codeSlashSettingsDesc;

  /// File mention list is empty
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get codeMentionNoFiles;

  /// Opens the terminal panel as a page
  ///
  /// In en, this message translates to:
  /// **'Open full screen'**
  String get codeTerminalExpand;

  /// Opens the terminal panel
  ///
  /// In en, this message translates to:
  /// **'Show terminal'**
  String get codeTerminalShow;

  /// Closes the terminal panel
  ///
  /// In en, this message translates to:
  /// **'Hide terminal'**
  String get codeTerminalHide;

  /// Title of the Linux sandbox page
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get codeLinuxTitle;

  /// Intro of the Linux sandbox page
  ///
  /// In en, this message translates to:
  /// **'A real Alpine Linux runs on this phone for FinnAI Code. Install what a project needs (apk or apt-get, pip, npm), clone repositories and build. It sees its own files and this session’s project folder at /workspace, nothing else on the device. It uses the internet for installs and git.'**
  String get codeLinuxIntro;

  /// Linux sandbox not installed
  ///
  /// In en, this message translates to:
  /// **'Not set up · {size} download'**
  String codeLinuxStatusMissing(String size);

  /// Linux sandbox is being unpacked
  ///
  /// In en, this message translates to:
  /// **'Setting up…'**
  String get codeLinuxStatusPreparing;

  /// Linux sandbox installed
  ///
  /// In en, this message translates to:
  /// **'Alpine Linux {version} · ready'**
  String codeLinuxStatusReady(String version);

  /// Downloads and sets up the sandbox
  ///
  /// In en, this message translates to:
  /// **'Set up Linux ({size})'**
  String codeLinuxSetUp(String size);

  /// Switch: commands use the sandbox
  ///
  /// In en, this message translates to:
  /// **'Run commands in Linux'**
  String get codeLinuxUse;

  /// Deletes the sandbox
  ///
  /// In en, this message translates to:
  /// **'Remove Linux'**
  String get codeLinuxRemove;

  /// Confirm title
  ///
  /// In en, this message translates to:
  /// **'Remove Linux?'**
  String get codeLinuxRemoveTitle;

  /// Confirm body
  ///
  /// In en, this message translates to:
  /// **'Everything installed in it is deleted. Your project folders stay.'**
  String get codeLinuxRemoveBody;

  /// Sandbox unsupported
  ///
  /// In en, this message translates to:
  /// **'This device can’t run Linux, so commands use its own shell.'**
  String get codeLinuxUnsupported;

  /// Licence note
  ///
  /// In en, this message translates to:
  /// **'Alpine Linux and its packages come under their own licences. proot (GPL-2.0) runs them; its source is at github.com/termux/proot.'**
  String get codeLinuxLicence;

  /// Terminal intro in the Linux sandbox
  ///
  /// In en, this message translates to:
  /// **'Alpine Linux, in this session’s project folder (/workspace).'**
  String get codeTerminalIntroLinux;

  /// Settings row subtitle
  ///
  /// In en, this message translates to:
  /// **'Alpine Linux · commands run here'**
  String get codeSettingsLinuxSubReady;

  /// Exactly one model in a provider's list
  ///
  /// In en, this message translates to:
  /// **'1 model available'**
  String get codeProviderModelsOne;

  /// FinnAI Code changes review: codeChangesTitle
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get codeChangesTitle;

  /// FinnAI Code changes review: codeChangesSubtitle
  ///
  /// In en, this message translates to:
  /// **'Everything this session changed, file by file.'**
  String get codeChangesSubtitle;

  /// FinnAI Code changes review: codeChangesSemantic
  ///
  /// In en, this message translates to:
  /// **'Review changes: {files}, plus {added}, minus {removed}'**
  String codeChangesSemantic(String files, String added, String removed);

  /// FinnAI Code changes review: codeChangesNewFile
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get codeChangesNewFile;

  /// FinnAI Code approval: allow this kind of action for the rest of the session
  ///
  /// In en, this message translates to:
  /// **'Allow in session'**
  String get codeApproveSession;
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
