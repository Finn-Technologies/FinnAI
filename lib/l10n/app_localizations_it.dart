// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

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
      'Installazione di LFM2.5-VL 1.6B';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B è pronto';

  @override
  String get onboardingInstallPreparing =>
      'Preparazione di LFM2.5-VL 1.6B per questo dispositivo…';

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
      'Chiedimi qualsiasi cosa — funziono interamente su questo dispositivo, le tue\nconversazioni non lasciano mai il telefono.';

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
    return '$size viene scaricato una sola volta e verificato prima dell\'uso. Il download riprende in sicurezza dopo un\'interruzione di connessione, e le tue chat restano su questo dispositivo.';
  }

  @override
  String get chatHiPrefix => 'Ciao, sono Finn.';

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
      'Questo elimina definitivamente conversazioni e chiavi crittografate, modelli AI scaricati, creazioni, preferenze del profilo, Skill e lo stato di onboarding. FinnAI tornerà a un primo avvio pulito.';

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
  String get commonClose => 'Chiudi';

  @override
  String get commonTryAgain => 'Riprova';

  @override
  String get commonDismiss => 'Ignora';

  @override
  String get bootstrapErrorTitle => 'FinnAI non è riuscito ad avviarsi';

  @override
  String get bootstrapErrorBody =>
      'Qualcosa è andato storto durante l\'inizializzazione del motore AI. Le tue conversazioni sono al sicuro.';

  @override
  String get chatHeicNotSupported =>
      'Le immagini HEIC non sono supportate. Condividile come JPEG o PNG.';

  @override
  String get chatImageAnalysisUnavailable =>
      'Analisi delle immagini non disponibile: installa il componente immagini nelle Impostazioni.';

  @override
  String get attachmentCamera => 'Fotocamera';

  @override
  String get attachmentPhotos => 'Foto';

  @override
  String get attachmentFiles => 'File';

  @override
  String get chatAddAttachmentSemantic => 'Allega un file';

  @override
  String get chatImagePromptDefault =>
      'Analizza questa immagine allegata in dettaglio.';

  @override
  String get chatFilePromptDefault =>
      'Riassumi il file allegato ed evidenzia i punti chiave.';

  @override
  String get suggestionSummarizeArticle => 'Riassumimi un articolo web';

  @override
  String get suggestionExplainSimply =>
      'Spiega un argomento complesso in modo semplice';

  @override
  String get suggestionPlanDay => 'Pianifica la mia giornata in tre passaggi';

  @override
  String get suggestionDraftEmail => 'Scrivi una breve e-mail';

  @override
  String get suggestionBrainstormNames =>
      'Fai brainstorming di nomi per il mio nuovo progetto';

  @override
  String get suggestionIdeaToPlan =>
      'Trasforma un\'idea grezza in un piano passo a passo';

  @override
  String get suggestionDebugError =>
      'Aiutami a fare il debug di un errore confuso';

  @override
  String get suggestionGoodbyeNote => 'Scrivi un breve messaggio d\'addio';

  @override
  String get suggestionCompareOptions =>
      'Confronta due opzioni prima di decidere';

  @override
  String get suggestionFreshPerspective =>
      'Dammi una prospettiva nuova su un problema';

  @override
  String get chatAnotherChatFallback => 'un\'altra chat';

  @override
  String get chatSelectText => 'Seleziona testo';

  @override
  String get chatReportAction => 'Segnala';

  @override
  String get chatMessageActionsHint =>
      'Tieni premuto per le azioni del messaggio';

  @override
  String get chatGeneratingInOtherChat => 'Generazione in un\'altra chat';

  @override
  String get chatRegenerate => 'Rigenera';

  @override
  String get chatHideSources => 'Nascondi fonti';

  @override
  String get chatShowSources => 'Mostra fonti';

  @override
  String get chatRewriteHint => 'Riscrivi il tuo messaggio';

  @override
  String get chatAskAnythingHint => 'Chiedi qualsiasi cosa';

  @override
  String get chatMessageToFinnSemantic => 'Messaggio per Finn';

  @override
  String get chatStopGeneratingSemantic => 'Interrompi la generazione';

  @override
  String get chatSendMessageSemantic => 'Invia messaggio';

  @override
  String get chatOpenMenuTooltip => 'Apri il menu';

  @override
  String get chatRenameAction => 'Rinomina';

  @override
  String get chatRenameEnterTitleHint => 'Inserisci il titolo della chat';

  @override
  String get chatDeleteActiveGenerationBody =>
      'Interrompi la generazione attiva prima di eliminare questa chat. La risposta parziale verrà conservata.';

  @override
  String get chatDeleteConfirmBody =>
      'Vuoi davvero eliminare questa cronologia chat? Questa azione non può essere annullata.';

  @override
  String get settingsModelActive => 'Attivo';

  @override
  String get settingsModelInstalled => 'Installato';

  @override
  String get settingsModelPartial => 'Parziale';

  @override
  String get settingsModelNotInstalled => 'Non installato';

  @override
  String get creationsAll => 'Tutti';

  @override
  String creationsFilterSemantic(String kind) {
    return 'Creazioni: $kind';
  }

  @override
  String get creationsEmptyFilteredTitle => 'Qui non c\'è ancora nulla';

  @override
  String get creationsEmptyTitle => 'Crea qualcosa di utile';

  @override
  String get creationsEmptyFilteredBody =>
      'Prova un\'altra categoria o creane una nuova.';

  @override
  String get creationsEmptyBody =>
      'Descrivi qui sotto un\'app, un widget o una presentazione. Finn la trasformerà in un piano pratico.';

  @override
  String get creationsDescribeHint => 'Descrivi una creazione';

  @override
  String get creationsCreateSemantic => 'Crea';

  @override
  String get creationsCreatingSemantic => 'Creazione';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Presentazione';

  @override
  String get skillsSaveFailed => 'Impossibile salvare questa Skill.';

  @override
  String get skillsBuiltForFinn => 'Creato per Finn';

  @override
  String get skillsBuiltForFinnSubtitle =>
      'Attiva solo ciò che ti serve per ogni tipo di lavoro.';

  @override
  String get skillsYourSkills => 'Le tue Skill';

  @override
  String get skillsYourSkillsSubtitle =>
      'Crea istruzioni riutilizzabili per i tuoi flussi di lavoro.';

  @override
  String get skillsNoneActive => 'Nessuna Skill attiva';

  @override
  String skillsActiveCount(int count) {
    return '$count attive';
  }

  @override
  String get skillsActionsTooltip => 'Azioni della Skill';

  @override
  String skillsNameSemantic(String name) {
    return 'Skill $name';
  }

  @override
  String get skillsEditTitle => 'Modifica Skill';

  @override
  String get skillsEditorName => 'Nome';

  @override
  String get skillsEditorNameHint => 'Cosa fa questa Skill?';

  @override
  String get skillsEditorDescription => 'Breve descrizione';

  @override
  String get skillsEditorDescriptionHint => 'Un promemoria rapido per te';

  @override
  String get skillsEditorInstructions => 'Istruzioni';

  @override
  String get skillsEditorInstructionsHint =>
      'Dì a Finn come affrontare questo tipo di attività';

  @override
  String get skillsCategoryWriting => 'Scrittura';

  @override
  String get skillsCategoryDevelopment => 'Sviluppo';

  @override
  String get skillsCategoryLearning => 'Apprendimento';

  @override
  String get skillsCategoryPlanning => 'Pianificazione';

  @override
  String get skillsCategoryCustom => 'Personalizzata';

  @override
  String get youNamePlaceholder => 'Nome preferito';

  @override
  String get youAboutQuestion => 'Qualcosa che Finn dovrebbe sapere?';

  @override
  String get youAboutPlaceholder =>
      'Il tuo lavoro, i tuoi interessi, obiettivi o contesto';

  @override
  String get youInstructionsQuestion => 'Come dovrebbe rispondere Finn?';

  @override
  String get youInstructionsPlaceholder =>
      'Ad esempio: spiega i termini tecnici, usa le unità metriche…';

  @override
  String get youSaving => 'Salvataggio…';

  @override
  String get youSavePreferences => 'Salva preferenze';

  @override
  String youStyleSemantic(String style) {
    return 'Stile di risposta $style';
  }

  @override
  String get youResponseStyleConversational => 'Conversazionale';

  @override
  String get reportSentThanks =>
      'Segnalazione inviata. Grazie per aiutare a mantenere FinnAI sicuro.';

  @override
  String get reportNoEmailApp =>
      'Impossibile aprire un\'app di posta. Scrivi direttamente a finn_org@proton.me.';

  @override
  String get reportDetailsHint => 'Dettagli aggiuntivi facoltativi...';

  @override
  String get reportCategoryHarmfulOrDangerous => 'Dannoso o pericoloso';

  @override
  String get reportCategoryHateOrHarassment => 'Odio o molestia';

  @override
  String get reportCategorySexualContent => 'Contenuto sessuale';

  @override
  String get reportCategoryChildSafety => 'Problema di sicurezza dei minori';

  @override
  String get reportCategorySelfHarm => 'Problema di autolesione';

  @override
  String get reportCategoryIllegalOrDeceptive =>
      'Indicazioni illegali o ingannevoli';

  @override
  String get reportCategoryFalseOrMisleading => 'Risposta falsa o fuorviante';

  @override
  String get reportCategorySpamOrScam => 'Spam o truffa';

  @override
  String get statusReady => 'Pronto';

  @override
  String get statusOptimizedAutomatically => 'Ottimizzato automaticamente';

  @override
  String get statusModelReady => 'Il modello AI è pronto';

  @override
  String get statusDownloadPaused => 'Download in pausa';

  @override
  String get statusModelRemoved => 'Modello rimosso';

  @override
  String get statusCheckingWeb => 'Controllo del web…';

  @override
  String get statusSearchingBrowser => 'Ricerca nel browser…';

  @override
  String get statusThinkingOnDevice => 'Ragiona su questo dispositivo';

  @override
  String get statusGeneratedLocally => 'Generato localmente';

  @override
  String get statusStopped => 'Interrotto';

  @override
  String get statusReadyAfterRuntimeReset => 'Pronto dopo il reset del runtime';

  @override
  String get statusOptimizingForDevice =>
      'Configurazione di FinnAI per prestazioni ottimali…';

  @override
  String get statusOptimizedForDevice =>
      'FinnAI è ottimizzato per questo dispositivo';

  @override
  String get statusCheckingDownload => 'Verifica del download';

  @override
  String get statusDownloadingModel => 'Download del modello AI';

  @override
  String statusDownloadingArtifact(String artifact) {
    return 'Download di $artifact';
  }

  @override
  String statusVerifyingArtifact(String artifact) {
    return 'Verifica di $artifact';
  }

  @override
  String get statusLoadingModel => 'Caricamento del modello AI';
}
