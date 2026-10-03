// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCopiedToClipboard => 'Copied to clipboard';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonResend => 'Resend';

  @override
  String get commonSaveFlow => 'Save flow';

  @override
  String get commonKeepCreating => 'Keep creating';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonPurge => 'Free up';

  @override
  String get commonClearAll => 'Clear All';

  @override
  String get commonDeleteEverything => 'Delete Everything';

  @override
  String get appTitle => 'Finn AI';

  @override
  String get appBrandFinnAI => 'FinnAI';

  @override
  String get unsupportedTitle => 'Finn AI cannot run on this device';

  @override
  String get unsupportedBody =>
      'Finn AI requires at least 3 GB of RAM and a 64-bit ARM processor to run local models reliably. No model has been downloaded.';

  @override
  String get onboardingWelcome => 'Welcome to FinnAI';

  @override
  String get onboardingSwipeToStart => 'Swipe to start';

  @override
  String get onboardingPrivacyTitle => 'FinnAI values your privacy';

  @override
  String get onboardingPrivacyLead => 'FinnAI takes your privacy at its core.';

  @override
  String get onboardingPrivacyBody =>
      'We do not track or store your data, every request is processed locally on your device. ';

  @override
  String get onboardingPrivacyLink => 'View more on our Privacy Policy.';

  @override
  String get onboardingPrecautionsTitle => 'Before starting, read precautions';

  @override
  String get onboardingPrecautionOne => 'On-device AI prompt processing';

  @override
  String get onboardingPrecautionTwo => 'Offline chat after model download';

  @override
  String get onboardingPrecautionThree => 'Encrypted conversation storage';

  @override
  String get onboardingPrecautionFour => 'Designed for battery efficiency';

  @override
  String get onboardingInstallTitleInstalling =>
      'Downloading FinnAI Foundation';

  @override
  String get onboardingInstallTitleReady => 'FinnAI Foundation ready';

  @override
  String get onboardingDownloadLead => 'Setting up FinnAI,';

  @override
  String get onboardingDownloadNote => 'the first run takes a few minutes.';

  @override
  String onboardingProgressPercent(Object percent) {
    return '$percent% done.';
  }

  @override
  String get onboardingProgressEtaTail => 'left.';

  @override
  String onboardingProgressEtaAbout(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'About $_temp0 left.';
  }

  @override
  String get onboardingInstallPreparing =>
      'Preparing LFM2.5-VL 1.6B for this device…';

  @override
  String get onboardingInstallReadyForChat =>
      'Ready for private text chat on this device';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + image support · $size';
  }

  @override
  String get onboardingInstallModelReady => 'Model ready';

  @override
  String onboardingInstallProgressStatus(String status, String percent) {
    return '$status · $percent%';
  }

  @override
  String onboardingInstallBytesOf(String received, String total) {
    return '$received of $total';
  }

  @override
  String onboardingInstallBytesLeft(String remaining) {
    return '$remaining left';
  }

  @override
  String get onboardingInstallRetry => 'Retry';

  @override
  String get onboardingInstallRetryLabel => 'Retry model download';

  @override
  String get onboardingInstallVerificationFailed => 'Model verification failed';

  @override
  String get onboardingUpgradeTitle => 'FinnAI Software Upgrade';

  @override
  String get onboardingUpgradeBody =>
      'Finn AI now runs a newer on-device model. Download it to continue chatting privately.';

  @override
  String get onboardingReadyTitle => 'FinnAI is ready!';

  @override
  String get onboardingReadyLead => 'FinnAI is ready for use!';

  @override
  String get onboardingReadyBody =>
      'You can now use FinnAI, both online and offline.\nWe hope you enjoy using it!';

  @override
  String get onboardingReadySubtitle => 'You\'re all set. Finn AI is ready.';

  @override
  String get onboardingConsentTitle =>
      'Do you allow FinnAI to get context on your device?';

  @override
  String get onboardingConsentBody =>
      'This lets FinnAI read things like your calendar, notes and photos so its answers fit you better. It only reads on this device, and nothing is sent anywhere.';

  @override
  String get onboardingConsentRequiredHint => 'Choose Yes or No to continue';

  @override
  String get onboardingStartUsing => 'Start using FinnAI';

  @override
  String get onboardingYouLabel => 'You';

  @override
  String get chatNewChat => 'New chat';

  @override
  String get chatHistory => 'Chats';

  @override
  String get chatNoHistory => 'No history';

  @override
  String get chatFinnGenerating => 'Finn is generating…';

  @override
  String get chatFinnTyping => 'Finn is typing…';

  @override
  String get chatAskAnything =>
      'Ask me anything — I run entirely on this device, so your\nconversations never leave your phone.';

  @override
  String get chatTryAsking => 'Try asking';

  @override
  String get chatMessageHint => 'Message Finn…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatStopGeneration => 'Stop';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get chatRenameTitle => 'Rename chat';

  @override
  String get chatRenameHint => 'Chat title';

  @override
  String get chatDeleteTitle => 'Delete chat?';

  @override
  String chatDeleteBody(String title) {
    return '“$title” will be removed. This cannot be undone.';
  }

  @override
  String get chatContinue => 'Continue';

  @override
  String get chatSources => 'Sources';

  @override
  String get chatHistoryUnavailableNotice =>
      'Finn couldn\'t open your chat history on this device, so new replies won\'t be saved.';

  @override
  String get chatOfflineNotice =>
      'Offline — answer may be less accurate. Connect for cited sources.';

  @override
  String get chatFinishingTask => 'Finn AI is finishing another local task.';

  @override
  String get chatAttachmentPickFailed =>
      'Couldn\'t open the picker. Please try again.';

  @override
  String get chatCouldNotPrepare =>
      'Could not prepare chat. Check the model and storage, then try again.';

  @override
  String get chatEmptyReply =>
      'Finn didn\'t come up with an answer that time. Tap Retry to ask again.';

  @override
  String chatGeneratingIn(String title) {
    return 'Generating in $title';
  }

  @override
  String get chatDownloadModelTitle =>
      'Download the AI model for offline chat?';

  @override
  String chatDownloadModelBody(String size) {
    return '$size downloads once and is verified before use. The download resumes safely after an interrupted connection, and your chats stay on this device.';
  }

  @override
  String get chatHiPrefix => 'Hi, I\'m Finn.';

  @override
  String get chatFinnAI => 'Finn AI';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsContextTitle => 'On-device context';

  @override
  String get settingsContextSubtitle =>
      'Let FinnAI use context from this device';

  @override
  String get settingsAiModel => 'AI MODEL';

  @override
  String get settingsStorageData => 'STORAGE & DATA';

  @override
  String get settingsPrivacyLegal => 'PRIVACY & LEGAL';

  @override
  String get settingsAbout => 'ABOUT';

  @override
  String settingsSavedConversations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats (Encrypted)',
      one: '1 chat (Encrypted)',
    );
    return '$_temp0';
  }

  @override
  String get settingsReleasingMemory => 'Freeing up memory…';

  @override
  String get settingsPurgeMemorySubtitle =>
      'Frees RAM. The model reloads on your next message.';

  @override
  String get settingsClearHistorySubtitle =>
      'Deletes every saved chat. Cannot be undone.';

  @override
  String get settingsDeleteAllDataSubtitle =>
      'Chats, models, creations and preferences — back to a first run.';

  @override
  String get settingsPurgeMemory => 'Free up memory';

  @override
  String get settingsPurgeMemoryTitle => 'Free up memory?';

  @override
  String get settingsPurgeMemoryBody =>
      'This closes the AI model to free up memory. It will open again on your next message.';

  @override
  String get settingsPurgeMemoryReleased => 'Memory freed up.';

  @override
  String get settingsClearHistory => 'Clear All Chat History';

  @override
  String get settingsClearHistoryTitle => 'Clear All Conversations?';

  @override
  String get settingsClearHistoryBody =>
      'This will permanently delete all chat history. This action cannot be undone.';

  @override
  String get settingsClearHistorySuccess => 'All conversations cleared.';

  @override
  String get settingsClearHistoryFailure =>
      'Could not clear conversations. Check storage and try again.';

  @override
  String get settingsDeleteAllData => 'Delete All Local Data';

  @override
  String get settingsDeleteAllDataTitle => 'Delete All Local Data?';

  @override
  String get settingsDeleteAllDataBody =>
      'This permanently deletes encrypted conversations and keys, downloaded AI models, creations, profile preferences, flows, and onboarding state. FinnAI will return to a clean first run.';

  @override
  String get settingsDeleteAllDataDeleting => 'Deleting All Local Data…';

  @override
  String get settingsDeleteAllDataSuccess =>
      'All local data deleted. Returning to onboarding.';

  @override
  String settingsDeleteAllDataPartialFailure(String items) {
    return 'Partial deletion failure: Failed to delete $items.';
  }

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsPrivacyPolicyUnconfigured =>
      'The privacy policy link isn\'t available in this build.';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return 'Could not launch $url';
  }

  @override
  String get settingsTermsOfUse => 'Terms of Use';

  @override
  String get settingsTermsUnconfigured =>
      'The terms of use link isn\'t available in this build.';

  @override
  String settingsTermsLaunchFailed(String url) {
    return 'Could not launch $url';
  }

  @override
  String get settingsSupportContact => 'Support Contact';

  @override
  String get settingsSupportUnavailable => 'Support contact is unavailable.';

  @override
  String settingsSupportEmailLabel(String email) {
    return 'Support email: $email';
  }

  @override
  String settingsSupportLaunchFailed(String url) {
    return 'Could not launch $url';
  }

  @override
  String get settingsOpenSourceLicenses => 'Open-Source Licences';

  @override
  String get settingsAppVersion => 'App Version';

  @override
  String get settingsInferenceEngine => 'How Finn runs';

  @override
  String get settingsInferenceEngineValue => 'Entirely on this phone';

  @override
  String get settingsPrivacyMode => 'Privacy Mode';

  @override
  String get settingsPrivacyModeValue => 'Encrypted On-Device';

  @override
  String get settingsModelArchitecture => 'Model Architecture';

  @override
  String get settingsModelArchitectureValue => 'LFM2.5-VL 1.6B (Liquid)';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSpokenResponses => 'Spoken responses';

  @override
  String get settingsSpokenResponsesBody =>
      'Finn reads replies aloud in voice mode. What you say is turned into text on this device and never leaves it.';

  @override
  String get voiceMicSemantic => 'Talk to Finn';

  @override
  String get voiceCancelSemantic => 'Cancel voice input';

  @override
  String get voiceExpandSemantic => 'Open full voice mode';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceTapToSpeak => 'Tap the mic and speak';

  @override
  String get voiceHeardYou => 'Heard you';

  @override
  String get voiceDidNotCatch => 'Didn\'t catch that — try again';

  @override
  String get voiceThinking => 'Finn is thinking…';

  @override
  String get voiceSpeaking => 'Finn is speaking — tap to interrupt';

  @override
  String get voiceMicDenied =>
      'Microphone access is off. Enable it in system Settings to use voice mode.';

  @override
  String get voiceUnavailable =>
      'Speech recognition isn\'t available right now. Type your message instead.';

  @override
  String voiceModelNeeded(String size) {
    return 'Voice mode needs a one-time $size download. Your voice is turned into text on this device and never leaves it.';
  }

  @override
  String get voiceModelDownload => 'Download';

  @override
  String voiceModelDownloading(int percent) {
    return 'Downloading speech model… $percent%';
  }

  @override
  String get voiceModelFailed =>
      'The download didn\'t finish. Check your connection and try again.';

  @override
  String get voiceModelRetry => 'Try again';

  @override
  String get voiceSpeakingLive => 'Speaking…';

  @override
  String get voiceStopSemantic => 'Stop';

  @override
  String get voiceCloseSemantic => 'Close voice mode';

  @override
  String get youTitle => 'You';

  @override
  String get youIntroTitle => 'Make Finn feel like yours';

  @override
  String get youIntroBody =>
      'Your preferences stay on this device and shape future replies.';

  @override
  String get youAboutYou => 'About you';

  @override
  String get youNameLabel => 'Name';

  @override
  String get youNameHint => 'What should Finn call you?';

  @override
  String get youAboutLabel => 'About you';

  @override
  String get youAboutHint => 'Interests, work, or context Finn should remember';

  @override
  String get youInstructionsLabel => 'Custom instructions';

  @override
  String get youInstructionsHint =>
      'How should Finn respond? Tone, length, style…';

  @override
  String get youResponseStyle => 'Response style';

  @override
  String get youResponseStyleBalanced => 'Balanced';

  @override
  String get youResponseStyleConcise => 'Concise';

  @override
  String get youResponseStyleDetailed => 'Detailed';

  @override
  String get youResponseStyleCreative => 'Creative';

  @override
  String get youSave => 'Save';

  @override
  String get youSaved => 'Personalization saved locally.';

  @override
  String get youSaveFailed => 'Could not save changes.';

  @override
  String get flowsTitle => 'Flows';

  @override
  String flowsSubtitle(int count) {
    return '$count available · flows guide relevant replies';
  }

  @override
  String get flowsDeleteTitle => 'Delete this flow?';

  @override
  String flowsDeleteBody(String name) {
    return '“$name” will be removed from this device.';
  }

  @override
  String get flowsNameLabel => 'Flow name';

  @override
  String get flowsRunAction => 'Run now';

  @override
  String get flowsRunRunning => 'Running…';

  @override
  String get flowsGrantLabel => 'Let this run by itself';

  @override
  String get flowsGrantExplain =>
      'A flow that changes your phone needs this before it can run without you. You can turn it off at any time.';

  @override
  String get flowsNeedsGrant => 'Needs your permission to run by itself';

  @override
  String get flowsHistoryTitle => 'Recent runs';

  @override
  String get flowsHistoryEmpty => 'This flow has not run yet.';

  @override
  String get flowsRunCompleted => 'Finished';

  @override
  String get flowsRunDeclined => 'You said no';

  @override
  String get flowsRunFailed => 'Stopped early';

  @override
  String get flowsRunInterrupted => 'Cancelled';

  @override
  String get flowsRunBySchedule => 'Ran by itself';

  @override
  String get flowsAutomationsTitle => 'Automations';

  @override
  String get flowsAutomationsSubtitle =>
      'Things Finn does for you on a schedule. Nothing runs unless you turn it on.';

  @override
  String get flowsNewAutomation => 'New automation';

  @override
  String get flowsNoAutomations =>
      'No automations yet. Start with a morning brief.';

  @override
  String get flowsTemplateMorningBrief => 'Morning brief';

  @override
  String get flowsTemplateMorningBriefBody =>
      'News you care about and the weather, in a few lines.';

  @override
  String get flowsTemplateWebCheck => 'Web check';

  @override
  String get flowsTemplateWebCheckBody =>
      'Checks one topic and tells you what\'s new.';

  @override
  String get flowsTemplateReminder => 'Reminder';

  @override
  String get flowsTemplateReminderBody => 'A notification with your own words.';

  @override
  String get flowsSlotTopics => 'What to follow';

  @override
  String get flowsSlotCity => 'City for the weather (optional)';

  @override
  String get flowsSlotTopic => 'Topic';

  @override
  String get flowsSlotMessage => 'Message';

  @override
  String get flowsScheduleHeading => 'When';

  @override
  String flowsScheduleWeekdaysAt(String time) {
    return 'Weekdays at $time';
  }

  @override
  String get flowsScheduleEveryDay => 'Every day';

  @override
  String get flowsScheduleWeekdaysOnly => 'Weekdays';

  @override
  String get flowsScheduleTime => 'Time';

  @override
  String get flowsNotifyWhyTitle => 'Allow notifications?';

  @override
  String get flowsNotifyWhyBody =>
      'Finn sends a notification when this automation is due. Without it, the automation can only run when you tap Run.';

  @override
  String get flowsNotifyAllow => 'Allow';

  @override
  String get flowsNotifyOff =>
      'Notifications are off, so this won\'t run by itself.';

  @override
  String flowsRunning(String name) {
    return 'Running $name…';
  }

  @override
  String flowsRunReady(String name) {
    return '$name is ready';
  }

  @override
  String flowsRunCouldNotFinish(String name) {
    return '$name couldn\'t finish';
  }

  @override
  String get flowsOpenResult => 'Open result';

  @override
  String flowsNextRun(String when) {
    return 'Next: $when';
  }

  @override
  String get flowsRunByYou => 'Run by you';

  @override
  String get flowsStepsLabel => 'Steps';

  @override
  String flowsStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get flowsStepPrompt => 'Ask';

  @override
  String get flowsStepDeviceAction => 'Act on phone';

  @override
  String get flowsStepNotify => 'Note';

  @override
  String get flowsStepBrowse => 'Look up';

  @override
  String get flowsScheduleLabel => 'Runs';

  @override
  String get flowsScheduleManual => 'Only when you run it';

  @override
  String flowsScheduleDaily(String time) {
    return 'Every day at $time';
  }

  @override
  String flowsScheduleWeekly(String days, String time) {
    return 'Days $days at $time';
  }

  @override
  String get flowsScheduleAdd => 'Add a time';

  @override
  String get flowsScheduleRemove => 'Run it only when I ask';

  @override
  String get chatBrowsingTitle => 'Browsing the web';

  @override
  String get chatSearchingInline => 'Searching the web…';

  @override
  String get chatSearchedInline => 'Searched the web';

  @override
  String get chatShowSearchSteps => 'Show search steps';

  @override
  String get chatBrowsingHide => 'Hide';

  @override
  String chatBrowsingSteps(int count) {
    return '$count steps';
  }

  @override
  String chatBrowsingSearch(String query) {
    return 'Searched the web for “$query”';
  }

  @override
  String chatBrowsingOpen(String title) {
    return 'Read “$title”';
  }

  @override
  String chatBrowsingFind(String query) {
    return 'Looked for “$query” on the page';
  }

  @override
  String get creationsNoneTitle => 'No Creations yet.';

  @override
  String get creationsNoneBody =>
      'Your creativity lives here.\nTry making something with FinnAI Creations.';

  @override
  String get creationsTitle => 'Creations';

  @override
  String get creationsSubtitle =>
      'Describe what you want. Finn builds it on device.';

  @override
  String get creationsWhatAreWeMaking => 'What are we making?';

  @override
  String get creationsOriginalBrief => 'Original brief';

  @override
  String get creationsFinnAdapts => 'Finn adapts the structure to the format.';

  @override
  String get creationsAskKind =>
      'Is your new Creation an app, a widget or a presentation?';

  @override
  String creationsDescribeKind(String kind) {
    return 'Tell me what your $kind should do.';
  }

  @override
  String get creationsStageDesigning => 'Designing…';

  @override
  String get creationsStageWriting => 'Writing…';

  @override
  String get creationsStageValidating => 'Checking the result…';

  @override
  String get creationsStageRepairing => 'Fixing a detail…';

  @override
  String get creationsFallbackNote =>
      'Finn couldn\'t finish that design, so here is a working starter you can build on.';

  @override
  String get creationsTemplateAuto => 'Let Finn choose';

  @override
  String get creationsTemplateQuestion =>
      'Want a starting point? Pick one, or just describe what you want.';

  @override
  String get creationsTemplateCounter => 'Counter';

  @override
  String get creationsTemplateChecklist => 'Checklist';

  @override
  String get creationsTemplateList => 'List';

  @override
  String get creationsTemplateScoreboard => 'Scoreboard';

  @override
  String get creationsTemplateStat => 'Big number';

  @override
  String get creationsTemplateRows => 'Lines';

  @override
  String get creationsEdit => 'Edit';

  @override
  String get creationsEditTitle => 'Edit details';

  @override
  String get creationsSlotTitle => 'Name';

  @override
  String get creationsSlotUnit => 'What you count';

  @override
  String get creationsSlotGoal => 'Goal';

  @override
  String get creationsSlotEmoji => 'Emoji';

  @override
  String get creationsSlotAccent => 'Colour';

  @override
  String get creationsSlotItems => 'Items';

  @override
  String get creationsSlotHint => 'Input hint';

  @override
  String get creationsSlotEmpty => 'Empty message';

  @override
  String get creationsSlotNameA => 'First name';

  @override
  String get creationsSlotNameB => 'Second name';

  @override
  String get creationsSlotLabel => 'Label';

  @override
  String get creationsSlotValue => 'Value';

  @override
  String get creationsSlotFooter => 'Footer';

  @override
  String get creationsSlotRows => 'Lines';

  @override
  String get creationsSlotOnePerLine => 'One per line';

  @override
  String get creationsSlotRowFormat => 'One per line, like “Water: 3”';

  @override
  String get creationsAccentMint => 'Mint';

  @override
  String get creationsAccentBlue => 'Blue';

  @override
  String get creationsAccentLime => 'Lime';

  @override
  String get creationsAccentAmber => 'Amber';

  @override
  String get creationsAccentRose => 'Rose';

  @override
  String get creationsAccentViolet => 'Violet';

  @override
  String get creationsAccentSky => 'Sky';

  @override
  String get creationsNewCreation => 'New creation';

  @override
  String get creationsChooseKindSemantic => 'Choose what to create';

  @override
  String get creationsFailed =>
      'Finn could not finish that creation. Please try again.';

  @override
  String get creationsHomeScreenUnsupported =>
      'Home screen widgets aren\'t available on this device.';

  @override
  String get creationsHomeScreenAdded => 'Added to your home screen.';

  @override
  String get creationsHomeScreenFailed =>
      'That couldn\'t be added to your home screen.';

  @override
  String creationsExportedTo(String fileName) {
    return 'Saved $fileName';
  }

  @override
  String get creationsExportDeck => 'Export as PowerPoint';

  @override
  String get creationsAddToHomeScreen => 'Add to home screen';

  @override
  String get creationsWidgetPreview =>
      'This is how it will look on your home screen.';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Presentation';

  @override
  String get creationsFilterApps => 'Apps';

  @override
  String get creationsFilterWidgets => 'Widgets';

  @override
  String get creationsFilterPresentations => 'Presentations';

  @override
  String get flowsSaveFailed => 'That flow could not be saved.';

  @override
  String get creationsExportedShared => 'Presentation ready to share.';

  @override
  String get creationsExportFailed =>
      'That presentation couldn\'t be exported.';

  @override
  String get creationsResetApp => 'Reset';

  @override
  String get creationsPreviousSlide => 'Previous slide';

  @override
  String get creationsNextSlide => 'Next slide';

  @override
  String creationsSlideOf(int index, int count) {
    return 'Slide $index of $count';
  }

  @override
  String creationsElementCount(int count) {
    return '$count elements';
  }

  @override
  String creationsRowCount(int count) {
    return '$count rows';
  }

  @override
  String creationsSlideCount(int count) {
    return '$count slides';
  }

  @override
  String get creationsStopTitle => 'Stop this creation?';

  @override
  String get creationsStopBody =>
      'The unfinished result will be discarded. Your prompt will stay here.';

  @override
  String get creationsDeleteTitle => 'Delete this creation?';

  @override
  String creationsDeleteBody(String title) {
    return '“$title” will be removed from this device.';
  }

  @override
  String get creationsOpening => 'Opening creations';

  @override
  String get creationsGenerating => 'Generating…';

  @override
  String get reportTitle => 'Report AI Response';

  @override
  String get reportSubtitle =>
      'Help us maintain safe and accurate AI responses. Reports are reviewed to improve FinnAI safeguards.';

  @override
  String get reportReasonLabel => 'Reason for report';

  @override
  String get reportIncludePrompt => 'Include my prompt in this report';

  @override
  String get reportResponsePreview => 'Reported response preview';

  @override
  String get reportContinueHint =>
      'Continue opens a complete report addressed to finn_org@proton.me. Nothing is sent until you review and send it in your email app.';

  @override
  String get reportContinueToEmail => 'Continue to Email';

  @override
  String get reportReviewInEmail =>
      'Review the report in your email app, then send it.';

  @override
  String get reportNotConfigured =>
      'The report email address is not configured.';

  @override
  String get reportCategoryHarmful => 'Harmful or unsafe';

  @override
  String get reportCategoryIncorrect => 'Incorrect or misleading';

  @override
  String get reportCategoryBiased => 'Biased or unfair';

  @override
  String get reportCategoryOther => 'Other';

  @override
  String get snackModelMemoryReleased => 'Memory freed up.';

  @override
  String get settingsSavedConversationsLabel => 'Saved Conversations';

  @override
  String get commonClose => 'Close';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get bootstrapErrorTitle => 'FinnAI could not start';

  @override
  String get bootstrapErrorBody =>
      'Something went wrong while initializing the AI engine. Your conversations are safe.';

  @override
  String get chatHeicNotSupported =>
      'HEIC images are not supported. Please share as JPEG or PNG.';

  @override
  String get chatImageAnalysisUnavailable =>
      'Looking at images isn\'t set up yet. Add image support in Settings.';

  @override
  String get attachmentCamera => 'Camera';

  @override
  String get attachmentPhotos => 'Photos';

  @override
  String get attachmentFiles => 'Files';

  @override
  String get chatAddAttachmentSemantic => 'Add attachment';

  @override
  String get chatImagePromptDefault =>
      'Please analyze this attached image in detail.';

  @override
  String get chatFilePromptDefault =>
      'Please summarize the attached file and highlight its key points.';

  @override
  String get suggestionSummarizeArticle => 'Summarize a web article for me';

  @override
  String get suggestionExplainSimply => 'Explain a complex topic simply';

  @override
  String get suggestionPlanDay => 'Plan my day in three steps';

  @override
  String get suggestionDraftEmail => 'Draft a short email';

  @override
  String get suggestionBrainstormNames => 'Brainstorm names for my new project';

  @override
  String get suggestionIdeaToPlan =>
      'Turn a rough idea into a step-by-step plan';

  @override
  String get suggestionDebugError => 'Help me debug a confusing error';

  @override
  String get suggestionGoodbyeNote => 'Write a quick goodbye note';

  @override
  String get suggestionCompareOptions => 'Compare two options before I decide';

  @override
  String get suggestionFreshPerspective =>
      'Give me a fresh perspective on a problem';

  @override
  String get chatAnotherChatFallback => 'another chat';

  @override
  String get chatSelectText => 'Select Text';

  @override
  String get chatReportAction => 'Report';

  @override
  String get chatMessageActionsHint => 'Press and hold for message actions';

  @override
  String get chatGeneratingInOtherChat => 'Generating in another chat';

  @override
  String get chatRegenerate => 'Regenerate';

  @override
  String get chatMoreActions => 'More actions';

  @override
  String get chatHideSources => 'Hide sources';

  @override
  String get chatShowSources => 'Show sources';

  @override
  String get chatRewriteHint => 'Rewrite your message';

  @override
  String get chatAskAnythingHint => 'Ask anything';

  @override
  String get chatGreeting => 'Hi, what\'s on your mind?';

  @override
  String get voiceGreeting => 'What\'s up?';

  @override
  String get chatMessageToFinnSemantic => 'Message to Finn';

  @override
  String get chatStopGeneratingSemantic => 'Stop generating';

  @override
  String get chatSendMessageSemantic => 'Send message';

  @override
  String get chatOpenMenuTooltip => 'Open menu';

  @override
  String get chatRenameAction => 'Rename';

  @override
  String get chatRenameEnterTitleHint => 'Enter chat title';

  @override
  String get chatDeleteActiveGenerationBody =>
      'Stop the active generation before deleting this chat. Its partial response will be preserved.';

  @override
  String get chatDeleteConfirmBody =>
      'Are you sure you want to delete this chat history? This action cannot be undone.';

  @override
  String get settingsModelActive => 'Active';

  @override
  String get settingsModelInstalled => 'Installed';

  @override
  String get settingsModelPartial => 'Partial';

  @override
  String get settingsModelNotInstalled => 'Not installed';

  @override
  String get creationsAll => 'All';

  @override
  String creationsFilterSemantic(String kind) {
    return '$kind creations';
  }

  @override
  String get creationsEmptyFilteredTitle => 'Nothing here yet';

  @override
  String get creationsEmptyTitle => 'Make something useful';

  @override
  String get creationsEmptyFilteredBody =>
      'Try another category or create a new one.';

  @override
  String get creationsEmptyBody =>
      'Describe an app, widget or presentation below. Finn will shape it into a practical plan.';

  @override
  String get creationsDescribeHint => 'Describe a creation';

  @override
  String get flowsActionsTooltip => 'Flow actions';

  @override
  String flowsNameSemantic(String name) {
    return '$name flow';
  }

  @override
  String get flowsEditorNameHint => 'What does this flow do?';

  @override
  String get youNamePlaceholder => 'Preferred name';

  @override
  String get youAboutQuestion => 'Anything Finn should know?';

  @override
  String get youAboutPlaceholder => 'Your work, interests, goals, or context';

  @override
  String get youInstructionsQuestion => 'How should Finn respond?';

  @override
  String get youInstructionsPlaceholder =>
      'For example: explain technical terms, use metric units…';

  @override
  String get youSaving => 'Saving…';

  @override
  String get youSavePreferences => 'Save preferences';

  @override
  String youStyleSemantic(String style) {
    return '$style response style';
  }

  @override
  String get youResponseStyleConversational => 'Conversational';

  @override
  String get reportSentThanks =>
      'Report sent. Thank you for helping keep FinnAI safe.';

  @override
  String get reportNoEmailApp =>
      'No email app could be opened. Email finn_org@proton.me directly.';

  @override
  String get reportDetailsHint => 'Optional additional details...';

  @override
  String get reportCategoryHarmfulOrDangerous => 'Harmful or dangerous';

  @override
  String get reportCategoryHateOrHarassment => 'Hate or harassment';

  @override
  String get reportCategorySexualContent => 'Sexual content';

  @override
  String get reportCategoryChildSafety => 'Child-safety concern';

  @override
  String get reportCategorySelfHarm => 'Self-harm concern';

  @override
  String get reportCategoryIllegalOrDeceptive =>
      'Illegal or deceptive guidance';

  @override
  String get reportCategoryFalseOrMisleading => 'False or misleading response';

  @override
  String get reportCategorySpamOrScam => 'Spam or scam';

  @override
  String get statusReady => 'Ready';

  @override
  String get statusOptimizedAutomatically => 'Optimized automatically';

  @override
  String get statusModelReady => 'AI model is ready';

  @override
  String get statusDownloadPaused => 'Download paused';

  @override
  String get statusModelRemoved => 'Model removed';

  @override
  String get statusCheckingWeb => 'Checking web…';

  @override
  String get statusSearchingBrowser => 'Searching browser…';

  @override
  String get statusThinkingOnDevice => 'Thinking on this device';

  @override
  String get statusGeneratedLocally => 'Generated locally';

  @override
  String get statusStopped => 'Stopped';

  @override
  String get statusReadyAfterRuntimeReset => 'Ready after runtime reset';

  @override
  String get statusOptimizingForDevice =>
      'Setting up FinnAI for optimal performance…';

  @override
  String get statusOptimizedForDevice => 'FinnAI is optimized for this device';

  @override
  String get statusCheckingDownload => 'Checking the download';

  @override
  String get statusDownloadingModel => 'Downloading the AI model';

  @override
  String statusDownloadingArtifact(String artifact) {
    return 'Downloading $artifact';
  }

  @override
  String statusVerifyingArtifact(String artifact) {
    return 'Verifying $artifact';
  }

  @override
  String get statusLoadingModel => 'Loading the AI model';

  @override
  String get deviceActionsTitle => 'Actions';

  @override
  String get deviceActionsIntro =>
      'Ask Finn to do something on your phone — set an alarm, start a timer, or open a setting.';

  @override
  String get deviceActionsExamples => 'Try one of these';

  @override
  String get deviceActionsHint => 'What should Finn do?';

  @override
  String get deviceActionsRun => 'Continue';

  @override
  String get deviceActionsResolving => 'Working out what to do…';

  @override
  String get deviceActionsUnresolved =>
      'I couldn\'t turn that into an action. Try naming the setting or app directly.';

  @override
  String get deviceActionsConfirm => 'Do it';

  @override
  String get deviceActionsCancel => 'Cancel';

  @override
  String get deviceActionsAgain => 'Do something else';

  @override
  String get deviceActionsOpenNotice =>
      'Android doesn\'t let apps change wireless settings on their own, so Finn opens the right screen and you flip the switch.';

  @override
  String deviceActionsResultOpened(String detail) {
    return 'Opened $detail';
  }

  @override
  String deviceActionsResultPerformed(String detail) {
    return 'Done — $detail';
  }

  @override
  String get deviceActionsResultUnavailable => 'Your device can\'t do that';

  @override
  String get deviceActionsResultFailed => 'That didn\'t work';

  @override
  String deviceActionsResultFailedDetail(String error) {
    return 'That didn\'t work — $error';
  }

  @override
  String get deviceActionsExampleAlarm => 'Set an alarm for 7am';

  @override
  String get deviceActionsExampleTimer => 'Start a 10 minute timer';

  @override
  String get deviceActionsExampleWifi => 'Open Wi-Fi settings';

  @override
  String get deviceActionsExampleFlashlight => 'Turn on the flashlight';

  @override
  String get deviceActionsExampleBluetooth => 'Open Bluetooth settings';

  @override
  String deviceActionSetAlarm(String time) {
    return 'Set an alarm for $time';
  }

  @override
  String deviceActionSetTimer(String duration) {
    return 'Start a $duration timer';
  }

  @override
  String get deviceActionShowAlarms => 'Open the alarm clock';

  @override
  String get deviceActionTorchOn => 'Turn the flashlight on';

  @override
  String get deviceActionTorchOff => 'Turn the flashlight off';

  @override
  String deviceActionMedia(String action) {
    return 'Music player: $action';
  }

  @override
  String deviceActionVolume(String direction) {
    return 'Volume $direction';
  }

  @override
  String deviceActionOpenSettings(String screen) {
    return 'Open $screen settings';
  }

  @override
  String deviceActionOpenApp(String name) {
    return 'Open $name';
  }

  @override
  String deviceActionDial(String number) {
    return 'Open the dialer with $number';
  }

  @override
  String get deviceActionComposeSms => 'Open a new text message';

  @override
  String get deviceActionComposeEmail => 'Open a new email';

  @override
  String get deviceActionTakePhoto => 'Open the camera';

  @override
  String deviceActionOpenUrl(String url) {
    return 'Open $url';
  }

  @override
  String deviceActionNavigate(String query) {
    return 'Get directions to $query';
  }

  @override
  String get deviceActionShare => 'Share text through another app';

  @override
  String get deviceActionMediaPlay => 'play';

  @override
  String get deviceActionMediaPause => 'pause';

  @override
  String get deviceActionMediaNext => 'skip to the next track';

  @override
  String get deviceActionMediaPrevious => 'go back a track';

  @override
  String get deviceActionVolumeUp => 'up';

  @override
  String get deviceActionVolumeDown => 'down';

  @override
  String get deviceActionVolumeMute => 'off';

  @override
  String get deviceScreenWifi => 'Wi-Fi';

  @override
  String get deviceScreenBluetooth => 'Bluetooth';

  @override
  String get deviceScreenAirplane => 'Airplane mode';

  @override
  String get deviceScreenHotspot => 'Hotspot';

  @override
  String get deviceScreenMobileData => 'Mobile data';

  @override
  String get deviceScreenBatterySaver => 'Battery saver';

  @override
  String get deviceScreenBatteryUsage => 'Battery usage';

  @override
  String get deviceScreenDnd => 'Do Not Disturb';

  @override
  String get deviceScreenDisplay => 'Display';

  @override
  String get deviceScreenSound => 'Sound';

  @override
  String get deviceScreenLocation => 'Location';

  @override
  String get deviceScreenStorage => 'Storage';

  @override
  String get deviceScreenDateTime => 'Date and time';

  @override
  String get deviceScreenKeyboard => 'Keyboard';

  @override
  String get deviceScreenLanguage => 'Language';

  @override
  String get deviceScreenAccessibility => 'Accessibility';

  @override
  String get deviceScreenApplications => 'Apps';

  @override
  String get deviceScreenNfc => 'NFC';

  @override
  String get deviceScreenCast => 'Cast';

  @override
  String get deviceScreenVpn => 'VPN';

  @override
  String get deviceScreenDeveloper => 'Developer options';

  @override
  String get deviceScreenHome => 'Home screen';

  @override
  String get deviceActionsResultDone => 'Done';

  @override
  String get settingsActionsSection => 'Actions on your device';

  @override
  String get settingsActionsRow => 'Actions';

  @override
  String get deviceScreenSystem => 'Settings';

  @override
  String get deviceActionsDismissed => 'Cancelled';

  @override
  String get creationsStopped => 'Stopped.';

  @override
  String get creationsLoadFailed =>
      'Finn couldn\'t open your saved creations. Please try again.';

  @override
  String get creationsDeleteFailed =>
      'That creation couldn\'t be deleted. Please try again.';

  @override
  String get hubModelTitle => 'FinnAI Foundation';

  @override
  String hubModelSub(String size) {
    return 'On this device, $size';
  }

  @override
  String get hubVoiceTitle => 'Voice and language';

  @override
  String hubVoiceSub(String speed, String language) {
    return '$speed speed, $language';
  }

  @override
  String get hubAccessTitle => 'Device access';

  @override
  String get hubAccessSub => 'Calendar, contacts, files';

  @override
  String get hubYouTitle => 'You';

  @override
  String get hubYouSub => 'What FinnAI learns and uses';

  @override
  String get hubDataTitle => 'Privacy and data';

  @override
  String get hubDataSub => 'Storage, export, erase';

  @override
  String get hubAboutTitle => 'About';

  @override
  String hubAboutSub(String version) {
    return 'Version $version';
  }

  @override
  String modelVersion(String version) {
    return 'Version $version';
  }

  @override
  String modelStored(String size, String date) {
    return '$size of your storage, downloaded on $date.';
  }

  @override
  String modelStoredNoDate(String size) {
    return '$size of your storage.';
  }

  @override
  String get modelNotInstalled => 'Not downloaded yet.';

  @override
  String get modelOffline => 'Work offline';

  @override
  String get modelOfflineSub => 'Everything runs on this device';

  @override
  String get modelLookups => 'Look things up online';

  @override
  String get modelLookupsSub =>
      'Only when a question needs it. Your chats and You stay here.';

  @override
  String get modelUpdates => 'Check for updates';

  @override
  String get modelUpToDate => 'Up to date';

  @override
  String get modelRemove => 'Remove the model';

  @override
  String modelRemoveSub(String size) {
    return 'Frees $size';
  }

  @override
  String get modelRemoveTitle => 'Remove the model?';

  @override
  String get modelRemoveBody =>
      'FinnAI has to download it again before you can chat. Your chats stay.';

  @override
  String get modelRemoveConfirm => 'Remove';

  @override
  String get voiceReadAloud => 'Read replies aloud';

  @override
  String get voiceReadAloudSub => 'In voice chats';

  @override
  String get voiceTranscript => 'Show live transcript';

  @override
  String get voiceTranscriptSub => 'While you speak';

  @override
  String get voiceSpeed => 'Speaking speed';

  @override
  String get voiceSpeedSlow => 'Slow';

  @override
  String get voiceSpeedNormal => 'Normal';

  @override
  String get voiceSpeedFast => 'Fast';

  @override
  String get voiceLanguage => 'Language';

  @override
  String get voiceLanguageSub => 'Follows your phone';

  @override
  String get accessIntro =>
      'FinnAI only reads what you allow, and only on this device.';

  @override
  String get accessMaster => 'Use context from this device';

  @override
  String get accessMasterSub => 'Turn off to stop FinnAI reading anything';

  @override
  String get accessActions => 'Actions on your device';

  @override
  String get accessActionsSub => 'Alarms, timers, settings';

  @override
  String get ctxCalendar => 'Calendar';

  @override
  String get ctxCalendarSub => 'Events and free time';

  @override
  String get ctxContacts => 'Contacts';

  @override
  String get ctxContactsSub => 'Names and relationships';

  @override
  String get ctxNotifications => 'Notifications';

  @override
  String get ctxNotificationsSub => 'What needs your attention';

  @override
  String get ctxPhotos => 'Photos';

  @override
  String get ctxPhotosSub => 'Only when you attach them';

  @override
  String get ctxFiles => 'Files';

  @override
  String get ctxFilesSub => 'Documents you open with FinnAI';

  @override
  String get ctxLocation => 'Location';

  @override
  String get ctxLocationSub => 'Only while the app is open';

  @override
  String get dataStoredHere => 'Stored on this device';

  @override
  String get dataChats => 'Chats';

  @override
  String get dataCreations => 'Creations';

  @override
  String get dataYou => 'You';

  @override
  String get dataModel => 'FinnAI Foundation';

  @override
  String get dataExport => 'Export everything';

  @override
  String get dataExportSub => 'Chats, creations, flows and You';

  @override
  String get dataDeleteChats => 'Delete all chats';

  @override
  String get dataDeleteChatsSub => 'You stays as it is';

  @override
  String get dataErase => 'Erase everything';

  @override
  String get dataEraseSub => 'Resets FinnAI on this device';

  @override
  String get dataExportFailed => 'Could not export. Try again.';

  @override
  String get aboutBlurb => 'A private assistant that runs on your device.';

  @override
  String get aboutPrivacy => 'Privacy Policy';

  @override
  String get aboutTerms => 'Terms of use';

  @override
  String get aboutLicences => 'Open source licences';

  @override
  String get aboutFeedback => 'Send feedback';

  @override
  String chatUsedFromYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things',
      one: '1 thing',
    );
    return 'Used $_temp0 from You';
  }

  @override
  String get youAboutTitle => 'What FinnAI knows about you';

  @override
  String youUpdated(String when) {
    return 'Updated $when';
  }

  @override
  String youReviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new things to review',
      one: '1 new thing to review',
    );
    return '$_temp0';
  }

  @override
  String get youReviewSub => 'Noticed in your recent chats';

  @override
  String youCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things',
      one: '1 thing',
    );
    return '$_temp0';
  }

  @override
  String get youStoredOnly => 'Stored only on this device';

  @override
  String get youCatPeople => 'People';

  @override
  String get youCatWork => 'Work';

  @override
  String get youCatRoutines => 'Routines';

  @override
  String get youCatPreferences => 'Preferences';

  @override
  String get youCatPlaces => 'Places';

  @override
  String get youCatInterests => 'Interests';

  @override
  String get youEmptyTitle => 'Still getting to know you';

  @override
  String get youEmptyBody =>
      'As you chat, FinnAI learns what helps and keeps it here, on this device. You can also write something yourself.';

  @override
  String get youTellFinn => 'Tell FinnAI about you';

  @override
  String get youPrivacyTitle => 'Privacy';

  @override
  String youCategoryIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count things FinnAI remembers. Tap one to see where it came from.',
      one: '1 thing FinnAI remembers. Tap one to see where it came from.',
    );
    return '$_temp0';
  }

  @override
  String get youCategoryEmpty => 'Nothing here yet. Tap plus to add something.';

  @override
  String youSeenIn(String where) {
    return 'Seen in $where';
  }

  @override
  String get youSeenInLabel => 'Seen in';

  @override
  String get youAddedByYou => 'Added by you';

  @override
  String youLearnedOn(String when) {
    return 'Learned $when. Stored on this device.';
  }

  @override
  String get youEdit => 'Edit';

  @override
  String get youDoNotUse => 'Do not use in chats';

  @override
  String get youForgetThis => 'Forget this';

  @override
  String get youForgetTitle => 'Forget this?';

  @override
  String get youForgetBody =>
      'FinnAI stops using it in chats. If you bring it up again, it can be learned again.';

  @override
  String get youForgetConfirm => 'Forget';

  @override
  String get youAddLabel => 'In your own words';

  @override
  String get youAddHint =>
      'Something FinnAI should remember, like how you like to work or who matters to you.';

  @override
  String get youWhereBelongs => 'Where it belongs';

  @override
  String get youUseEveryChat => 'Use in every chat';

  @override
  String get youUseEveryChatSub => 'Turn off to keep it for when you ask';

  @override
  String get youSaveToYou => 'Save to You';

  @override
  String get youReviewTitleBar => 'Review';

  @override
  String get youReviewIntro =>
      'FinnAI noticed these in recent chats. Keep what is right and forget the rest.';

  @override
  String get youReviewEmpty => 'Nothing to review right now.';

  @override
  String get youKeep => 'Keep';

  @override
  String youFrom(String category, String chat) {
    return '$category, from $chat';
  }

  @override
  String get youPrivacyNote =>
      'Everything in You is stored on this device. FinnAI never sends it anywhere.';

  @override
  String get youLearn => 'Learn from conversations';

  @override
  String get youLearnSub => 'FinnAI suggests things to add after you chat';

  @override
  String get youUseInChats => 'Use You in new chats';

  @override
  String get youUseInChatsSub => 'You can turn it off per chat';

  @override
  String get youLearnAbout => 'Learn about';

  @override
  String get youExport => 'Export You';

  @override
  String get youExportSub => 'Save a copy as a file';

  @override
  String get youErase => 'Erase everything in You';

  @override
  String youEraseSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things',
      one: '1 thing',
    );
    return 'Removes $_temp0';
  }

  @override
  String get youEraseTitle => 'Erase everything in You?';

  @override
  String get youEraseBody =>
      'Everything FinnAI remembers is removed from this device. Your chats stay.';

  @override
  String get youEraseConfirm => 'Erase';

  @override
  String get youPersonalise => 'Reply style and instructions';

  @override
  String get youPersonaliseSub => 'Name, tone and custom instructions';

  @override
  String get youRemembered => 'Saved to You';

  @override
  String get youWhenToday => 'today';

  @override
  String youWhenMinutes(int count) {
    return '$count minutes ago';
  }

  @override
  String youWhenHours(int count) {
    return '$count hours ago';
  }

  @override
  String youWhenDays(int count) {
    return '$count days ago';
  }

  @override
  String get youWhenJustNow => 'just now';

  @override
  String get searchHint => 'Search';

  @override
  String get searchChatsHeading => 'Chats';

  @override
  String get searchCreationsHeading => 'Creations';

  @override
  String get searchNothing => 'Nothing found';

  @override
  String get searchPrompt => 'Search your chats, creations and You.';

  @override
  String get chatReadAloud => 'Read aloud';

  @override
  String get chatRememberInYou => 'Remember in You';

  @override
  String get chatShare => 'Share';

  @override
  String get plusCreate => 'Create';

  @override
  String get plusWidget => 'Widget';

  @override
  String get plusWidgetSub => 'For your home screen';

  @override
  String get plusMiniApp => 'Mini app';

  @override
  String get plusMiniAppSub => 'A small tool';

  @override
  String get plusPresentation => 'Presentation';

  @override
  String get plusPresentationSub => 'Slides to share';

  @override
  String get plusFlow => 'Flow';

  @override
  String get plusFlowSub => 'Runs on its own';

  @override
  String get plusAddToChat => 'Add to chat';

  @override
  String get plusPhoto => 'Photo';

  @override
  String optionsStarted(String when) {
    return 'Started $when. Stored on this device.';
  }

  @override
  String get optionsPin => 'Pin chat';

  @override
  String get optionsUnpin => 'Unpin chat';

  @override
  String get optionsExport => 'Export as text';

  @override
  String get optionsDelete => 'Delete chat';

  @override
  String get deleteChatTitle => 'Delete this chat?';

  @override
  String get deleteChatBody =>
      'It is removed from this device. What FinnAI learned from it stays in You until you forget it.';

  @override
  String get fromYouTitle => 'From You';

  @override
  String get fromYouSub =>
      'FinnAI used these in this chat. Nothing leaves your device.';

  @override
  String get fromYouUse => 'Use You in this chat';

  @override
  String get fromYouOpen => 'Open You';

  @override
  String get chatRenamePrompt => 'Rename chat';

  @override
  String get flowsFilterAll => 'All';

  @override
  String get flowsFilterActive => 'Active';

  @override
  String get flowsFilterPaused => 'Paused';

  @override
  String get flowsPhoneOn =>
      'Flows run on this device, so your phone needs to be on.';

  @override
  String get flowsOnlyWhenAsked => 'Only when I ask';

  @override
  String flowsLastRunLine(String when, String result) {
    return 'Last run $when, $result';
  }

  @override
  String get flowsNeverRun => 'Not run yet';

  @override
  String get flowsPausedLine => 'Paused';

  @override
  String get flowsResultDone => 'done';

  @override
  String get flowsResultFailed => 'failed';

  @override
  String get flowsResultStopped => 'stopped';

  @override
  String get flowsWhenToday => 'today';

  @override
  String get flowsWhenYesterday => 'yesterday';

  @override
  String get flowsEmptyTitle => 'No flows yet';

  @override
  String get flowsEmptyBody =>
      'A flow does a task for you on a schedule, or when something happens. Describe one in chat.';

  @override
  String get flowsEmptyCreate => 'Create a flow';

  @override
  String get flowsNewTitle => 'New flow';

  @override
  String get flowsNewSub => 'Start with words, a time, or an event.';

  @override
  String get flowsNewDescribe => 'Describe it';

  @override
  String get flowsNewDescribeSub => 'Tell FinnAI what should happen';

  @override
  String get flowsNewTime => 'At a set time';

  @override
  String get flowsNewTimeSub => 'Every day, week or month';

  @override
  String get flowsNewEvent => 'When something happens';

  @override
  String get flowsNewEventSub => 'Charging, arriving, a notification';

  @override
  String flowsDetailOn(String when) {
    return 'On, next run $when';
  }

  @override
  String get flowsDetailOnManual => 'On, runs when you ask';

  @override
  String get flowsDetailPaused => 'Paused';

  @override
  String get flowsWhen => 'When';

  @override
  String get flowsThen => 'Then';

  @override
  String get flowsRecentRuns => 'Recent runs';

  @override
  String get flowsNoRunsYet => 'No runs yet';

  @override
  String get flowsRunStatusDone => 'Done';

  @override
  String get flowsRunStatusFailed => 'Could not finish';

  @override
  String get flowsRunStatusDeclined => 'Not allowed';

  @override
  String get flowsRunStatusNeedsGrant => 'Needs your permission';

  @override
  String get flowsRunStatusStopped => 'Stopped';

  @override
  String get flowsMenuEdit => 'Edit';

  @override
  String get flowsMenuPause => 'Pause';

  @override
  String get flowsMenuResume => 'Turn on';

  @override
  String get flowsMenuDuplicate => 'Duplicate';

  @override
  String get flowsMenuDelete => 'Delete';

  @override
  String get flowsRunFinished => 'Finished';

  @override
  String flowsRunFinishedIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Finished in $_temp0';
  }

  @override
  String get flowsRunAgain => 'Run again';

  @override
  String get flowsBuilderHint => 'Describe what should happen';

  @override
  String get flowsBuilderHere => 'Here is the flow. Check it, then turn it on.';

  @override
  String get flowsBuilderNoMatch =>
      'I can not build that one yet. Pick one of these and I will set it up.';

  @override
  String get flowsBuilderTurnOn => 'Turn on';

  @override
  String get flowsStartWhen => 'Start when';

  @override
  String get flowsTriggerTime => 'At a set time';

  @override
  String get flowsTriggerTimeSub => 'Every day, week or month';

  @override
  String get flowsTriggerPlace => 'Arriving or leaving';

  @override
  String get flowsTriggerPlaceSub => 'A place you choose';

  @override
  String get flowsTriggerCharging => 'Charging';

  @override
  String get flowsTriggerChargingSub => 'When plugged in or unplugged';

  @override
  String get flowsTriggerBattery => 'Battery level';

  @override
  String get flowsTriggerBatterySub => 'Below or above a level';

  @override
  String get flowsTriggerNotification => 'A notification';

  @override
  String get flowsTriggerNotificationSub => 'When one arrives from an app';

  @override
  String get flowsTriggerManual => 'Only when I ask';

  @override
  String get flowsTriggerManualSub => 'Start it yourself';

  @override
  String get flowsTriggerSoon => 'Not available yet';

  @override
  String get flowsScheduleSheetTitle => 'Schedule';

  @override
  String get flowsScheduleSave => 'Save schedule';

  @override
  String flowsAllowTitle(String name) {
    return 'Allow $name to act on your phone?';
  }

  @override
  String get flowsAllowConfirm => 'Allow';

  @override
  String flowsDeleteNamed(String name) {
    return 'Delete $name?';
  }

  @override
  String get flowsDeleteNamedBody =>
      'Its past runs are removed too. This can not be undone.';

  @override
  String flowsStepLookUp(String query) {
    return 'Look up $query';
  }

  @override
  String get flowsStepWrite => 'Write the answer';

  @override
  String get creationsNewSheetSub =>
      'Describe it in chat. FinnAI builds it on this device.';

  @override
  String get creationsNewWidgetSub => 'Small tools for your home screen';

  @override
  String get creationsNewAppSub => 'A simple tool that runs inside FinnAI';

  @override
  String get creationsNewDeckSub => 'Slides you can present or share';

  @override
  String get creationsMenuEditWithFinn => 'Edit with FinnAI';

  @override
  String get creationsMenuDuplicate => 'Duplicate';

  @override
  String get creationsMenuShare => 'Share';

  @override
  String creationsDeleteNamed(String name) {
    return 'Delete $name?';
  }

  @override
  String get creationsDeleteNamedBody =>
      'It is removed from Creations and from your home screen. This can not be undone.';

  @override
  String get creationsSizeSmall => 'Small';

  @override
  String get creationsSizeMedium => 'Medium';

  @override
  String get creationsSizeLarge => 'Large';

  @override
  String get creationsUpdatesOnDevice =>
      'Updates on this device. Nothing leaves your phone.';

  @override
  String get creationsMadeInChat => 'Made in chat';

  @override
  String get creationsDataLabel => 'Data';

  @override
  String get creationsDataSub => 'Stored inside this widget';

  @override
  String creationsAddHomeTitle(String name) {
    return 'Add $name to your home screen?';
  }

  @override
  String get creationsAddHomeBody =>
      'It sits like any other widget. You can move or remove it later.';

  @override
  String get creationsAddHomeConfirm => 'Add';

  @override
  String get creationsBuilderTitleWidget => 'New widget';

  @override
  String get creationsBuilderTitleApp => 'New mini app';

  @override
  String get creationsBuilderTitleDeck => 'New presentation';

  @override
  String get creationsBuilderHint => 'Describe what to build';

  @override
  String get creationsBuilderChangeHint => 'Ask for changes';

  @override
  String get creationsBuilderGotIt => 'Got it. I will build it on this device.';

  @override
  String get creationsBuilderReady => 'Here it is. Open it, or keep editing.';

  @override
  String get creationsSaveToCreations => 'Save to Creations';

  @override
  String get creationsKeepEditing => 'Keep editing';

  @override
  String get creationsSpeakerNotes => 'Speaker notes';

  @override
  String get creationsPresent => 'Present';

  @override
  String get creationsDuplicated => 'Duplicated.';

  @override
  String get onboardingChooseTitle => 'Choose what FinnAI can see';

  @override
  String get onboardingChooseBody =>
      'You can change this any time in Settings. All of it stays on this device.';

  @override
  String get onboardingDownloadPausedTitle => 'Download paused';

  @override
  String get onboardingDownloadPausedBody =>
      'Waiting for a connection, your progress is saved.';

  @override
  String get onboardingDownloadPausedNote =>
      'It continues when you are back online.';

  @override
  String get flowsStepNotifyMe => 'Notify me';

  @override
  String get creationsTemplateTracker => 'Tracker';

  @override
  String get creationsSlotStep => 'Added per tap';

  @override
  String get creationsResetAppTitle => 'Reset this app?';

  @override
  String get creationsResetAppBody =>
      'Everything you added to it is cleared. This cannot be undone.';

  @override
  String get deviceActionVibrate => 'Vibrate the phone';

  @override
  String get flowsTrigManual => 'Only when I start it';

  @override
  String get flowsTrigTimeOfDay => 'At a set time';

  @override
  String flowsTrigEveryMinutes(int n) {
    return 'Every $n minutes';
  }

  @override
  String flowsTrigEveryHours(int n) {
    return 'Every $n hours';
  }

  @override
  String get flowsTrigEveryHour => 'Every hour';

  @override
  String get flowsTrigInterval => 'Repeating';

  @override
  String get flowsTrigChargerOn => 'Charger connected';

  @override
  String get flowsTrigChargerOff => 'Charger disconnected';

  @override
  String flowsTrigBatteryLow(int n) {
    return 'Battery drops to $n%';
  }

  @override
  String get flowsTrigHeadsetOn => 'Headphones connected';

  @override
  String get flowsTrigHeadsetOff => 'Headphones disconnected';

  @override
  String get flowsTrigWifiOn => 'Wi‑Fi connected';

  @override
  String get flowsTrigWifiOff => 'Wi‑Fi disconnected';

  @override
  String get flowsTrigAirplaneOn => 'Airplane mode turns on';

  @override
  String get flowsTrigAirplaneOff => 'Airplane mode turns off';

  @override
  String get flowsTrigBoot => 'Phone starts up';

  @override
  String get flowsTrigUnlock => 'Screen unlocked';

  @override
  String get flowsTrigGroupTime => 'Time';

  @override
  String get flowsTrigGroupPhone => 'On the phone';

  @override
  String get flowsTrigGroupHand => 'By hand';

  @override
  String flowsCondBatteryBelow(int n) {
    return 'Battery below $n%';
  }

  @override
  String flowsCondBatteryAbove(int n) {
    return 'Battery above $n%';
  }

  @override
  String get flowsCondCharging => 'Charging';

  @override
  String get flowsCondNotCharging => 'Not charging';

  @override
  String flowsCondTimeBetween(String from, String to) {
    return 'Between $from and $to';
  }

  @override
  String flowsCondDays(String days) {
    return 'On $days';
  }

  @override
  String get flowsCondWifiOn => 'Wi‑Fi connected';

  @override
  String get flowsCondWifiOff => 'Wi‑Fi not connected';

  @override
  String get flowsCondHeadsetOn => 'Headphones connected';

  @override
  String get flowsCondHeadsetOff => 'Headphones not connected';

  @override
  String get flowsCondAirplaneOn => 'Airplane mode on';

  @override
  String get flowsCondAirplaneOff => 'Airplane mode off';

  @override
  String flowsCondAnswer(String text) {
    return 'The answer mentions “$text”';
  }

  @override
  String get flowsBlockAsk => 'Ask FinnAI';

  @override
  String get flowsBlockAskSub => 'Write something with the on-device model';

  @override
  String get flowsBlockWeb => 'Look up';

  @override
  String get flowsBlockWebSub => 'News, weather or the web';

  @override
  String get flowsBlockNotify => 'Notify me';

  @override
  String get flowsBlockNotifySub => 'Show a notification';

  @override
  String get flowsBlockSpeak => 'Say it out loud';

  @override
  String get flowsBlockSpeakSub => 'Speak with the phone’s voice';

  @override
  String get flowsBlockAction => 'Do on the phone';

  @override
  String get flowsBlockActionSub => 'Flashlight, volume, alarm, open an app';

  @override
  String get flowsBlockWait => 'Wait';

  @override
  String get flowsBlockWaitSub => 'Pause for a few seconds';

  @override
  String get flowsBlockBranch => 'If … then';

  @override
  String get flowsBlockBranchSub => 'Do one thing or another';

  @override
  String get flowsBlockSave => 'Save to chat';

  @override
  String get flowsBlockSaveSub => 'Keep the answer as a chat';

  @override
  String get flowsBlockStop => 'Stop here';

  @override
  String get flowsBlockStopSub => 'End the flow';

  @override
  String flowsSumAsk(String text) {
    return 'Ask: $text';
  }

  @override
  String flowsSumWeb(String text) {
    return 'Look up $text';
  }

  @override
  String get flowsSumNotifyAnswer => 'Show the answer';

  @override
  String get flowsSumSpeakAnswer => 'Read the answer aloud';

  @override
  String flowsSumWait(int n) {
    return 'Wait $n s';
  }

  @override
  String flowsSumIf(String condition) {
    return 'If $condition';
  }

  @override
  String get flowsEdWhen => 'When';

  @override
  String get flowsEdOnlyIf => 'Only if';

  @override
  String get flowsEdThen => 'Then';

  @override
  String get flowsEdOr => 'or';

  @override
  String get flowsEdYes => 'Yes';

  @override
  String get flowsEdOtherwise => 'Otherwise';

  @override
  String get flowsEdEnd => 'Done';

  @override
  String get flowsEdAddTrigger => 'Add a trigger';

  @override
  String get flowsEdAddCondition => 'Add a condition';

  @override
  String get flowsEdAddStep => 'Add a step';

  @override
  String get flowsEdInsertHere => 'Add a step here';

  @override
  String get flowsEdNoSteps => 'Nothing to do yet. Add the first step.';

  @override
  String get flowsEdManualStart => 'Starts when you tap Run';

  @override
  String get flowsEdMoveUp => 'Move up';

  @override
  String get flowsEdMoveDown => 'Move down';

  @override
  String get flowsEdRemove => 'Remove';

  @override
  String get flowsEdDone => 'Done';

  @override
  String get flowsEdChooseStep => 'What should happen?';

  @override
  String get flowsEdChooseTrigger => 'What starts it?';

  @override
  String get flowsEdChooseCondition => 'Only when…';

  @override
  String get flowsEdConditionNote =>
      'If this is not true, the flow does not run when something else starts it.';

  @override
  String get flowsFieldPrompt => 'What should FinnAI write?';

  @override
  String flowsFieldPromptHint(String input) {
    return 'Use $input for the last answer';
  }

  @override
  String get flowsFieldQuery => 'What to look up';

  @override
  String get flowsFieldSource => 'Where';

  @override
  String get flowsSourceWeb => 'The web';

  @override
  String get flowsSourceNews => 'News';

  @override
  String get flowsSourceWeather => 'Weather';

  @override
  String get flowsFieldTitle => 'Title';

  @override
  String get flowsFieldMessage => 'Message';

  @override
  String get flowsFieldMessageHint => 'Leave empty to show the last answer';

  @override
  String get flowsFieldSay => 'What to say';

  @override
  String get flowsFieldSayHint => 'Leave empty to read the last answer';

  @override
  String get flowsFieldSeconds => 'How many seconds';

  @override
  String get flowsFieldAction => 'What to do';

  @override
  String get flowsFieldCondition => 'Condition';

  @override
  String get flowsFieldLevel => 'Battery level';

  @override
  String get flowsFieldFrom => 'From';

  @override
  String get flowsFieldTo => 'To';

  @override
  String get flowsFieldDays => 'Days';

  @override
  String get flowsFieldContains => 'Contains';

  @override
  String get flowsFieldEveryMinutes => 'Repeat every';

  @override
  String get flowsUnitMinutes => 'minutes';

  @override
  String get flowsUnitHours => 'hours';

  @override
  String get flowsBgWorks => 'Works in the background';

  @override
  String get flowsBgNeedsScreen => 'Needs you to tap a notification';

  @override
  String get flowsAutoTitle => 'Let it run by itself';

  @override
  String get flowsAutoNeedsAllow =>
      'This flow changes your phone. Allow it to run when you are not looking.';

  @override
  String get flowsListenerOn =>
      'FinnAI is listening for these in the background.';

  @override
  String get flowsListenerNeedsNotify =>
      'Turn on notifications so FinnAI can keep listening.';

  @override
  String get flowsRunStatusSkipped => 'Conditions not met';

  @override
  String get flowsRunStatusNeedsScreen => 'Waiting for you';

  @override
  String get flowsRunSkipped => 'Skipped';

  @override
  String get flowsRunNeedsScreen => 'Tap to finish';

  @override
  String get flowsRunByEvent => 'Ran by itself';

  @override
  String get flowsRunByChat => 'Run from chat';

  @override
  String flowsNeedsScreenBody(String name) {
    return 'Tap to finish “$name” — it needs the screen.';
  }

  @override
  String flowsNeedsGrantBody(String name) {
    return '“$name” wanted to run but needs your permission first.';
  }

  @override
  String get flowsStepWaiting => 'Waiting';

  @override
  String flowsPathStep(int n) {
    return 'Step $n';
  }

  @override
  String get flowsDescribeTitle => 'Describe your flow';

  @override
  String get flowsDescribeHint =>
      'For example: when I plug in my charger, turn on the flashlight';

  @override
  String get flowsDescribeBuild => 'Build it';

  @override
  String get flowsDescribeThinking => 'Working it out…';

  @override
  String get flowsDescribeFailed =>
      'I could not turn that into a flow. Try saying when it starts and what it should do.';

  @override
  String flowsDescribeMissed(String parts) {
    return 'I did not understand: $parts';
  }

  @override
  String get flowsDescribeExamples => 'Try one of these';

  @override
  String get flowsExampleCharger =>
      'When I plug in my charger, turn on the flashlight';

  @override
  String get flowsExampleBattery =>
      'When the battery is below 15%, remind me to charge';

  @override
  String get flowsExampleNews => 'Every morning at 7 tell me the news';

  @override
  String get flowsExampleHeadset => 'When I connect headphones, play music';

  @override
  String get flowsNewBlank => 'Start from scratch';

  @override
  String get flowsNewBlankSub => 'Build it step by step';

  @override
  String get flowsNewTemplates => 'From a template';

  @override
  String get flowsNewTemplatesSub => 'News brief, reminder, low battery…';

  @override
  String get flowsTemplateLowBattery => 'Low battery alert';

  @override
  String get flowsTemplateLowBatteryBody =>
      'Tells you once when the battery gets low.';

  @override
  String get flowsTemplateHeadset => 'Headphones and music';

  @override
  String get flowsTemplateHeadsetBody =>
      'Plays or pauses when headphones connect.';

  @override
  String get flowsSlotLevel => 'Warn at (%)';

  @override
  String get flowsSlotWhat => 'What to do';

  @override
  String get flowsSlotPlay => 'Play';

  @override
  String get flowsSlotPause => 'Pause';

  @override
  String get flowsRunsTitle => 'Runs';

  @override
  String get flowsRunsAll => 'See all runs';

  @override
  String get flowsRenameTitle => 'Rename flow';

  @override
  String get flowsSavedToast => 'Saved';

  @override
  String get flowsStepOutcomeSkipped => 'Skipped';

  @override
  String flowsChatCreated(String name) {
    return 'I made a flow: “$name”. Check it, then turn it on.';
  }

  @override
  String get flowsChatOpen => 'Open flow';

  @override
  String get flowsChatTurnOn => 'Turn on';

  @override
  String get flowsChatIsOn => 'Turned on';

  @override
  String get flowsChatDiscard => 'Discard';

  @override
  String get flowsActSetAlarm => 'Set an alarm';

  @override
  String get flowsActSetTimer => 'Start a timer';

  @override
  String get flowsActShowAlarms => 'Show my alarms';

  @override
  String get flowsActTorch => 'Flashlight';

  @override
  String get flowsActMedia => 'Control music';

  @override
  String get flowsActVolume => 'Change the volume';

  @override
  String get flowsActVibrate => 'Vibrate';

  @override
  String get flowsActOpenSettings => 'Open a settings screen';

  @override
  String get flowsActOpenApp => 'Open an app';

  @override
  String get flowsActDial => 'Start a call';

  @override
  String get flowsActSms => 'Write a text message';

  @override
  String get flowsActEmail => 'Write an email';

  @override
  String get flowsActPhoto => 'Open the camera';

  @override
  String get flowsActUrl => 'Open a web address';

  @override
  String get flowsActNavigate => 'Get directions';

  @override
  String get flowsActShare => 'Share text';

  @override
  String get flowsOn => 'On';

  @override
  String get flowsOff => 'Off';

  @override
  String get flowsParamState => 'State';

  @override
  String get flowsParamDirection => 'Direction';

  @override
  String get flowsParamScreen => 'Screen';

  @override
  String get flowsParamTime => 'Time';

  @override
  String get flowsParamSeconds => 'Seconds';

  @override
  String get flowsParamMilliseconds => 'Milliseconds';

  @override
  String get flowsParamLabel => 'Label';

  @override
  String get flowsParamName => 'App name';

  @override
  String get flowsParamNumber => 'Phone number';

  @override
  String get flowsParamTo => 'To';

  @override
  String get flowsParamBody => 'Message';

  @override
  String get flowsParamSubject => 'Subject';

  @override
  String get flowsParamUrl => 'Web address';

  @override
  String get flowsParamQuery => 'Place or address';

  @override
  String get flowsParamText => 'Text';

  @override
  String get flowsPickAction => 'What should the phone do?';

  @override
  String get flowsEveryHowLong => 'Repeat every';

  @override
  String get flowsIntervalNote =>
      'The phone groups timers to save battery, so it can be a few minutes late.';

  @override
  String get flowsBatteryLevelNote =>
      'Runs once when the battery falls to this level.';

  @override
  String get chatCreationReady =>
      'Here it is. Open it, or put it on your home screen.';

  @override
  String get chatCreationBuilding => 'Building it…';

  @override
  String get flowsDetailOnEvent => 'On, starts by itself';

  @override
  String get voiceStyle => 'Voice';

  @override
  String get voiceStyleF1 => 'Female 1';

  @override
  String get voiceStyleF2 => 'Female 2';

  @override
  String get voiceStyleM1 => 'Male 1';

  @override
  String get voiceStyleM2 => 'Male 2';
}
