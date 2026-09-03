// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

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
  String get onboardingInstallTitleInstalling => 'Instalando LFM2.5-VL 1.6B';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B listo';

  @override
  String get onboardingInstallPreparing =>
      'Preparando LFM2.5-VL 1.6B para este dispositivo…';

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
      'Pregúntame lo que quieras — funciono por completo en este dispositivo, así que tus\nconversaciones nunca salen de tu teléfono.';

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
    return '$size se descarga una vez y se verifica antes de usarlo. La descarga se reanuda de forma segura tras una conexión interrumpida, y tus chats permanecen en este dispositivo.';
  }

  @override
  String get chatHiPrefix => 'Hola, soy Finn.';

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
      'Esto elimina definitivamente las conversaciones y claves cifradas, los modelos de IA descargados, las creaciones, las preferencias del perfil, las Skills y el estado de onboarding. FinnAI volverá a un primer inicio limpio.';

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
  String get commonClose => 'Cerrar';

  @override
  String get commonTryAgain => 'Reintentar';

  @override
  String get commonDismiss => 'Descartar';

  @override
  String get bootstrapErrorTitle => 'FinnAI no pudo iniciarse';

  @override
  String get bootstrapErrorBody =>
      'Algo salió mal al inicializar el motor de IA. Tus conversaciones están a salvo.';

  @override
  String get chatHeicNotSupported =>
      'Las imágenes HEIC no son compatibles. Compártelas como JPEG o PNG.';

  @override
  String get chatImageAnalysisUnavailable =>
      'Análisis de imágenes no disponible: instala el componente de imágenes en Ajustes.';

  @override
  String get attachmentCamera => 'Cámara';

  @override
  String get attachmentPhotos => 'Fotos';

  @override
  String get attachmentFiles => 'Archivos';

  @override
  String get chatAddAttachmentSemantic => 'Añadir archivo adjunto';

  @override
  String get chatImagePromptDefault =>
      'Analiza esta imagen adjunta en detalle.';

  @override
  String get chatFilePromptDefault =>
      'Resume el archivo adjunto y destaca sus puntos clave.';

  @override
  String get suggestionSummarizeArticle => 'Resúme un artículo web';

  @override
  String get suggestionExplainSimply =>
      'Explica un tema complejo de forma sencilla';

  @override
  String get suggestionPlanDay => 'Planifica mi día en tres pasos';

  @override
  String get suggestionDraftEmail => 'Redacta un correo breve';

  @override
  String get suggestionBrainstormNames =>
      'Propón nombres para mi nuevo proyecto';

  @override
  String get suggestionIdeaToPlan =>
      'Convierte una idea aproximada en un plan paso a paso';

  @override
  String get suggestionDebugError => 'Ayúdame a depurar un error confuso';

  @override
  String get suggestionGoodbyeNote => 'Escribe una nota de despedida rápida';

  @override
  String get suggestionCompareOptions =>
      'Compara dos opciones antes de decidir';

  @override
  String get suggestionFreshPerspective =>
      'Dame una perspectiva nueva sobre un problema';

  @override
  String get chatAnotherChatFallback => 'otro chat';

  @override
  String get chatSelectText => 'Seleccionar texto';

  @override
  String get chatReportAction => 'Denunciar';

  @override
  String get chatMessageActionsHint =>
      'Mantén pulsado el mensaje para ver las acciones';

  @override
  String get chatGeneratingInOtherChat => 'Generando en otro chat';

  @override
  String get chatRegenerate => 'Regenerar';

  @override
  String get chatHideSources => 'Ocultar fuentes';

  @override
  String get chatShowSources => 'Mostrar fuentes';

  @override
  String get chatRewriteHint => 'Reescribe tu mensaje';

  @override
  String get chatAskAnythingHint => 'Pregunta algo';

  @override
  String get chatMessageToFinnSemantic => 'Mensaje para Finn';

  @override
  String get chatStopGeneratingSemantic => 'Detener la generación';

  @override
  String get chatSendMessageSemantic => 'Enviar mensaje';

  @override
  String get chatOpenMenuTooltip => 'Abrir menú';

  @override
  String get chatRenameAction => 'Renombrar';

  @override
  String get chatRenameEnterTitleHint => 'Introduce el título del chat';

  @override
  String get chatDeleteActiveGenerationBody =>
      'Detén la generación activa antes de eliminar este chat. Su respuesta parcial se conservará.';

  @override
  String get chatDeleteConfirmBody =>
      '¿Seguro que quieres eliminar este historial de chat? Esta acción no se puede deshacer.';

  @override
  String get settingsModelActive => 'Activo';

  @override
  String get settingsModelInstalled => 'Instalado';

  @override
  String get settingsModelPartial => 'Parcial';

  @override
  String get settingsModelNotInstalled => 'No instalado';

  @override
  String get creationsAll => 'Todo';

  @override
  String creationsFilterSemantic(String kind) {
    return 'Creaciones: $kind';
  }

  @override
  String get creationsEmptyFilteredTitle => 'Aquí no hay nada todavía';

  @override
  String get creationsEmptyTitle => 'Crea algo útil';

  @override
  String get creationsEmptyFilteredBody =>
      'Prueba otra categoría o crea una nueva.';

  @override
  String get creationsEmptyBody =>
      'Describe abajo una app, un widget o una presentación. Finn lo convertirá en un plan práctico.';

  @override
  String get creationsDescribeHint => 'Describe una creación';

  @override
  String get creationsCreateSemantic => 'Crear';

  @override
  String get creationsCreatingSemantic => 'Creando';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Presentación';

  @override
  String get skillsSaveFailed => 'No se pudo guardar esa Skill.';

  @override
  String get skillsBuiltForFinn => 'Diseñado para Finn';

  @override
  String get skillsBuiltForFinnSubtitle =>
      'Activa solo lo que necesites para cada tipo de trabajo.';

  @override
  String get skillsYourSkills => 'Tus Skills';

  @override
  String get skillsYourSkillsSubtitle =>
      'Crea instrucciones reutilizables para tus propios flujos de trabajo.';

  @override
  String get skillsNoneActive => 'No hay Skills activas';

  @override
  String skillsActiveCount(int count) {
    return '$count activas';
  }

  @override
  String get skillsActionsTooltip => 'Acciones de la Skill';

  @override
  String skillsNameSemantic(String name) {
    return 'Skill $name';
  }

  @override
  String get skillsEditTitle => 'Editar Skill';

  @override
  String get skillsEditorName => 'Nombre';

  @override
  String get skillsEditorNameHint => '¿Qué hace esta Skill?';

  @override
  String get skillsEditorDescription => 'Descripción breve';

  @override
  String get skillsEditorDescriptionHint => 'Un recordatorio rápido para ti';

  @override
  String get skillsEditorInstructions => 'Instrucciones';

  @override
  String get skillsEditorInstructionsHint =>
      'Di a Finn cómo abordar este tipo de tarea';

  @override
  String get skillsCategoryWriting => 'Escritura';

  @override
  String get skillsCategoryDevelopment => 'Desarrollo';

  @override
  String get skillsCategoryLearning => 'Aprendizaje';

  @override
  String get skillsCategoryPlanning => 'Planificación';

  @override
  String get skillsCategoryCustom => 'Personalizada';

  @override
  String get youNamePlaceholder => 'Nombre preferido';

  @override
  String get youAboutQuestion => '¿Algo que Finn deba saber?';

  @override
  String get youAboutPlaceholder => 'Tu trabajo, intereses, metas o contexto';

  @override
  String get youInstructionsQuestion => '¿Cómo debe responder Finn?';

  @override
  String get youInstructionsPlaceholder =>
      'Por ejemplo: explica los términos técnicos, usa unidades métricas…';

  @override
  String get youSaving => 'Guardando…';

  @override
  String get youSavePreferences => 'Guardar preferencias';

  @override
  String youStyleSemantic(String style) {
    return 'Estilo de respuesta $style';
  }

  @override
  String get youResponseStyleConversational => 'Conversacional';

  @override
  String get reportSentThanks =>
      'Informe enviado. Gracias por ayudar a mantener FinnAI seguro.';

  @override
  String get reportNoEmailApp =>
      'No se pudo abrir ninguna app de correo. Escribe directamente a finn_org@proton.me.';

  @override
  String get reportDetailsHint => 'Detalles adicionales opcionales...';

  @override
  String get reportCategoryHarmfulOrDangerous => 'Dañino o peligroso';

  @override
  String get reportCategoryHateOrHarassment => 'Odio o acoso';

  @override
  String get reportCategorySexualContent => 'Contenido sexual';

  @override
  String get reportCategoryChildSafety => 'Preocupación de seguridad infantil';

  @override
  String get reportCategorySelfHarm => 'Preocupación de autolesión';

  @override
  String get reportCategoryIllegalOrDeceptive =>
      'Orientación ilegal o engañosa';

  @override
  String get reportCategoryFalseOrMisleading => 'Respuesta falsa o engañosa';

  @override
  String get reportCategorySpamOrScam => 'Spam o estafa';

  @override
  String get statusReady => 'Listo';

  @override
  String get statusOptimizedAutomatically => 'Optimizado automáticamente';

  @override
  String get statusModelReady => 'El modelo de IA está listo';

  @override
  String get statusDownloadPaused => 'Descarga en pausa';

  @override
  String get statusModelRemoved => 'Modelo eliminado';

  @override
  String get statusCheckingWeb => 'Consultando la web…';

  @override
  String get statusSearchingBrowser => 'Buscando en el navegador…';

  @override
  String get statusThinkingOnDevice => 'Pensando en este dispositivo';

  @override
  String get statusGeneratedLocally => 'Generado localmente';

  @override
  String get statusStopped => 'Detenido';

  @override
  String get statusReadyAfterRuntimeReset =>
      'Listo tras el reinicio del runtime';

  @override
  String get statusOptimizingForDevice =>
      'Configurando FinnAI para un rendimiento óptimo…';

  @override
  String get statusOptimizedForDevice =>
      'FinnAI está optimizado para este dispositivo';

  @override
  String get statusCheckingDownload => 'Verificando la descarga';

  @override
  String get statusDownloadingModel => 'Descargando el modelo de IA';

  @override
  String statusDownloadingArtifact(String artifact) {
    return 'Descargando $artifact';
  }

  @override
  String statusVerifyingArtifact(String artifact) {
    return 'Verificando $artifact';
  }

  @override
  String get statusLoadingModel => 'Cargando el modelo de IA';
}
