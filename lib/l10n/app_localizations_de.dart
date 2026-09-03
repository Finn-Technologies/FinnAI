// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

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
  String get onboardingInstallTitleInstalling =>
      'LFM2.5-VL 1.6B wird installiert';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B ist bereit';

  @override
  String get onboardingInstallPreparing =>
      'LFM2.5-VL 1.6B wird für dieses Gerät vorbereitet…';

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
      'Frag mich alles — ich laufe komplett auf diesem Gerät, deine\nUnterhaltungen verlassen niemals dein Telefon.';

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
    return '$size wird einmal heruntergeladen und vor der Nutzung überprüft. Nach einer unterbrochenen Verbindung wird der Download sicher fortgesetzt, und deine Chats bleiben auf diesem Gerät.';
  }

  @override
  String get chatHiPrefix => 'Hi, ich bin Finn.';

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
      'Dies löscht endgültig verschlüsselte Unterhaltungen und Schlüssel, heruntergeladene KI-Modelle, Kreationen, Profileinstellungen, Skills und den Onboarding-Zustand. FinnAI kehrt zu einem sauberen Erststart zurück.';

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
  String get creationsTitle => 'Creations';

  @override
  String get creationsSubtitle =>
      'Turn an idea into a structured plan, entirely on device.';

  @override
  String get creationsWhatAreWeMaking => 'What are we making?';

  @override
  String get creationsOriginalBrief => 'Original brief';

  @override
  String get creationsFinnAdapts => 'Finn adapts the structure to the format.';

  @override
  String get creationsComposerHint => 'Describe what you want to make…';

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
  String get creationsDiscarded => 'Creation discarded';

  @override
  String get creationsKindStory => 'Story';

  @override
  String get creationsKindPlan => 'Plan';

  @override
  String get creationsKindEmail => 'Email';

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
  String get commonClose => 'Schließen';

  @override
  String get commonTryAgain => 'Erneut versuchen';

  @override
  String get commonDismiss => 'Schließen';

  @override
  String get bootstrapErrorTitle => 'FinnAI konnte nicht gestartet werden';

  @override
  String get bootstrapErrorBody =>
      'Beim Initialisieren der KI-Engine ist etwas schiefgelaufen. Deine Unterhaltungen sind sicher.';

  @override
  String get chatHeicNotSupported =>
      'HEIC-Bilder werden nicht unterstützt. Bitte als JPEG oder PNG teilen.';

  @override
  String get chatImageAnalysisUnavailable =>
      'Bildanalyse nicht verfügbar: Installiere die Bildkomponente in den Einstellungen.';

  @override
  String get attachmentCamera => 'Kamera';

  @override
  String get attachmentPhotos => 'Fotos';

  @override
  String get attachmentFiles => 'Dateien';

  @override
  String get chatAddAttachmentSemantic => 'Anhang hinzufügen';

  @override
  String get chatImagePromptDefault =>
      'Bitte analysiere das angehängte Bild im Detail.';

  @override
  String get chatFilePromptDefault =>
      'Bitte fasse die angehängte Datei zusammen und hebe die wichtigsten Punkte hervor.';

  @override
  String get suggestionSummarizeArticle =>
      'Fasse mir einen Webartikel zusammen';

  @override
  String get suggestionExplainSimply => 'Erkläre ein komplexes Thema einfach';

  @override
  String get suggestionPlanDay => 'Plane meinen Tag in drei Schritten';

  @override
  String get suggestionDraftEmail => 'Verfasse eine kurze E-Mail';

  @override
  String get suggestionBrainstormNames =>
      'Brainstorme Namen für mein neues Projekt';

  @override
  String get suggestionIdeaToPlan =>
      'Mach aus einer groben Idee einen Schritt-für-Schritt-Plan';

  @override
  String get suggestionDebugError =>
      'Hilf mir, einen kryptischen Fehler zu finden';

  @override
  String get suggestionGoodbyeNote => 'Schreibe eine kurze Abschiedsnachricht';

  @override
  String get suggestionCompareOptions =>
      'Vergleiche zwei Optionen, bevor ich mich entscheide';

  @override
  String get suggestionFreshPerspective =>
      'Gib mir eine neue Perspektive auf ein Problem';

  @override
  String get chatAnotherChatFallback => 'einem anderen Chat';

  @override
  String get chatSelectText => 'Text auswählen';

  @override
  String get chatReportAction => 'Melden';

  @override
  String get chatMessageActionsHint => 'Nachricht für Aktionen gedrückt halten';

  @override
  String get chatGeneratingInOtherChat => 'Generierung in einem anderen Chat';

  @override
  String get chatRegenerate => 'Neu generieren';

  @override
  String get chatHideSources => 'Quellen ausblenden';

  @override
  String get chatShowSources => 'Quellen einblenden';

  @override
  String get chatRewriteHint => 'Nachricht neu formulieren';

  @override
  String get chatAskAnythingHint => 'Frag etwas';

  @override
  String get chatMessageToFinnSemantic => 'Nachricht an Finn';

  @override
  String get chatStopGeneratingSemantic => 'Generierung stoppen';

  @override
  String get chatSendMessageSemantic => 'Nachricht senden';

  @override
  String get chatOpenMenuTooltip => 'Menü öffnen';

  @override
  String get chatRenameAction => 'Umbenennen';

  @override
  String get chatRenameEnterTitleHint => 'Chattitel eingeben';

  @override
  String get chatDeleteActiveGenerationBody =>
      'Beende die laufende Generierung, bevor du diesen Chat löschst. Die unvollständige Antwort bleibt erhalten.';

  @override
  String get chatDeleteConfirmBody =>
      'Möchtest du diesen Chatverlauf wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get settingsModelActive => 'Aktiv';

  @override
  String get settingsModelInstalled => 'Installiert';

  @override
  String get settingsModelPartial => 'Unvollständig';

  @override
  String get settingsModelNotInstalled => 'Nicht installiert';

  @override
  String get creationsAll => 'Alle';

  @override
  String creationsFilterSemantic(String kind) {
    return '$kind Kreationen';
  }

  @override
  String get creationsEmptyFilteredTitle => 'Hier ist noch nichts';

  @override
  String get creationsEmptyTitle => 'Etwas Nützliches erstellen';

  @override
  String get creationsEmptyFilteredBody =>
      'Versuche eine andere Kategorie oder erstelle eine neue.';

  @override
  String get creationsEmptyBody =>
      'Beschreibe unten eine App, ein Widget oder eine Präsentation. Finn formt daraus einen praktischen Plan.';

  @override
  String get creationsDescribeHint => 'Beschreibe eine Kreation';

  @override
  String get creationsCreateSemantic => 'Erstellen';

  @override
  String get creationsCreatingSemantic => 'Wird erstellt';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Präsentation';

  @override
  String get skillsSaveFailed =>
      'Dieser Skill konnte nicht gespeichert werden.';

  @override
  String get skillsBuiltForFinn => 'Für Finn gebaut';

  @override
  String get skillsBuiltForFinnSubtitle =>
      'Aktiviere nur, was du für jede Art von Arbeit brauchst.';

  @override
  String get skillsYourSkills => 'Deine Skills';

  @override
  String get skillsYourSkillsSubtitle =>
      'Erstelle wiederverwendbare Anweisungen für deine eigenen Workflows.';

  @override
  String get skillsNoneActive => 'Keine Skills aktiv';

  @override
  String skillsActiveCount(int count) {
    return '$count aktiv';
  }

  @override
  String get skillsActionsTooltip => 'Skill-Aktionen';

  @override
  String skillsNameSemantic(String name) {
    return '$name Skill';
  }

  @override
  String get skillsEditTitle => 'Skill bearbeiten';

  @override
  String get skillsEditorName => 'Name';

  @override
  String get skillsEditorNameHint => 'Was macht dieser Skill?';

  @override
  String get skillsEditorDescription => 'Kurze Beschreibung';

  @override
  String get skillsEditorDescriptionHint => 'Eine kurze Erinnerung für dich';

  @override
  String get skillsEditorInstructions => 'Anweisungen';

  @override
  String get skillsEditorInstructionsHint =>
      'Sag Finn, wie es diese Art von Aufgabe angehen soll';

  @override
  String get skillsCategoryWriting => 'Schreiben';

  @override
  String get skillsCategoryDevelopment => 'Entwicklung';

  @override
  String get skillsCategoryLearning => 'Lernen';

  @override
  String get skillsCategoryPlanning => 'Planung';

  @override
  String get skillsCategoryCustom => 'Benutzerdefiniert';

  @override
  String get youNamePlaceholder => 'Gewünschter Name';

  @override
  String get youAboutQuestion => 'Etwas, das Finn wissen sollte?';

  @override
  String get youAboutPlaceholder =>
      'Deine Arbeit, Interessen, Ziele oder dein Kontext';

  @override
  String get youInstructionsQuestion => 'Wie soll Finn antworten?';

  @override
  String get youInstructionsPlaceholder =>
      'Zum Beispiel: technische Begriffe erklären, metrische Einheiten verwenden…';

  @override
  String get youSaving => 'Speichern…';

  @override
  String get youSavePreferences => 'Einstellungen speichern';

  @override
  String youStyleSemantic(String style) {
    return '$style Antwortstil';
  }

  @override
  String get youResponseStyleConversational => 'Konversationell';

  @override
  String get reportSentThanks =>
      'Meldung gesendet. Danke, dass du hilfst, FinnAI sicher zu halten.';

  @override
  String get reportNoEmailApp =>
      'Keine E-Mail-App konnte geöffnet werden. Schreibe direkt an finn_org@proton.me.';

  @override
  String get reportDetailsHint => 'Optionale weitere Details...';

  @override
  String get reportCategoryHarmfulOrDangerous => 'Schädlich oder gefährlich';

  @override
  String get reportCategoryHateOrHarassment => 'Hass oder Belästigung';

  @override
  String get reportCategorySexualContent => 'Sexuelle Inhalte';

  @override
  String get reportCategoryChildSafety => 'Kinderschutzbedenken';

  @override
  String get reportCategorySelfHarm => 'Selbstverletzungsbedenken';

  @override
  String get reportCategoryIllegalOrDeceptive =>
      'Illegale oder täuschende Anleitung';

  @override
  String get reportCategoryFalseOrMisleading =>
      'Falsche oder irreführende Antwort';

  @override
  String get reportCategorySpamOrScam => 'Spam oder Betrug';

  @override
  String get statusReady => 'Bereit';

  @override
  String get statusOptimizedAutomatically => 'Automatisch optimiert';

  @override
  String get statusModelReady => 'KI-Modell ist bereit';

  @override
  String get statusDownloadPaused => 'Download pausiert';

  @override
  String get statusModelRemoved => 'Modell entfernt';

  @override
  String get statusCheckingWeb => 'Web wird durchsucht…';

  @override
  String get statusSearchingBrowser => 'Browser-Suche läuft…';

  @override
  String get statusThinkingOnDevice => 'Denkt auf diesem Gerät';

  @override
  String get statusGeneratedLocally => 'Lokal generiert';

  @override
  String get statusStopped => 'Gestoppt';

  @override
  String get statusReadyAfterRuntimeReset => 'Nach Runtime-Reset bereit';

  @override
  String get statusOptimizingForDevice =>
      'FinnAI wird für optimale Leistung eingerichtet…';

  @override
  String get statusOptimizedForDevice =>
      'FinnAI ist für dieses Gerät optimiert';

  @override
  String get statusCheckingDownload => 'Download wird geprüft';

  @override
  String get statusDownloadingModel => 'KI-Modell wird heruntergeladen';

  @override
  String statusDownloadingArtifact(String artifact) {
    return '$artifact wird heruntergeladen';
  }

  @override
  String statusVerifyingArtifact(String artifact) {
    return '$artifact wird überprüft';
  }

  @override
  String get statusLoadingModel => 'KI-Modell wird geladen';
}
