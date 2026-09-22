// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get commonOpen => 'Abrir';

  @override
  String get commonStop => 'Detener';

  @override
  String get commonDownload => 'Descargar';

  @override
  String get commonResend => 'Reenviar';

  @override
  String get commonSaveSkill => 'Guardar habilidad';

  @override
  String get commonKeepCreating => 'Seguir creando';

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get commonPurge => 'Purgar';

  @override
  String get commonClearAll => 'Borrar todo';

  @override
  String get commonDeleteEverything => 'Eliminar todo';

  @override
  String get appTitle => 'Finn AI';

  @override
  String get appBrandFinnAI => 'FinnAI';

  @override
  String get unsupportedTitle =>
      'Finn AI no puede ejecutarse en este dispositivo';

  @override
  String get unsupportedBody =>
      'Finn AI requiere al menos 3 GB de RAM y un procesador ARM de 64 bits para ejecutar modelos locales de forma fiable. No se ha descargado ningún modelo.';

  @override
  String get onboardingWelcome => '¡Bienvenido a Finn AI!';

  @override
  String get onboardingSwipeToStart => 'Desliza para empezar';

  @override
  String get onboardingPrivacyTitle => 'Finn AI antepone la privacidad';

  @override
  String get onboardingPrivacyBody =>
      'Finn AI está diseñado para respetar tu privacidad.\n\nEl procesamiento de la IA y el historial de conversaciones permanecen en este dispositivo. Cuando una solicitud necesita información actualizada, Finn AI puede enviar solo esa solicitud como consulta de búsqueda web y mostrará las fuentes utilizadas. Tu historial y tu perfil personal nunca se incluyen.\n\nFinn AI es software propietario y no es de código abierto.';

  @override
  String get onboardingPrecautionsTitle =>
      'Antes de empezar, lee las precauciones';

  @override
  String get onboardingPrecautionOne =>
      'Procesamiento de prompts de IA en el dispositivo';

  @override
  String get onboardingPrecautionTwo =>
      'Chat sin conexión tras descargar el modelo';

  @override
  String get onboardingPrecautionThree =>
      'Almacenamiento cifrado de conversaciones';

  @override
  String get onboardingPrecautionFour =>
      'Diseñado para la eficiencia energética';

  @override
  String get onboardingInstallTitleInstalling => 'Instalando LFM2.5-VL 1.6B';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B listo';

  @override
  String get onboardingInstallPreparing =>
      'Preparando LFM2.5-VL 1.6B para este dispositivo…';

  @override
  String get onboardingInstallReadyForChat =>
      'Listo para chatear en privado por texto en este dispositivo';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + componente multimodal · $size';
  }

  @override
  String get onboardingInstallModelReady => 'Modelo listo';

  @override
  String onboardingInstallProgressStatus(String status, String percent) {
    return '$status · $percent%';
  }

  @override
  String onboardingInstallBytesOf(String received, String total) {
    return '$received de $total';
  }

  @override
  String onboardingInstallBytesLeft(String remaining) {
    return 'quedan $remaining';
  }

  @override
  String get onboardingInstallRetry => 'Reintentar';

  @override
  String get onboardingInstallRetryLabel => 'Reintentar la descarga del modelo';

  @override
  String get onboardingInstallVerificationFailed =>
      'Falló la verificación del modelo';

  @override
  String get onboardingUpgradeTitle => 'Actualización de software de FinnAI';

  @override
  String get onboardingUpgradeBody =>
      'Finn AI ahora usa un modelo más reciente en el dispositivo. Descárgalo para seguir chateando en privado.';

  @override
  String get onboardingReadyTitle => '¡Finn AI está listo!';

  @override
  String get onboardingReadySubtitle => 'Todo listo. Finn AI está preparado.';

  @override
  String get onboardingYouLabel => 'Tú';

  @override
  String get chatNewChat => 'Nuevo chat';

  @override
  String get chatHistory => 'Historial de chats';

  @override
  String get chatNoHistory => 'Sin historial';

  @override
  String get chatFinnGenerating => 'Finn está generando…';

  @override
  String get chatFinnTyping => 'Finn está escribiendo…';

  @override
  String get chatAskAnything =>
      'Pregúntame lo que quieras — funciono por completo en este dispositivo, así que tus\nconversaciones nunca salen de tu teléfono.';

  @override
  String get chatTryAsking => 'Prueba a preguntar';

  @override
  String get chatMessageHint => 'Mensaje para Finn…';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatStopGeneration => 'Detener';

  @override
  String get chatCopy => 'Copiar';

  @override
  String get chatEditMessage => 'Editar mensaje';

  @override
  String get chatRenameTitle => 'Cambiar nombre del chat';

  @override
  String get chatRenameHint => 'Título del chat';

  @override
  String get chatDeleteTitle => '¿Eliminar el chat?';

  @override
  String chatDeleteBody(String title) {
    return 'Se eliminará «$title». Esto no se puede deshacer.';
  }

  @override
  String get chatContinue => 'Continuar';

  @override
  String get chatSources => 'Fuentes';

  @override
  String get chatHistoryUnavailableNotice =>
      'Finn no ha podido abrir tu historial de chat en este dispositivo, así que las nuevas respuestas no se guardarán.';

  @override
  String get chatOfflineNotice =>
      'Sin conexión: la respuesta puede ser menos precisa. Conéctate para obtener fuentes citadas.';

  @override
  String get chatFinishingTask => 'Finn AI está terminando otra tarea local.';

  @override
  String get chatAttachmentPickFailed =>
      'No se pudo abrir el selector. Inténtalo de nuevo.';

  @override
  String get chatCouldNotPrepare =>
      'No se pudo preparar el chat. Comprueba el modelo y el almacenamiento e inténtalo de nuevo.';

  @override
  String chatGeneratingIn(String title) {
    return 'Generando en $title';
  }

  @override
  String get chatDownloadModelTitle =>
      '¿Descargar el modelo de IA para chatear sin conexión?';

  @override
  String chatDownloadModelBody(String size) {
    return '$size se descarga una vez y se verifica antes de usarlo. La descarga se reanuda de forma segura tras una conexión interrumpida, y tus chats permanecen en este dispositivo.';
  }

  @override
  String get chatHiPrefix => 'Hola, soy Finn.';

  @override
  String get chatFinnAI => 'Finn AI';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAiModel => 'MODELO DE IA';

  @override
  String get settingsStorageData => 'ALMACENAMIENTO Y DATOS';

  @override
  String get settingsPrivacyLegal => 'PRIVACIDAD Y LEGAL';

  @override
  String get settingsAbout => 'ACERCA DE';

  @override
  String settingsSavedConversations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats (cifrados)',
      one: '1 chat (cifrado)',
    );
    return '$_temp0';
  }

  @override
  String get settingsReleasingMemory => 'Liberando memoria…';

  @override
  String get settingsPurgeMemory => 'Purgar la memoria de la IA';

  @override
  String get settingsPurgeMemoryTitle => '¿Purgar la memoria de la IA?';

  @override
  String get settingsPurgeMemoryBody =>
      'Esto descargará el modelo de IA de la RAM. Se volverá a cargar automáticamente con el siguiente mensaje.';

  @override
  String get settingsPurgeMemoryReleased =>
      'Memoria del modelo de IA liberada.';

  @override
  String get settingsClearHistory => 'Borrar todo el historial de chats';

  @override
  String get settingsClearHistoryTitle => '¿Borrar todas las conversaciones?';

  @override
  String get settingsClearHistoryBody =>
      'Esto eliminará permanentemente todo el historial de chats. Esta acción no se puede deshacer.';

  @override
  String get settingsClearHistorySuccess =>
      'Todas las conversaciones borradas.';

  @override
  String get settingsClearHistoryFailure =>
      'No se pudieron borrar las conversaciones. Comprueba el almacenamiento e inténtalo de nuevo.';

  @override
  String get settingsDeleteAllData => 'Eliminar todos los datos locales';

  @override
  String get settingsDeleteAllDataTitle => '¿Eliminar todos los datos locales?';

  @override
  String get settingsDeleteAllDataBody =>
      'Esto elimina definitivamente las conversaciones y claves cifradas, los modelos de IA descargados, las creaciones, las preferencias del perfil, las Skills y el estado de onboarding. FinnAI volverá a un primer inicio limpio.';

  @override
  String get settingsDeleteAllDataDeleting =>
      'Eliminando todos los datos locales…';

  @override
  String get settingsDeleteAllDataSuccess =>
      'Todos los datos locales eliminados. Volviendo a la introducción.';

  @override
  String settingsDeleteAllDataPartialFailure(String items) {
    return 'Error de eliminación parcial: no se pudo eliminar $items.';
  }

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsPrivacyPolicyUnconfigured =>
      'La URL de la política de privacidad no está configurada (define FINN_PRIVACY_POLICY_URL).';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return 'No se pudo abrir $url';
  }

  @override
  String get settingsTermsOfUse => 'Términos de uso';

  @override
  String get settingsTermsUnconfigured =>
      'La URL de los términos de uso no está configurada (define FINN_TERMS_URL).';

  @override
  String settingsTermsLaunchFailed(String url) {
    return 'No se pudo abrir $url';
  }

  @override
  String get settingsSupportContact => 'Contacto de soporte';

  @override
  String get settingsSupportUnavailable =>
      'El contacto de soporte no está disponible.';

  @override
  String settingsSupportEmailLabel(String email) {
    return 'Correo de soporte: $email';
  }

  @override
  String settingsSupportLaunchFailed(String url) {
    return 'No se pudo abrir $url';
  }

  @override
  String get settingsOpenSourceLicenses => 'Licencias de código abierto';

  @override
  String get settingsAppVersion => 'Versión de la app';

  @override
  String get settingsInferenceEngine => 'Motor de inferencia';

  @override
  String get settingsInferenceEngineValue => 'llama.cpp · GGUF';

  @override
  String get settingsPrivacyMode => 'Modo de privacidad';

  @override
  String get settingsPrivacyModeValue => 'Cifrado en el dispositivo';

  @override
  String get settingsModelArchitecture => 'Arquitectura del modelo';

  @override
  String get settingsModelArchitectureValue => 'LFM2.5-VL 1.6B (Liquid)';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsSpokenResponses => 'Respuestas habladas';

  @override
  String get settingsSpokenResponsesBody =>
      'Finn lee las respuestas en voz alta en el modo de voz. Tu transcripción de voz la procesa el reconocimiento de voz de tu dispositivo, que puede necesitar internet.';

  @override
  String get voiceMicSemantic => 'Habla con Finn';

  @override
  String get voiceListening => 'Escuchando…';

  @override
  String get voiceTapToSpeak => 'Toca el micrófono y habla';

  @override
  String get voiceHeardYou => 'Te he oído';

  @override
  String get voiceDidNotCatch => 'No te he entendido — inténtalo de nuevo';

  @override
  String get voiceThinking => 'Finn está pensando…';

  @override
  String get voiceSpeaking => 'Finn está hablando — toca para interrumpir';

  @override
  String get voiceMicDenied =>
      'El acceso al micrófono está desactivado. Actívalo en los ajustes del sistema para usar el modo de voz.';

  @override
  String get voiceUnavailable =>
      'El reconocimiento de voz no está disponible ahora mismo. Escribe tu mensaje en su lugar.';

  @override
  String get voiceStopSemantic => 'Detener';

  @override
  String get voiceCloseSemantic => 'Cerrar el modo de voz';

  @override
  String get youTitle => 'Tú';

  @override
  String get youIntroTitle => 'Haz que Finn sea tuyo';

  @override
  String get youIntroBody =>
      'Tus preferencias permanecen en este dispositivo y dan forma a las respuestas futuras.';

  @override
  String get youAboutYou => 'Sobre ti';

  @override
  String get youNameLabel => 'Nombre';

  @override
  String get youNameHint => '¿Cómo quieres que Finn te llame?';

  @override
  String get youAboutLabel => 'Sobre ti';

  @override
  String get youAboutHint =>
      'Intereses, trabajo o contexto que Finn debería recordar';

  @override
  String get youInstructionsLabel => 'Instrucciones personalizadas';

  @override
  String get youInstructionsHint =>
      '¿Cómo debería responder Finn? Tono, longitud, estilo…';

  @override
  String get youResponseStyle => 'Estilo de respuesta';

  @override
  String get youResponseStyleBalanced => 'Equilibrado';

  @override
  String get youResponseStyleConcise => 'Conciso';

  @override
  String get youResponseStyleDetailed => 'Detallado';

  @override
  String get youResponseStyleCreative => 'Creativo';

  @override
  String get youSave => 'Guardar';

  @override
  String get youSaved => 'Personalización guardada localmente.';

  @override
  String get youSaveFailed => 'No se pudieron guardar los cambios.';

  @override
  String get skillsTitle => 'Skills';

  @override
  String skillsSubtitle(int count) {
    return '$count disponibles · los Skills guían respuestas relevantes';
  }

  @override
  String get skillsNewSkill => 'Nueva skill';

  @override
  String get skillsNoSkills =>
      'Aún no hay skills personalizadas. Crea una para un flujo de trabajo que repitas.';

  @override
  String get skillsInstructionHint =>
      'Escribe una instrucción reutilizable que Finn deba aplicar cuando sea relevante.';

  @override
  String get skillsDeleteTitle => '¿Eliminar esta skill?';

  @override
  String skillsDeleteBody(String name) {
    return 'Se eliminará «$name» de este dispositivo.';
  }

  @override
  String get skillsLimitReached =>
      'Límite de skills alcanzado (4). Elimina una para añadir otra.';

  @override
  String get skillsNameLabel => 'Nombre de la skill';

  @override
  String get skillsInstructionLabel => 'Instrucción';

  @override
  String get chatBrowseTooltip => 'Buscar en la web para este mensaje';

  @override
  String get chatBrowseOnSemantic => 'Búsqueda web activada';

  @override
  String get chatBrowseOffSemantic => 'Búsqueda web desactivada';

  @override
  String get chatBrowsingTitle => 'Explorando la web';

  @override
  String get chatSearchingInline => 'Buscando en la web…';

  @override
  String get chatSearchedInline => 'Buscó en la web';

  @override
  String get chatShowSearchSteps => 'Mostrar pasos de búsqueda';

  @override
  String get chatBrowsingHide => 'Ocultar';

  @override
  String chatBrowsingSteps(int count) {
    return '$count pasos';
  }

  @override
  String chatBrowsingSearch(String query) {
    return 'Buscó en la web «$query»';
  }

  @override
  String chatBrowsingOpen(String title) {
    return 'Leyó «$title»';
  }

  @override
  String chatBrowsingFind(String query) {
    return 'Buscó «$query» en la página';
  }

  @override
  String get creationsTitle => 'Creaciones';

  @override
  String get creationsSubtitle =>
      'Describe lo que quieres. Finn lo crea en el dispositivo.';

  @override
  String get creationsWhatAreWeMaking => '¿Qué vamos a crear?';

  @override
  String get creationsOriginalBrief => 'Encargo original';

  @override
  String get creationsFinnAdapts => 'Finn adapta la estructura al formato.';

  @override
  String get creationsAskKind =>
      '¿Tu nueva creación es una app, un widget o una presentación?';

  @override
  String creationsDescribeKind(String kind) {
    return 'Dime qué debe hacer tu $kind.';
  }

  @override
  String get creationsStageDesigning => 'Diseñando…';

  @override
  String get creationsStageWriting => 'Escribiendo…';

  @override
  String get creationsStageValidating => 'Comprobando el resultado…';

  @override
  String get creationsStageRepairing => 'Corrigiendo un detalle…';

  @override
  String get creationsFallbackNote =>
      'Finn no pudo terminar el diseño, así que aquí tienes una plantilla funcional sobre la que construir.';

  @override
  String get creationsNewCreation => 'Nueva creación';

  @override
  String get creationsChooseKindSemantic => 'Elegir qué crear';

  @override
  String get creationsFailed =>
      'Finn no pudo terminar esa creación. Inténtalo de nuevo.';

  @override
  String get creationsHomeScreenUnsupported =>
      'Los widgets de pantalla de inicio no están disponibles en este dispositivo.';

  @override
  String get creationsHomeScreenAdded => 'Añadido a tu pantalla de inicio.';

  @override
  String get creationsHomeScreenFailed =>
      'No se pudo añadir a tu pantalla de inicio.';

  @override
  String creationsExportedTo(String fileName) {
    return '$fileName guardado';
  }

  @override
  String get creationsExportDeck => 'Exportar como PowerPoint';

  @override
  String get creationsAddToHomeScreen => 'Añadir a la pantalla de inicio';

  @override
  String get creationsWidgetPreview => 'Así se verá en tu pantalla de inicio.';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Presentación';

  @override
  String get creationsFilterApps => 'Apps';

  @override
  String get creationsFilterWidgets => 'Widgets';

  @override
  String get creationsFilterPresentations => 'Presentaciones';

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
  String get creationsExportedShared => 'Presentación lista para compartir.';

  @override
  String get creationsExportFailed => 'No se pudo exportar esa presentación.';

  @override
  String get creationsResetApp => 'Restablecer';

  @override
  String get creationsPreviousSlide => 'Diapositiva anterior';

  @override
  String get creationsNextSlide => 'Diapositiva siguiente';

  @override
  String creationsSlideOf(int index, int count) {
    return 'Diapositiva $index de $count';
  }

  @override
  String creationsElementCount(int count) {
    return '$count elementos';
  }

  @override
  String creationsRowCount(int count) {
    return '$count filas';
  }

  @override
  String creationsSlideCount(int count) {
    return '$count diapositivas';
  }

  @override
  String get creationsStopTitle => '¿Detener esta creación?';

  @override
  String get creationsStopBody =>
      'Se descartará el resultado inacabado. Tu prompt permanecerá aquí.';

  @override
  String get creationsDeleteTitle => '¿Eliminar esta creación?';

  @override
  String creationsDeleteBody(String title) {
    return 'Se eliminará «$title» de este dispositivo.';
  }

  @override
  String get creationsOpening => 'Abriendo creaciones';

  @override
  String get creationsGenerating => 'Generando…';

  @override
  String get reportTitle => 'Informar sobre la respuesta de la IA';

  @override
  String get reportSubtitle =>
      'Ayúdanos a mantener respuestas de IA seguras y precisas. Los informes se revisan para mejorar las protecciones de FinnAI.';

  @override
  String get reportReasonLabel => 'Motivo del informe';

  @override
  String get reportIncludePrompt => 'Incluir mi prompt en este informe';

  @override
  String get reportResponsePreview => 'Vista previa de la respuesta informada';

  @override
  String get reportContinueHint =>
      'Continuar abre un informe completo dirigido a finn_org@proton.me. No se enviará nada hasta que lo revises y lo envíes desde tu app de correo.';

  @override
  String get reportContinueToEmail => 'Continuar al correo';

  @override
  String get reportReviewInEmail =>
      'Revisa el informe en tu app de correo y envíalo.';

  @override
  String get reportNotConfigured =>
      'La dirección de correo para informes no está configurada.';

  @override
  String get reportCategoryHarmful => 'Nocivo o inseguro';

  @override
  String get reportCategoryIncorrect => 'Incorrecto o engañoso';

  @override
  String get reportCategoryBiased => 'Sesgado o injusto';

  @override
  String get reportCategoryOther => 'Otro';

  @override
  String get snackModelMemoryReleased => 'Memoria del modelo de IA liberada.';

  @override
  String get settingsSavedConversationsLabel => 'Conversaciones guardadas';

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

  @override
  String get deviceActionsTitle => 'Acciones';

  @override
  String get deviceActionsIntro =>
      'Pide a Finn que haga algo en tu teléfono: poner una alarma, iniciar un temporizador o abrir un ajuste.';

  @override
  String get deviceActionsExamples => 'Prueba una de estas';

  @override
  String get deviceActionsHint => '¿Qué quieres que haga Finn?';

  @override
  String get deviceActionsRun => 'Continuar';

  @override
  String get deviceActionsResolving => 'Pensando qué hacer…';

  @override
  String get deviceActionsUnresolved =>
      'No he podido convertir eso en una acción. Nombra el ajuste o la app directamente.';

  @override
  String get deviceActionsConfirm => 'Hacerlo';

  @override
  String get deviceActionsCancel => 'Cancelar';

  @override
  String get deviceActionsAgain => 'Hacer otra cosa';

  @override
  String get deviceActionsOpenNotice =>
      'Android no permite que las apps cambien los ajustes de red por sí solas: Finn abre la pantalla y tú cambias el interruptor.';

  @override
  String deviceActionsResultOpened(String detail) {
    return '$detail abierto';
  }

  @override
  String deviceActionsResultPerformed(String detail) {
    return 'Hecho — $detail';
  }

  @override
  String get deviceActionsResultUnavailable =>
      'Tu dispositivo no puede hacer eso';

  @override
  String get deviceActionsResultFailed => 'No ha funcionado';

  @override
  String deviceActionsResultFailedDetail(String error) {
    return 'No ha funcionado — $error';
  }

  @override
  String get deviceActionsExampleAlarm => 'Poner una alarma a las 7';

  @override
  String get deviceActionsExampleTimer =>
      'Iniciar un temporizador de 10 minutos';

  @override
  String get deviceActionsExampleWifi => 'Abrir los ajustes de Wi-Fi';

  @override
  String get deviceActionsExampleFlashlight => 'Encender la linterna';

  @override
  String get deviceActionsExampleBluetooth => 'Abrir los ajustes de Bluetooth';

  @override
  String deviceActionSetAlarm(String time) {
    return 'Poner una alarma a las $time';
  }

  @override
  String deviceActionSetTimer(String duration) {
    return 'Iniciar un temporizador de $duration';
  }

  @override
  String get deviceActionShowAlarms => 'Abrir el reloj despertador';

  @override
  String get deviceActionTorchOn => 'Encender la linterna';

  @override
  String get deviceActionTorchOff => 'Apagar la linterna';

  @override
  String deviceActionMedia(String action) {
    return 'Reproductor: $action';
  }

  @override
  String deviceActionVolume(String direction) {
    return 'Volumen $direction';
  }

  @override
  String deviceActionOpenSettings(String screen) {
    return 'Abrir los ajustes de $screen';
  }

  @override
  String deviceActionOpenApp(String name) {
    return 'Abrir $name';
  }

  @override
  String deviceActionDial(String number) {
    return 'Abrir el marcador con $number';
  }

  @override
  String get deviceActionComposeSms => 'Escribir un mensaje nuevo';

  @override
  String get deviceActionComposeEmail => 'Escribir un correo nuevo';

  @override
  String get deviceActionTakePhoto => 'Abrir la cámara';

  @override
  String deviceActionOpenUrl(String url) {
    return 'Abrir $url';
  }

  @override
  String deviceActionNavigate(String query) {
    return 'Cómo llegar a $query';
  }

  @override
  String get deviceActionShare => 'Compartir texto con otra app';

  @override
  String get deviceActionMediaPlay => 'reproducir';

  @override
  String get deviceActionMediaPause => 'pausar';

  @override
  String get deviceActionMediaNext => 'siguiente pista';

  @override
  String get deviceActionMediaPrevious => 'pista anterior';

  @override
  String get deviceActionVolumeUp => 'subir';

  @override
  String get deviceActionVolumeDown => 'bajar';

  @override
  String get deviceActionVolumeMute => 'silenciar';

  @override
  String get deviceScreenWifi => 'Wi-Fi';

  @override
  String get deviceScreenBluetooth => 'Bluetooth';

  @override
  String get deviceScreenAirplane => 'Modo avión';

  @override
  String get deviceScreenHotspot => 'Punto de acceso';

  @override
  String get deviceScreenMobileData => 'Datos móviles';

  @override
  String get deviceScreenBatterySaver => 'Ahorro de batería';

  @override
  String get deviceScreenBatteryUsage => 'Consumo de batería';

  @override
  String get deviceScreenDnd => 'No molestar';

  @override
  String get deviceScreenDisplay => 'Pantalla';

  @override
  String get deviceScreenSound => 'Sonido';

  @override
  String get deviceScreenLocation => 'Ubicación';

  @override
  String get deviceScreenStorage => 'Almacenamiento';

  @override
  String get deviceScreenDateTime => 'Fecha y hora';

  @override
  String get deviceScreenKeyboard => 'Teclado';

  @override
  String get deviceScreenLanguage => 'Idioma';

  @override
  String get deviceScreenAccessibility => 'Accesibilidad';

  @override
  String get deviceScreenApplications => 'Aplicaciones';

  @override
  String get deviceScreenNfc => 'NFC';

  @override
  String get deviceScreenCast => 'Transmitir';

  @override
  String get deviceScreenVpn => 'VPN';

  @override
  String get deviceScreenDeveloper => 'Opciones de desarrollador';

  @override
  String get deviceScreenHome => 'Pantalla de inicio';

  @override
  String get deviceActionsResultDone => 'Hecho';

  @override
  String get settingsActionsSection => 'Acciones en tu dispositivo';

  @override
  String get settingsActionsRow => 'Acciones';

  @override
  String get deviceScreenSystem => 'Ajustes';

  @override
  String get deviceActionsDismissed => 'Cancelado';

  @override
  String get creationsStopped => 'Detenido.';

  @override
  String get creationsLoadFailed =>
      'Finn no ha podido abrir tus creaciones guardadas. Inténtalo de nuevo.';

  @override
  String get creationsDeleteFailed =>
      'No se ha podido eliminar esa creación. Inténtalo de nuevo.';
}
