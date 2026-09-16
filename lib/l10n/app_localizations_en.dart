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
  String get commonSaveSkill => 'Save skill';

  @override
  String get commonKeepCreating => 'Keep creating';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonPurge => 'Purge';

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
  String get onboardingWelcome => 'Welcome to Finn AI!';

  @override
  String get onboardingSwipeToStart => 'Swipe to start';

  @override
  String get onboardingPrivacyTitle => 'Finn AI is Privacy-First';

  @override
  String get onboardingPrivacyBody =>
      'Finn AI is designed to respect your privacy.\n\nAI processing and conversation history stay on this device. When a request needs fresh information, Finn AI may send only that request as a web search query and will show the sources it used. Your history and personal profile are never included.\n\nFinn AI is proprietary software and is not open source.';

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
  String get onboardingInstallTitleInstalling => 'Installing LFM2.5-VL 1.6B';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B ready';

  @override
  String get onboardingInstallPreparing =>
      'Preparing LFM2.5-VL 1.6B for this device…';

  @override
  String get onboardingInstallReadyForChat =>
      'Ready for private text chat on this device';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + multimodal component · $size';
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
  String get onboardingReadyTitle => 'Finn AI is ready!';

  @override
  String get onboardingReadySubtitle => 'You\'re all set. Finn AI is ready.';

  @override
  String get onboardingYouLabel => 'You';

  @override
  String get chatNewChat => 'New chat';

  @override
  String get chatHistory => 'Chat History';

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
  String get settingsReleasingMemory => 'Releasing Memory…';

  @override
  String get settingsPurgeMemory => 'Purge AI Memory';

  @override
  String get settingsPurgeMemoryTitle => 'Purge AI Memory?';

  @override
  String get settingsPurgeMemoryBody =>
      'This will unload the AI model from RAM. It will be reloaded automatically on the next message.';

  @override
  String get settingsPurgeMemoryReleased => 'AI model memory released.';

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
      'This permanently deletes encrypted conversations and keys, downloaded AI models, creations, profile preferences, skills, and onboarding state. FinnAI will return to a clean first run.';

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
      'Privacy Policy URL is unconfigured (set FINN_PRIVACY_POLICY_URL).';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return 'Could not launch $url';
  }

  @override
  String get settingsTermsOfUse => 'Terms of Use';

  @override
  String get settingsTermsUnconfigured =>
      'Terms of Use URL is unconfigured (set FINN_TERMS_URL).';

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
  String get settingsInferenceEngine => 'Inference Engine';

  @override
  String get settingsInferenceEngineValue => 'llama.cpp · GGUF';

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
      'Finn reads replies aloud in voice mode. Your voice transcript is processed by your device\'s speech recognition, which may need internet.';

  @override
  String get voiceMicSemantic => 'Talk to Finn';

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
  String get skillsTitle => 'Skills';

  @override
  String skillsSubtitle(int count) {
    return '$count available · skills guide relevant replies';
  }

  @override
  String get skillsNewSkill => 'New skill';

  @override
  String get skillsNoSkills =>
      'No custom skills yet. Create one for a workflow you repeat.';

  @override
  String get skillsInstructionHint =>
      'Write a reusable instruction Finn should apply when relevant.';

  @override
  String get skillsDeleteTitle => 'Delete this skill?';

  @override
  String skillsDeleteBody(String name) {
    return '“$name” will be removed from this device.';
  }

  @override
  String get skillsLimitReached =>
      'Skill limit reached (4). Delete one to add another.';

  @override
  String get skillsNameLabel => 'Skill name';

  @override
  String get skillsInstructionLabel => 'Instruction';

  @override
  String get chatBrowseTooltip => 'Browse the web for this message';

  @override
  String get chatBrowseOnSemantic => 'Web browsing on';

  @override
  String get chatBrowseOffSemantic => 'Web browsing off';

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
  String get skillsSaveFailed => 'That skill could not be saved.';

  @override
  String get skillsBuiltForFinn => 'Built for Finn';

  @override
  String get skillsBuiltForFinnSubtitle =>
      'Enable only what you need for each kind of work.';

  @override
  String get skillsYourSkills => 'Your skills';

  @override
  String get skillsYourSkillsSubtitle =>
      'Create reusable instructions for your own workflows.';

  @override
  String get skillsNoneActive => 'No skills active';

  @override
  String skillsActiveCount(int count) {
    return '$count active';
  }

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
  String get snackModelMemoryReleased => 'AI model memory released.';

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
      'Image analysis unavailable: install the image component in Settings.';

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
  String get chatHideSources => 'Hide sources';

  @override
  String get chatShowSources => 'Show sources';

  @override
  String get chatRewriteHint => 'Rewrite your message';

  @override
  String get chatAskAnythingHint => 'Ask anything';

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
  String get skillsActionsTooltip => 'Skill actions';

  @override
  String skillsNameSemantic(String name) {
    return '$name skill';
  }

  @override
  String get skillsEditTitle => 'Edit skill';

  @override
  String get skillsEditorName => 'Name';

  @override
  String get skillsEditorNameHint => 'What does this skill do?';

  @override
  String get skillsEditorDescription => 'Short description';

  @override
  String get skillsEditorDescriptionHint => 'A quick reminder for you';

  @override
  String get skillsEditorInstructions => 'Instructions';

  @override
  String get skillsEditorInstructionsHint =>
      'Tell Finn how to approach this kind of task';

  @override
  String get skillsCategoryWriting => 'Writing';

  @override
  String get skillsCategoryDevelopment => 'Development';

  @override
  String get skillsCategoryLearning => 'Learning';

  @override
  String get skillsCategoryPlanning => 'Planning';

  @override
  String get skillsCategoryCustom => 'Custom';

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
}
