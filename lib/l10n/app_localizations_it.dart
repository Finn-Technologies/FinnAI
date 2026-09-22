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
  String get commonSaveSkill => 'Salva competenza';

  @override
  String get commonKeepCreating => 'Continua a creare';

  @override
  String get commonNotNow => 'Non ora';

  @override
  String get commonPurge => 'Svuota';

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
  String get onboardingWelcome => 'Benvenuto in Finn AI!';

  @override
  String get onboardingSwipeToStart => 'Scorri per iniziare';

  @override
  String get onboardingPrivacyTitle => 'Finn AI mette prima la privacy';

  @override
  String get onboardingPrivacyBody =>
      'Finn AI è progettato per rispettare la tua privacy.\n\nL\'elaborazione dell\'IA e la cronologia delle conversazioni restano su questo dispositivo. Quando una richiesta necessita di informazioni aggiornate, Finn AI può inviare solo quella richiesta come query di ricerca web e mostrerà le fonti utilizzate. La tua cronologia e il tuo profilo personale non vengono mai inclusi.\n\nFinn AI è software proprietario e non è open source.';

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
      'Installazione di LFM2.5-VL 1.6B';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B è pronto';

  @override
  String get onboardingInstallPreparing =>
      'Preparazione di LFM2.5-VL 1.6B per questo dispositivo…';

  @override
  String get onboardingInstallReadyForChat =>
      'Pronto per la chat testuale privata su questo dispositivo';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + componente multimodale · $size';
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
  String get onboardingReadyTitle => 'Finn AI è pronto!';

  @override
  String get onboardingReadySubtitle => 'Tutto pronto. Finn AI è a posto.';

  @override
  String get onboardingYouLabel => 'Tu';

  @override
  String get chatNewChat => 'Nuova chat';

  @override
  String get chatHistory => 'Cronologia chat';

  @override
  String get chatNoHistory => 'Nessuna cronologia';

  @override
  String get chatFinnGenerating => 'Finn sta generando…';

  @override
  String get chatFinnTyping => 'Finn sta scrivendo…';

  @override
  String get chatAskAnything =>
      'Chiedimi qualsiasi cosa — funziono interamente su questo dispositivo, le tue\nconversazioni non lasciano mai il telefono.';

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
  String get settingsPurgeMemory => 'Svuota la memoria dell\'IA';

  @override
  String get settingsPurgeMemoryTitle => 'Svuotare la memoria dell\'IA?';

  @override
  String get settingsPurgeMemoryBody =>
      'Il modello IA verrà scaricato dalla RAM. Verrà ricaricato automaticamente al prossimo messaggio.';

  @override
  String get settingsPurgeMemoryReleased =>
      'Memoria del modello IA rilasciata.';

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
      'Questo elimina definitivamente conversazioni e chiavi crittografate, modelli AI scaricati, creazioni, preferenze del profilo, Skill e lo stato di onboarding. FinnAI tornerà a un primo avvio pulito.';

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
      'L\'URL dell\'informativa sulla privacy non è configurato (imposta FINN_PRIVACY_POLICY_URL).';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return 'Impossibile aprire $url';
  }

  @override
  String get settingsTermsOfUse => 'Termini di utilizzo';

  @override
  String get settingsTermsUnconfigured =>
      'L\'URL dei termini di utilizzo non è configurato (imposta FINN_TERMS_URL).';

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
  String get settingsInferenceEngine => 'Motore di inferenza';

  @override
  String get settingsInferenceEngineValue => 'llama.cpp · GGUF';

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
      'Finn legge le risposte ad alta voce in modalità vocale. La trascrizione della tua voce viene elaborata dal riconoscimento vocale del dispositivo, che potrebbe richiedere internet.';

  @override
  String get voiceMicSemantic => 'Parla con Finn';

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
  String get skillsTitle => 'Skill';

  @override
  String skillsSubtitle(int count) {
    return '$count disponibili · le Skill guidano risposte pertinenti';
  }

  @override
  String get skillsNewSkill => 'Nuova skill';

  @override
  String get skillsNoSkills =>
      'Nessuna skill personalizzata. Creane una per un flusso di lavoro che ripeti.';

  @override
  String get skillsInstructionHint =>
      'Scrivi un\'istruzione riutilizzabile che Finn deve applicare quando è pertinente.';

  @override
  String get skillsDeleteTitle => 'Eliminare questa skill?';

  @override
  String skillsDeleteBody(String name) {
    return '\"$name\" verrà rimossa da questo dispositivo.';
  }

  @override
  String get skillsLimitReached =>
      'Limite di skill raggiunto (4). Eliminane una per aggiungerne un\'altra.';

  @override
  String get skillsNameLabel => 'Nome della skill';

  @override
  String get skillsInstructionLabel => 'Istruzione';

  @override
  String get chatBrowseTooltip => 'Cerca sul web per questo messaggio';

  @override
  String get chatBrowseOnSemantic => 'Ricerca web attiva';

  @override
  String get chatBrowseOffSemantic => 'Ricerca web disattivata';

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
  String get snackModelMemoryReleased => 'Memoria del modello IA rilasciata.';

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
}
