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
  String get commonYes => 'Sí';

  @override
  String get commonNo => 'No';

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
  String get commonSaveFlow => 'Guardar habilidad';

  @override
  String get commonKeepCreating => 'Seguir creando';

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get commonPurge => 'Liberar';

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
  String get onboardingWelcome => 'Te damos la bienvenida a FinnAI';

  @override
  String get onboardingSwipeToStart => 'Desliza para empezar';

  @override
  String get onboardingPrivacyTitle => 'FinnAI protege tu privacidad';

  @override
  String get onboardingPrivacyLead => 'FinnAI cuida tu privacidad ante todo.';

  @override
  String get onboardingPrivacyBody =>
      'No rastreamos ni almacenamos tus datos; cada solicitud se procesa localmente en tu dispositivo. ';

  @override
  String get onboardingPrivacyLink =>
      'Más información en nuestra Política de privacidad.';

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
  String get onboardingInstallTitleInstalling =>
      'Descargando FinnAI Foundation';

  @override
  String get onboardingInstallTitleReady => 'FinnAI Foundation lista';

  @override
  String get onboardingDownloadLead => 'Configurando FinnAI,';

  @override
  String get onboardingDownloadNote => 'el primer inicio tarda unos minutos.';

  @override
  String onboardingProgressPercent(Object percent) {
    return '$percent% completado.';
  }

  @override
  String get onboardingProgressEtaTail => 'restantes.';

  @override
  String onboardingProgressEtaAbout(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    return 'Quedan unos $_temp0.';
  }

  @override
  String get onboardingInstallPreparing =>
      'Preparando LFM2.5-VL 1.6B para este dispositivo…';

  @override
  String get onboardingInstallReadyForChat =>
      'Listo para chatear en privado por texto en este dispositivo';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + soporte de imágenes · $size';
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
  String get onboardingReadyTitle => '¡FinnAI está listo!';

  @override
  String get onboardingReadyLead => '¡FinnAI está listo para usarse!';

  @override
  String get onboardingReadyBody =>
      'Ya puedes usar FinnAI, tanto en línea como sin conexión.\nEsperamos que lo disfrutes.';

  @override
  String get onboardingReadySubtitle => 'Todo listo. Finn AI está preparado.';

  @override
  String get onboardingConsentTitle =>
      '¿Permites que FinnAI use el contexto de tu dispositivo?';

  @override
  String get onboardingConsentBody =>
      'Esto permite que FinnAI lea cosas como tu calendario, tus notas y tus fotos para que sus respuestas te encajen mejor. Solo lee en este dispositivo y no se envía nada a ningún sitio.';

  @override
  String get onboardingConsentRequiredHint => 'Elige Sí o No para continuar';

  @override
  String get onboardingStartUsing => 'Empezar a usar FinnAI';

  @override
  String get onboardingYouLabel => 'Tú';

  @override
  String get chatNewChat => 'Nuevo chat';

  @override
  String get chatHistory => 'Chats';

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
  String get chatEmptyReply =>
      'Finn no encontró una respuesta esta vez. Toca «Reintentar» para volver a preguntar.';

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
  String get settingsContextTitle => 'Contexto en el dispositivo';

  @override
  String get settingsContextSubtitle =>
      'Permite que FinnAI use el contexto de este dispositivo';

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
  String get settingsPurgeMemorySubtitle =>
      'Libera RAM. El modelo se recarga con tu próximo mensaje.';

  @override
  String get settingsClearHistorySubtitle =>
      'Elimina todos los chats guardados. No se puede deshacer.';

  @override
  String get settingsDeleteAllDataSubtitle =>
      'Conversaciones, modelos, creaciones y preferencias: como en el primer inicio.';

  @override
  String get settingsPurgeMemory => 'Liberar memoria';

  @override
  String get settingsPurgeMemoryTitle => '¿Liberar memoria?';

  @override
  String get settingsPurgeMemoryBody =>
      'Esto cierra el modelo de IA para liberar memoria. Volverá a abrirse con tu próximo mensaje.';

  @override
  String get settingsPurgeMemoryReleased => 'Memoria liberada.';

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
      'Esto elimina definitivamente las conversaciones y claves cifradas, los modelos de IA descargados, las creaciones, las preferencias del perfil, las Flows y el estado de onboarding. FinnAI volverá a un primer inicio limpio.';

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
      'El enlace a la política de privacidad no está disponible en esta versión.';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return 'No se pudo abrir $url';
  }

  @override
  String get settingsTermsOfUse => 'Términos de uso';

  @override
  String get settingsTermsUnconfigured =>
      'El enlace a los términos de uso no está disponible en esta versión.';

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
  String get settingsInferenceEngine => 'Cómo funciona Finn';

  @override
  String get settingsInferenceEngineValue => 'Enteramente en este teléfono';

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
      'Finn lee las respuestas en voz alta en el modo de voz. Lo que dices se convierte en texto en este dispositivo y nunca sale de él.';

  @override
  String get voiceMicSemantic => 'Habla con Finn';

  @override
  String get voiceCancelSemantic => 'Cancelar la entrada de voz';

  @override
  String get voiceExpandSemantic => 'Abrir el modo de voz completo';

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
  String voiceModelNeeded(String size) {
    return 'El modo de voz necesita una descarga única de $size. Tu voz se convierte en texto en este dispositivo y nunca sale de él.';
  }

  @override
  String get voiceModelDownload => 'Descargar';

  @override
  String voiceModelDownloading(int percent) {
    return 'Descargando el modelo de voz… $percent %';
  }

  @override
  String get voiceModelFailed =>
      'La descarga no terminó. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get voiceModelRetry => 'Reintentar';

  @override
  String get voiceSpeakingLive => 'Hablando…';

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
  String get flowsTitle => 'Flows';

  @override
  String flowsSubtitle(int count) {
    return '$count disponibles · los Flows guían respuestas relevantes';
  }

  @override
  String get flowsDeleteTitle => '¿Eliminar esta flow?';

  @override
  String flowsDeleteBody(String name) {
    return 'Se eliminará «$name» de este dispositivo.';
  }

  @override
  String get flowsNameLabel => 'Nombre de la flow';

  @override
  String get flowsRunAction => 'Ejecutar ahora';

  @override
  String get flowsRunRunning => 'En curso…';

  @override
  String get flowsGrantLabel => 'Dejar que se ejecute solo';

  @override
  String get flowsGrantExplain =>
      'Un flow que cambia tu teléfono necesita esto para ejecutarse sin ti. Puedes desactivarlo cuando quieras.';

  @override
  String get flowsNeedsGrant => 'Necesita tu permiso para ejecutarse solo';

  @override
  String get flowsHistoryTitle => 'Ejecuciones recientes';

  @override
  String get flowsHistoryEmpty => 'Este flow aún no se ha ejecutado.';

  @override
  String get flowsRunCompleted => 'Terminado';

  @override
  String get flowsRunDeclined => 'Has rechazado';

  @override
  String get flowsRunFailed => 'Se detuvo antes de tiempo';

  @override
  String get flowsRunInterrupted => 'Cancelado';

  @override
  String get flowsRunBySchedule => 'Se ejecutó solo';

  @override
  String get flowsAutomationsTitle => 'Automatizaciones';

  @override
  String get flowsAutomationsSubtitle =>
      'Cosas que Finn hace por ti con un horario. Nada se ejecuta si no lo activas.';

  @override
  String get flowsNewAutomation => 'Nueva automatización';

  @override
  String get flowsNoAutomations =>
      'Aún no hay automatizaciones. Empieza con un resumen matutino.';

  @override
  String get flowsTemplateMorningBrief => 'Resumen matutino';

  @override
  String get flowsTemplateMorningBriefBody =>
      'Las noticias que te importan y el tiempo, en pocas líneas.';

  @override
  String get flowsTemplateWebCheck => 'Revisión web';

  @override
  String get flowsTemplateWebCheckBody =>
      'Revisa un tema y te dice qué hay de nuevo.';

  @override
  String get flowsTemplateReminder => 'Recordatorio';

  @override
  String get flowsTemplateReminderBody =>
      'Una notificación con tus propias palabras.';

  @override
  String get flowsSlotTopics => 'Qué seguir';

  @override
  String get flowsSlotCity => 'Ciudad para el tiempo (opcional)';

  @override
  String get flowsSlotTopic => 'Tema';

  @override
  String get flowsSlotMessage => 'Mensaje';

  @override
  String get flowsScheduleHeading => 'Cuándo';

  @override
  String flowsScheduleWeekdaysAt(String time) {
    return 'Días laborables a las $time';
  }

  @override
  String get flowsScheduleEveryDay => 'Todos los días';

  @override
  String get flowsScheduleWeekdaysOnly => 'Días laborables';

  @override
  String get flowsScheduleTime => 'Hora';

  @override
  String get flowsNotifyWhyTitle => '¿Permitir notificaciones?';

  @override
  String get flowsNotifyWhyBody =>
      'Finn envía una notificación cuando toca esta automatización. Sin ella, solo se ejecuta cuando tocas Ejecutar.';

  @override
  String get flowsNotifyAllow => 'Permitir';

  @override
  String get flowsNotifyOff =>
      'Las notificaciones están desactivadas, así que no se ejecutará sola.';

  @override
  String flowsRunning(String name) {
    return 'Ejecutando $name…';
  }

  @override
  String flowsRunReady(String name) {
    return '$name está listo';
  }

  @override
  String flowsRunCouldNotFinish(String name) {
    return '$name no pudo terminar';
  }

  @override
  String get flowsOpenResult => 'Abrir resultado';

  @override
  String flowsNextRun(String when) {
    return 'Próxima: $when';
  }

  @override
  String get flowsRunByYou => 'Lo ejecutaste tú';

  @override
  String get flowsStepsLabel => 'Pasos';

  @override
  String flowsStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pasos',
      one: '1 paso',
    );
    return '$_temp0';
  }

  @override
  String get flowsStepPrompt => 'Preguntar';

  @override
  String get flowsStepDeviceAction => 'Actuar en el teléfono';

  @override
  String get flowsStepNotify => 'Nota';

  @override
  String get flowsStepBrowse => 'Buscar';

  @override
  String get flowsScheduleLabel => 'Se ejecuta';

  @override
  String get flowsScheduleManual => 'Solo cuando tú lo ejecutas';

  @override
  String flowsScheduleDaily(String time) {
    return 'Todos los días a las $time';
  }

  @override
  String flowsScheduleWeekly(String days, String time) {
    return '$days a las $time';
  }

  @override
  String get flowsScheduleAdd => 'Añadir una hora';

  @override
  String get flowsScheduleRemove => 'Ejecutar solo cuando yo lo pida';

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
  String get creationsNoneTitle => 'Aún no hay creaciones.';

  @override
  String get creationsNoneBody =>
      'Tu creatividad vive aquí.\nPrueba a crear algo con FinnAI Creations.';

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
  String get creationsTemplateAuto => 'Que Finn elija';

  @override
  String get creationsTemplateQuestion =>
      '¿Quieres un punto de partida? Elige uno o describe lo que quieres.';

  @override
  String get creationsTemplateCounter => 'Contador';

  @override
  String get creationsTemplateChecklist => 'Lista de tareas';

  @override
  String get creationsTemplateList => 'Lista';

  @override
  String get creationsTemplateScoreboard => 'Marcador';

  @override
  String get creationsTemplateStat => 'Número grande';

  @override
  String get creationsTemplateRows => 'Líneas';

  @override
  String get creationsEdit => 'Editar';

  @override
  String get creationsEditTitle => 'Editar detalles';

  @override
  String get creationsSlotTitle => 'Nombre';

  @override
  String get creationsSlotUnit => 'Qué cuentas';

  @override
  String get creationsSlotGoal => 'Objetivo';

  @override
  String get creationsSlotEmoji => 'Emoji';

  @override
  String get creationsSlotAccent => 'Color';

  @override
  String get creationsSlotItems => 'Elementos';

  @override
  String get creationsSlotHint => 'Sugerencia de entrada';

  @override
  String get creationsSlotEmpty => 'Mensaje vacío';

  @override
  String get creationsSlotNameA => 'Primer nombre';

  @override
  String get creationsSlotNameB => 'Segundo nombre';

  @override
  String get creationsSlotLabel => 'Etiqueta';

  @override
  String get creationsSlotValue => 'Valor';

  @override
  String get creationsSlotFooter => 'Pie';

  @override
  String get creationsSlotRows => 'Líneas';

  @override
  String get creationsSlotOnePerLine => 'Uno por línea';

  @override
  String get creationsSlotRowFormat => 'Una por línea, como «Agua: 3»';

  @override
  String get creationsAccentMint => 'Menta';

  @override
  String get creationsAccentBlue => 'Azul';

  @override
  String get creationsAccentLime => 'Lima';

  @override
  String get creationsAccentAmber => 'Ámbar';

  @override
  String get creationsAccentRose => 'Rosa';

  @override
  String get creationsAccentViolet => 'Violeta';

  @override
  String get creationsAccentSky => 'Cielo';

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
  String get flowsSaveFailed => 'No se pudo guardar esa Flow.';

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
  String get snackModelMemoryReleased => 'Memoria liberada.';

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
      'El análisis de imágenes aún no está configurado. Añade el soporte de imágenes en Ajustes.';

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
  String get chatMoreActions => 'Más acciones';

  @override
  String get chatHideSources => 'Ocultar fuentes';

  @override
  String get chatShowSources => 'Mostrar fuentes';

  @override
  String get chatRewriteHint => 'Reescribe tu mensaje';

  @override
  String get chatAskAnythingHint => 'Pregunta algo';

  @override
  String get chatGreeting => 'Hola, ¿en qué estás pensando?';

  @override
  String get voiceGreeting => '¿Qué tal?';

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
  String get flowsActionsTooltip => 'Acciones de la Flow';

  @override
  String flowsNameSemantic(String name) {
    return 'Flow $name';
  }

  @override
  String get flowsEditorNameHint => '¿Qué hace esta Flow?';

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

  @override
  String get hubModelTitle => 'FinnAI Foundation';

  @override
  String hubModelSub(String size) {
    return 'En este dispositivo, $size';
  }

  @override
  String get hubVoiceTitle => 'Voz e idioma';

  @override
  String hubVoiceSub(String speed, String language) {
    return 'Velocidad $speed, $language';
  }

  @override
  String get hubAccessTitle => 'Acceso al dispositivo';

  @override
  String get hubAccessSub => 'Calendario, contactos, archivos';

  @override
  String get hubYouTitle => 'Tú';

  @override
  String get hubYouSub => 'Lo que FinnAI aprende y usa';

  @override
  String get hubDataTitle => 'Privacidad y datos';

  @override
  String get hubDataSub => 'Almacenamiento, exportar, borrar';

  @override
  String get hubAboutTitle => 'Acerca de';

  @override
  String hubAboutSub(String version) {
    return 'Versión $version';
  }

  @override
  String modelVersion(String version) {
    return 'Versión $version';
  }

  @override
  String modelStored(String size, String date) {
    return '$size de tu almacenamiento, descargado el $date.';
  }

  @override
  String modelStoredNoDate(String size) {
    return '$size de tu almacenamiento.';
  }

  @override
  String get modelNotInstalled => 'Aún no descargado.';

  @override
  String get modelOffline => 'Trabajar sin conexión';

  @override
  String get modelOfflineSub => 'Todo se ejecuta en este dispositivo';

  @override
  String get modelLookups => 'Buscar en línea';

  @override
  String get modelLookupsSub =>
      'Solo cuando una pregunta lo necesita. Tus chats y Tú se quedan aquí.';

  @override
  String get modelUpdates => 'Buscar actualizaciones';

  @override
  String get modelUpToDate => 'Al día';

  @override
  String get modelRemove => 'Quitar el modelo';

  @override
  String modelRemoveSub(String size) {
    return 'Libera $size';
  }

  @override
  String get modelRemoveTitle => '¿Quitar el modelo?';

  @override
  String get modelRemoveBody =>
      'FinnAI tendrá que descargarlo de nuevo para que puedas chatear. Tus chats se quedan.';

  @override
  String get modelRemoveConfirm => 'Quitar';

  @override
  String get voiceReadAloud => 'Leer las respuestas en voz alta';

  @override
  String get voiceReadAloudSub => 'En chats de voz';

  @override
  String get voiceTranscript => 'Mostrar transcripción en vivo';

  @override
  String get voiceTranscriptSub => 'Mientras hablas';

  @override
  String get voiceSpeed => 'Velocidad de habla';

  @override
  String get voiceSpeedSlow => 'Lenta';

  @override
  String get voiceSpeedNormal => 'Normal';

  @override
  String get voiceSpeedFast => 'Rápida';

  @override
  String get voiceLanguage => 'Idioma';

  @override
  String get voiceLanguageSub => 'Sigue a tu teléfono';

  @override
  String get accessIntro =>
      'FinnAI solo lee lo que permites, y solo en este dispositivo.';

  @override
  String get accessMaster => 'Usar contexto de este dispositivo';

  @override
  String get accessMasterSub => 'Desactívalo para que FinnAI no lea nada';

  @override
  String get accessActions => 'Acciones en tu dispositivo';

  @override
  String get accessActionsSub => 'Alarmas, temporizadores, ajustes';

  @override
  String get ctxCalendar => 'Calendario';

  @override
  String get ctxCalendarSub => 'Eventos y tiempo libre';

  @override
  String get ctxContacts => 'Contactos';

  @override
  String get ctxContactsSub => 'Nombres y relaciones';

  @override
  String get ctxNotifications => 'Notificaciones';

  @override
  String get ctxNotificationsSub => 'Lo que necesita tu atención';

  @override
  String get ctxPhotos => 'Fotos';

  @override
  String get ctxPhotosSub => 'Solo cuando las adjuntas';

  @override
  String get ctxFiles => 'Archivos';

  @override
  String get ctxFilesSub => 'Documentos que abres con FinnAI';

  @override
  String get ctxLocation => 'Ubicación';

  @override
  String get ctxLocationSub => 'Solo mientras la app está abierta';

  @override
  String get dataStoredHere => 'Guardado en este dispositivo';

  @override
  String get dataChats => 'Chats';

  @override
  String get dataCreations => 'Creaciones';

  @override
  String get dataYou => 'Tú';

  @override
  String get dataModel => 'FinnAI Foundation';

  @override
  String get dataExport => 'Exportar todo';

  @override
  String get dataExportSub => 'Chats, creaciones, flujos y Tú';

  @override
  String get dataDeleteChats => 'Borrar todos los chats';

  @override
  String get dataDeleteChatsSub => 'Tú se queda como está';

  @override
  String get dataErase => 'Borrar todo';

  @override
  String get dataEraseSub => 'Restablece FinnAI en este dispositivo';

  @override
  String get dataExportFailed => 'No se pudo exportar. Inténtalo de nuevo.';

  @override
  String get aboutBlurb =>
      'Un asistente privado que funciona en tu dispositivo.';

  @override
  String get aboutPrivacy => 'Política de privacidad';

  @override
  String get aboutTerms => 'Términos de uso';

  @override
  String get aboutLicences => 'Licencias de código abierto';

  @override
  String get aboutFeedback => 'Enviar comentarios';

  @override
  String chatUsedFromYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas',
      one: '1 cosa',
    );
    return 'Usó $_temp0 de Tú';
  }

  @override
  String get youAboutTitle => 'Lo que FinnAI sabe de ti';

  @override
  String youUpdated(String when) {
    return 'Actualizado $when';
  }

  @override
  String youReviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novedades por revisar',
      one: '1 novedad por revisar',
    );
    return '$_temp0';
  }

  @override
  String get youReviewSub => 'Notado en tus chats recientes';

  @override
  String youCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas',
      one: '1 cosa',
    );
    return '$_temp0';
  }

  @override
  String get youStoredOnly => 'Guardado solo en este dispositivo';

  @override
  String get youCatPeople => 'Personas';

  @override
  String get youCatWork => 'Trabajo';

  @override
  String get youCatRoutines => 'Rutinas';

  @override
  String get youCatPreferences => 'Preferencias';

  @override
  String get youCatPlaces => 'Lugares';

  @override
  String get youCatInterests => 'Intereses';

  @override
  String get youEmptyTitle => 'Aún te estoy conociendo';

  @override
  String get youEmptyBody =>
      'Mientras chateas, FinnAI aprende lo que ayuda y lo guarda aquí, en este dispositivo. También puedes escribir algo tú mismo.';

  @override
  String get youTellFinn => 'Cuéntale a FinnAI sobre ti';

  @override
  String get youPrivacyTitle => 'Privacidad';

  @override
  String youCategoryIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cosas que FinnAI recuerda. Toca una para ver de dónde viene.',
      one: '1 cosa que FinnAI recuerda. Toca para ver de dónde viene.',
    );
    return '$_temp0';
  }

  @override
  String get youCategoryEmpty => 'Aún no hay nada. Toca más para añadir algo.';

  @override
  String youSeenIn(String where) {
    return 'Visto en $where';
  }

  @override
  String get youSeenInLabel => 'Visto en';

  @override
  String get youAddedByYou => 'Añadido por ti';

  @override
  String youLearnedOn(String when) {
    return 'Aprendido $when. Guardado en este dispositivo.';
  }

  @override
  String get youEdit => 'Editar';

  @override
  String get youDoNotUse => 'No usar en chats';

  @override
  String get youForgetThis => 'Olvidar esto';

  @override
  String get youForgetTitle => '¿Olvidar esto?';

  @override
  String get youForgetBody =>
      'FinnAI deja de usarlo en los chats. Si lo mencionas otra vez, puede volver a aprenderlo.';

  @override
  String get youForgetConfirm => 'Olvidar';

  @override
  String get youAddLabel => 'Con tus propias palabras';

  @override
  String get youAddHint =>
      'Algo que FinnAI deba recordar, como cómo te gusta trabajar o quién te importa.';

  @override
  String get youWhereBelongs => 'Dónde va';

  @override
  String get youUseEveryChat => 'Usar en cada chat';

  @override
  String get youUseEveryChatSub =>
      'Desactívalo para usarlo solo cuando lo pidas';

  @override
  String get youSaveToYou => 'Guardar en Tú';

  @override
  String get youReviewTitleBar => 'Revisar';

  @override
  String get youReviewIntro =>
      'FinnAI notó esto en chats recientes. Conserva lo correcto y olvida el resto.';

  @override
  String get youReviewEmpty => 'Nada que revisar ahora.';

  @override
  String get youKeep => 'Conservar';

  @override
  String youFrom(String category, String chat) {
    return '$category, de $chat';
  }

  @override
  String get youPrivacyNote =>
      'Todo en Tú se guarda en este dispositivo. FinnAI nunca lo envía a ninguna parte.';

  @override
  String get youLearn => 'Aprender de las conversaciones';

  @override
  String get youLearnSub => 'FinnAI sugiere qué añadir después de chatear';

  @override
  String get youUseInChats => 'Usar Tú en chats nuevos';

  @override
  String get youUseInChatsSub => 'Puedes desactivarlo por chat';

  @override
  String get youLearnAbout => 'Aprender sobre';

  @override
  String get youExport => 'Exportar Tú';

  @override
  String get youExportSub => 'Guardar una copia como archivo';

  @override
  String get youErase => 'Borrar todo en Tú';

  @override
  String youEraseSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas',
      one: '1 cosa',
    );
    return 'Quita $_temp0';
  }

  @override
  String get youEraseTitle => '¿Borrar todo en Tú?';

  @override
  String get youEraseBody =>
      'Todo lo que FinnAI recuerda se elimina de este dispositivo. Tus chats se quedan.';

  @override
  String get youEraseConfirm => 'Borrar';

  @override
  String get youPersonalise => 'Estilo e instrucciones de respuesta';

  @override
  String get youPersonaliseSub => 'Nombre, tono e instrucciones propias';

  @override
  String get youRemembered => 'Guardado en Tú';

  @override
  String get youWhenToday => 'hoy';

  @override
  String youWhenMinutes(int count) {
    return 'hace $count minutos';
  }

  @override
  String youWhenHours(int count) {
    return 'hace $count horas';
  }

  @override
  String youWhenDays(int count) {
    return 'hace $count días';
  }

  @override
  String get youWhenJustNow => 'ahora mismo';

  @override
  String get searchHint => 'Buscar';

  @override
  String get searchChatsHeading => 'Chats';

  @override
  String get searchCreationsHeading => 'Creaciones';

  @override
  String get searchNothing => 'No se encontró nada';

  @override
  String get searchPrompt => 'Busca en tus chats, creaciones y Tú.';

  @override
  String get chatReadAloud => 'Leer en voz alta';

  @override
  String get chatRememberInYou => 'Recordar en Tú';

  @override
  String get chatShare => 'Compartir';

  @override
  String get plusCreate => 'Crear';

  @override
  String get plusWidget => 'Widget';

  @override
  String get plusWidgetSub => 'Para tu pantalla de inicio';

  @override
  String get plusMiniApp => 'Mini app';

  @override
  String get plusMiniAppSub => 'Una herramienta pequeña';

  @override
  String get plusPresentation => 'Presentación';

  @override
  String get plusPresentationSub => 'Diapositivas para compartir';

  @override
  String get plusFlow => 'Flujo';

  @override
  String get plusFlowSub => 'Se ejecuta solo';

  @override
  String get plusAddToChat => 'Añadir al chat';

  @override
  String get plusPhoto => 'Foto';

  @override
  String optionsStarted(String when) {
    return 'Iniciado $when. Guardado en este dispositivo.';
  }

  @override
  String get optionsPin => 'Fijar chat';

  @override
  String get optionsUnpin => 'Desfijar chat';

  @override
  String get optionsExport => 'Exportar como texto';

  @override
  String get optionsDelete => 'Borrar chat';

  @override
  String get deleteChatTitle => '¿Borrar este chat?';

  @override
  String get deleteChatBody =>
      'Se elimina de este dispositivo. Lo que FinnAI aprendió de él se queda en Tú hasta que lo olvides.';

  @override
  String get fromYouTitle => 'De Tú';

  @override
  String get fromYouSub =>
      'FinnAI usó esto en este chat. Nada sale de tu dispositivo.';

  @override
  String get fromYouUse => 'Usar Tú en este chat';

  @override
  String get fromYouOpen => 'Abrir Tú';

  @override
  String get chatRenamePrompt => 'Renombrar chat';

  @override
  String get flowsFilterAll => 'Todos';

  @override
  String get flowsFilterActive => 'Activos';

  @override
  String get flowsFilterPaused => 'En pausa';

  @override
  String get flowsPhoneOn =>
      'Los flujos se ejecutan en este dispositivo, así que tu teléfono debe estar encendido.';

  @override
  String get flowsOnlyWhenAsked => 'Solo cuando lo pido';

  @override
  String flowsLastRunLine(String when, String result) {
    return 'Última ejecución $when, $result';
  }

  @override
  String get flowsNeverRun => 'Aún sin ejecutar';

  @override
  String get flowsPausedLine => 'En pausa';

  @override
  String get flowsResultDone => 'hecho';

  @override
  String get flowsResultFailed => 'falló';

  @override
  String get flowsResultStopped => 'detenido';

  @override
  String get flowsWhenToday => 'hoy';

  @override
  String get flowsWhenYesterday => 'ayer';

  @override
  String get flowsEmptyTitle => 'Aún no hay flujos';

  @override
  String get flowsEmptyBody =>
      'Un flujo hace una tarea por ti según un horario o cuando algo ocurre. Descríbelo en el chat.';

  @override
  String get flowsEmptyCreate => 'Crear un flujo';

  @override
  String get flowsNewTitle => 'Nuevo flujo';

  @override
  String get flowsNewSub => 'Empieza con palabras, una hora o un evento.';

  @override
  String get flowsNewDescribe => 'Descríbelo';

  @override
  String get flowsNewDescribeSub => 'Dile a FinnAI qué debe pasar';

  @override
  String get flowsNewTime => 'A una hora fija';

  @override
  String get flowsNewTimeSub => 'Cada día, semana o mes';

  @override
  String get flowsNewEvent => 'Cuando algo ocurre';

  @override
  String get flowsNewEventSub => 'Cargar, llegar, una notificación';

  @override
  String flowsDetailOn(String when) {
    return 'Activo, próxima ejecución $when';
  }

  @override
  String get flowsDetailOnManual => 'Activo, se ejecuta cuando lo pides';

  @override
  String get flowsDetailPaused => 'En pausa';

  @override
  String get flowsWhen => 'Cuándo';

  @override
  String get flowsThen => 'Luego';

  @override
  String get flowsRecentRuns => 'Ejecuciones recientes';

  @override
  String get flowsNoRunsYet => 'Aún sin ejecuciones';

  @override
  String get flowsRunStatusDone => 'Hecho';

  @override
  String get flowsRunStatusFailed => 'No se pudo terminar';

  @override
  String get flowsRunStatusDeclined => 'No permitido';

  @override
  String get flowsRunStatusNeedsGrant => 'Necesita tu permiso';

  @override
  String get flowsRunStatusStopped => 'Detenido';

  @override
  String get flowsMenuEdit => 'Editar';

  @override
  String get flowsMenuPause => 'Pausar';

  @override
  String get flowsMenuResume => 'Activar';

  @override
  String get flowsMenuDuplicate => 'Duplicar';

  @override
  String get flowsMenuDelete => 'Borrar';

  @override
  String get flowsRunFinished => 'Terminado';

  @override
  String flowsRunFinishedIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '1 segundo',
    );
    return 'Terminado en $_temp0';
  }

  @override
  String get flowsRunAgain => 'Ejecutar de nuevo';

  @override
  String get flowsBuilderHint => 'Describe qué debe pasar';

  @override
  String get flowsBuilderHere =>
      'Aquí está el flujo. Revísalo y luego actívalo.';

  @override
  String get flowsBuilderNoMatch =>
      'Todavía no puedo construir eso. Elige uno de estos y lo preparo.';

  @override
  String get flowsBuilderTurnOn => 'Activar';

  @override
  String get flowsStartWhen => 'Empezar cuando';

  @override
  String get flowsTriggerTime => 'A una hora fija';

  @override
  String get flowsTriggerTimeSub => 'Cada día, semana o mes';

  @override
  String get flowsTriggerPlace => 'Llegar o salir';

  @override
  String get flowsTriggerPlaceSub => 'Un lugar que elijas';

  @override
  String get flowsTriggerCharging => 'Carga';

  @override
  String get flowsTriggerChargingSub => 'Al conectar o desconectar';

  @override
  String get flowsTriggerBattery => 'Nivel de batería';

  @override
  String get flowsTriggerBatterySub => 'Por debajo o por encima de un nivel';

  @override
  String get flowsTriggerNotification => 'Una notificación';

  @override
  String get flowsTriggerNotificationSub => 'Cuando llega una de una app';

  @override
  String get flowsTriggerManual => 'Solo cuando lo pido';

  @override
  String get flowsTriggerManualSub => 'Inícialo tú mismo';

  @override
  String get flowsTriggerSoon => 'Aún no disponible';

  @override
  String get flowsScheduleSheetTitle => 'Horario';

  @override
  String get flowsScheduleSave => 'Guardar horario';

  @override
  String flowsAllowTitle(String name) {
    return '¿Permitir que $name actúe en tu teléfono?';
  }

  @override
  String get flowsAllowConfirm => 'Permitir';

  @override
  String flowsDeleteNamed(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get flowsDeleteNamedBody =>
      'Sus ejecuciones pasadas también se eliminan. Esto no se puede deshacer.';

  @override
  String flowsStepLookUp(String query) {
    return 'Buscar $query';
  }

  @override
  String get flowsStepWrite => 'Escribir la respuesta';

  @override
  String get creationsNewSheetSub =>
      'Descríbelo en el chat. FinnAI lo crea en este dispositivo.';

  @override
  String get creationsNewWidgetSub =>
      'Pequeñas herramientas para tu pantalla de inicio';

  @override
  String get creationsNewAppSub =>
      'Una herramienta simple que funciona dentro de FinnAI';

  @override
  String get creationsNewDeckSub => 'Diapositivas para presentar o compartir';

  @override
  String get creationsMenuEditWithFinn => 'Editar con FinnAI';

  @override
  String get creationsMenuDuplicate => 'Duplicar';

  @override
  String get creationsMenuShare => 'Compartir';

  @override
  String creationsDeleteNamed(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get creationsDeleteNamedBody =>
      'Se elimina de Creaciones y de tu pantalla de inicio. Esto no se puede deshacer.';

  @override
  String get creationsSizeSmall => 'Pequeño';

  @override
  String get creationsSizeMedium => 'Mediano';

  @override
  String get creationsSizeLarge => 'Grande';

  @override
  String get creationsUpdatesOnDevice =>
      'Se actualiza en este dispositivo. Nada sale de tu teléfono.';

  @override
  String get creationsMadeInChat => 'Creado en el chat';

  @override
  String get creationsDataLabel => 'Datos';

  @override
  String get creationsDataSub => 'Guardados dentro de este widget';

  @override
  String creationsAddHomeTitle(String name) {
    return '¿Añadir $name a tu pantalla de inicio?';
  }

  @override
  String get creationsAddHomeBody =>
      'Se ve como cualquier otro widget. Puedes moverlo o quitarlo después.';

  @override
  String get creationsAddHomeConfirm => 'Añadir';

  @override
  String get creationsBuilderTitleWidget => 'Nuevo widget';

  @override
  String get creationsBuilderTitleApp => 'Nueva mini app';

  @override
  String get creationsBuilderTitleDeck => 'Nueva presentación';

  @override
  String get creationsBuilderHint => 'Describe qué construir';

  @override
  String get creationsBuilderChangeHint => 'Pide cambios';

  @override
  String get creationsBuilderGotIt =>
      'Entendido. Lo construyo en este dispositivo.';

  @override
  String get creationsBuilderReady => 'Aquí está. Ábrelo o sigue editando.';

  @override
  String get creationsSaveToCreations => 'Guardar en Creaciones';

  @override
  String get creationsKeepEditing => 'Seguir editando';

  @override
  String get creationsSpeakerNotes => 'Notas del orador';

  @override
  String get creationsPresent => 'Presentar';

  @override
  String get creationsDuplicated => 'Duplicado.';

  @override
  String get onboardingChooseTitle => 'Elige lo que FinnAI puede ver';

  @override
  String get onboardingChooseBody =>
      'Puedes cambiarlo en cualquier momento en Ajustes. Todo se queda en este dispositivo.';

  @override
  String get onboardingDownloadPausedTitle => 'Descarga en pausa';

  @override
  String get onboardingDownloadPausedBody =>
      'Esperando conexión, tu progreso está guardado.';

  @override
  String get onboardingDownloadPausedNote =>
      'Continúa cuando vuelvas a tener conexión.';

  @override
  String get flowsStepNotifyMe => 'Avisarme';

  @override
  String get creationsTemplateTracker => 'Seguimiento';

  @override
  String get creationsSlotStep => 'Suma por toque';

  @override
  String get creationsResetAppTitle => '¿Restablecer esta app?';

  @override
  String get creationsResetAppBody =>
      'Se borra todo lo que añadiste. No se puede deshacer.';

  @override
  String get deviceActionVibrate => 'Hacer vibrar el teléfono';

  @override
  String get flowsTrigManual => 'Solo cuando yo lo inicie';

  @override
  String get flowsTrigTimeOfDay => 'A una hora fija';

  @override
  String flowsTrigEveryMinutes(int n) {
    return 'Cada $n minutos';
  }

  @override
  String flowsTrigEveryHours(int n) {
    return 'Cada $n horas';
  }

  @override
  String get flowsTrigEveryHour => 'Cada hora';

  @override
  String get flowsTrigInterval => 'Repetido';

  @override
  String get flowsTrigChargerOn => 'Cargador conectado';

  @override
  String get flowsTrigChargerOff => 'Cargador desconectado';

  @override
  String flowsTrigBatteryLow(int n) {
    return 'La batería baja al $n %';
  }

  @override
  String get flowsTrigHeadsetOn => 'Auriculares conectados';

  @override
  String get flowsTrigHeadsetOff => 'Auriculares desconectados';

  @override
  String get flowsTrigWifiOn => 'Wi‑Fi conectado';

  @override
  String get flowsTrigWifiOff => 'Wi‑Fi desconectado';

  @override
  String get flowsTrigAirplaneOn => 'Se activa el modo avión';

  @override
  String get flowsTrigAirplaneOff => 'Se desactiva el modo avión';

  @override
  String get flowsTrigBoot => 'El teléfono se inicia';

  @override
  String get flowsTrigUnlock => 'Pantalla desbloqueada';

  @override
  String get flowsTrigGroupTime => 'Hora';

  @override
  String get flowsTrigGroupPhone => 'En el teléfono';

  @override
  String get flowsTrigGroupHand => 'A mano';

  @override
  String flowsCondBatteryBelow(int n) {
    return 'Batería por debajo del $n %';
  }

  @override
  String flowsCondBatteryAbove(int n) {
    return 'Batería por encima del $n %';
  }

  @override
  String get flowsCondCharging => 'Cargando';

  @override
  String get flowsCondNotCharging => 'No está cargando';

  @override
  String flowsCondTimeBetween(String from, String to) {
    return 'Entre las $from y las $to';
  }

  @override
  String flowsCondDays(String days) {
    return 'El $days';
  }

  @override
  String get flowsCondWifiOn => 'Wi‑Fi conectado';

  @override
  String get flowsCondWifiOff => 'Wi‑Fi no conectado';

  @override
  String get flowsCondHeadsetOn => 'Auriculares conectados';

  @override
  String get flowsCondHeadsetOff => 'Auriculares no conectados';

  @override
  String get flowsCondAirplaneOn => 'Modo avión activado';

  @override
  String get flowsCondAirplaneOff => 'Modo avión desactivado';

  @override
  String flowsCondAnswer(String text) {
    return 'La respuesta menciona «$text»';
  }

  @override
  String get flowsBlockAsk => 'Preguntar a FinnAI';

  @override
  String get flowsBlockAskSub => 'Escribir algo con el modelo del dispositivo';

  @override
  String get flowsBlockWeb => 'Buscar';

  @override
  String get flowsBlockWebSub => 'Noticias, tiempo o la web';

  @override
  String get flowsBlockNotify => 'Avisarme';

  @override
  String get flowsBlockNotifySub => 'Mostrar una notificación';

  @override
  String get flowsBlockSpeak => 'Decirlo en voz alta';

  @override
  String get flowsBlockSpeakSub => 'Hablar con la voz del teléfono';

  @override
  String get flowsBlockAction => 'Hacer en el teléfono';

  @override
  String get flowsBlockActionSub => 'Linterna, volumen, alarma, abrir una app';

  @override
  String get flowsBlockWait => 'Esperar';

  @override
  String get flowsBlockWaitSub => 'Pausar unos segundos';

  @override
  String get flowsBlockBranch => 'Si … entonces';

  @override
  String get flowsBlockBranchSub => 'Hacer una cosa u otra';

  @override
  String get flowsBlockSave => 'Guardar en el chat';

  @override
  String get flowsBlockSaveSub => 'Guardar la respuesta como chat';

  @override
  String get flowsBlockStop => 'Parar aquí';

  @override
  String get flowsBlockStopSub => 'Terminar el flujo';

  @override
  String flowsSumAsk(String text) {
    return 'Preguntar: $text';
  }

  @override
  String flowsSumWeb(String text) {
    return 'Buscar $text';
  }

  @override
  String get flowsSumNotifyAnswer => 'Mostrar la respuesta';

  @override
  String get flowsSumSpeakAnswer => 'Leer la respuesta en voz alta';

  @override
  String flowsSumWait(int n) {
    return 'Esperar $n s';
  }

  @override
  String flowsSumIf(String condition) {
    return 'Si $condition';
  }

  @override
  String get flowsEdWhen => 'Cuándo';

  @override
  String get flowsEdOnlyIf => 'Solo si';

  @override
  String get flowsEdThen => 'Entonces';

  @override
  String get flowsEdOr => 'o';

  @override
  String get flowsEdYes => 'Sí';

  @override
  String get flowsEdOtherwise => 'Si no';

  @override
  String get flowsEdEnd => 'Listo';

  @override
  String get flowsEdAddTrigger => 'Añadir un disparador';

  @override
  String get flowsEdAddCondition => 'Añadir una condición';

  @override
  String get flowsEdAddStep => 'Añadir un paso';

  @override
  String get flowsEdInsertHere => 'Añadir un paso aquí';

  @override
  String get flowsEdNoSteps =>
      'Aún no hay nada que hacer. Añade el primer paso.';

  @override
  String get flowsEdManualStart => 'Empieza cuando tocas Ejecutar';

  @override
  String get flowsEdMoveUp => 'Subir';

  @override
  String get flowsEdMoveDown => 'Bajar';

  @override
  String get flowsEdRemove => 'Quitar';

  @override
  String get flowsEdDone => 'Listo';

  @override
  String get flowsEdChooseStep => '¿Qué debería pasar?';

  @override
  String get flowsEdChooseTrigger => '¿Qué lo inicia?';

  @override
  String get flowsEdChooseCondition => 'Solo cuando…';

  @override
  String get flowsEdConditionNote =>
      'Si no se cumple, el flujo no se ejecuta cuando lo inicia otra cosa.';

  @override
  String get flowsFieldPrompt => '¿Qué debe escribir FinnAI?';

  @override
  String flowsFieldPromptHint(String input) {
    return 'Usa $input para la última respuesta';
  }

  @override
  String get flowsFieldQuery => 'Qué buscar';

  @override
  String get flowsFieldSource => 'Dónde';

  @override
  String get flowsSourceWeb => 'La web';

  @override
  String get flowsSourceNews => 'Noticias';

  @override
  String get flowsSourceWeather => 'Tiempo';

  @override
  String get flowsFieldTitle => 'Título';

  @override
  String get flowsFieldMessage => 'Mensaje';

  @override
  String get flowsFieldMessageHint =>
      'Déjalo vacío para mostrar la última respuesta';

  @override
  String get flowsFieldSay => 'Qué decir';

  @override
  String get flowsFieldSayHint => 'Déjalo vacío para leer la última respuesta';

  @override
  String get flowsFieldSeconds => 'Cuántos segundos';

  @override
  String get flowsFieldAction => 'Qué hacer';

  @override
  String get flowsFieldCondition => 'Condición';

  @override
  String get flowsFieldLevel => 'Nivel de batería';

  @override
  String get flowsFieldFrom => 'Desde';

  @override
  String get flowsFieldTo => 'Hasta';

  @override
  String get flowsFieldDays => 'Días';

  @override
  String get flowsFieldContains => 'Contiene';

  @override
  String get flowsFieldEveryMinutes => 'Repetir cada';

  @override
  String get flowsUnitMinutes => 'minutos';

  @override
  String get flowsUnitHours => 'horas';

  @override
  String get flowsBgWorks => 'Funciona en segundo plano';

  @override
  String get flowsBgNeedsScreen => 'Necesita que toques una notificación';

  @override
  String get flowsAutoTitle => 'Dejar que se ejecute solo';

  @override
  String get flowsAutoNeedsAllow =>
      'Este flujo cambia tu teléfono. Permite que se ejecute cuando no estás mirando.';

  @override
  String get flowsListenerOn =>
      'FinnAI está atento a estos eventos en segundo plano.';

  @override
  String get flowsListenerNeedsNotify =>
      'Activa las notificaciones para que FinnAI pueda seguir atento.';

  @override
  String get flowsRunStatusSkipped => 'Condiciones no cumplidas';

  @override
  String get flowsRunStatusNeedsScreen => 'Esperando por ti';

  @override
  String get flowsRunSkipped => 'Omitido';

  @override
  String get flowsRunNeedsScreen => 'Toca para terminar';

  @override
  String get flowsRunByEvent => 'Se ejecutó solo';

  @override
  String get flowsRunByChat => 'Ejecutado desde el chat';

  @override
  String flowsNeedsScreenBody(String name) {
    return 'Toca para terminar «$name»: necesita la pantalla.';
  }

  @override
  String flowsNeedsGrantBody(String name) {
    return '«$name» quería ejecutarse pero necesita tu permiso.';
  }

  @override
  String get flowsStepWaiting => 'Esperando';

  @override
  String flowsPathStep(int n) {
    return 'Paso $n';
  }

  @override
  String get flowsDescribeTitle => 'Describe tu flujo';

  @override
  String get flowsDescribeHint =>
      'Por ejemplo: cuando conecte el cargador, enciende la linterna';

  @override
  String get flowsDescribeBuild => 'Crear';

  @override
  String get flowsDescribeThinking => 'Pensándolo…';

  @override
  String get flowsDescribeFailed =>
      'No pude convertirlo en un flujo. Di cuándo empieza y qué debe hacer.';

  @override
  String flowsDescribeMissed(String parts) {
    return 'No entendí: $parts';
  }

  @override
  String get flowsDescribeExamples => 'Prueba uno de estos';

  @override
  String get flowsExampleCharger =>
      'Cuando conecte el cargador, enciende la linterna';

  @override
  String get flowsExampleBattery =>
      'Cuando la batería esté por debajo del 15 %, recuérdame cargar';

  @override
  String get flowsExampleNews => 'Cada mañana a las 7 cuéntame las noticias';

  @override
  String get flowsExampleHeadset =>
      'Cuando conecte los auriculares, reproduce música';

  @override
  String get flowsNewBlank => 'Empezar desde cero';

  @override
  String get flowsNewBlankSub => 'Constrúyelo paso a paso';

  @override
  String get flowsNewTemplates => 'Desde una plantilla';

  @override
  String get flowsNewTemplatesSub =>
      'Resumen de noticias, recordatorio, batería baja…';

  @override
  String get flowsTemplateLowBattery => 'Aviso de batería baja';

  @override
  String get flowsTemplateLowBatteryBody =>
      'Te avisa una vez cuando la batería está baja.';

  @override
  String get flowsTemplateHeadset => 'Auriculares y música';

  @override
  String get flowsTemplateHeadsetBody =>
      'Reproduce o pausa cuando se conectan los auriculares.';

  @override
  String get flowsSlotLevel => 'Avisar al (%)';

  @override
  String get flowsSlotWhat => 'Qué hacer';

  @override
  String get flowsSlotPlay => 'Reproducir';

  @override
  String get flowsSlotPause => 'Pausar';

  @override
  String get flowsRunsTitle => 'Ejecuciones';

  @override
  String get flowsRunsAll => 'Ver todas las ejecuciones';

  @override
  String get flowsRenameTitle => 'Renombrar flujo';

  @override
  String get flowsSavedToast => 'Guardado';

  @override
  String get flowsStepOutcomeSkipped => 'Omitido';

  @override
  String flowsChatCreated(String name) {
    return 'He creado un flujo: «$name». Revísalo y actívalo.';
  }

  @override
  String get flowsChatOpen => 'Abrir flujo';

  @override
  String get flowsChatTurnOn => 'Activar';

  @override
  String get flowsChatIsOn => 'Activado';

  @override
  String get flowsChatDiscard => 'Descartar';

  @override
  String get flowsActSetAlarm => 'Poner una alarma';

  @override
  String get flowsActSetTimer => 'Iniciar un temporizador';

  @override
  String get flowsActShowAlarms => 'Mostrar mis alarmas';

  @override
  String get flowsActTorch => 'Linterna';

  @override
  String get flowsActMedia => 'Controlar la música';

  @override
  String get flowsActVolume => 'Cambiar el volumen';

  @override
  String get flowsActVibrate => 'Vibrar';

  @override
  String get flowsActOpenSettings => 'Abrir unos ajustes';

  @override
  String get flowsActOpenApp => 'Abrir una app';

  @override
  String get flowsActDial => 'Iniciar una llamada';

  @override
  String get flowsActSms => 'Escribir un SMS';

  @override
  String get flowsActEmail => 'Escribir un correo';

  @override
  String get flowsActPhoto => 'Abrir la cámara';

  @override
  String get flowsActUrl => 'Abrir una dirección web';

  @override
  String get flowsActNavigate => 'Ver indicaciones';

  @override
  String get flowsActShare => 'Compartir texto';

  @override
  String get flowsOn => 'Activado';

  @override
  String get flowsOff => 'Desactivado';

  @override
  String get flowsParamState => 'Estado';

  @override
  String get flowsParamDirection => 'Dirección';

  @override
  String get flowsParamScreen => 'Pantalla';

  @override
  String get flowsParamTime => 'Hora';

  @override
  String get flowsParamSeconds => 'Segundos';

  @override
  String get flowsParamMilliseconds => 'Milisegundos';

  @override
  String get flowsParamLabel => 'Etiqueta';

  @override
  String get flowsParamName => 'Nombre de la app';

  @override
  String get flowsParamNumber => 'Número de teléfono';

  @override
  String get flowsParamTo => 'Para';

  @override
  String get flowsParamBody => 'Mensaje';

  @override
  String get flowsParamSubject => 'Asunto';

  @override
  String get flowsParamUrl => 'Dirección web';

  @override
  String get flowsParamQuery => 'Lugar o dirección';

  @override
  String get flowsParamText => 'Texto';

  @override
  String get flowsPickAction => '¿Qué debe hacer el teléfono?';

  @override
  String get flowsEveryHowLong => 'Repetir cada';

  @override
  String get flowsIntervalNote =>
      'El teléfono agrupa los temporizadores para ahorrar batería, así que puede retrasarse unos minutos.';

  @override
  String get flowsBatteryLevelNote =>
      'Se ejecuta una vez cuando la batería baja a este nivel.';

  @override
  String get chatCreationReady =>
      'Aquí lo tienes. Ábrelo o ponlo en tu pantalla de inicio.';

  @override
  String get chatCreationBuilding => 'Creándolo…';

  @override
  String get flowsDetailOnEvent => 'Activado, empieza solo';

  @override
  String get voiceStyle => 'Voz';

  @override
  String get voiceStyleF1 => 'Femenina 1';

  @override
  String get voiceStyleF2 => 'Femenina 2';

  @override
  String get voiceStyleM1 => 'Masculina 1';

  @override
  String get voiceStyleM2 => 'Masculina 2';

  @override
  String get appBrandFinnAICode => 'FinnAI Code';

  @override
  String get appModeSwitchSemantic => 'Cambiar entre FinnAI y FinnAI Code';

  @override
  String get codeGreeting => '¿Qué construimos?';

  @override
  String get codeGreetingCaption =>
      'Tu proyecto vive en una carpeta privada de este teléfono.';

  @override
  String get codeComposerHint => 'Describe qué construir o arreglar';

  @override
  String get codeNewSession => 'Nueva sesión';

  @override
  String get codeSessionsTitle => 'Sesiones';

  @override
  String get codeNoSessions => 'Aún no hay sesiones';

  @override
  String get codeFilesTitle => 'Archivos';

  @override
  String get codeTerminalTitle => 'Terminal';

  @override
  String get codeModelsTitle => 'Modelos';

  @override
  String get codeSettingsTitle => 'Ajustes de Code';

  @override
  String get codeLocalLabel => 'FinnAI · en el dispositivo';

  @override
  String codeModelChipSemantic(String model) {
    return 'Elegir modelo. Actual: $model';
  }

  @override
  String get codePermissionAsk => 'Preguntar antes';

  @override
  String get codePermissionEdits => 'Editar solo';

  @override
  String get codePermissionAuto => 'Ejecutar solo';

  @override
  String codePermissionSemantic(String mode) {
    return 'Cambiar lo que puede hacer el agente. Actual: $mode';
  }

  @override
  String get codeThinking => 'Pensando…';

  @override
  String get codeActionRunCommand => 'Ejecutar comando';

  @override
  String codeActionWriteFile(String path) {
    return 'Escribir $path';
  }

  @override
  String get codeActionRun => 'Ejecutar';

  @override
  String get codeActionAllow => 'Permitir';

  @override
  String get codeActionSkip => 'Omitir';

  @override
  String get codeActionRunning => 'Ejecutando…';

  @override
  String get codeActionDone => 'Hecho';

  @override
  String codeActionFailedExit(String code) {
    return 'Falló (código $code)';
  }

  @override
  String get codeActionFailed => 'Falló';

  @override
  String get codeActionTimedOut => 'Tiempo agotado';

  @override
  String get codeActionSkipped => 'Omitido';

  @override
  String get codeActionDenied => 'Bloqueado';

  @override
  String get codeActionOutput => 'Salida';

  @override
  String get codeActionNoOutput => 'Sin salida';

  @override
  String get codeActionOutputCut => 'La salida se acortó';

  @override
  String codeDeniedBlockedProgram(String program) {
    return '«$program» no está permitido aquí.';
  }

  @override
  String get codeDeniedNetwork => 'Los comandos de red están desactivados.';

  @override
  String codeDeniedOutside(String path) {
    return '$path está fuera de la carpeta del proyecto.';
  }

  @override
  String get codeDeniedParent => '«..» no está permitido en las rutas.';

  @override
  String get codeDeniedOther => 'Ese comando no está permitido.';

  @override
  String get codeErrorStepLimit => 'Detenido en el límite de pasos.';

  @override
  String get codeErrorRepeating => 'Detenido: el modelo repetía el mismo paso.';

  @override
  String get codeErrorEmpty => 'El modelo envió una respuesta vacía.';

  @override
  String get codeErrorCutOff =>
      'La respuesta se cortó antes de terminar el paso, así que no se ejecutó nada.';

  @override
  String codeErrorEngine(String detail) {
    return 'Algo salió mal: $detail';
  }

  @override
  String get codeErrorAuth =>
      'El proveedor rechazó la clave. Revísala en los ajustes de Code.';

  @override
  String get codeErrorPlanNoApi =>
      'El plan Go de Command Code no tiene acceso a la API. Pasa a GOAT o superior para usarlo aquí.';

  @override
  String get codeErrorPayment => 'No queda crédito con este proveedor.';

  @override
  String get codeErrorRate =>
      'Límite de solicitudes alcanzado. Inténtalo de nuevo en un momento.';

  @override
  String get codeErrorWrongEndpoint =>
      'Este proveedor no pudo ofrecer ese modelo.';

  @override
  String get codeErrorBadRequest =>
      'El proveedor no pudo aceptar la solicitud.';

  @override
  String get codeErrorServer =>
      'El proveedor tuvo un problema. Inténtalo de nuevo.';

  @override
  String get codeErrorNetwork =>
      'No se pudo contactar con el proveedor. Revisa tu conexión.';

  @override
  String get codeErrorTimeout => 'El proveedor tardó demasiado en responder.';

  @override
  String get codeErrorMalformed =>
      'El proveedor envió una respuesta que no se pudo leer.';

  @override
  String get codeErrorUnknown => 'Algo salió mal con el proveedor.';

  @override
  String get codeSessionRename => 'Renombrar';

  @override
  String get codeSessionRenameTitle => 'Renombrar sesión';

  @override
  String get codeSessionPin => 'Fijar';

  @override
  String get codeSessionUnpin => 'Desfijar';

  @override
  String get codeSessionFiles => 'Archivos del proyecto';

  @override
  String get codeSessionDelete => 'Eliminar sesión';

  @override
  String get codeSessionDeleteTitle => '¿Eliminar esta sesión?';

  @override
  String get codeSessionDeleteBody =>
      'La conversación y sus archivos del proyecto se eliminan de este teléfono.';

  @override
  String codeCloudTitle(String provider) {
    return '¿Usar $provider?';
  }

  @override
  String codeCloudBody(String provider) {
    return '$provider funciona en la nube. Lo que escribes, junto con el contenido de archivos y la salida de comandos que lee el agente, se envía a $provider y se trata según sus condiciones. FinnAI en este dispositivo lo mantiene todo en el teléfono.';
  }

  @override
  String codeCloudConfirm(String provider) {
    return 'Usar $provider';
  }

  @override
  String get codeModelsSearchHint => 'Buscar modelos';

  @override
  String get codeModelsOnDeviceTitle => 'FinnAI';

  @override
  String get codeModelsOnDeviceSub =>
      'Se ejecuta en este teléfono. Privado, gratuito y funciona sin conexión.';

  @override
  String get codeModelsAddProvider =>
      'Añade un proveedor para usar más modelos';

  @override
  String get codeModelsLoading => 'Cargando modelos…';

  @override
  String get codeModelsLoad => 'Cargar modelos';

  @override
  String get codeModelsNone => 'Ningún modelo coincide';

  @override
  String get codeModelsFree => 'Gratis';

  @override
  String codeModelsContext(String size) {
    return '$size de contexto';
  }

  @override
  String codeModelsPrice(String input, String output) {
    return '$input entrada · $output salida por 1 M';
  }

  @override
  String codeModelsFetchFailed(String reason) {
    return 'No se pudieron cargar los modelos. $reason';
  }

  @override
  String get codeSettingsProviders => 'Proveedores';

  @override
  String get codeSettingsProvidersSubNone => 'FinnAI en este dispositivo';

  @override
  String codeSettingsProvidersSub(String count) {
    return 'FinnAI y $count conectados';
  }

  @override
  String get codeSettingsModel => 'Modelo';

  @override
  String get codeSettingsAgent => 'Agente';

  @override
  String get codeSettingsWorkspace => 'Carpetas de proyecto';

  @override
  String codeSettingsWorkspaceSub(String size) {
    return '$size en este teléfono';
  }

  @override
  String get codeSettingsData => 'Privacidad y datos';

  @override
  String get codeSettingsDataSub => 'Claves, sesiones y archivos del proyecto';

  @override
  String get codeSettingsAbout => 'Acerca de FinnAI Code';

  @override
  String get codeProvidersTitle => 'Proveedores';

  @override
  String get codeProvidersIntro =>
      'FinnAI en tu teléfono es la opción predeterminada. Añade tu propia clave de API para usar un modelo en la nube en FinnAI Code. Las claves permanecen en el almacenamiento seguro de tu teléfono.';

  @override
  String get codeProviderStatusLocal => 'En este dispositivo';

  @override
  String codeProviderStatusConnected(String hint) {
    return 'Conectado · ••••$hint';
  }

  @override
  String get codeProviderStatusConnectedNoKey => 'Conectado';

  @override
  String get codeProviderStatusNotSet => 'Sin configurar';

  @override
  String get codeProviderDescOpenRouter =>
      'Una clave para cientos de modelos, incluidos gratuitos.';

  @override
  String get codeProviderDescCommandCode =>
      'Los modelos de Command Code con tu propia clave.';

  @override
  String get codeProviderDescZen =>
      'OpenCode Zen: modelos de pago por uso elegidos para programar.';

  @override
  String get codeProviderDescGo =>
      'OpenCode Go: un plan mensual fijo de modelos abiertos para programar.';

  @override
  String get codeProviderDescCustom =>
      'Cualquier servidor con la API de OpenAI: el tuyo, Ollama, LM Studio y más.';

  @override
  String get codeProviderCustomName => 'Personalizado (compatible con OpenAI)';

  @override
  String get codeProviderKeyLabel => 'Clave de API';

  @override
  String get codeProviderKeyHint => 'Pega tu clave';

  @override
  String get codeProviderKeyOptionalHint =>
      'Pega una clave si tu servidor la necesita';

  @override
  String get codeProviderKeySave => 'Guardar clave';

  @override
  String get codeProviderKeyReplace => 'Reemplazar clave';

  @override
  String get codeProviderKeyRemove => 'Quitar clave';

  @override
  String get codeProviderKeyRemoveTitle => '¿Quitar esta clave?';

  @override
  String codeProviderKeyRemoveBody(String provider) {
    return 'FinnAI Code dejará de usar $provider hasta que añadas una clave de nuevo.';
  }

  @override
  String get codeProviderKeyStored =>
      'Guardada de forma segura en este teléfono';

  @override
  String get codeProviderGetKey => 'Obtener una clave';

  @override
  String get codeProviderTest => 'Probar clave';

  @override
  String get codeProviderTesting => 'Probando…';

  @override
  String get codeProviderTestOk => 'La clave funciona.';

  @override
  String codeProviderTestFail(String reason) {
    return 'La prueba falló. $reason';
  }

  @override
  String get codeProviderTestNeedsModel =>
      'Carga primero los modelos y luego prueba.';

  @override
  String get codeProviderAddressLabel => 'Dirección del servidor';

  @override
  String get codeProviderAddressHint => 'https://tu-servidor/v1';

  @override
  String get codeProviderAddressInvalid =>
      'Usa una dirección https, o http para un servidor de tu propia red.';

  @override
  String get codeProviderAddressSave => 'Guardar dirección';

  @override
  String get codeProviderPlanNote =>
      'Requiere el plan GOAT o superior. El plan Go no tiene acceso a la API y no se puede usar aquí.';

  @override
  String codeProviderPrivacy(String provider) {
    return 'Cuando usas uno de sus modelos, tus mensajes, el contenido de archivos y la salida de comandos se envían a $provider.';
  }

  @override
  String get codeProviderAllowance => 'Saldo';

  @override
  String codeProviderAllowanceRemaining(String remaining, String limit) {
    return 'Quedan $remaining de $limit';
  }

  @override
  String get codeProviderAllowanceUnlimited =>
      'Sin límite de gasto en esta clave';

  @override
  String codeProviderAllowanceUsed(String used) {
    return '$used usados';
  }

  @override
  String codeProviderAllowanceToday(String amount) {
    return '$amount hoy';
  }

  @override
  String codeProviderAllowanceMonth(String amount) {
    return '$amount este mes';
  }

  @override
  String codeProviderAllowanceBalance(String balance) {
    return 'Crédito de la cuenta $balance';
  }

  @override
  String get codeProviderAllowanceFree => 'Clave del nivel gratuito';

  @override
  String codeProviderAllowanceNoApi(String provider) {
    return '$provider no ofrece una API de uso. Consulta tu saldo en su panel.';
  }

  @override
  String get codeProviderOpenDashboard => 'Abrir panel';

  @override
  String get codeProviderRefresh => 'Actualizar';

  @override
  String codeProviderModelsCount(String count) {
    return '$count modelos disponibles';
  }

  @override
  String get codeProviderModelsRefresh => 'Actualizar lista de modelos';

  @override
  String get codeProviderChooseModel => 'Elegir un modelo';

  @override
  String codeProviderModelsLive(String provider) {
    return 'Obtenidos en directo de $provider';
  }

  @override
  String get codeAgentTitle => 'Agente';

  @override
  String get codeAgentPermissionTitle => 'Cuando el agente actúa';

  @override
  String get codeAgentAsk => 'Preguntar antes de todo';

  @override
  String get codeAgentAskSub =>
      'Cada comando y cada escritura de archivo espera tu toque.';

  @override
  String get codeAgentEdits => 'Escribir archivos, preguntar por comandos';

  @override
  String get codeAgentEditsSub =>
      'Los archivos se escriben sobre la marcha. Los comandos esperan tu toque.';

  @override
  String get codeAgentAuto => 'Ejecutar todo';

  @override
  String get codeAgentAutoSub =>
      'Nada espera por ti. Los comandos siguen limitados a la carpeta del proyecto.';

  @override
  String get codeAgentSteps => 'Pasos por solicitud';

  @override
  String get codeAgentStepsSub =>
      'Cuántas acciones puede hacer el agente antes de detenerse y pedir continuar.';

  @override
  String get codeAgentStepsAuto => 'Automático';

  @override
  String codeAgentStepsValue(String count) {
    return '$count pasos';
  }

  @override
  String get codeAgentNetwork => 'Permitir comandos de red';

  @override
  String get codeAgentNetworkSub =>
      'Permite que comandos como curl lleguen a internet. Desactivado evita que tu proyecto se suba por error.';

  @override
  String get codeAgentTimeout => 'Límite de tiempo de comandos';

  @override
  String codeAgentTimeoutValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get codeSandboxNote =>
      'Los comandos se ejecutan en una carpeta privada de este teléfono, como el propio usuario de la app y con un límite de tiempo. No es un sistema Linux completo: no hay python, git ni compilador, y no se puede instalar nada.';

  @override
  String get codeWorkspaceTitle => 'Carpetas de proyecto';

  @override
  String codeWorkspaceUsed(String size, String count) {
    return '$size en $count carpetas de proyecto';
  }

  @override
  String get codeWorkspaceClear => 'Eliminar todos los archivos de proyecto';

  @override
  String get codeWorkspaceClearTitle =>
      '¿Eliminar todos los archivos de proyecto?';

  @override
  String get codeWorkspaceClearBody =>
      'Se vacía la carpeta de proyecto de cada sesión. Las conversaciones se conservan.';

  @override
  String get codeDataTitle => 'Privacidad y datos';

  @override
  String get codeDataNote =>
      'Las sesiones y los archivos del proyecto se guardan en el almacenamiento privado de esta app en tu teléfono. Las claves de API se guardan en el almacenamiento seguro del sistema. Con FinnAI en este dispositivo, nada sale del teléfono.';

  @override
  String get codeDataDelete => 'Eliminar datos de FinnAI Code';

  @override
  String get codeDataDeleteSub =>
      'Sesiones, archivos de proyecto, claves guardadas y ajustes';

  @override
  String get codeDataDeleteTitle => '¿Eliminar los datos de FinnAI Code?';

  @override
  String get codeDataDeleteBody =>
      'Se eliminan todas las sesiones, carpetas de proyecto, claves guardadas y ajustes de Code. Los chats de FinnAI no se tocan.';

  @override
  String get codeDataDeleted => 'Datos de FinnAI Code eliminados.';

  @override
  String get codeAboutBody =>
      'FinnAI Code es un agente de programación. Funciona con el modelo de tu teléfono o con tus propias claves de proveedor, y puede leer y escribir archivos en una carpeta de proyecto privada y ejecutar comandos sencillos allí.';

  @override
  String get codeFilesEmpty =>
      'Aún no hay archivos. Pide al agente que cree algo.';

  @override
  String get codeFilesNoSession =>
      'Inicia una sesión para tener una carpeta de proyecto.';

  @override
  String get codeFileCopy => 'Copiar';

  @override
  String get codeFileCopied => 'Copiado';

  @override
  String get codeFileDelete => 'Eliminar archivo';

  @override
  String codeFileDeleteTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get codeFileEmpty => 'Este archivo está vacío.';

  @override
  String get codeTerminalHint => 'Ejecutar un comando';

  @override
  String get codeTerminalIntro =>
      'Se ejecuta en la carpeta de proyecto de esta sesión.';

  @override
  String get codeTerminalUnsupported =>
      'Los comandos no se pueden ejecutar en este dispositivo.';

  @override
  String get codeTerminalClear => 'Borrar';

  @override
  String get codeErrorMalformedAction =>
      'El modelo escribió una acción que no se pudo usar, así que no se ejecutó nada.';

  @override
  String get codeCloudTitleCustom => '¿Usar este servidor?';

  @override
  String codeCloudBodyCustom(String address) {
    return 'Lo que escribes, junto con el contenido de archivos y la salida de comandos que lee el agente, se envía a $address. FinnAI en este dispositivo lo mantiene todo en el teléfono.';
  }

  @override
  String get codeCloudConfirmCustom => 'Usar este servidor';
}
