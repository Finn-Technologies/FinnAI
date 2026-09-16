// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

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
      'Installation de LFM2.5-VL 1.6B';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B est prêt';

  @override
  String get onboardingInstallPreparing =>
      'Préparation de LFM2.5-VL 1.6B pour cet appareil…';

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
      'Posez-moi toutes vos questions — je fonctionne entièrement sur cet appareil, vos\nconversations ne quittent jamais votre téléphone.';

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
      'Impossible d\'ouvrir le sélecteur. Veuillez réessayer.';

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
    return '$size est téléchargé une seule fois et vérifié avant utilisation. Le téléchargement reprend en toute sécurité après une interruption, et vos conversations restent sur cet appareil.';
  }

  @override
  String get chatHiPrefix => 'Salut, je suis Finn.';

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
      'Cette action supprime définitivement les conversations et clés chiffrées, les modèles d\'IA téléchargés, les créations, les préférences de profil, les Skills et l\'état d\'onboarding. FinnAI reviendra à un premier démarrage vierge.';

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
  String get chatBrowseTooltip => 'Rechercher sur le web pour ce message';

  @override
  String get chatBrowseOnSemantic => 'Recherche web activée';

  @override
  String get chatBrowseOffSemantic => 'Recherche web désactivée';

  @override
  String get chatBrowsingTitle => 'Navigation sur le web';

  @override
  String get chatSearchingInline => 'Recherche sur le web…';

  @override
  String get chatSearchedInline => 'Recherche web effectuée';

  @override
  String get chatShowSearchSteps => 'Afficher les étapes de recherche';

  @override
  String get chatBrowsingHide => 'Masquer';

  @override
  String chatBrowsingSteps(int count) {
    return '$count étapes';
  }

  @override
  String chatBrowsingSearch(String query) {
    return 'Recherche web : « $query »';
  }

  @override
  String chatBrowsingOpen(String title) {
    return 'Lecture de « $title »';
  }

  @override
  String chatBrowsingFind(String query) {
    return 'Recherche de « $query » sur la page';
  }

  @override
  String get creationsTitle => 'Creations';

  @override
  String get creationsSubtitle =>
      'Décrivez ce que vous voulez. Finn le crée sur l’appareil.';

  @override
  String get creationsWhatAreWeMaking => 'What are we making?';

  @override
  String get creationsOriginalBrief => 'Original brief';

  @override
  String get creationsFinnAdapts => 'Finn adapts the structure to the format.';

  @override
  String get creationsAskKind =>
      'Votre nouvelle création est-elle une app, un widget ou une présentation ?';

  @override
  String creationsDescribeKind(String kind) {
    return 'Dites-moi ce que votre $kind doit faire.';
  }

  @override
  String get creationsStageDesigning => 'Conception…';

  @override
  String get creationsStageWriting => 'Rédaction…';

  @override
  String get creationsStageValidating => 'Vérification du résultat…';

  @override
  String get creationsStageRepairing => 'Correction d’un détail…';

  @override
  String get creationsFallbackNote =>
      'Finn n’a pas pu terminer la conception ; voici un modèle fonctionnel sur lequel vous pouvez vous appuyer.';

  @override
  String get creationsNewCreation => 'Nouvelle création';

  @override
  String get creationsChooseKindSemantic => 'Choisir quoi créer';

  @override
  String get creationsFailed =>
      'Finn n’a pas pu terminer cette création. Veuillez réessayer.';

  @override
  String get creationsHomeScreenUnsupported =>
      'Les widgets d’écran d’accueil ne sont pas disponibles sur cet appareil.';

  @override
  String get creationsHomeScreenAdded => 'Ajouté à votre écran d’accueil.';

  @override
  String get creationsHomeScreenFailed =>
      'Impossible de l’ajouter à votre écran d’accueil.';

  @override
  String creationsExportedTo(String fileName) {
    return '$fileName enregistré';
  }

  @override
  String get creationsExportDeck => 'Exporter en PowerPoint';

  @override
  String get creationsAddToHomeScreen => 'Ajouter à l’écran d’accueil';

  @override
  String get creationsWidgetPreview =>
      'Voici à quoi cela ressemblera sur votre écran d’accueil.';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Présentation';

  @override
  String get creationsFilterApps => 'Apps';

  @override
  String get creationsFilterWidgets => 'Widgets';

  @override
  String get creationsFilterPresentations => 'Présentations';

  @override
  String get skillsSaveFailed => 'Impossible d\'enregistrer ce Skill.';

  @override
  String get skillsBuiltForFinn => 'Conçu pour Finn';

  @override
  String get skillsBuiltForFinnSubtitle =>
      'Activez uniquement ce dont vous avez besoin pour chaque type de travail.';

  @override
  String get skillsYourSkills => 'Vos Skills';

  @override
  String get skillsYourSkillsSubtitle =>
      'Créez des instructions réutilisables pour vos propres flux de travail.';

  @override
  String get skillsNoneActive => 'Aucun Skill actif';

  @override
  String skillsActiveCount(int count) {
    return '$count actifs';
  }

  @override
  String get creationsExportedShared => 'Présentation prête à être partagée.';

  @override
  String get creationsExportFailed =>
      'Cette présentation n’a pas pu être exportée.';

  @override
  String get creationsResetApp => 'Réinitialiser';

  @override
  String get creationsPreviousSlide => 'Diapositive précédente';

  @override
  String get creationsNextSlide => 'Diapositive suivante';

  @override
  String creationsSlideOf(int index, int count) {
    return 'Diapositive $index sur $count';
  }

  @override
  String creationsElementCount(int count) {
    return '$count éléments';
  }

  @override
  String creationsRowCount(int count) {
    return '$count lignes';
  }

  @override
  String creationsSlideCount(int count) {
    return '$count diapositives';
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
  String get commonClose => 'Fermer';

  @override
  String get commonTryAgain => 'Réessayer';

  @override
  String get commonDismiss => 'Fermer';

  @override
  String get bootstrapErrorTitle => 'FinnAI n\'a pas pu démarrer';

  @override
  String get bootstrapErrorBody =>
      'Une erreur est survenue lors de l\'initialisation du moteur d\'IA. Vos conversations sont en sécurité.';

  @override
  String get chatHeicNotSupported =>
      'Les images HEIC ne sont pas prises en charge. Partagez-les en JPEG ou PNG.';

  @override
  String get chatImageAnalysisUnavailable =>
      'Analyse d\'image indisponible : installez le composant d\'image dans les Réglages.';

  @override
  String get attachmentCamera => 'Appareil photo';

  @override
  String get attachmentPhotos => 'Photos';

  @override
  String get attachmentFiles => 'Fichiers';

  @override
  String get chatAddAttachmentSemantic => 'Joindre un fichier';

  @override
  String get chatImagePromptDefault => 'Analyse cette image jointe en détail.';

  @override
  String get chatFilePromptDefault =>
      'Résume le fichier joint et mets en évidence ses points clés.';

  @override
  String get suggestionSummarizeArticle => 'Résumez-moi un article web';

  @override
  String get suggestionExplainSimply =>
      'Expliquez un sujet complexe simplement';

  @override
  String get suggestionPlanDay => 'Organisez ma journée en trois étapes';

  @override
  String get suggestionDraftEmail => 'Rédigez un e-mail court';

  @override
  String get suggestionBrainstormNames =>
      'Proposez des noms pour mon nouveau projet';

  @override
  String get suggestionIdeaToPlan =>
      'Transformez une idée approximative en plan étape par étape';

  @override
  String get suggestionDebugError =>
      'Aidez-moi à déboguer une erreur déroutante';

  @override
  String get suggestionGoodbyeNote => 'Rédigez un petit mot d\'adieu';

  @override
  String get suggestionCompareOptions =>
      'Comparez deux options avant que je décide';

  @override
  String get suggestionFreshPerspective =>
      'Donnez-moi un regard neuf sur un problème';

  @override
  String get chatAnotherChatFallback => 'une autre conversation';

  @override
  String get chatSelectText => 'Sélectionner le texte';

  @override
  String get chatReportAction => 'Signaler';

  @override
  String get chatMessageActionsHint =>
      'Appuyez longuement pour les actions du message';

  @override
  String get chatGeneratingInOtherChat =>
      'Génération dans une autre conversation';

  @override
  String get chatRegenerate => 'Régénérer';

  @override
  String get chatHideSources => 'Masquer les sources';

  @override
  String get chatShowSources => 'Afficher les sources';

  @override
  String get chatRewriteHint => 'Réécrivez votre message';

  @override
  String get chatAskAnythingHint => 'Posez votre question';

  @override
  String get chatMessageToFinnSemantic => 'Message pour Finn';

  @override
  String get chatStopGeneratingSemantic => 'Arrêter la génération';

  @override
  String get chatSendMessageSemantic => 'Envoyer le message';

  @override
  String get chatOpenMenuTooltip => 'Ouvrir le menu';

  @override
  String get chatRenameAction => 'Renommer';

  @override
  String get chatRenameEnterTitleHint =>
      'Saisissez le titre de la conversation';

  @override
  String get chatDeleteActiveGenerationBody =>
      'Arrêtez la génération en cours avant de supprimer cette conversation. Sa réponse partielle sera conservée.';

  @override
  String get chatDeleteConfirmBody =>
      'Voulez-vous vraiment supprimer cet historique de conversation ? Cette action est irréversible.';

  @override
  String get settingsModelActive => 'Actif';

  @override
  String get settingsModelInstalled => 'Installé';

  @override
  String get settingsModelPartial => 'Partiel';

  @override
  String get settingsModelNotInstalled => 'Non installé';

  @override
  String get creationsAll => 'Tout';

  @override
  String creationsFilterSemantic(String kind) {
    return 'Créations : $kind';
  }

  @override
  String get creationsEmptyFilteredTitle => 'Rien ici pour l\'instant';

  @override
  String get creationsEmptyTitle => 'Créez quelque chose d\'utile';

  @override
  String get creationsEmptyFilteredBody =>
      'Essayez une autre catégorie ou créez-en une nouvelle.';

  @override
  String get creationsEmptyBody =>
      'Décrivez ci-dessous une app, un widget ou une présentation. Finn en fera un plan pratique.';

  @override
  String get creationsDescribeHint => 'Décrivez une création';

  @override
  String get skillsActionsTooltip => 'Actions du Skill';

  @override
  String skillsNameSemantic(String name) {
    return 'Skill $name';
  }

  @override
  String get skillsEditTitle => 'Modifier le Skill';

  @override
  String get skillsEditorName => 'Nom';

  @override
  String get skillsEditorNameHint => 'Que fait ce Skill ?';

  @override
  String get skillsEditorDescription => 'Brève description';

  @override
  String get skillsEditorDescriptionHint => 'Un petit rappel pour vous';

  @override
  String get skillsEditorInstructions => 'Instructions';

  @override
  String get skillsEditorInstructionsHint =>
      'Dites à Finn comment aborder ce type de tâche';

  @override
  String get skillsCategoryWriting => 'Rédaction';

  @override
  String get skillsCategoryDevelopment => 'Développement';

  @override
  String get skillsCategoryLearning => 'Apprentissage';

  @override
  String get skillsCategoryPlanning => 'Planification';

  @override
  String get skillsCategoryCustom => 'Personnalisé';

  @override
  String get youNamePlaceholder => 'Nom souhaité';

  @override
  String get youAboutQuestion => 'Quelque chose que Finn devrait savoir ?';

  @override
  String get youAboutPlaceholder =>
      'Votre travail, vos centres d\'intérêt, vos objectifs ou votre contexte';

  @override
  String get youInstructionsQuestion => 'Comment Finn doit-il répondre ?';

  @override
  String get youInstructionsPlaceholder =>
      'Par exemple : expliquez les termes techniques, utilisez les unités métriques…';

  @override
  String get youSaving => 'Enregistrement…';

  @override
  String get youSavePreferences => 'Enregistrer les préférences';

  @override
  String youStyleSemantic(String style) {
    return 'Style de réponse $style';
  }

  @override
  String get youResponseStyleConversational => 'Conversationnel';

  @override
  String get reportSentThanks =>
      'Signalement envoyé. Merci de contribuer à la sécurité de FinnAI.';

  @override
  String get reportNoEmailApp =>
      'Impossible d\'ouvrir une application de messagerie. Écrivez directement à finn_org@proton.me.';

  @override
  String get reportDetailsHint => 'Détails supplémentaires facultatifs...';

  @override
  String get reportCategoryHarmfulOrDangerous => 'Préjudiciable ou dangereux';

  @override
  String get reportCategoryHateOrHarassment => 'Haine ou harcèlement';

  @override
  String get reportCategorySexualContent => 'Contenu sexuel';

  @override
  String get reportCategoryChildSafety => 'Problème de sécurité des enfants';

  @override
  String get reportCategorySelfHarm => 'Problème d\'automutilation';

  @override
  String get reportCategoryIllegalOrDeceptive =>
      'Conseils illégaux ou trompeurs';

  @override
  String get reportCategoryFalseOrMisleading => 'Réponse fausse ou trompeuse';

  @override
  String get reportCategorySpamOrScam => 'Spam ou arnaque';

  @override
  String get statusReady => 'Prêt';

  @override
  String get statusOptimizedAutomatically => 'Optimisé automatiquement';

  @override
  String get statusModelReady => 'Le modèle d\'IA est prêt';

  @override
  String get statusDownloadPaused => 'Téléchargement en pause';

  @override
  String get statusModelRemoved => 'Modèle supprimé';

  @override
  String get statusCheckingWeb => 'Vérification du web…';

  @override
  String get statusSearchingBrowser => 'Recherche dans le navigateur…';

  @override
  String get statusThinkingOnDevice => 'Réflexion sur cet appareil';

  @override
  String get statusGeneratedLocally => 'Généré localement';

  @override
  String get statusStopped => 'Arrêté';

  @override
  String get statusReadyAfterRuntimeReset =>
      'Prêt après réinitialisation du runtime';

  @override
  String get statusOptimizingForDevice =>
      'Configuration de FinnAI pour des performances optimales…';

  @override
  String get statusOptimizedForDevice =>
      'FinnAI est optimisé pour cet appareil';

  @override
  String get statusCheckingDownload => 'Vérification du téléchargement';

  @override
  String get statusDownloadingModel => 'Téléchargement du modèle d\'IA';

  @override
  String statusDownloadingArtifact(String artifact) {
    return 'Téléchargement de $artifact';
  }

  @override
  String statusVerifyingArtifact(String artifact) {
    return 'Vérification de $artifact';
  }

  @override
  String get statusLoadingModel => 'Chargement du modèle d\'IA';
}
