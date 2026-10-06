// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonNext => 'Avanti';

  @override
  String get commonYes => 'Sì';

  @override
  String get commonNo => 'No';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonContinue => 'Continua';

  @override
  String get commonCopiedToClipboard => 'Copiato negli appunti';

  @override
  String get commonOpen => 'Apri';

  @override
  String get commonStop => 'Interrompi';

  @override
  String get commonDownload => 'Scarica';

  @override
  String get commonResend => 'Reinvia';

  @override
  String get commonSaveFlow => 'Salva competenza';

  @override
  String get commonKeepCreating => 'Continua a creare';

  @override
  String get commonNotNow => 'Non ora';

  @override
  String get commonPurge => 'Libera';

  @override
  String get commonClearAll => 'Cancella tutto';

  @override
  String get commonDeleteEverything => 'Elimina tutto';

  @override
  String get appTitle => 'Finn AI';

  @override
  String get appBrandFinnAI => 'FinnAI';

  @override
  String get unsupportedTitle =>
      'Finn AI non può essere eseguito su questo dispositivo';

  @override
  String get unsupportedBody =>
      'Finn AI richiede almeno 3 GB di RAM e un processore ARM a 64 bit per eseguire modelli locali in modo affidabile. Nessun modello è stato scaricato.';

  @override
  String get onboardingWelcome => 'Benvenuto in FinnAI';

  @override
  String get onboardingSwipeToStart => 'Scorri per iniziare';

  @override
  String get onboardingPrivacyTitle => 'FinnAI rispetta la tua privacy';

  @override
  String get onboardingPrivacyLead =>
      'FinnAI mette al primo posto la tua privacy.';

  @override
  String get onboardingPrivacyBody =>
      'Non tracciamo né memorizziamo i tuoi dati: ogni richiesta viene elaborata localmente sul tuo dispositivo. ';

  @override
  String get onboardingPrivacyLink =>
      'Scopri di più nella nostra Informativa sulla privacy.';

  @override
  String get onboardingPrecautionsTitle =>
      'Prima di iniziare, leggi le precauzioni';

  @override
  String get onboardingPrecautionOne =>
      'Elaborazione dei prompt IA sul dispositivo';

  @override
  String get onboardingPrecautionTwo =>
      'Chat offline dopo il download del modello';

  @override
  String get onboardingPrecautionThree =>
      'Archiviazione cifrata delle conversazioni';

  @override
  String get onboardingPrecautionFour =>
      'Progettato per l\'efficienza della batteria';

  @override
  String get onboardingInstallTitleInstalling =>
      'Download di FinnAI Foundation';

  @override
  String get onboardingInstallTitleReady => 'FinnAI Foundation pronta';

  @override
  String get onboardingDownloadLead => 'Configurazione di FinnAI,';

  @override
  String get onboardingDownloadNote =>
      'il primo avvio richiede qualche minuto.';

  @override
  String onboardingProgressPercent(Object percent) {
    return '$percent% completato.';
  }

  @override
  String get onboardingProgressEtaTail => 'rimanenti.';

  @override
  String onboardingProgressEtaAbout(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuti',
      one: '1 minuto',
    );
    return 'Circa $_temp0 rimanenti.';
  }

  @override
  String get onboardingInstallPreparing =>
      'Preparazione di LFM2.5-VL 1.6B per questo dispositivo…';

  @override
  String get onboardingInstallReadyForChat =>
      'Pronto per la chat testuale privata su questo dispositivo';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + supporto immagini · $size';
  }

  @override
  String get onboardingInstallModelReady => 'Modello pronto';

  @override
  String onboardingInstallProgressStatus(String status, String percent) {
    return '$status · $percent%';
  }

  @override
  String onboardingInstallBytesOf(String received, String total) {
    return '$received di $total';
  }

  @override
  String onboardingInstallBytesLeft(String remaining) {
    return '$remaining rimanenti';
  }

  @override
  String get onboardingInstallRetry => 'Riprova';

  @override
  String get onboardingInstallRetryLabel => 'Riprova il download del modello';

  @override
  String get onboardingInstallVerificationFailed =>
      'Verifica del modello non riuscita';

  @override
  String get onboardingUpgradeTitle => 'Aggiornamento software FinnAI';

  @override
  String get onboardingUpgradeBody =>
      'Finn AI ora esegue un modello più recente sul dispositivo. Scaricalo per continuare a chattare in privato.';

  @override
  String get onboardingReadyTitle => 'FinnAI è pronto!';

  @override
  String get onboardingReadyLead => 'FinnAI è pronto all\'uso!';

  @override
  String get onboardingReadyBody =>
      'Ora puoi usare FinnAI, sia online che offline.\nSperiamo che ti piaccia!';

  @override
  String get onboardingReadySubtitle => 'Tutto pronto. Finn AI è a posto.';

  @override
  String get onboardingConsentTitle =>
      'Consenti a FinnAI di usare il contesto del tuo dispositivo?';

  @override
  String get onboardingConsentBody =>
      'Questo permette a FinnAI di leggere cose come il tuo calendario, le tue note e le tue foto, così le risposte si adattano meglio a te. Legge solo su questo dispositivo e nulla viene inviato altrove.';

  @override
  String get onboardingConsentRequiredHint => 'Scegli Sì o No per continuare';

  @override
  String get onboardingStartUsing => 'Inizia a usare FinnAI';

  @override
  String get onboardingYouLabel => 'Tu';

  @override
  String get chatNewChat => 'Nuova chat';

  @override
  String get chatHistory => 'Chat';

  @override
  String get chatNoHistory => 'Nessuna cronologia';

  @override
  String get chatFinnGenerating => 'Finn sta generando…';

  @override
  String get chatFinnTyping => 'Finn sta scrivendo…';

  @override
  String get chatAskAnything =>
      'Chiedimi qualsiasi cosa — funziono interamente su questo dispositivo, le tue\nconversazioni non lasciano mai il dispositivo.';

  @override
  String get chatTryAsking => 'Prova a chiedere';

  @override
  String get chatMessageHint => 'Messaggio a Finn…';

  @override
  String get chatSend => 'Invia';

  @override
  String get chatStopGeneration => 'Interrompi';

  @override
  String get chatCopy => 'Copia';

  @override
  String get chatEditMessage => 'Modifica messaggio';

  @override
  String get chatRenameTitle => 'Rinomina chat';

  @override
  String get chatRenameHint => 'Titolo della chat';

  @override
  String get chatDeleteTitle => 'Eliminare la chat?';

  @override
  String chatDeleteBody(String title) {
    return '\"$title\" verrà rimossa. L\'operazione non può essere annullata.';
  }

  @override
  String get chatContinue => 'Continua';

  @override
  String get chatSources => 'Fonti';

  @override
  String get chatHistoryUnavailableNotice =>
      'Finn non ha potuto aprire la cronologia delle chat su questo dispositivo, quindi le nuove risposte non verranno salvate.';

  @override
  String get chatOfflineNotice =>
      'Offline — la risposta potrebbe essere meno precisa. Connettiti per ottenere fonti citate.';

  @override
  String get chatFinishingTask =>
      'Finn AI sta completando un\'altra attività locale.';

  @override
  String get chatAttachmentPickFailed =>
      'Impossibile aprire il selettore. Riprova.';

  @override
  String get chatCouldNotPrepare =>
      'Impossibile preparare la chat. Controlla il modello e lo spazio di archiviazione, poi riprova.';

  @override
  String get chatEmptyReply =>
      'Questa volta Finn non ha trovato una risposta. Tocca «Riprova» per chiedere di nuovo.';

  @override
  String chatGeneratingIn(String title) {
    return 'Generazione in $title';
  }

  @override
  String get chatDownloadModelTitle =>
      'Scaricare il modello IA per la chat offline?';

  @override
  String chatDownloadModelBody(String size) {
    return '$size viene scaricato una sola volta e verificato prima dell\'uso. Il download riprende in sicurezza dopo un\'interruzione di connessione, e le tue chat restano su questo dispositivo.';
  }

  @override
  String get chatHiPrefix => 'Ciao, sono Finn.';

  @override
  String get chatFinnAI => 'Finn AI';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsContextTitle => 'Contesto sul dispositivo';

  @override
  String get settingsContextSubtitle =>
      'Consenti a FinnAI di usare il contesto di questo dispositivo';

  @override
  String get settingsAiModel => 'MODELLO IA';

  @override
  String get settingsStorageData => 'ARCHIVIAZIONE E DATI';

  @override
  String get settingsPrivacyLegal => 'PRIVACY E LEGALE';

  @override
  String get settingsAbout => 'INFORMAZIONI';

  @override
  String settingsSavedConversations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chat (cifrate)',
      one: '1 chat (cifrata)',
    );
    return '$_temp0';
  }

  @override
  String get settingsReleasingMemory => 'Rilascio della memoria…';

  @override
  String get settingsPurgeMemorySubtitle =>
      'Libera RAM. Il modello si ricarica al prossimo messaggio.';

  @override
  String get settingsClearHistorySubtitle =>
      'Elimina tutte le chat salvate. Non può essere annullato.';

  @override
  String get settingsDeleteAllDataSubtitle =>
      'Chat, modelli, creazioni e preferenze: come al primo avvio.';

  @override
  String get settingsPurgeMemory => 'Libera la memoria';

  @override
  String get settingsPurgeMemoryTitle => 'Liberare la memoria?';

  @override
  String get settingsPurgeMemoryBody =>
      'Questo chiude il modello IA per liberare memoria. Verrà riaperto al tuo prossimo messaggio.';

  @override
  String get settingsPurgeMemoryReleased => 'Memoria liberata.';

  @override
  String get settingsClearHistory => 'Cancella tutta la cronologia chat';

  @override
  String get settingsClearHistoryTitle => 'Cancellare tutte le conversazioni?';

  @override
  String get settingsClearHistoryBody =>
      'Questa operazione eliminerà definitivamente tutta la cronologia chat. Non può essere annullata.';

  @override
  String get settingsClearHistorySuccess =>
      'Tutte le conversazioni cancellate.';

  @override
  String get settingsClearHistoryFailure =>
      'Impossibile cancellare le conversazioni. Controlla lo spazio di archiviazione e riprova.';

  @override
  String get settingsDeleteAllData => 'Elimina tutti i dati locali';

  @override
  String get settingsDeleteAllDataTitle => 'Eliminare tutti i dati locali?';

  @override
  String get settingsDeleteAllDataBody =>
      'Questo elimina definitivamente conversazioni e chiavi crittografate, modelli AI scaricati, creazioni, preferenze del profilo, Flow e lo stato di onboarding. FinnAI tornerà a un primo avvio pulito.';

  @override
  String get settingsDeleteAllDataDeleting =>
      'Eliminazione di tutti i dati locali…';

  @override
  String get settingsDeleteAllDataSuccess =>
      'Tutti i dati locali eliminati. Ritorno all\'introduzione.';

  @override
  String settingsDeleteAllDataPartialFailure(String items) {
    return 'Errore parziale di eliminazione: impossibile eliminare $items.';
  }

  @override
  String get settingsPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get settingsPrivacyPolicyUnconfigured =>
      'Il collegamento all\'informativa sulla privacy non è disponibile in questa versione.';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return 'Impossibile aprire $url';
  }

  @override
  String get settingsTermsOfUse => 'Termini di utilizzo';

  @override
  String get settingsTermsUnconfigured =>
      'Il collegamento ai termini di utilizzo non è disponibile in questa versione.';

  @override
  String settingsTermsLaunchFailed(String url) {
    return 'Impossibile aprire $url';
  }

  @override
  String get settingsSupportContact => 'Contatto di assistenza';

  @override
  String get settingsSupportUnavailable =>
      'Il contatto di assistenza non è disponibile.';

  @override
  String settingsSupportEmailLabel(String email) {
    return 'Email di assistenza: $email';
  }

  @override
  String settingsSupportLaunchFailed(String url) {
    return 'Impossibile aprire $url';
  }

  @override
  String get settingsOpenSourceLicenses => 'Licenze open source';

  @override
  String get settingsAppVersion => 'Versione dell\'app';

  @override
  String get settingsInferenceEngine => 'Come funziona Finn';

  @override
  String get settingsInferenceEngineValue =>
      'Interamente su questo dispositivo';

  @override
  String get settingsPrivacyMode => 'Modalità privacy';

  @override
  String get settingsPrivacyModeValue => 'Cifrato sul dispositivo';

  @override
  String get settingsModelArchitecture => 'Architettura del modello';

  @override
  String get settingsModelArchitectureValue => 'LFM2.5-VL 1.6B (Liquid)';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsSpokenResponses => 'Risposte vocali';

  @override
  String get settingsSpokenResponsesBody =>
      'Finn legge le risposte ad alta voce in modalità vocale. Ciò che dici viene trasformato in testo su questo dispositivo e non lo lascia mai.';

  @override
  String get voiceMicSemantic => 'Parla con Finn';

  @override
  String get voiceCancelSemantic => 'Annulla input vocale';

  @override
  String get voiceExpandSemantic => 'Apri la modalità vocale completa';

  @override
  String get voiceListening => 'In ascolto…';

  @override
  String get voiceTapToSpeak => 'Tocca il microfono e parla';

  @override
  String get voiceHeardYou => 'Ti ho sentito';

  @override
  String get voiceDidNotCatch => 'Non ho capito — riprova';

  @override
  String get voiceThinking => 'Finn sta pensando…';

  @override
  String get voiceSpeaking => 'Finn sta parlando — tocca per interrompere';

  @override
  String get voiceMicDenied =>
      'L\'accesso al microfono è disattivato. Attivalo nelle impostazioni di sistema per usare la modalità vocale.';

  @override
  String get voiceUnavailable =>
      'Il riconoscimento vocale non è disponibile al momento. Digita invece il tuo messaggio.';

  @override
  String voiceModelNeeded(String size) {
    return 'La modalità vocale richiede un download una tantum di $size. La tua voce viene trasformata in testo su questo dispositivo e non lo lascia mai.';
  }

  @override
  String get voiceModelDownload => 'Scarica';

  @override
  String voiceModelDownloading(int percent) {
    return 'Download del modello vocale… $percent%';
  }

  @override
  String get voiceModelFailed =>
      'Il download non è stato completato. Controlla la connessione e riprova.';

  @override
  String get voiceModelRetry => 'Riprova';

  @override
  String get voiceSpeakingLive => 'Sta parlando…';

  @override
  String get voiceStopSemantic => 'Interrompi';

  @override
  String get voiceCloseSemantic => 'Chiudi la modalità vocale';

  @override
  String get youTitle => 'Tu';

  @override
  String get youIntroTitle => 'Fai tuo Finn';

  @override
  String get youIntroBody =>
      'Le tue preferenze restano su questo dispositivo e influenzano le risposte future.';

  @override
  String get youAboutYou => 'Su di te';

  @override
  String get youNameLabel => 'Nome';

  @override
  String get youNameHint => 'Come dovrebbe chiamarti Finn?';

  @override
  String get youAboutLabel => 'Su di te';

  @override
  String get youAboutHint =>
      'Interessi, lavoro o contesto che Finn dovrebbe ricordare';

  @override
  String get youInstructionsLabel => 'Istruzioni personalizzate';

  @override
  String get youInstructionsHint =>
      'Come dovrebbe rispondere Finn? Tono, lunghezza, stile…';

  @override
  String get youResponseStyle => 'Stile di risposta';

  @override
  String get youResponseStyleBalanced => 'Equilibrato';

  @override
  String get youResponseStyleConcise => 'Conciso';

  @override
  String get youResponseStyleDetailed => 'Dettagliato';

  @override
  String get youResponseStyleCreative => 'Creativo';

  @override
  String get youSave => 'Salva';

  @override
  String get youSaved => 'Personalizzazione salvata localmente.';

  @override
  String get youSaveFailed => 'Impossibile salvare le modifiche.';

  @override
  String get flowsTitle => 'Flow';

  @override
  String flowsSubtitle(int count) {
    return '$count disponibili · le Flow guidano risposte pertinenti';
  }

  @override
  String get flowsDeleteTitle => 'Eliminare questa flow?';

  @override
  String flowsDeleteBody(String name) {
    return '\"$name\" verrà rimossa da questo dispositivo.';
  }

  @override
  String get flowsNameLabel => 'Nome della flow';

  @override
  String get flowsRunAction => 'Esegui ora';

  @override
  String get flowsRunRunning => 'In corso…';

  @override
  String get flowsGrantLabel => 'Lascia che si esegua da solo';

  @override
  String get flowsGrantExplain =>
      'Un flow che modifica il telefono ha bisogno di questo per essere eseguito senza di te. Puoi disattivarlo quando vuoi.';

  @override
  String get flowsNeedsGrant =>
      'Ha bisogno della tua autorizzazione per essere eseguito da solo';

  @override
  String get flowsHistoryTitle => 'Esecuzioni recenti';

  @override
  String get flowsHistoryEmpty => 'Questo flow non è ancora stato eseguito.';

  @override
  String get flowsRunCompleted => 'Completato';

  @override
  String get flowsRunDeclined => 'Hai rifiutato';

  @override
  String get flowsRunFailed => 'Interrotto prima';

  @override
  String get flowsRunInterrupted => 'Annullato';

  @override
  String get flowsRunBySchedule => 'Eseguito da solo';

  @override
  String get flowsAutomationsTitle => 'Automazioni';

  @override
  String get flowsAutomationsSubtitle =>
      'Cose che Finn fa per te con un orario. Niente parte se non lo attivi.';

  @override
  String get flowsNewAutomation => 'Nuova automazione';

  @override
  String get flowsNoAutomations =>
      'Ancora nessuna automazione. Inizia con un riepilogo del mattino.';

  @override
  String get flowsTemplateMorningBrief => 'Riepilogo del mattino';

  @override
  String get flowsTemplateMorningBriefBody =>
      'Le notizie che ti interessano e il meteo, in poche righe.';

  @override
  String get flowsTemplateWebCheck => 'Controllo web';

  @override
  String get flowsTemplateWebCheckBody =>
      'Controlla un argomento e ti dice cosa c’è di nuovo.';

  @override
  String get flowsTemplateReminder => 'Promemoria';

  @override
  String get flowsTemplateReminderBody => 'Una notifica con parole tue.';

  @override
  String get flowsSlotTopics => 'Cosa seguire';

  @override
  String get flowsSlotCity => 'Città per il meteo (facoltativo)';

  @override
  String get flowsSlotTopic => 'Argomento';

  @override
  String get flowsSlotMessage => 'Messaggio';

  @override
  String get flowsScheduleHeading => 'Quando';

  @override
  String flowsScheduleWeekdaysAt(String time) {
    return 'Giorni feriali alle $time';
  }

  @override
  String get flowsScheduleEveryDay => 'Ogni giorno';

  @override
  String get flowsScheduleWeekdaysOnly => 'Giorni feriali';

  @override
  String get flowsScheduleTime => 'Ora';

  @override
  String get flowsNotifyWhyTitle => 'Consentire le notifiche?';

  @override
  String get flowsNotifyWhyBody =>
      'Finn invia una notifica quando questa automazione è dovuta. Senza, parte solo quando tocchi Esegui.';

  @override
  String get flowsNotifyAllow => 'Consenti';

  @override
  String get flowsNotifyOff =>
      'Le notifiche sono disattivate, quindi non partirà da sola.';

  @override
  String flowsRunning(String name) {
    return 'Esecuzione di $name…';
  }

  @override
  String flowsRunReady(String name) {
    return '$name è pronto';
  }

  @override
  String flowsRunCouldNotFinish(String name) {
    return '$name non è riuscito a completarsi';
  }

  @override
  String get flowsOpenResult => 'Apri il risultato';

  @override
  String flowsNextRun(String when) {
    return 'Prossima: $when';
  }

  @override
  String get flowsRunByYou => 'Eseguito da te';

  @override
  String get flowsStepsLabel => 'Passaggi';

  @override
  String flowsStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passaggi',
      one: '1 passo',
    );
    return '$_temp0';
  }

  @override
  String get flowsStepPrompt => 'Chiedi';

  @override
  String get flowsStepDeviceAction => 'Agisci sul telefono';

  @override
  String get flowsStepNotify => 'Nota';

  @override
  String get flowsStepBrowse => 'Cerca';

  @override
  String get flowsScheduleLabel => 'Esecuzione';

  @override
  String get flowsScheduleManual => 'Solo quando lo esegui tu';

  @override
  String flowsScheduleDaily(String time) {
    return 'Ogni giorno alle $time';
  }

  @override
  String flowsScheduleWeekly(String days, String time) {
    return '$days alle $time';
  }

  @override
  String get flowsScheduleAdd => 'Aggiungi un orario';

  @override
  String get flowsScheduleRemove => 'Esegui solo quando lo chiedo io';

  @override
  String get chatBrowsingTitle => 'Navigazione sul web';

  @override
  String get chatSearchingInline => 'Ricerca sul web…';

  @override
  String get chatSearchedInline => 'Ricerca web completata';

  @override
  String get chatShowSearchSteps => 'Mostra i passaggi di ricerca';

  @override
  String get chatBrowsingHide => 'Nascondi';

  @override
  String chatBrowsingSteps(int count) {
    return '$count passaggi';
  }

  @override
  String chatBrowsingSearch(String query) {
    return 'Cercato sul web “$query”';
  }

  @override
  String chatBrowsingOpen(String title) {
    return 'Letto “$title”';
  }

  @override
  String chatBrowsingFind(String query) {
    return 'Cercato “$query” nella pagina';
  }

  @override
  String get creationsNoneTitle => 'Ancora nessuna creazione.';

  @override
  String get creationsNoneBody =>
      'La tua creatività vive qui.\nProva a creare qualcosa con FinnAI Creations.';

  @override
  String get creationsTitle => 'Creazioni';

  @override
  String get creationsSubtitle =>
      'Descrivi ciò che vuoi. Finn lo crea sul dispositivo.';

  @override
  String get creationsWhatAreWeMaking => 'Cosa creiamo?';

  @override
  String get creationsOriginalBrief => 'Brief originale';

  @override
  String get creationsFinnAdapts => 'Finn adatta la struttura al formato.';

  @override
  String get creationsAskKind =>
      'La tua nuova creazione è un’app, un widget o una presentazione?';

  @override
  String creationsDescribeKind(String kind) {
    return 'Dimmi cosa deve fare la tua $kind.';
  }

  @override
  String get creationsStageDesigning => 'Progettazione…';

  @override
  String get creationsStageWriting => 'Scrittura…';

  @override
  String get creationsStageValidating => 'Verifica del risultato…';

  @override
  String get creationsStageRepairing => 'Correzione di un dettaglio…';

  @override
  String get creationsFallbackNote =>
      'Finn non è riuscito a completare il progetto, quindi ecco un modello funzionante su cui costruire.';

  @override
  String get creationsTemplateAuto => 'Scegli tu, Finn';

  @override
  String get creationsTemplateQuestion =>
      'Vuoi un punto di partenza? Sceglierne uno o descrivi semplicemente cosa vuoi.';

  @override
  String get creationsTemplateCounter => 'Contatore';

  @override
  String get creationsTemplateChecklist => 'Lista di controllo';

  @override
  String get creationsTemplateList => 'Lista';

  @override
  String get creationsTemplateScoreboard => 'Segnapunti';

  @override
  String get creationsTemplateStat => 'Numero grande';

  @override
  String get creationsTemplateRows => 'Righe';

  @override
  String get creationsEdit => 'Modifica';

  @override
  String get creationsEditTitle => 'Modifica i dettagli';

  @override
  String get creationsSlotTitle => 'Nome';

  @override
  String get creationsSlotUnit => 'Cosa conti';

  @override
  String get creationsSlotGoal => 'Obiettivo';

  @override
  String get creationsSlotEmoji => 'Emoji';

  @override
  String get creationsSlotAccent => 'Colore';

  @override
  String get creationsSlotItems => 'Voci';

  @override
  String get creationsSlotHint => 'Suggerimento di input';

  @override
  String get creationsSlotEmpty => 'Messaggio se vuota';

  @override
  String get creationsSlotNameA => 'Primo nome';

  @override
  String get creationsSlotNameB => 'Secondo nome';

  @override
  String get creationsSlotLabel => 'Etichetta';

  @override
  String get creationsSlotValue => 'Valore';

  @override
  String get creationsSlotFooter => 'Piè di pagina';

  @override
  String get creationsSlotRows => 'Righe';

  @override
  String get creationsSlotOnePerLine => 'Uno per riga';

  @override
  String get creationsSlotRowFormat => 'Una per riga, ad esempio «Acqua: 3»';

  @override
  String get creationsAccentMint => 'Menta';

  @override
  String get creationsAccentBlue => 'Blu';

  @override
  String get creationsAccentLime => 'Lime';

  @override
  String get creationsAccentAmber => 'Ambra';

  @override
  String get creationsAccentRose => 'Rosa';

  @override
  String get creationsAccentViolet => 'Viola';

  @override
  String get creationsAccentSky => 'Cielo';

  @override
  String get creationsNewCreation => 'Nuova creazione';

  @override
  String get creationsChooseKindSemantic => 'Scegli cosa creare';

  @override
  String get creationsFailed =>
      'Finn non è riuscito a completare quella creazione. Riprova.';

  @override
  String get creationsHomeScreenUnsupported =>
      'I widget della schermata Home non sono disponibili su questo dispositivo.';

  @override
  String get creationsHomeScreenAdded => 'Aggiunto alla schermata Home.';

  @override
  String get creationsHomeScreenFailed =>
      'Non è stato possibile aggiungerlo alla schermata Home.';

  @override
  String creationsExportedTo(String fileName) {
    return '$fileName salvato';
  }

  @override
  String get creationsExportDeck => 'Esporta come PowerPoint';

  @override
  String get creationsAddToHomeScreen => 'Aggiungi alla schermata Home';

  @override
  String get creationsWidgetPreview =>
      'Ecco come apparirà sulla schermata Home.';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Presentazione';

  @override
  String get creationsFilterApps => 'App';

  @override
  String get creationsFilterWidgets => 'Widget';

  @override
  String get creationsFilterPresentations => 'Presentazioni';

  @override
  String get flowsSaveFailed => 'Impossibile salvare questa Flow.';

  @override
  String get creationsExportedShared => 'Presentazione pronta da condividere.';

  @override
  String get creationsExportFailed =>
      'Non è stato possibile esportare quella presentazione.';

  @override
  String get creationsResetApp => 'Reimposta';

  @override
  String get creationsPreviousSlide => 'Diapositiva precedente';

  @override
  String get creationsNextSlide => 'Diapositiva successiva';

  @override
  String creationsSlideOf(int index, int count) {
    return 'Diapositiva $index di $count';
  }

  @override
  String creationsElementCount(int count) {
    return '$count elementi';
  }

  @override
  String creationsRowCount(int count) {
    return '$count righe';
  }

  @override
  String creationsSlideCount(int count) {
    return '$count diapositive';
  }

  @override
  String get creationsStopTitle => 'Interrompere questa creazione?';

  @override
  String get creationsStopBody =>
      'Il risultato incompleto verrà scartato. Il tuo prompt resterà qui.';

  @override
  String get creationsDeleteTitle => 'Eliminare questa creazione?';

  @override
  String creationsDeleteBody(String title) {
    return '\"$title\" verrà rimossa da questo dispositivo.';
  }

  @override
  String get creationsOpening => 'Apertura delle creazioni';

  @override
  String get creationsGenerating => 'Generazione…';

  @override
  String get reportTitle => 'Segnala risposta IA';

  @override
  String get reportSubtitle =>
      'Aiutaci a mantenere risposte IA sicure e accurate. Le segnalazioni vengono esaminate per migliorare le protezioni di FinnAI.';

  @override
  String get reportReasonLabel => 'Motivo della segnalazione';

  @override
  String get reportIncludePrompt =>
      'Includi il mio prompt in questa segnalazione';

  @override
  String get reportResponsePreview => 'Anteprima della risposta segnalata';

  @override
  String get reportContinueHint =>
      'Continua apre una segnalazione completa indirizzata a finn_org@proton.me. Non viene inviato nulla finché non la controlli e la invii dalla tua app di posta.';

  @override
  String get reportContinueToEmail => 'Continua verso l\'email';

  @override
  String get reportReviewInEmail =>
      'Controlla la segnalazione nella tua app di posta, poi inviala.';

  @override
  String get reportNotConfigured =>
      'L\'indirizzo email per le segnalazioni non è configurato.';

  @override
  String get reportCategoryHarmful => 'Nocivo o non sicuro';

  @override
  String get reportCategoryIncorrect => 'Errato o fuorviante';

  @override
  String get reportCategoryBiased => 'Parziale o iniquo';

  @override
  String get reportCategoryOther => 'Altro';

  @override
  String get snackModelMemoryReleased => 'Memoria liberata.';

  @override
  String get settingsSavedConversationsLabel => 'Conversazioni salvate';

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
      'L\'analisi delle immagini non è ancora configurata. Aggiungi il supporto immagini nelle Impostazioni.';

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
  String get chatMoreActions => 'Altre azioni';

  @override
  String get chatHideSources => 'Nascondi fonti';

  @override
  String get chatShowSources => 'Mostra fonti';

  @override
  String get chatRewriteHint => 'Riscrivi il tuo messaggio';

  @override
  String get chatAskAnythingHint => 'Chiedi qualsiasi cosa';

  @override
  String get chatGreeting => 'Ciao, a cosa stai pensando?';

  @override
  String get voiceGreeting => 'Come va?';

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
  String get flowsActionsTooltip => 'Azioni della Flow';

  @override
  String flowsNameSemantic(String name) {
    return 'Flow $name';
  }

  @override
  String get flowsEditorNameHint => 'Cosa fa questa Flow?';

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

  @override
  String get deviceActionsTitle => 'Azioni';

  @override
  String get deviceActionsIntro =>
      'Chiedi a Finn di fare qualcosa sul tuo telefono: impostare una sveglia, avviare un timer o aprire un\'impostazione.';

  @override
  String get deviceActionsExamples => 'Prova una di queste';

  @override
  String get deviceActionsHint => 'Cosa deve fare Finn?';

  @override
  String get deviceActionsRun => 'Continua';

  @override
  String get deviceActionsResolving => 'Sto capendo cosa fare…';

  @override
  String get deviceActionsUnresolved =>
      'Non sono riuscito a trasformarlo in un\'azione. Nomina l\'impostazione o l\'app.';

  @override
  String get deviceActionsConfirm => 'Esegui';

  @override
  String get deviceActionsCancel => 'Annulla';

  @override
  String get deviceActionsAgain => 'Fai un\'altra cosa';

  @override
  String get deviceActionsOpenNotice =>
      'Android non permette alle app di cambiare da sole le impostazioni di rete: Finn apre la schermata giusta e l\'interruttore lo tocchi tu.';

  @override
  String deviceActionsResultOpened(String detail) {
    return '$detail aperto';
  }

  @override
  String deviceActionsResultPerformed(String detail) {
    return 'Fatto — $detail';
  }

  @override
  String get deviceActionsResultUnavailable =>
      'Il tuo dispositivo non può farlo';

  @override
  String get deviceActionsResultFailed => 'Non ha funzionato';

  @override
  String deviceActionsResultFailedDetail(String error) {
    return 'Non ha funzionato — $error';
  }

  @override
  String get deviceActionsExampleAlarm => 'Imposta una sveglia alle 7';

  @override
  String get deviceActionsExampleTimer => 'Avvia un timer di 10 minuti';

  @override
  String get deviceActionsExampleWifi => 'Apri le impostazioni Wi-Fi';

  @override
  String get deviceActionsExampleFlashlight => 'Accendi la torcia';

  @override
  String get deviceActionsExampleBluetooth => 'Apri le impostazioni Bluetooth';

  @override
  String deviceActionSetAlarm(String time) {
    return 'Imposta una sveglia alle $time';
  }

  @override
  String deviceActionSetTimer(String duration) {
    return 'Avvia un timer di $duration';
  }

  @override
  String get deviceActionShowAlarms => 'Apri la sveglia';

  @override
  String get deviceActionTorchOn => 'Accendi la torcia';

  @override
  String get deviceActionTorchOff => 'Spegni la torcia';

  @override
  String deviceActionMedia(String action) {
    return 'Riproduzione: $action';
  }

  @override
  String deviceActionVolume(String direction) {
    return 'Volume $direction';
  }

  @override
  String deviceActionOpenSettings(String screen) {
    return 'Apri le impostazioni $screen';
  }

  @override
  String deviceActionOpenApp(String name) {
    return 'Apri $name';
  }

  @override
  String deviceActionDial(String number) {
    return 'Apri il compositore con $number';
  }

  @override
  String get deviceActionComposeSms => 'Scrivi un nuovo SMS';

  @override
  String get deviceActionComposeEmail => 'Scrivi una nuova email';

  @override
  String get deviceActionTakePhoto => 'Apri la fotocamera';

  @override
  String deviceActionOpenUrl(String url) {
    return 'Apri $url';
  }

  @override
  String deviceActionNavigate(String query) {
    return 'Indicazioni per $query';
  }

  @override
  String get deviceActionShare => 'Condividi testo con un\'altra app';

  @override
  String get deviceActionMediaPlay => 'riproduci';

  @override
  String get deviceActionMediaPause => 'pausa';

  @override
  String get deviceActionMediaNext => 'brano successivo';

  @override
  String get deviceActionMediaPrevious => 'brano precedente';

  @override
  String get deviceActionVolumeUp => 'su';

  @override
  String get deviceActionVolumeDown => 'giù';

  @override
  String get deviceActionVolumeMute => 'muto';

  @override
  String get deviceScreenWifi => 'Wi-Fi';

  @override
  String get deviceScreenBluetooth => 'Bluetooth';

  @override
  String get deviceScreenAirplane => 'Modalità aereo';

  @override
  String get deviceScreenHotspot => 'Hotspot';

  @override
  String get deviceScreenMobileData => 'Dati mobili';

  @override
  String get deviceScreenBatterySaver => 'Risparmio batteria';

  @override
  String get deviceScreenBatteryUsage => 'Consumo batteria';

  @override
  String get deviceScreenDnd => 'Non disturbare';

  @override
  String get deviceScreenDisplay => 'Schermo';

  @override
  String get deviceScreenSound => 'Audio';

  @override
  String get deviceScreenLocation => 'Posizione';

  @override
  String get deviceScreenStorage => 'Spazio di archiviazione';

  @override
  String get deviceScreenDateTime => 'Data e ora';

  @override
  String get deviceScreenKeyboard => 'Tastiera';

  @override
  String get deviceScreenLanguage => 'Lingua';

  @override
  String get deviceScreenAccessibility => 'Accessibilità';

  @override
  String get deviceScreenApplications => 'App';

  @override
  String get deviceScreenNfc => 'NFC';

  @override
  String get deviceScreenCast => 'Trasmetti';

  @override
  String get deviceScreenVpn => 'VPN';

  @override
  String get deviceScreenDeveloper => 'Opzioni sviluppatore';

  @override
  String get deviceScreenHome => 'Schermata Home';

  @override
  String get deviceActionsResultDone => 'Fatto';

  @override
  String get settingsActionsSection => 'Azioni sul tuo dispositivo';

  @override
  String get settingsActionsRow => 'Azioni';

  @override
  String get deviceScreenSystem => 'Impostazioni';

  @override
  String get deviceActionsDismissed => 'Annullato';

  @override
  String get creationsStopped => 'Interrotto.';

  @override
  String get creationsLoadFailed =>
      'Finn non ha potuto aprire le tue creazioni salvate. Riprova.';

  @override
  String get creationsDeleteFailed =>
      'Non è stato possibile eliminare quella creazione. Riprova.';

  @override
  String get hubModelTitle => 'FinnAI Foundation';

  @override
  String hubModelSub(String size) {
    return 'Su questo dispositivo, $size';
  }

  @override
  String get hubVoiceTitle => 'Voce e lingua';

  @override
  String hubVoiceSub(String speed, String language) {
    return 'Velocità $speed, $language';
  }

  @override
  String get hubAccessTitle => 'Accesso al dispositivo';

  @override
  String get hubAccessSub => 'Calendario, contatti, file';

  @override
  String get hubYouTitle => 'Tu';

  @override
  String get hubYouSub => 'Ciò che FinnAI impara e usa';

  @override
  String get hubDataTitle => 'Privacy e dati';

  @override
  String get hubDataSub => 'Spazio, esporta, cancella';

  @override
  String get hubAboutTitle => 'Informazioni';

  @override
  String hubAboutSub(String version) {
    return 'Versione $version';
  }

  @override
  String modelVersion(String version) {
    return 'Versione $version';
  }

  @override
  String modelStored(String size, String date) {
    return '$size del tuo spazio, scaricato il $date.';
  }

  @override
  String modelStoredNoDate(String size) {
    return '$size del tuo spazio.';
  }

  @override
  String get modelNotInstalled => 'Non ancora scaricato.';

  @override
  String get modelOffline => 'Lavora offline';

  @override
  String get modelOfflineSub => 'Tutto funziona su questo dispositivo';

  @override
  String get modelLookups => 'Cerca online';

  @override
  String get modelLookupsSub =>
      'Solo quando una domanda lo richiede. Le tue chat e Tu restano qui.';

  @override
  String get modelUpdates => 'Controlla aggiornamenti';

  @override
  String get modelUpToDate => 'Aggiornato';

  @override
  String get modelRemove => 'Rimuovi il modello';

  @override
  String modelRemoveSub(String size) {
    return 'Libera $size';
  }

  @override
  String get modelRemoveTitle => 'Rimuovere il modello?';

  @override
  String get modelRemoveBody =>
      'FinnAI deve scaricarlo di nuovo prima che tu possa chattare. Le tue chat restano.';

  @override
  String get modelRemoveConfirm => 'Rimuovi';

  @override
  String get voiceReadAloud => 'Leggi le risposte ad alta voce';

  @override
  String get voiceReadAloudSub => 'Nelle chat vocali';

  @override
  String get voiceTranscript => 'Mostra trascrizione in diretta';

  @override
  String get voiceTranscriptSub => 'Mentre parli';

  @override
  String get voiceSpeed => 'Velocità di parlato';

  @override
  String get voiceSpeedSlow => 'Lenta';

  @override
  String get voiceSpeedNormal => 'Normale';

  @override
  String get voiceSpeedFast => 'Veloce';

  @override
  String get voiceLanguage => 'Lingua';

  @override
  String get voiceLanguageSub => 'Segue il tuo dispositivo';

  @override
  String get accessIntro =>
      'FinnAI legge solo ciò che consenti, e solo su questo dispositivo.';

  @override
  String get accessMaster => 'Usa il contesto di questo dispositivo';

  @override
  String get accessMasterSub => 'Disattiva per far smettere FinnAI di leggere';

  @override
  String get accessActions => 'Azioni sul tuo dispositivo';

  @override
  String get accessActionsSub => 'Sveglie, timer, impostazioni';

  @override
  String get ctxCalendar => 'Calendario';

  @override
  String get ctxCalendarSub => 'Eventi e tempo libero';

  @override
  String get ctxContacts => 'Contatti';

  @override
  String get ctxContactsSub => 'Nomi e relazioni';

  @override
  String get ctxNotifications => 'Notifiche';

  @override
  String get ctxNotificationsSub => 'Cosa richiede la tua attenzione';

  @override
  String get ctxPhotos => 'Foto';

  @override
  String get ctxPhotosSub => 'Solo quando le allegi';

  @override
  String get ctxFiles => 'File';

  @override
  String get ctxFilesSub => 'Documenti che apri con FinnAI';

  @override
  String get ctxLocation => 'Posizione';

  @override
  String get ctxLocationSub => 'Solo mentre l’app è aperta';

  @override
  String get dataStoredHere => 'Salvato su questo dispositivo';

  @override
  String get dataChats => 'Chat';

  @override
  String get dataCreations => 'Creazioni';

  @override
  String get dataYou => 'Tu';

  @override
  String get dataModel => 'FinnAI Foundation';

  @override
  String get dataExport => 'Esporta tutto';

  @override
  String get dataExportSub => 'Chat, creazioni, flussi e Tu';

  @override
  String get dataDeleteChats => 'Elimina tutte le chat';

  @override
  String get dataDeleteChatsSub => 'Tu resta com’è';

  @override
  String get dataErase => 'Cancella tutto';

  @override
  String get dataEraseSub => 'Reimposta FinnAI su questo dispositivo';

  @override
  String get dataExportFailed => 'Impossibile esportare. Riprova.';

  @override
  String get aboutBlurb =>
      'Un assistente privato che funziona sul tuo dispositivo.';

  @override
  String get aboutPrivacy => 'Informativa sulla privacy';

  @override
  String get aboutTerms => 'Termini di utilizzo';

  @override
  String get aboutLicences => 'Licenze open source';

  @override
  String get aboutFeedback => 'Invia feedback';

  @override
  String chatUsedFromYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cose',
      one: '1 cosa',
    );
    return 'Usate $_temp0 da Tu';
  }

  @override
  String get youAboutTitle => 'Cosa sa FinnAI di te';

  @override
  String youUpdated(String when) {
    return 'Aggiornato $when';
  }

  @override
  String youReviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novità da rivedere',
      one: '1 novità da rivedere',
    );
    return '$_temp0';
  }

  @override
  String get youReviewSub => 'Notato nelle tue chat recenti';

  @override
  String youCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cose',
      one: '1 cosa',
    );
    return '$_temp0';
  }

  @override
  String get youStoredOnly => 'Salvato solo su questo dispositivo';

  @override
  String get youCatPeople => 'Persone';

  @override
  String get youCatWork => 'Lavoro';

  @override
  String get youCatRoutines => 'Routine';

  @override
  String get youCatPreferences => 'Preferenze';

  @override
  String get youCatPlaces => 'Luoghi';

  @override
  String get youCatInterests => 'Interessi';

  @override
  String get youEmptyTitle => 'Sto ancora imparando a conoscerti';

  @override
  String get youEmptyBody =>
      'Mentre chatti, FinnAI impara ciò che aiuta e lo tiene qui, su questo dispositivo. Puoi anche scrivere qualcosa tu stesso.';

  @override
  String get youTellFinn => 'Parla di te a FinnAI';

  @override
  String get youPrivacyTitle => 'Privacy';

  @override
  String youCategoryIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cose che FinnAI ricorda. Tocca una per vedere da dove viene.',
      one: '1 cosa che FinnAI ricorda. Tocca per vedere da dove viene.',
    );
    return '$_temp0';
  }

  @override
  String get youCategoryEmpty =>
      'Ancora niente. Tocca più per aggiungere qualcosa.';

  @override
  String youSeenIn(String where) {
    return 'Visto in $where';
  }

  @override
  String get youSeenInLabel => 'Visto in';

  @override
  String get youAddedByYou => 'Aggiunto da te';

  @override
  String youLearnedOn(String when) {
    return 'Imparato $when. Salvato su questo dispositivo.';
  }

  @override
  String get youEdit => 'Modifica';

  @override
  String get youDoNotUse => 'Non usare nelle chat';

  @override
  String get youForgetThis => 'Dimentica questo';

  @override
  String get youForgetTitle => 'Dimenticare questo?';

  @override
  String get youForgetBody =>
      'FinnAI smette di usarlo nelle chat. Se lo menzioni di nuovo, può essere imparato di nuovo.';

  @override
  String get youForgetConfirm => 'Dimentica';

  @override
  String get youAddLabel => 'Con parole tue';

  @override
  String get youAddHint =>
      'Qualcosa che FinnAI deve ricordare, come il tuo modo di lavorare o chi è importante per te.';

  @override
  String get youWhereBelongs => 'Dove va';

  @override
  String get youUseEveryChat => 'Usa in ogni chat';

  @override
  String get youUseEveryChatSub => 'Disattiva per usarlo solo quando lo chiedi';

  @override
  String get youSaveToYou => 'Salva in Tu';

  @override
  String get youReviewTitleBar => 'Rivedi';

  @override
  String get youReviewIntro =>
      'FinnAI ha notato queste cose nelle chat recenti. Tieni ciò che è giusto e dimentica il resto.';

  @override
  String get youReviewEmpty => 'Niente da rivedere per ora.';

  @override
  String get youKeep => 'Tieni';

  @override
  String youFrom(String category, String chat) {
    return '$category, da $chat';
  }

  @override
  String get youPrivacyNote =>
      'Tutto in Tu è salvato su questo dispositivo. FinnAI non lo invia da nessuna parte.';

  @override
  String get youLearn => 'Impara dalle conversazioni';

  @override
  String get youLearnSub => 'FinnAI suggerisce cosa aggiungere dopo le chat';

  @override
  String get youUseInChats => 'Usa Tu nelle nuove chat';

  @override
  String get youUseInChatsSub => 'Puoi disattivarlo per chat';

  @override
  String get youLearnAbout => 'Impara su';

  @override
  String get youExport => 'Esporta Tu';

  @override
  String get youExportSub => 'Salva una copia come file';

  @override
  String get youErase => 'Cancella tutto in Tu';

  @override
  String youEraseSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cose',
      one: '1 cosa',
    );
    return 'Rimuove $_temp0';
  }

  @override
  String get youEraseTitle => 'Cancellare tutto in Tu?';

  @override
  String get youEraseBody =>
      'Tutto ciò che FinnAI ricorda viene rimosso da questo dispositivo. Le tue chat restano.';

  @override
  String get youEraseConfirm => 'Cancella';

  @override
  String get youPersonalise => 'Stile e istruzioni di risposta';

  @override
  String get youPersonaliseSub => 'Nome, tono e istruzioni personali';

  @override
  String get youRemembered => 'Salvato in Tu';

  @override
  String get youWhenToday => 'oggi';

  @override
  String youWhenMinutes(int count) {
    return '$count minuti fa';
  }

  @override
  String youWhenHours(int count) {
    return '$count ore fa';
  }

  @override
  String youWhenDays(int count) {
    return '$count giorni fa';
  }

  @override
  String get youWhenJustNow => 'proprio ora';

  @override
  String get searchHint => 'Cerca';

  @override
  String get searchChatsHeading => 'Chat';

  @override
  String get searchCreationsHeading => 'Creazioni';

  @override
  String get searchNothing => 'Nessun risultato';

  @override
  String get searchPrompt => 'Cerca nelle tue chat, creazioni e Tu.';

  @override
  String get chatReadAloud => 'Leggi ad alta voce';

  @override
  String get chatRememberInYou => 'Ricorda in Tu';

  @override
  String get chatShare => 'Condividi';

  @override
  String get plusCreate => 'Crea';

  @override
  String get plusWidget => 'Widget';

  @override
  String get plusWidgetSub => 'Per la tua schermata Home';

  @override
  String get plusMiniApp => 'Mini app';

  @override
  String get plusMiniAppSub => 'Un piccolo strumento';

  @override
  String get plusPresentation => 'Presentazione';

  @override
  String get plusPresentationSub => 'Slide da condividere';

  @override
  String get plusFlow => 'Flusso';

  @override
  String get plusFlowSub => 'Si avvia da solo';

  @override
  String get plusAddToChat => 'Aggiungi alla chat';

  @override
  String get plusPhoto => 'Foto';

  @override
  String optionsStarted(String when) {
    return 'Iniziata $when. Salvata su questo dispositivo.';
  }

  @override
  String get optionsPin => 'Fissa chat';

  @override
  String get optionsUnpin => 'Rimuovi dai fissati';

  @override
  String get optionsExport => 'Esporta come testo';

  @override
  String get optionsDelete => 'Elimina chat';

  @override
  String get deleteChatTitle => 'Eliminare questa chat?';

  @override
  String get deleteChatBody =>
      'Viene rimossa da questo dispositivo. Ciò che FinnAI ha imparato resta in Tu finché non lo dimentichi.';

  @override
  String get fromYouTitle => 'Da Tu';

  @override
  String get fromYouSub =>
      'FinnAI ha usato questi in questa chat. Niente lascia il tuo dispositivo.';

  @override
  String get fromYouUse => 'Usa Tu in questa chat';

  @override
  String get fromYouOpen => 'Apri Tu';

  @override
  String get chatRenamePrompt => 'Rinomina chat';

  @override
  String get flowsSearchEmpty => 'Nessun flow corrisponde a questa ricerca.';

  @override
  String get flowsPickerDevice => 'Dispositivo';

  @override
  String get flowsPickerLogic => 'Logica';

  @override
  String get flowsPickerEmpty =>
      'Nessun passaggio corrisponde a questa ricerca.';

  @override
  String get flowsFilterAll => 'Tutti';

  @override
  String get flowsFilterActive => 'Attivi';

  @override
  String get flowsFilterPaused => 'In pausa';

  @override
  String get flowsPhoneOn =>
      'I flussi funzionano su questo dispositivo, quindi il telefono deve essere acceso.';

  @override
  String get flowsOnlyWhenAsked => 'Solo quando lo chiedo';

  @override
  String flowsLastRunLine(String when, String result) {
    return 'Ultima esecuzione $when, $result';
  }

  @override
  String get flowsNeverRun => 'Non ancora eseguito';

  @override
  String get flowsPausedLine => 'In pausa';

  @override
  String get flowsResultDone => 'fatto';

  @override
  String get flowsResultFailed => 'non riuscito';

  @override
  String get flowsResultStopped => 'interrotto';

  @override
  String get flowsWhenToday => 'oggi';

  @override
  String get flowsWhenYesterday => 'ieri';

  @override
  String get flowsEmptyTitle => 'Ancora nessun flusso';

  @override
  String get flowsEmptyBody =>
      'Un flusso svolge un compito per te a un orario o quando succede qualcosa. Descrivine uno in chat.';

  @override
  String get flowsEmptyCreate => 'Crea un flusso';

  @override
  String get flowsNewTitle => 'Nuovo flusso';

  @override
  String get flowsNewSub => 'Inizia con parole, un orario o un evento.';

  @override
  String get flowsNewDescribe => 'Descrivilo';

  @override
  String get flowsNewDescribeSub => 'Di a FinnAI cosa deve succedere';

  @override
  String get flowsNewTime => 'A un orario fisso';

  @override
  String get flowsNewTimeSub => 'Ogni giorno, settimana o mese';

  @override
  String get flowsNewEvent => 'Quando succede qualcosa';

  @override
  String get flowsNewEventSub => 'Ricarica, arrivo, una notifica';

  @override
  String flowsDetailOn(String when) {
    return 'Attivo, prossima esecuzione $when';
  }

  @override
  String get flowsDetailOnManual => 'Attivo, parte quando lo chiedi';

  @override
  String get flowsDetailPaused => 'In pausa';

  @override
  String get flowsWhen => 'Quando';

  @override
  String get flowsThen => 'Poi';

  @override
  String get flowsRecentRuns => 'Esecuzioni recenti';

  @override
  String get flowsNoRunsYet => 'Nessuna esecuzione';

  @override
  String get flowsRunStatusDone => 'Fatto';

  @override
  String get flowsRunStatusFailed => 'Non completato';

  @override
  String get flowsRunStatusDeclined => 'Non consentito';

  @override
  String get flowsRunStatusNeedsGrant => 'Serve il tuo permesso';

  @override
  String get flowsRunStatusStopped => 'Interrotto';

  @override
  String get flowsMenuEdit => 'Modifica';

  @override
  String get flowsMenuPause => 'Metti in pausa';

  @override
  String get flowsMenuResume => 'Attiva';

  @override
  String get flowsMenuDuplicate => 'Duplica';

  @override
  String get flowsMenuDelete => 'Elimina';

  @override
  String get flowsRunFinished => 'Completato';

  @override
  String flowsRunFinishedIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondi',
      one: '1 secondo',
    );
    return 'Completato in $_temp0';
  }

  @override
  String get flowsRunAgain => 'Esegui di nuovo';

  @override
  String get flowsBuilderHint => 'Descrivi cosa deve succedere';

  @override
  String get flowsBuilderHere => 'Ecco il flusso. Controllalo, poi attivalo.';

  @override
  String get flowsBuilderNoMatch =>
      'Non so ancora costruirlo. Scegline uno e lo preparo.';

  @override
  String get flowsBuilderTurnOn => 'Attiva';

  @override
  String get flowsStartWhen => 'Avvia quando';

  @override
  String get flowsTriggerTime => 'A un orario fisso';

  @override
  String get flowsTriggerTimeSub => 'Ogni giorno, settimana o mese';

  @override
  String get flowsTriggerPlace => 'Arrivo o partenza';

  @override
  String get flowsTriggerPlaceSub => 'Un luogo a tua scelta';

  @override
  String get flowsTriggerCharging => 'Ricarica';

  @override
  String get flowsTriggerChargingSub => 'Quando colleghi o scolleghi';

  @override
  String get flowsTriggerBattery => 'Livello batteria';

  @override
  String get flowsTriggerBatterySub => 'Sotto o sopra un livello';

  @override
  String get flowsTriggerNotification => 'Una notifica';

  @override
  String get flowsTriggerNotificationSub => 'Quando ne arriva una da un’app';

  @override
  String get flowsTriggerManual => 'Solo quando lo chiedo';

  @override
  String get flowsTriggerManualSub => 'Avvialo tu';

  @override
  String get flowsTriggerSoon => 'Non ancora disponibile';

  @override
  String get flowsScheduleSheetTitle => 'Programma';

  @override
  String get flowsScheduleSave => 'Salva programma';

  @override
  String flowsAllowTitle(String name) {
    return 'Consentire a $name di agire sul tuo telefono?';
  }

  @override
  String get flowsAllowConfirm => 'Consenti';

  @override
  String flowsDeleteNamed(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get flowsDeleteNamedBody =>
      'Anche le esecuzioni passate vengono rimosse. Non si può annullare.';

  @override
  String flowsStepLookUp(String query) {
    return 'Cerca $query';
  }

  @override
  String get flowsStepWrite => 'Scrivere la risposta';

  @override
  String get creationsNewSheetSub =>
      'Descrivilo in chat. FinnAI lo crea su questo dispositivo.';

  @override
  String get creationsNewWidgetSub =>
      'Piccoli strumenti per la tua schermata Home';

  @override
  String get creationsNewAppSub =>
      'Uno strumento semplice che funziona dentro FinnAI';

  @override
  String get creationsNewDeckSub => 'Slide da presentare o condividere';

  @override
  String get creationsMenuEditWithFinn => 'Modifica con FinnAI';

  @override
  String get creationsMenuDuplicate => 'Duplica';

  @override
  String get creationsMenuShare => 'Condividi';

  @override
  String creationsDeleteNamed(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get creationsDeleteNamedBody =>
      'Viene rimosso da Creazioni e dalla tua schermata Home. Non si può annullare.';

  @override
  String get creationsSizeSmall => 'Piccolo';

  @override
  String get creationsSizeMedium => 'Medio';

  @override
  String get creationsSizeLarge => 'Grande';

  @override
  String get creationsUpdatesOnDevice =>
      'Si aggiorna su questo dispositivo. Niente lascia il tuo dispositivo.';

  @override
  String get creationsMadeInChat => 'Creato in chat';

  @override
  String get creationsDataLabel => 'Dati';

  @override
  String get creationsDataSub => 'Salvati dentro questo widget';

  @override
  String creationsAddHomeTitle(String name) {
    return 'Aggiungere $name alla tua schermata Home?';
  }

  @override
  String get creationsAddHomeBody =>
      'Si comporta come qualsiasi altro widget. Puoi spostarlo o rimuoverlo più tardi.';

  @override
  String get creationsAddHomeConfirm => 'Aggiungi';

  @override
  String get creationsBuilderTitleWidget => 'Nuovo widget';

  @override
  String get creationsBuilderTitleApp => 'Nuova mini app';

  @override
  String get creationsBuilderTitleDeck => 'Nuova presentazione';

  @override
  String get creationsBuilderHint => 'Descrivi cosa costruire';

  @override
  String get creationsBuilderChangeHint => 'Chiedi modifiche';

  @override
  String get creationsBuilderGotIt =>
      'Capito. Lo costruisco su questo dispositivo.';

  @override
  String get creationsBuilderReady => 'Eccolo. Aprilo o continua a modificare.';

  @override
  String get creationsSaveToCreations => 'Salva in Creazioni';

  @override
  String get creationsKeepEditing => 'Continua a modificare';

  @override
  String get creationsSpeakerNotes => 'Note del relatore';

  @override
  String get creationsPresent => 'Presenta';

  @override
  String get creationsDuplicated => 'Duplicato.';

  @override
  String get onboardingChooseTitle => 'Scegli cosa può vedere FinnAI';

  @override
  String get onboardingChooseBody =>
      'Puoi cambiarlo in qualsiasi momento nelle Impostazioni. Tutto resta su questo dispositivo.';

  @override
  String get onboardingDownloadPausedTitle => 'Download in pausa';

  @override
  String get onboardingDownloadPausedBody =>
      'In attesa di connessione, i tuoi progressi sono salvati.';

  @override
  String get onboardingDownloadPausedNote => 'Riprende quando torni online.';

  @override
  String get flowsStepNotifyMe => 'Avvisami';

  @override
  String get creationsTemplateTracker => 'Tracker';

  @override
  String get creationsSlotStep => 'Aggiunto a ogni tocco';

  @override
  String get creationsResetAppTitle => 'Reimpostare questa app?';

  @override
  String get creationsResetAppBody =>
      'Tutto ciò che hai aggiunto viene cancellato. Non si può annullare.';

  @override
  String get deviceActionVibrate => 'Far vibrare il telefono';

  @override
  String get flowsTrigManual => 'Solo quando lo avvio';

  @override
  String get flowsTrigTimeOfDay => 'A un orario preciso';

  @override
  String flowsTrigEveryMinutes(int n) {
    return 'Ogni $n minuti';
  }

  @override
  String flowsTrigEveryHours(int n) {
    return 'Ogni $n ore';
  }

  @override
  String get flowsTrigEveryHour => 'Ogni ora';

  @override
  String get flowsTrigInterval => 'Ripetuto';

  @override
  String get flowsTrigChargerOn => 'Caricatore collegato';

  @override
  String get flowsTrigChargerOff => 'Caricatore scollegato';

  @override
  String flowsTrigBatteryLow(int n) {
    return 'La batteria scende al $n%';
  }

  @override
  String get flowsTrigHeadsetOn => 'Cuffie collegate';

  @override
  String get flowsTrigHeadsetOff => 'Cuffie scollegate';

  @override
  String get flowsTrigWifiOn => 'Wi‑Fi connesso';

  @override
  String get flowsTrigWifiOff => 'Wi‑Fi disconnesso';

  @override
  String get flowsTrigAirplaneOn => 'Si attiva la modalità aereo';

  @override
  String get flowsTrigAirplaneOff => 'Si disattiva la modalità aereo';

  @override
  String get flowsTrigBoot => 'Il telefono si avvia';

  @override
  String get flowsTrigUnlock => 'Schermo sbloccato';

  @override
  String get flowsTrigGroupTime => 'Orario';

  @override
  String get flowsTrigGroupPhone => 'Sul telefono';

  @override
  String get flowsTrigGroupHand => 'A mano';

  @override
  String flowsCondBatteryBelow(int n) {
    return 'Batteria sotto il $n%';
  }

  @override
  String flowsCondBatteryAbove(int n) {
    return 'Batteria sopra il $n%';
  }

  @override
  String get flowsCondCharging => 'In carica';

  @override
  String get flowsCondNotCharging => 'Non in carica';

  @override
  String flowsCondTimeBetween(String from, String to) {
    return 'Tra le $from e le $to';
  }

  @override
  String flowsCondDays(String days) {
    return 'Il $days';
  }

  @override
  String get flowsCondWifiOn => 'Wi‑Fi connesso';

  @override
  String get flowsCondWifiOff => 'Wi‑Fi non connesso';

  @override
  String get flowsCondHeadsetOn => 'Cuffie collegate';

  @override
  String get flowsCondHeadsetOff => 'Cuffie non collegate';

  @override
  String get flowsCondAirplaneOn => 'Modalità aereo attiva';

  @override
  String get flowsCondAirplaneOff => 'Modalità aereo spenta';

  @override
  String flowsCondAnswer(String text) {
    return 'La risposta contiene «$text»';
  }

  @override
  String get flowsBlockAsk => 'Chiedi a FinnAI';

  @override
  String get flowsBlockAskSub =>
      'Scrivere qualcosa con il modello sul dispositivo';

  @override
  String get flowsBlockWeb => 'Cerca';

  @override
  String get flowsBlockWebSub => 'Notizie, meteo o il web';

  @override
  String get flowsBlockNotify => 'Avvisami';

  @override
  String get flowsBlockNotifySub => 'Mostra una notifica';

  @override
  String get flowsBlockSpeak => 'Dillo ad alta voce';

  @override
  String get flowsBlockSpeakSub => 'Parla con la voce del telefono';

  @override
  String get flowsBlockAction => 'Fai sul telefono';

  @override
  String get flowsBlockActionSub => 'Torcia, volume, sveglia, apri un’app';

  @override
  String get flowsBlockWait => 'Attendi';

  @override
  String get flowsBlockWaitSub => 'Pausa di qualche secondo';

  @override
  String get flowsBlockBranch => 'Se … allora';

  @override
  String get flowsBlockBranchSub => 'Fai una cosa o l’altra';

  @override
  String get flowsBlockSave => 'Salva nella chat';

  @override
  String get flowsBlockSaveSub => 'Tieni la risposta come chat';

  @override
  String get flowsBlockStop => 'Fermati qui';

  @override
  String get flowsBlockStopSub => 'Termina il flusso';

  @override
  String flowsSumAsk(String text) {
    return 'Chiedi: $text';
  }

  @override
  String flowsSumWeb(String text) {
    return 'Cerca $text';
  }

  @override
  String get flowsSumNotifyAnswer => 'Mostra la risposta';

  @override
  String get flowsSumSpeakAnswer => 'Leggi la risposta ad alta voce';

  @override
  String flowsSumWait(int n) {
    return 'Attendi $n s';
  }

  @override
  String flowsSumIf(String condition) {
    return 'Se $condition';
  }

  @override
  String get flowsEdWhen => 'Quando';

  @override
  String get flowsEdOnlyIf => 'Solo se';

  @override
  String get flowsEdThen => 'Poi';

  @override
  String get flowsEdOr => 'oppure';

  @override
  String get flowsEdYes => 'Sì';

  @override
  String get flowsEdOtherwise => 'Altrimenti';

  @override
  String get flowsEdEnd => 'Fine';

  @override
  String get flowsEdAddTrigger => 'Aggiungi un avvio';

  @override
  String get flowsEdAddCondition => 'Aggiungi una condizione';

  @override
  String get flowsEdAddStep => 'Aggiungi un passaggio';

  @override
  String get flowsEdInsertHere => 'Aggiungi un passaggio qui';

  @override
  String get flowsEdNoSteps =>
      'Ancora niente da fare. Aggiungi il primo passaggio.';

  @override
  String get flowsEdManualStart => 'Parte quando tocchi Esegui';

  @override
  String get flowsEdMoveUp => 'Su';

  @override
  String get flowsEdMoveDown => 'Giù';

  @override
  String get flowsEdRemove => 'Rimuovi';

  @override
  String get flowsEdDone => 'Fatto';

  @override
  String get flowsEdChooseStep => 'Cosa deve succedere?';

  @override
  String get flowsEdChooseTrigger => 'Cosa lo avvia?';

  @override
  String get flowsEdChooseCondition => 'Solo quando…';

  @override
  String get flowsEdConditionNote =>
      'Se non è vero, il flusso non parte quando lo avvia qualcos’altro.';

  @override
  String get flowsFieldPrompt => 'Cosa deve scrivere FinnAI?';

  @override
  String flowsFieldPromptHint(String input) {
    return 'Usa $input per l’ultima risposta';
  }

  @override
  String get flowsFieldQuery => 'Cosa cercare';

  @override
  String get flowsFieldSource => 'Dove';

  @override
  String get flowsSourceWeb => 'Il web';

  @override
  String get flowsSourceNews => 'Notizie';

  @override
  String get flowsSourceWeather => 'Meteo';

  @override
  String get flowsFieldTitle => 'Titolo';

  @override
  String get flowsFieldMessage => 'Messaggio';

  @override
  String get flowsFieldMessageHint =>
      'Lascia vuoto per mostrare l’ultima risposta';

  @override
  String get flowsFieldSay => 'Cosa dire';

  @override
  String get flowsFieldSayHint => 'Lascia vuoto per leggere l’ultima risposta';

  @override
  String get flowsFieldSeconds => 'Quanti secondi';

  @override
  String get flowsFieldAction => 'Cosa fare';

  @override
  String get flowsFieldCondition => 'Condizione';

  @override
  String get flowsFieldLevel => 'Livello batteria';

  @override
  String get flowsFieldFrom => 'Da';

  @override
  String get flowsFieldTo => 'A';

  @override
  String get flowsFieldDays => 'Giorni';

  @override
  String get flowsFieldContains => 'Contiene';

  @override
  String get flowsFieldEveryMinutes => 'Ripeti ogni';

  @override
  String get flowsUnitMinutes => 'minuti';

  @override
  String get flowsUnitHours => 'ore';

  @override
  String get flowsBgWorks => 'Funziona in background';

  @override
  String get flowsBgNeedsScreen => 'Devi toccare una notifica';

  @override
  String get flowsAutoTitle => 'Lascia che parta da solo';

  @override
  String get flowsAutoNeedsAllow =>
      'Questo flusso modifica il telefono. Consenti che parta quando non guardi.';

  @override
  String get flowsListenerOn => 'FinnAI ascolta questi eventi in background.';

  @override
  String get flowsListenerNeedsNotify =>
      'Attiva le notifiche così FinnAI può continuare ad ascoltare.';

  @override
  String get flowsRunStatusSkipped => 'Condizioni non soddisfatte';

  @override
  String get flowsRunStatusNeedsScreen => 'In attesa di te';

  @override
  String get flowsRunSkipped => 'Saltato';

  @override
  String get flowsRunNeedsScreen => 'Tocca per finire';

  @override
  String get flowsRunByEvent => 'È partito da solo';

  @override
  String get flowsRunByChat => 'Avviato dalla chat';

  @override
  String flowsNeedsScreenBody(String name) {
    return 'Tocca per finire «$name»: serve lo schermo.';
  }

  @override
  String flowsNeedsGrantBody(String name) {
    return '«$name» voleva partire ma serve prima il tuo permesso.';
  }

  @override
  String get flowsStepWaiting => 'In attesa';

  @override
  String flowsPathStep(int n) {
    return 'Passaggio $n';
  }

  @override
  String get flowsDescribeTitle => 'Descrivi il tuo flusso';

  @override
  String get flowsDescribeHint =>
      'Per esempio: quando collego il caricatore, accendi la torcia';

  @override
  String get flowsDescribeBuild => 'Crea';

  @override
  String get flowsDescribeThinking => 'Ci sto pensando…';

  @override
  String get flowsDescribeFailed =>
      'Non sono riuscito a farne un flusso. Dì quando parte e cosa deve fare.';

  @override
  String flowsDescribeMissed(String parts) {
    return 'Non ho capito: $parts';
  }

  @override
  String get flowsDescribeExamples => 'Prova uno di questi';

  @override
  String get flowsExampleCharger =>
      'Quando collego il caricatore, accendi la torcia';

  @override
  String get flowsExampleBattery =>
      'Quando la batteria è sotto il 15%, ricordami di caricare';

  @override
  String get flowsExampleNews => 'Ogni mattina alle 7 dimmi le notizie';

  @override
  String get flowsExampleHeadset =>
      'Quando collego le cuffie, riproduci la musica';

  @override
  String get flowsNewBlank => 'Parti da zero';

  @override
  String get flowsNewBlankSub => 'Costruiscilo passo dopo passo';

  @override
  String get flowsNewTemplates => 'Da un modello';

  @override
  String get flowsNewTemplatesSub => 'Notizie, promemoria, batteria scarica…';

  @override
  String get flowsTemplateLowBattery => 'Avviso batteria scarica';

  @override
  String get flowsTemplateLowBatteryBody =>
      'Ti avvisa una volta quando la batteria è scarica.';

  @override
  String get flowsTemplateHeadset => 'Cuffie e musica';

  @override
  String get flowsTemplateHeadsetBody =>
      'Riproduce o mette in pausa quando si collegano le cuffie.';

  @override
  String get flowsSlotLevel => 'Avvisa al (%)';

  @override
  String get flowsSlotWhat => 'Cosa fare';

  @override
  String get flowsSlotPlay => 'Riproduci';

  @override
  String get flowsSlotPause => 'Pausa';

  @override
  String get flowsRunsTitle => 'Esecuzioni';

  @override
  String get flowsRunsAll => 'Vedi tutte le esecuzioni';

  @override
  String get flowsRenameTitle => 'Rinomina flusso';

  @override
  String get flowsSavedToast => 'Salvato';

  @override
  String get flowsStepOutcomeSkipped => 'Saltato';

  @override
  String flowsChatCreated(String name) {
    return 'Ho creato un flusso: «$name». Controllalo e attivalo.';
  }

  @override
  String get flowsChatOpen => 'Apri flusso';

  @override
  String get flowsChatTurnOn => 'Attiva';

  @override
  String get flowsChatIsOn => 'Attivato';

  @override
  String get flowsChatDiscard => 'Scarta';

  @override
  String get flowsActSetAlarm => 'Imposta una sveglia';

  @override
  String get flowsActSetTimer => 'Avvia un timer';

  @override
  String get flowsActShowAlarms => 'Mostra le sveglie';

  @override
  String get flowsActTorch => 'Torcia';

  @override
  String get flowsActMedia => 'Controlla la musica';

  @override
  String get flowsActVolume => 'Cambia il volume';

  @override
  String get flowsActVibrate => 'Vibra';

  @override
  String get flowsActOpenSettings => 'Apri un’impostazione';

  @override
  String get flowsActOpenApp => 'Apri un’app';

  @override
  String get flowsActDial => 'Avvia una chiamata';

  @override
  String get flowsActSms => 'Scrivi un SMS';

  @override
  String get flowsActEmail => 'Scrivi un’email';

  @override
  String get flowsActPhoto => 'Apri la fotocamera';

  @override
  String get flowsActUrl => 'Apri un indirizzo web';

  @override
  String get flowsActNavigate => 'Ottieni indicazioni';

  @override
  String get flowsActShare => 'Condividi testo';

  @override
  String get flowsOn => 'Acceso';

  @override
  String get flowsOff => 'Spento';

  @override
  String get flowsParamState => 'Stato';

  @override
  String get flowsParamDirection => 'Direzione';

  @override
  String get flowsParamScreen => 'Schermata';

  @override
  String get flowsParamTime => 'Orario';

  @override
  String get flowsParamSeconds => 'Secondi';

  @override
  String get flowsParamMilliseconds => 'Millisecondi';

  @override
  String get flowsParamLabel => 'Etichetta';

  @override
  String get flowsParamName => 'Nome dell’app';

  @override
  String get flowsParamNumber => 'Numero di telefono';

  @override
  String get flowsParamTo => 'A';

  @override
  String get flowsParamBody => 'Messaggio';

  @override
  String get flowsParamSubject => 'Oggetto';

  @override
  String get flowsParamUrl => 'Indirizzo web';

  @override
  String get flowsParamQuery => 'Luogo o indirizzo';

  @override
  String get flowsParamText => 'Testo';

  @override
  String get flowsPickAction => 'Cosa deve fare il telefono?';

  @override
  String get flowsEveryHowLong => 'Ripeti ogni';

  @override
  String get flowsIntervalNote =>
      'Il telefono raggruppa i timer per risparmiare batteria, quindi può ritardare di qualche minuto.';

  @override
  String get flowsBatteryLevelNote =>
      'Parte una volta quando la batteria scende a questo livello.';

  @override
  String get chatCreationReady =>
      'Ecco qui. Aprilo o mettilo nella schermata Home.';

  @override
  String get chatCreationBuilding => 'Lo sto creando…';

  @override
  String get flowsDetailOnEvent => 'Attivo, parte da solo';

  @override
  String get voiceStyle => 'Voce';

  @override
  String get voiceStyleF1 => 'Femminile 1';

  @override
  String get voiceStyleF2 => 'Femminile 2';

  @override
  String get voiceStyleM1 => 'Maschile 1';

  @override
  String get voiceStyleM2 => 'Maschile 2';

  @override
  String get appBrandFinnAICode => 'FinnAI Code';

  @override
  String get appModeSwitchSemantic => 'Passa tra FinnAI e FinnAI Code';

  @override
  String get codeGreeting => 'Cosa costruiamo?';

  @override
  String get codeGreetingCaption =>
      'Il tuo progetto vive in una cartella privata su questo dispositivo.';

  @override
  String get codeComposerHint => 'Descrivi un compito';

  @override
  String get codeNewSession => 'Nuova sessione';

  @override
  String get codeSessionsTitle => 'Sessioni';

  @override
  String get codeNoSessions => 'Ancuna sessione per ora';

  @override
  String get codeFilesTitle => 'File';

  @override
  String get codeTerminalTitle => 'Terminale';

  @override
  String get codeModelsTitle => 'Modelli';

  @override
  String get codeSettingsTitle => 'Impostazioni di Code';

  @override
  String get codeLocalLabel => 'FinnAI · sul dispositivo';

  @override
  String codeModelChipSemantic(String model) {
    return 'Scegli un modello. Attuale: $model';
  }

  @override
  String get codePermissionAsk => 'Chiedi prima';

  @override
  String get codePermissionEdits => 'Modifica auto';

  @override
  String get codePermissionAuto => 'Esecuzione auto';

  @override
  String codePermissionSemantic(String mode) {
    return 'Cambia cosa può fare l’agente. Attuale: $mode';
  }

  @override
  String get codeThinking => 'Sto pensando…';

  @override
  String get codeActionRunCommand => 'Esegui comando';

  @override
  String codeActionWriteFile(String path) {
    return 'Scrivi $path';
  }

  @override
  String get codeActionRun => 'Esegui';

  @override
  String get codeActionAllow => 'Consenti';

  @override
  String get codeActionSkip => 'Salta';

  @override
  String get codeActionRunning => 'In esecuzione…';

  @override
  String get codeActionDone => 'Fatto';

  @override
  String codeActionFailedExit(String code) {
    return 'Non riuscito (codice $code)';
  }

  @override
  String get codeSessionsPinned => 'Fissate';

  @override
  String get codeSessionsToday => 'Oggi';

  @override
  String get codeSessionsEarlier => 'Precedenti';

  @override
  String get codeSessionWorking => 'In corso';

  @override
  String get codeSessionNeedsYou => 'Serve il tuo ok';

  @override
  String get codeSessionNoChanges => 'Nessuna modifica';

  @override
  String get codeSessionOneFile => '1 file';

  @override
  String codeSessionFileCount(int count) {
    return '$count file';
  }

  @override
  String get codeActionFailed => 'Non riuscito';

  @override
  String get codeActionTimedOut => 'Tempo scaduto';

  @override
  String get codeActionSkipped => 'Saltato';

  @override
  String get codeActionDenied => 'Bloccato';

  @override
  String get codeActionOutput => 'Output';

  @override
  String get codeActionNoOutput => 'Nessun output';

  @override
  String get codeActionOutputCut => 'L’output è stato accorciato';

  @override
  String codeDeniedBlockedProgram(String program) {
    return '“$program” non è consentito qui.';
  }

  @override
  String get codeDeniedNetwork => 'I comandi di rete sono disattivati.';

  @override
  String codeDeniedOutside(String path) {
    return '$path è fuori dalla cartella del progetto.';
  }

  @override
  String get codeDeniedParent => '“..” non è consentito nei percorsi.';

  @override
  String get codeDeniedOther => 'Quel comando non è consentito.';

  @override
  String get codeErrorStepLimit => 'Fermato al limite di passaggi.';

  @override
  String get codeErrorRepeating =>
      'Fermato: il modello ripeteva lo stesso passaggio.';

  @override
  String get codeErrorEmpty => 'Il modello ha inviato una risposta vuota.';

  @override
  String get codeErrorCutOff =>
      'La risposta si è interrotta prima della fine del passaggio, quindi non è stato eseguito nulla.';

  @override
  String codeErrorEngine(String detail) {
    return 'Qualcosa è andato storto: $detail';
  }

  @override
  String get codeErrorAuth =>
      'Il fornitore ha rifiutato la chiave. Controllala nelle impostazioni di Code.';

  @override
  String get codeErrorPlanNoApi =>
      'Il piano Go di Command Code non ha accesso all’API. Passa a GOAT o superiore per usarlo qui.';

  @override
  String get codeErrorPayment => 'Credito esaurito con questo fornitore.';

  @override
  String get codeErrorRate =>
      'Limite di richieste raggiunto. Riprova tra poco.';

  @override
  String get codeErrorWrongEndpoint =>
      'Questo fornitore non ha potuto servire quel modello.';

  @override
  String get codeErrorBadRequest =>
      'Il fornitore non ha potuto accettare la richiesta.';

  @override
  String get codeErrorServer => 'Il fornitore ha avuto un problema. Riprova.';

  @override
  String get codeErrorNetwork =>
      'Impossibile raggiungere il fornitore. Controlla la connessione.';

  @override
  String get codeErrorTimeout =>
      'Il fornitore ci ha messo troppo a rispondere.';

  @override
  String get codeErrorMalformed =>
      'Il fornitore ha inviato una risposta illeggibile.';

  @override
  String get codeErrorUnknown => 'Qualcosa è andato storto con il fornitore.';

  @override
  String get codeSessionRename => 'Rinomina';

  @override
  String get codeSessionRenameTitle => 'Rinomina sessione';

  @override
  String get codeSessionPin => 'Fissa';

  @override
  String get codeSessionUnpin => 'Rimuovi';

  @override
  String get codeSessionFiles => 'File del progetto';

  @override
  String get codeSessionDelete => 'Elimina sessione';

  @override
  String get codeSessionDeleteTitle => 'Eliminare questa sessione?';

  @override
  String get codeSessionDeleteBody =>
      'La conversazione e i suoi file di progetto vengono rimossi da questo dispositivo.';

  @override
  String codeCloudTitle(String provider) {
    return 'Usare $provider?';
  }

  @override
  String codeCloudBody(String provider) {
    return '$provider funziona nel cloud. Ciò che scrivi, insieme al contenuto dei file e all’output dei comandi letti dall’agente, viene inviato a $provider e trattato secondo le sue condizioni. FinnAI su questo dispositivo tiene tutto sul telefono.';
  }

  @override
  String codeCloudConfirm(String provider) {
    return 'Usa $provider';
  }

  @override
  String get codeModelsSearchHint => 'Cerca modelli';

  @override
  String get codeModelsOnDeviceTitle => 'FinnAI';

  @override
  String get codeModelsOnDeviceSub =>
      'Funziona su questo dispositivo. Privato, gratuito e utilizzabile offline.';

  @override
  String get codeModelsAddProvider =>
      'Aggiungi un fornitore per usare più modelli';

  @override
  String get codeModelsLoading => 'Caricamento dei modelli…';

  @override
  String get codeModelsLoad => 'Carica modelli';

  @override
  String get codeModelsNone => 'Nessun modello corrisponde';

  @override
  String get codeModelsFree => 'Gratis';

  @override
  String codeModelsContext(String size) {
    return '$size di contesto';
  }

  @override
  String codeModelsPrice(String input, String output) {
    return '$input in · $output out per 1 M';
  }

  @override
  String codeModelsFetchFailed(String reason) {
    return 'Impossibile caricare i modelli. $reason';
  }

  @override
  String get codeSettingsProviders => 'Fornitori';

  @override
  String get codeSettingsProvidersSubNone => 'FinnAI su questo dispositivo';

  @override
  String codeSettingsProvidersSub(String count) {
    return 'FinnAI più $count collegati';
  }

  @override
  String get codeSettingsModel => 'Modello';

  @override
  String get codeSettingsAgent => 'Agente';

  @override
  String get codeSettingsWorkspace => 'Cartelle di progetto';

  @override
  String codeSettingsWorkspaceSub(String size) {
    return '$size su questo dispositivo';
  }

  @override
  String get codeSettingsData => 'Privacy e dati';

  @override
  String get codeSettingsDataSub => 'Chiavi, sessioni e file di progetto';

  @override
  String get codeSettingsAbout => 'Informazioni su FinnAI Code';

  @override
  String get codeProvidersTitle => 'Fornitori';

  @override
  String get codeProvidersIntro =>
      'FinnAI sul tuo telefono è la scelta predefinita. Aggiungi la tua chiave API per usare un modello cloud in FinnAI Code. Le chiavi restano nell’archivio sicuro del telefono.';

  @override
  String get codeProviderStatusLocal => 'Su questo dispositivo';

  @override
  String codeProviderStatusConnected(String hint) {
    return 'Collegato · ••••$hint';
  }

  @override
  String get codeProviderStatusConnectedNoKey => 'Collegato';

  @override
  String get codeProviderStatusNotSet => 'Non configurato';

  @override
  String get codeProviderDescOpenRouter =>
      'Una chiave per centinaia di modelli, anche gratuiti.';

  @override
  String get codeProviderDescCommandCode =>
      'I modelli di Command Code con la tua chiave.';

  @override
  String get codeProviderDescZen =>
      'OpenCode Zen: modelli a consumo scelti per programmare.';

  @override
  String get codeProviderDescGo =>
      'OpenCode Go: un piano mensile fisso di modelli aperti per programmare.';

  @override
  String get codeProviderDescCustom =>
      'Qualsiasi server con l’API OpenAI: il tuo, Ollama, LM Studio e altri.';

  @override
  String get codeProviderCustomName =>
      'Personalizzato (compatibile con OpenAI)';

  @override
  String get codeProviderKeyLabel => 'Chiave API';

  @override
  String get codeProviderKeyHint => 'Incolla la tua chiave';

  @override
  String get codeProviderKeyOptionalHint =>
      'Incolla una chiave se il tuo server la richiede';

  @override
  String get codeProviderKeySave => 'Salva chiave';

  @override
  String get codeProviderKeyReplace => 'Sostituisci chiave';

  @override
  String get codeProviderKeyRemove => 'Rimuovi chiave';

  @override
  String get codeProviderKeyRemoveTitle => 'Rimuovere questa chiave?';

  @override
  String codeProviderKeyRemoveBody(String provider) {
    return 'FinnAI Code smetterà di usare $provider finché non aggiungerai di nuovo una chiave.';
  }

  @override
  String get codeProviderKeyStored =>
      'Salvata in modo sicuro su questo dispositivo';

  @override
  String get codeProviderGetKey => 'Ottieni una chiave';

  @override
  String get codeProviderTest => 'Prova chiave';

  @override
  String get codeProviderTesting => 'Test in corso…';

  @override
  String get codeProviderTestOk => 'La chiave funziona.';

  @override
  String codeProviderTestFail(String reason) {
    return 'Test non riuscito. $reason';
  }

  @override
  String get codeProviderTestNeedsModel => 'Carica prima i modelli, poi prova.';

  @override
  String get codeProviderAddressLabel => 'Indirizzo del server';

  @override
  String get codeProviderAddressHint => 'https://tuo-server/v1';

  @override
  String get codeProviderAddressInvalid =>
      'Usa un indirizzo https, oppure http per un server della tua rete.';

  @override
  String get codeProviderAddressSave => 'Salva indirizzo';

  @override
  String get codeProviderPlanNote =>
      'Richiede il piano GOAT o superiore. Il piano Go non ha accesso all’API e non può essere usato qui.';

  @override
  String codeProviderPrivacy(String provider) {
    return 'Quando usi uno dei suoi modelli, i tuoi messaggi, il contenuto dei file e l’output dei comandi vengono inviati a $provider.';
  }

  @override
  String get codeProviderAllowance => 'Credito';

  @override
  String codeProviderAllowanceRemaining(String remaining, String limit) {
    return 'Restano $remaining su $limit';
  }

  @override
  String get codeProviderAllowanceUnlimited =>
      'Nessun limite di spesa su questa chiave';

  @override
  String codeProviderAllowanceUsed(String used) {
    return '$used usati';
  }

  @override
  String codeProviderAllowanceToday(String amount) {
    return '$amount oggi';
  }

  @override
  String codeProviderAllowanceMonth(String amount) {
    return '$amount questo mese';
  }

  @override
  String codeProviderAllowanceBalance(String balance) {
    return 'Credito dell’account $balance';
  }

  @override
  String get codeProviderAllowanceFree => 'Chiave del livello gratuito';

  @override
  String codeProviderAllowanceNoApi(String provider) {
    return '$provider non offre un’API di utilizzo. Controlla il saldo sulla sua dashboard.';
  }

  @override
  String get codeProviderOpenDashboard => 'Apri dashboard';

  @override
  String get codeProviderRefresh => 'Aggiorna';

  @override
  String codeProviderModelsCount(String count) {
    return '$count modelli disponibili';
  }

  @override
  String get codeProviderModelsRefresh => 'Aggiorna elenco modelli';

  @override
  String get codeProviderChooseModel => 'Scegli un modello';

  @override
  String codeProviderModelsLive(String provider) {
    return 'Recuperati in tempo reale da $provider';
  }

  @override
  String get codeAgentTitle => 'Agente';

  @override
  String get codeAgentPermissionTitle => 'Quando l’agente agisce';

  @override
  String get codeAgentAsk => 'Chiedi prima di tutto';

  @override
  String get codeAgentAskSub =>
      'Ogni comando e ogni scrittura di file attende il tuo tocco.';

  @override
  String get codeAgentEdits => 'Scrivi file, chiedi per i comandi';

  @override
  String get codeAgentEditsSub =>
      'I file vengono scritti man mano. I comandi attendono il tuo tocco.';

  @override
  String get codeAgentAuto => 'Esegui tutto';

  @override
  String get codeAgentAutoSub =>
      'Niente attende te. I comandi restano comunque nella cartella del progetto.';

  @override
  String get codeAgentSteps => 'Passaggi per richiesta';

  @override
  String get codeAgentStepsSub =>
      'Quante azioni può compiere l’agente prima di fermarsi e chiedere di continuare.';

  @override
  String get codeAgentStepsAuto => 'Automatico';

  @override
  String codeAgentStepsValue(String count) {
    return '$count passaggi';
  }

  @override
  String get codeAgentNetwork => 'Consenti comandi di rete';

  @override
  String get codeAgentNetworkSub =>
      'Permette a comandi come curl di raggiungere internet. Disattivato evita che il progetto venga caricato per errore.';

  @override
  String get codeAgentTimeout => 'Limite di tempo dei comandi';

  @override
  String codeAgentTimeoutValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get codeSandboxNote =>
      'I comandi vengono eseguiti in una cartella privata di questo telefono, come utente dell’app e con un limite di tempo. Non è un sistema Linux completo: non ci sono python, git né compilatori e non si può installare nulla.';

  @override
  String get codeWorkspaceTitle => 'Cartelle di progetto';

  @override
  String codeWorkspaceUsed(String size, String count) {
    return '$size in $count cartelle di progetto';
  }

  @override
  String get codeWorkspaceClear => 'Elimina tutti i file di progetto';

  @override
  String get codeWorkspaceClearTitle => 'Eliminare tutti i file di progetto?';

  @override
  String get codeWorkspaceClearBody =>
      'La cartella di progetto di ogni sessione viene svuotata. Le conversazioni restano.';

  @override
  String get codeDataTitle => 'Privacy e dati';

  @override
  String get codeDataNote =>
      'Le sessioni e i file di progetto sono salvati nell’archivio privato di questa app sul telefono. Le chiavi API sono conservate nell’archivio sicuro del sistema. Con FinnAI su questo dispositivo nulla lascia il telefono.';

  @override
  String get codeDataDelete => 'Elimina i dati di FinnAI Code';

  @override
  String get codeDataDeleteSub =>
      'Sessioni, file di progetto, chiavi salvate e impostazioni';

  @override
  String get codeDataDeleteTitle => 'Eliminare i dati di FinnAI Code?';

  @override
  String get codeDataDeleteBody =>
      'Vengono eliminate tutte le sessioni, le cartelle di progetto, le chiavi salvate e le impostazioni di Code. Le chat di FinnAI non vengono toccate.';

  @override
  String get codeDataDeleted => 'Dati di FinnAI Code eliminati.';

  @override
  String get codeAboutBody =>
      'FinnAI Code è un agente di programmazione. Funziona con il modello del tuo telefono o con le tue chiavi dei fornitori e può leggere e scrivere file in una cartella di progetto privata ed eseguirvi comandi semplici.';

  @override
  String get codeFilesEmpty =>
      'Ancun file per ora. Chiedi all’agente di creare qualcosa.';

  @override
  String get codeFilesNoSession =>
      'Avvia una sessione per avere una cartella di progetto.';

  @override
  String get codeFileCopy => 'Copia';

  @override
  String get codeFileCopied => 'Copiato';

  @override
  String get codeFileDelete => 'Elimina file';

  @override
  String codeFileDeleteTitle(String name) {
    return 'Eliminare $name?';
  }

  @override
  String get codeFileEmpty => 'Questo file è vuoto.';

  @override
  String get codeTerminalHint => 'Esegui un comando';

  @override
  String get codeTerminalIntro =>
      'Viene eseguito nella cartella di progetto di questa sessione.';

  @override
  String get codeTerminalUnsupported =>
      'I comandi non possono essere eseguiti su questo dispositivo.';

  @override
  String get codeTerminalClear => 'Cancella';

  @override
  String get codeErrorMalformedAction =>
      'Il modello ha scritto un’azione inutilizzabile, quindi non è stato eseguito nulla.';

  @override
  String get codeCloudTitleCustom => 'Usare questo server?';

  @override
  String codeCloudBodyCustom(String address) {
    return 'Ciò che scrivi, insieme al contenuto dei file e all’output dei comandi letti dall’agente, viene inviato a $address. FinnAI su questo dispositivo tiene tutto sul telefono.';
  }

  @override
  String get codeCloudConfirmCustom => 'Usa questo server';

  @override
  String get windowMinimize => 'Riduci a icona';

  @override
  String get windowMaximize => 'Ingrandisci';

  @override
  String get windowRestore => 'Ripristina';

  @override
  String get onboardingGetStarted => 'Inizia';

  @override
  String get codeSettingsContainer => 'Container Linux';

  @override
  String get codeSettingsContainerSubReady => 'I comandi girano in Linux';

  @override
  String get codeSettingsContainerSubMissing => 'Non configurato';

  @override
  String get codeContainerTitle => 'Container Linux';

  @override
  String get codeContainerIntro =>
      'I comandi girano in un piccolo computer Linux che FinnAI emula su questo dispositivo. Funziona allo stesso modo su ogni telefono e computer e non può vedere né modificare nulla al di fuori del progetto. Ha gli strumenti busybox (sh, sed, awk, vi, tar…), ma niente python, git, compilatore o rete.';

  @override
  String get codeContainerStatusReady => 'Scaricato e verificato';

  @override
  String get codeContainerStatusRunning => 'In esecuzione';

  @override
  String get codeContainerStatusStarting => 'Avvio…';

  @override
  String codeContainerStatusMissing(String size) {
    return 'Non scaricato ($size)';
  }

  @override
  String codeContainerStatusDownloading(String percent) {
    return 'Download… $percent%';
  }

  @override
  String get codeContainerErrorNetwork =>
      'Il download non è riuscito. Controlla la connessione e riprova.';

  @override
  String get codeContainerErrorVerification =>
      'Il download non corrispondeva al suo checksum ed è stato scartato. Riprova.';

  @override
  String get codeContainerErrorStorage =>
      'Non c’è abbastanza spazio per salvarlo.';

  @override
  String get codeContainerUnsupported =>
      'Questo dispositivo non può eseguire il container, quindi i comandi usano la sua shell.';

  @override
  String codeContainerDownload(String size) {
    return 'Scarica ($size)';
  }

  @override
  String get codeContainerCancel => 'Annulla download';

  @override
  String get codeContainerUse => 'Esegui i comandi nel container';

  @override
  String get codeContainerUseSub =>
      'Disattivato, vengono eseguiti nella shell di questo dispositivo.';

  @override
  String get codeContainerRestart => 'Riavvia container';

  @override
  String get codeContainerRestartSub =>
      'I file del progetto restano; sono su questo dispositivo.';

  @override
  String get codeContainerRemove => 'Rimuovi container';

  @override
  String get codeContainerRemoveTitle => 'Rimuovere il container Linux?';

  @override
  String get codeContainerRemoveBody =>
      'I file del progetto restano. I comandi gireranno nella shell di questo dispositivo finché non lo scarichi di nuovo.';

  @override
  String get codeContainerLicence =>
      'L’emulatore è v86 (licenza BSD). Il kernel Linux, busybox e SeaBIOS vengono scaricati dal progetto v86 con le loro licenze GPL e LGPL.';

  @override
  String get codeTerminalIntroContainer =>
      'Gira nella cartella di progetto di questa sessione, nel container Linux. Il primo comando lo avvia.';

  @override
  String get codeTerminalSetUpContainer => 'Configura il container Linux';

  @override
  String get codeTerminalSetUpContainerSub =>
      'Per ora i comandi girano su questo dispositivo. Il container li isola e funziona ovunque allo stesso modo.';

  @override
  String get codeAttachFiles => 'Aggiungi file';

  @override
  String codeAttachmentRemove(String name) {
    return 'Rimuovi $name';
  }

  @override
  String codeAttachFailed(String names) {
    return 'Impossibile aggiungere $names';
  }

  @override
  String get codeVerbRun => 'Esegui';

  @override
  String get codeVerbWrite => 'Scrivi';

  @override
  String get codeVerbEdit => 'Modifica';

  @override
  String get codeNewFile => 'nuovo file';

  @override
  String codeShowMoreLines(String count) {
    return 'Mostra altre $count righe';
  }

  @override
  String get codeShowLess => 'Mostra meno';

  @override
  String codeUnchangedLines(String count) {
    return '$count righe invariate';
  }

  @override
  String get codeApproveRun => 'Eseguire questo comando?';

  @override
  String get codeApproveWrite => 'Scrivere questo file?';

  @override
  String get codeApproveEdit => 'Applicare questa modifica?';

  @override
  String get codeReject => 'Rifiuta';

  @override
  String get codeApply => 'Applica';

  @override
  String codeExitCode(String code) {
    return 'uscita $code';
  }

  @override
  String get codeCopy => 'Copia';

  @override
  String get codeStatusIdle => 'pronto';

  @override
  String get codeStatusThinking => 'sta pensando';

  @override
  String get codeStatusRunning => 'in esecuzione';

  @override
  String get codeStatusWaiting => 'in attesa di te';

  @override
  String get codeEnvLinux => 'Linux';

  @override
  String get codeEnvDevice => 'shell';

  @override
  String get codeEnvNone => 'solo file';

  @override
  String get codeSlashNewDesc => 'Avvia una nuova sessione';

  @override
  String get codeSlashFilesDesc => 'Sfoglia i file del progetto';

  @override
  String get codeSlashTerminalDesc => 'Apri il terminale';

  @override
  String get codeSlashModelDesc => 'Scegli il modello';

  @override
  String get codeSlashModeDesc => 'Cambia cosa può fare l’agente';

  @override
  String get codeSlashRetryDesc => 'Continua o riprova l’ultima richiesta';

  @override
  String get codeSlashSettingsDesc => 'Apri le impostazioni di Code';

  @override
  String get codeMentionNoFiles => 'Ancora nessun file';

  @override
  String get codeTerminalExpand => 'Apri a schermo intero';

  @override
  String get codeTerminalShow => 'Mostra terminale';

  @override
  String get codeTerminalHide => 'Nascondi terminale';

  @override
  String get codeLinuxTitle => 'Linux';

  @override
  String get codeLinuxIntro =>
      'Per FinnAI Code su questo telefono gira un vero Alpine Linux. Installa ciò che serve al progetto (apk o apt-get, pip, npm), clona repository e compila. Vede solo i propri file e la cartella del progetto di questa sessione in /workspace, nient’altro del dispositivo. Usa internet per installazioni e git.';

  @override
  String codeLinuxStatusMissing(String size) {
    return 'Non configurato · download di $size';
  }

  @override
  String get codeLinuxStatusPreparing => 'Configurazione…';

  @override
  String codeLinuxStatusReady(String version) {
    return 'Alpine Linux $version · pronto';
  }

  @override
  String codeLinuxSetUp(String size) {
    return 'Configura Linux ($size)';
  }

  @override
  String get codeLinuxUse => 'Esegui i comandi in Linux';

  @override
  String get codeLinuxRemove => 'Rimuovi Linux';

  @override
  String get codeLinuxRemoveTitle => 'Rimuovere Linux?';

  @override
  String get codeLinuxRemoveBody =>
      'Tutto ciò che vi è installato viene eliminato. Le cartelle dei progetti restano.';

  @override
  String get codeLinuxUnsupported =>
      'Questo dispositivo non può eseguire Linux, quindi i comandi usano la sua shell.';

  @override
  String get codeLinuxLicence =>
      'Alpine Linux e i suoi pacchetti hanno licenze proprie. proot (GPL-2.0) li esegue; il sorgente è su github.com/termux/proot.';

  @override
  String get codeTerminalIntroLinux =>
      'Alpine Linux, nella cartella del progetto di questa sessione (/workspace).';

  @override
  String get codeSettingsLinuxSubReady => 'Alpine Linux · i comandi girano qui';

  @override
  String get codeProviderModelsOne => '1 modello disponibile';
}
