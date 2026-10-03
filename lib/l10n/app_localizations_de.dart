// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonContinue => 'Weiter';

  @override
  String get commonCopiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get commonOpen => 'Öffnen';

  @override
  String get commonStop => 'Stoppen';

  @override
  String get commonDownload => 'Herunterladen';

  @override
  String get commonResend => 'Erneut senden';

  @override
  String get commonSaveFlow => 'Flow speichern';

  @override
  String get commonKeepCreating => 'Weiter erstellen';

  @override
  String get commonNotNow => 'Nicht jetzt';

  @override
  String get commonPurge => 'Freigeben';

  @override
  String get commonClearAll => 'Alle löschen';

  @override
  String get commonDeleteEverything => 'Alles löschen';

  @override
  String get appTitle => 'Finn AI';

  @override
  String get appBrandFinnAI => 'FinnAI';

  @override
  String get unsupportedTitle =>
      'Finn AI kann auf diesem Gerät nicht ausgeführt werden';

  @override
  String get unsupportedBody =>
      'Finn AI benötigt mindestens 3 GB RAM und einen 64-Bit-ARM-Prozessor, um lokale Modelle zuverlässig auszuführen. Es wurde kein Modell heruntergeladen.';

  @override
  String get onboardingWelcome => 'Willkommen bei FinnAI';

  @override
  String get onboardingSwipeToStart => 'Zum Starten wischen';

  @override
  String get onboardingPrivacyTitle => 'FinnAI schützt deine Privatsphäre';

  @override
  String get onboardingPrivacyLead =>
      'FinnAI nimmt den Schutz deiner Privatsphäre ernst.';

  @override
  String get onboardingPrivacyBody =>
      'Wir verfolgen und speichern deine Daten nicht, jede Anfrage wird lokal auf deinem Gerät verarbeitet. ';

  @override
  String get onboardingPrivacyLink =>
      'Mehr dazu in unserer Datenschutzerklärung.';

  @override
  String get onboardingPrecautionsTitle =>
      'Vor dem Start bitte die Hinweise lesen';

  @override
  String get onboardingPrecautionOne => 'KI-Prompt-Verarbeitung auf dem Gerät';

  @override
  String get onboardingPrecautionTwo => 'Offline-Chat nach dem Modell-Download';

  @override
  String get onboardingPrecautionThree => 'Verschlüsselte Gesprächsspeicherung';

  @override
  String get onboardingPrecautionFour => 'Auf Akkueffizienz ausgelegt';

  @override
  String get onboardingInstallTitleInstalling =>
      'FinnAI Foundation wird heruntergeladen';

  @override
  String get onboardingInstallTitleReady => 'FinnAI Foundation bereit';

  @override
  String get onboardingDownloadLead => 'FinnAI wird eingerichtet,';

  @override
  String get onboardingDownloadNote =>
      'der erste Start dauert ein paar Minuten.';

  @override
  String onboardingProgressPercent(Object percent) {
    return '$percent % fertig.';
  }

  @override
  String get onboardingProgressEtaTail => 'übrig.';

  @override
  String onboardingProgressEtaAbout(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Minuten',
      one: '1 Minute',
    );
    return 'Noch etwa $_temp0.';
  }

  @override
  String get onboardingInstallPreparing =>
      'LFM2.5-VL 1.6B wird für dieses Gerät vorbereitet…';

  @override
  String get onboardingInstallReadyForChat =>
      'Bereit für privaten Textchat auf diesem Gerät';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + Bildunterstützung · $size';
  }

  @override
  String get onboardingInstallModelReady => 'Modell bereit';

  @override
  String onboardingInstallProgressStatus(String status, String percent) {
    return '$status · $percent%';
  }

  @override
  String onboardingInstallBytesOf(String received, String total) {
    return '$received von $total';
  }

  @override
  String onboardingInstallBytesLeft(String remaining) {
    return '$remaining übrig';
  }

  @override
  String get onboardingInstallRetry => 'Erneut versuchen';

  @override
  String get onboardingInstallRetryLabel => 'Modell-Download wiederholen';

  @override
  String get onboardingInstallVerificationFailed =>
      'Modellüberprüfung fehlgeschlagen';

  @override
  String get onboardingUpgradeTitle => 'FinnAI-Software-Upgrade';

  @override
  String get onboardingUpgradeBody =>
      'Finn AI verwendet jetzt ein neueres Modell auf dem Gerät. Lade es herunter, um weiter privat zu chatten.';

  @override
  String get onboardingReadyTitle => 'FinnAI ist bereit!';

  @override
  String get onboardingReadyLead => 'FinnAI ist einsatzbereit!';

  @override
  String get onboardingReadyBody =>
      'Du kannst FinnAI jetzt online und offline nutzen.\nWir hoffen, es gefällt dir!';

  @override
  String get onboardingReadySubtitle =>
      'Du bist startklar. Finn AI ist bereit.';

  @override
  String get onboardingConsentTitle =>
      'Erlaubst du FinnAI, Kontext von deinem Gerät zu nutzen?';

  @override
  String get onboardingConsentBody =>
      'So kann FinnAI deinen Kalender, deine Notizen und Fotos lesen, damit die Antworten besser zu dir passen. Es liest nur auf diesem Gerät, und nichts wird irgendwohin gesendet.';

  @override
  String get onboardingConsentRequiredHint =>
      'Wähle Ja oder Nein, um fortzufahren';

  @override
  String get onboardingStartUsing => 'FinnAI jetzt nutzen';

  @override
  String get onboardingYouLabel => 'Du';

  @override
  String get chatNewChat => 'Neuer Chat';

  @override
  String get chatHistory => 'Chats';

  @override
  String get chatNoHistory => 'Kein Verlauf';

  @override
  String get chatFinnGenerating => 'Finn generiert…';

  @override
  String get chatFinnTyping => 'Finn tippt…';

  @override
  String get chatAskAnything =>
      'Frag mich alles — ich laufe komplett auf diesem Gerät, deine\nUnterhaltungen verlassen niemals dein Telefon.';

  @override
  String get chatTryAsking => 'Probier mal';

  @override
  String get chatMessageHint => 'Nachricht an Finn…';

  @override
  String get chatSend => 'Senden';

  @override
  String get chatStopGeneration => 'Stoppen';

  @override
  String get chatCopy => 'Kopieren';

  @override
  String get chatEditMessage => 'Nachricht bearbeiten';

  @override
  String get chatRenameTitle => 'Chat umbenennen';

  @override
  String get chatRenameHint => 'Chat-Titel';

  @override
  String get chatDeleteTitle => 'Chat löschen?';

  @override
  String chatDeleteBody(String title) {
    return '„$title“ wird entfernt. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get chatContinue => 'Weiter';

  @override
  String get chatSources => 'Quellen';

  @override
  String get chatHistoryUnavailableNotice =>
      'Finn konnte deinen Chatverlauf auf diesem Gerät nicht öffnen, neue Antworten werden nicht gespeichert.';

  @override
  String get chatOfflineNotice =>
      'Offline — die Antwort ist möglicherweise weniger genau. Stelle eine Verbindung her, um Quellen zu erhalten.';

  @override
  String get chatFinishingTask =>
      'Finn AI schließt gerade eine andere lokale Aufgabe ab.';

  @override
  String get chatAttachmentPickFailed =>
      'Auswahl konnte nicht geöffnet werden. Bitte erneut versuchen.';

  @override
  String get chatCouldNotPrepare =>
      'Chat konnte nicht vorbereitet werden. Prüfe Modell und Speicher und versuche es erneut.';

  @override
  String get chatEmptyReply =>
      'Finn hatte diesmal keine Antwort. Tippe auf „Erneut versuchen“, um es noch einmal zu fragen.';

  @override
  String chatGeneratingIn(String title) {
    return 'Wird in $title generiert';
  }

  @override
  String get chatDownloadModelTitle =>
      'Das KI-Modell für den Offline-Chat herunterladen?';

  @override
  String chatDownloadModelBody(String size) {
    return '$size wird einmal heruntergeladen und vor der Nutzung überprüft. Nach einer unterbrochenen Verbindung wird der Download sicher fortgesetzt, und deine Chats bleiben auf diesem Gerät.';
  }

  @override
  String get chatHiPrefix => 'Hi, ich bin Finn.';

  @override
  String get chatFinnAI => 'Finn AI';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsContextTitle => 'Kontext auf dem Gerät';

  @override
  String get settingsContextSubtitle =>
      'FinnAI darf Kontext von diesem Gerät nutzen';

  @override
  String get settingsAiModel => 'KI-MODELL';

  @override
  String get settingsStorageData => 'SPEICHER & DATEN';

  @override
  String get settingsPrivacyLegal => 'DATENSCHUTZ & RECHT';

  @override
  String get settingsAbout => 'ÜBER';

  @override
  String settingsSavedConversations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Chats (verschlüsselt)',
      one: '1 Chat (verschlüsselt)',
    );
    return '$_temp0';
  }

  @override
  String get settingsReleasingMemory => 'Speicher wird freigegeben…';

  @override
  String get settingsPurgeMemorySubtitle =>
      'Gibt Arbeitsspeicher frei. Das Modell lädt bei der nächsten Nachricht neu.';

  @override
  String get settingsClearHistorySubtitle =>
      'Löscht jeden gespeicherten Chat. Kann nicht rückgängig gemacht werden.';

  @override
  String get settingsDeleteAllDataSubtitle =>
      'Chats, Modelle, Kreationen und Einstellungen — zurück zum ersten Start.';

  @override
  String get settingsPurgeMemory => 'Speicher freigeben';

  @override
  String get settingsPurgeMemoryTitle => 'Speicher freigeben?';

  @override
  String get settingsPurgeMemoryBody =>
      'Dadurch wird das KI-Modell geschlossen, um Speicher freizugeben. Bei deiner nächsten Nachricht wird es wieder geöffnet.';

  @override
  String get settingsPurgeMemoryReleased => 'Speicher freigegeben.';

  @override
  String get settingsClearHistory => 'Gesamten Chatverlauf löschen';

  @override
  String get settingsClearHistoryTitle => 'Alle Gespräche löschen?';

  @override
  String get settingsClearHistoryBody =>
      'Dadurch wird der gesamte Chatverlauf dauerhaft gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get settingsClearHistorySuccess => 'Alle Gespräche gelöscht.';

  @override
  String get settingsClearHistoryFailure =>
      'Gespräche konnten nicht gelöscht werden. Prüfe den Speicher und versuche es erneut.';

  @override
  String get settingsDeleteAllData => 'Alle lokalen Daten löschen';

  @override
  String get settingsDeleteAllDataTitle => 'Alle lokalen Daten löschen?';

  @override
  String get settingsDeleteAllDataBody =>
      'Dies löscht endgültig verschlüsselte Unterhaltungen und Schlüssel, heruntergeladene KI-Modelle, Kreationen, Profileinstellungen, Flows und den Onboarding-Zustand. FinnAI kehrt zu einem sauberen Erststart zurück.';

  @override
  String get settingsDeleteAllDataDeleting =>
      'Alle lokalen Daten werden gelöscht…';

  @override
  String get settingsDeleteAllDataSuccess =>
      'Alle lokalen Daten gelöscht. Zurück zur Einführung.';

  @override
  String settingsDeleteAllDataPartialFailure(String items) {
    return 'Teilweiser Löschfehler: $items konnte nicht gelöscht werden.';
  }

  @override
  String get settingsPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get settingsPrivacyPolicyUnconfigured =>
      'Der Link zur Datenschutzerklärung ist in dieser Version nicht verfügbar.';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return '$url konnte nicht geöffnet werden';
  }

  @override
  String get settingsTermsOfUse => 'Nutzungsbedingungen';

  @override
  String get settingsTermsUnconfigured =>
      'Der Link zu den Nutzungsbedingungen ist in dieser Version nicht verfügbar.';

  @override
  String settingsTermsLaunchFailed(String url) {
    return '$url konnte nicht geöffnet werden';
  }

  @override
  String get settingsSupportContact => 'Support-Kontakt';

  @override
  String get settingsSupportUnavailable =>
      'Support-Kontakt ist nicht verfügbar.';

  @override
  String settingsSupportEmailLabel(String email) {
    return 'Support-E-Mail: $email';
  }

  @override
  String settingsSupportLaunchFailed(String url) {
    return '$url konnte nicht geöffnet werden';
  }

  @override
  String get settingsOpenSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get settingsAppVersion => 'App-Version';

  @override
  String get settingsInferenceEngine => 'Wie Finn läuft';

  @override
  String get settingsInferenceEngineValue => 'Vollständig auf diesem Telefon';

  @override
  String get settingsPrivacyMode => 'Datenschutzmodus';

  @override
  String get settingsPrivacyModeValue => 'Verschlüsselt auf dem Gerät';

  @override
  String get settingsModelArchitecture => 'Modellarchitektur';

  @override
  String get settingsModelArchitectureValue => 'LFM2.5-VL 1.6B (Liquid)';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsSpokenResponses => 'Gesprochene Antworten';

  @override
  String get settingsSpokenResponsesBody =>
      'Finn liest Antworten im Sprachmodus vor. Was du sagst, wird auf diesem Gerät in Text umgewandelt und verlässt es nie.';

  @override
  String get voiceMicSemantic => 'Sprich mit Finn';

  @override
  String get voiceCancelSemantic => 'Spracheingabe abbrechen';

  @override
  String get voiceExpandSemantic => 'Vollständigen Sprachmodus öffnen';

  @override
  String get voiceListening => 'Hört zu…';

  @override
  String get voiceTapToSpeak => 'Tippe auf das Mikrofon und sprich';

  @override
  String get voiceHeardYou => 'Verstanden';

  @override
  String get voiceDidNotCatch =>
      'Das habe ich nicht verstanden — versuch es noch einmal';

  @override
  String get voiceThinking => 'Finn denkt nach…';

  @override
  String get voiceSpeaking => 'Finn spricht — zum Unterbrechen tippen';

  @override
  String get voiceMicDenied =>
      'Mikrofonzugriff ist deaktiviert. Aktiviere ihn in den Systemeinstellungen, um den Sprachmodus zu nutzen.';

  @override
  String get voiceUnavailable =>
      'Spracherkennung ist derzeit nicht verfügbar. Gib deine Nachricht stattdessen ein.';

  @override
  String voiceModelNeeded(String size) {
    return 'Der Sprachmodus braucht einen einmaligen Download ($size). Deine Stimme wird auf diesem Gerät in Text umgewandelt und verlässt es nie.';
  }

  @override
  String get voiceModelDownload => 'Herunterladen';

  @override
  String voiceModelDownloading(int percent) {
    return 'Sprachmodell wird heruntergeladen… $percent %';
  }

  @override
  String get voiceModelFailed =>
      'Der Download wurde nicht abgeschlossen. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get voiceModelRetry => 'Erneut versuchen';

  @override
  String get voiceSpeakingLive => 'Spricht…';

  @override
  String get voiceStopSemantic => 'Stoppen';

  @override
  String get voiceCloseSemantic => 'Sprachmodus schließen';

  @override
  String get youTitle => 'Du';

  @override
  String get youIntroTitle => 'Mach Finn zu deinem';

  @override
  String get youIntroBody =>
      'Deine Einstellungen bleiben auf diesem Gerät und prägen künftige Antworten.';

  @override
  String get youAboutYou => 'Über dich';

  @override
  String get youNameLabel => 'Name';

  @override
  String get youNameHint => 'Wie soll Finn dich nennen?';

  @override
  String get youAboutLabel => 'Über dich';

  @override
  String get youAboutHint =>
      'Interessen, Arbeit oder Kontext, an den Finn sich erinnern soll';

  @override
  String get youInstructionsLabel => 'Benutzerdefinierte Anweisungen';

  @override
  String get youInstructionsHint =>
      'Wie soll Finn antworten? Ton, Länge, Stil…';

  @override
  String get youResponseStyle => 'Antwortstil';

  @override
  String get youResponseStyleBalanced => 'Ausgewogen';

  @override
  String get youResponseStyleConcise => 'Knapp';

  @override
  String get youResponseStyleDetailed => 'Ausführlich';

  @override
  String get youResponseStyleCreative => 'Kreativ';

  @override
  String get youSave => 'Speichern';

  @override
  String get youSaved => 'Personalisierung lokal gespeichert.';

  @override
  String get youSaveFailed => 'Änderungen konnten nicht gespeichert werden.';

  @override
  String get flowsTitle => 'Flows';

  @override
  String flowsSubtitle(int count) {
    return '$count verfügbar · Flows steuern relevante Antworten';
  }

  @override
  String get flowsNewSkill => 'Neuer Flow';

  @override
  String get flowsNoSkills =>
      'Noch keine eigenen Flows. Erstelle einen für einen wiederkehrenden Ablauf.';

  @override
  String get flowsInstructionHint =>
      'Schreibe eine wiederverwendbare Anweisung, die Finn bei Bedarf anwendet.';

  @override
  String get flowsDeleteTitle => 'Diesen Flow löschen?';

  @override
  String flowsDeleteBody(String name) {
    return '„$name“ wird von diesem Gerät entfernt.';
  }

  @override
  String get flowsLimitReached =>
      'Flow-Limit erreicht (4). Lösche einen, um einen weiteren hinzuzufügen.';

  @override
  String get flowsNameLabel => 'Flow-Name';

  @override
  String get flowsInstructionLabel => 'Anweisung';

  @override
  String get flowsRunAction => 'Jetzt ausführen';

  @override
  String get flowsRunRunning => 'Läuft…';

  @override
  String get flowsGrantLabel => 'Automatisch ausführen lassen';

  @override
  String get flowsGrantExplain =>
      'Ein Flow, der dein Handy verändert, braucht diese Erlaubnis, um ohne dich zu laufen. Du kannst sie jederzeit wieder deaktivieren.';

  @override
  String get flowsNeedsGrant => 'Braucht deine Erlaubnis, um selbst zu laufen';

  @override
  String get flowsHistoryTitle => 'Letzte Ausführungen';

  @override
  String get flowsHistoryEmpty => 'Dieser Flow wurde noch nicht ausgeführt.';

  @override
  String get flowsRunCompleted => 'Fertig';

  @override
  String get flowsRunDeclined => 'Du hast abgelehnt';

  @override
  String get flowsRunFailed => 'Früh beendet';

  @override
  String get flowsRunInterrupted => 'Abgebrochen';

  @override
  String get flowsRunBySchedule => 'Automatisch ausgeführt';

  @override
  String get flowsAutomationsTitle => 'Automatisierungen';

  @override
  String get flowsAutomationsSubtitle =>
      'Dinge, die Finn nach Zeitplan für dich erledigt. Nichts läuft, solange du es nicht einschaltest.';

  @override
  String get flowsNewAutomation => 'Neue Automatisierung';

  @override
  String get flowsNoAutomations =>
      'Noch keine Automatisierungen. Beginne mit einem Morgenbriefing.';

  @override
  String get flowsTemplateMorningBrief => 'Morgenbriefing';

  @override
  String get flowsTemplateMorningBriefBody =>
      'Nachrichten, die dich interessieren, und das Wetter in wenigen Zeilen.';

  @override
  String get flowsTemplateWebCheck => 'Web-Check';

  @override
  String get flowsTemplateWebCheckBody =>
      'Prüft ein Thema und sagt dir, was es Neues gibt.';

  @override
  String get flowsTemplateReminder => 'Erinnerung';

  @override
  String get flowsTemplateReminderBody =>
      'Eine Benachrichtigung mit deinen eigenen Worten.';

  @override
  String get flowsSlotTopics => 'Was du verfolgen möchtest';

  @override
  String get flowsSlotCity => 'Stadt für das Wetter (optional)';

  @override
  String get flowsSlotTopic => 'Thema';

  @override
  String get flowsSlotMessage => 'Nachricht';

  @override
  String get flowsScheduleHeading => 'Wann';

  @override
  String flowsScheduleWeekdaysAt(String time) {
    return 'Werktage um $time';
  }

  @override
  String get flowsScheduleEveryDay => 'Jeden Tag';

  @override
  String get flowsScheduleWeekdaysOnly => 'Werktage';

  @override
  String get flowsScheduleTime => 'Uhrzeit';

  @override
  String get flowsNotifyWhyTitle => 'Benachrichtigungen erlauben?';

  @override
  String get flowsNotifyWhyBody =>
      'Finn sendet eine Benachrichtigung, wenn die Automatisierung fällig ist. Ohne sie läuft sie nur, wenn du auf Ausführen tippst.';

  @override
  String get flowsNotifyAllow => 'Erlauben';

  @override
  String get flowsNotifyOff =>
      'Benachrichtigungen sind aus, daher läuft das nicht von selbst.';

  @override
  String flowsRunning(String name) {
    return '$name wird ausgeführt …';
  }

  @override
  String flowsRunReady(String name) {
    return '$name ist fertig';
  }

  @override
  String flowsRunCouldNotFinish(String name) {
    return '$name konnte nicht abgeschlossen werden';
  }

  @override
  String get flowsOpenResult => 'Ergebnis öffnen';

  @override
  String flowsNextRun(String when) {
    return 'Nächste: $when';
  }

  @override
  String get flowsRunByYou => 'Von dir ausgeführt';

  @override
  String get flowsStepsLabel => 'Schritte';

  @override
  String flowsStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schritte',
      one: '1 Schritt',
    );
    return '$_temp0';
  }

  @override
  String get flowsStepPrompt => 'Fragen';

  @override
  String get flowsStepDeviceAction => 'Auf dem Handy handeln';

  @override
  String get flowsStepNotify => 'Notiz';

  @override
  String get flowsStepBrowse => 'Nachschlagen';

  @override
  String get flowsScheduleLabel => 'Ausführung';

  @override
  String get flowsScheduleManual => 'Nur, wenn du ihn startest';

  @override
  String flowsScheduleDaily(String time) {
    return 'Täglich um $time';
  }

  @override
  String flowsScheduleWeekly(String days, String time) {
    return '$days um $time';
  }

  @override
  String get flowsScheduleAdd => 'Uhrzeit festlegen';

  @override
  String get flowsScheduleRemove => 'Nur auf deine Anfrage ausführen';

  @override
  String get chatBrowsingTitle => 'Web wird durchsucht';

  @override
  String get chatSearchingInline => 'Web wird durchsucht…';

  @override
  String get chatSearchedInline => 'Web durchsucht';

  @override
  String get chatShowSearchSteps => 'Suchschritte anzeigen';

  @override
  String get chatBrowsingHide => 'Ausblenden';

  @override
  String chatBrowsingSteps(int count) {
    return '$count Schritte';
  }

  @override
  String chatBrowsingSearch(String query) {
    return 'Im Web gesucht nach „$query“';
  }

  @override
  String chatBrowsingOpen(String title) {
    return '„$title“ gelesen';
  }

  @override
  String chatBrowsingFind(String query) {
    return 'Auf der Seite nach „$query“ gesucht';
  }

  @override
  String get creationsNoneTitle => 'Noch keine Kreationen.';

  @override
  String get creationsNoneBody =>
      'Hier lebt deine Kreativität.\nProbiere etwas mit FinnAI Creations aus.';

  @override
  String get creationsTitle => 'Kreationen';

  @override
  String get creationsSubtitle =>
      'Beschreibe, was du willst. Finn baut es auf dem Gerät.';

  @override
  String get creationsWhatAreWeMaking => 'Was erstellen wir?';

  @override
  String get creationsOriginalBrief => 'Ursprüngliche Beschreibung';

  @override
  String get creationsFinnAdapts => 'Finn passt die Struktur an das Format an.';

  @override
  String get creationsAskKind =>
      'Ist deine neue Kreation eine App, ein Widget oder eine Präsentation?';

  @override
  String creationsDescribeKind(String kind) {
    return 'Beschreibe, was deine $kind tun soll.';
  }

  @override
  String get creationsStageDesigning => 'Wird entworfen…';

  @override
  String get creationsStageWriting => 'Wird geschrieben…';

  @override
  String get creationsStageValidating => 'Ergebnis wird geprüft…';

  @override
  String get creationsStageRepairing => 'Detail wird korrigiert…';

  @override
  String get creationsFallbackNote =>
      'Finn konnte das Design nicht fertigstellen – hier ist eine funktionierende Vorlage, auf der du aufbauen kannst.';

  @override
  String get creationsTemplateAuto => 'Finn entscheiden lassen';

  @override
  String get creationsTemplateQuestion =>
      'Brauchst du einen Ausgangspunkt? Wähle einen oder beschreibe einfach, was du möchtest.';

  @override
  String get creationsTemplateCounter => 'Zähler';

  @override
  String get creationsTemplateChecklist => 'Checkliste';

  @override
  String get creationsTemplateList => 'Liste';

  @override
  String get creationsTemplateScoreboard => 'Spielstand';

  @override
  String get creationsTemplateStat => 'Große Zahl';

  @override
  String get creationsTemplateRows => 'Zeilen';

  @override
  String get creationsEdit => 'Bearbeiten';

  @override
  String get creationsEditTitle => 'Details bearbeiten';

  @override
  String get creationsSlotTitle => 'Name';

  @override
  String get creationsSlotUnit => 'Was du zählst';

  @override
  String get creationsSlotGoal => 'Ziel';

  @override
  String get creationsSlotEmoji => 'Emoji';

  @override
  String get creationsSlotAccent => 'Farbe';

  @override
  String get creationsSlotItems => 'Einträge';

  @override
  String get creationsSlotHint => 'Eingabehinweis';

  @override
  String get creationsSlotEmpty => 'Text für leere Liste';

  @override
  String get creationsSlotNameA => 'Erster Name';

  @override
  String get creationsSlotNameB => 'Zweiter Name';

  @override
  String get creationsSlotLabel => 'Beschriftung';

  @override
  String get creationsSlotValue => 'Wert';

  @override
  String get creationsSlotFooter => 'Fußzeile';

  @override
  String get creationsSlotRows => 'Zeilen';

  @override
  String get creationsSlotOnePerLine => 'Eine pro Zeile';

  @override
  String get creationsSlotRowFormat => 'Eine pro Zeile, z. B. „Wasser: 3“';

  @override
  String get creationsAccentMint => 'Mint';

  @override
  String get creationsAccentBlue => 'Blau';

  @override
  String get creationsAccentLime => 'Limone';

  @override
  String get creationsAccentAmber => 'Bernstein';

  @override
  String get creationsAccentRose => 'Rosa';

  @override
  String get creationsAccentViolet => 'Violett';

  @override
  String get creationsAccentSky => 'Himmel';

  @override
  String get creationsNewCreation => 'Neue Kreation';

  @override
  String get creationsChooseKindSemantic =>
      'Auswählen, was erstellt werden soll';

  @override
  String get creationsFailed =>
      'Finn konnte diese Kreation nicht fertigstellen. Bitte versuche es erneut.';

  @override
  String get creationsHomeScreenUnsupported =>
      'Widgets für den Startbildschirm sind auf diesem Gerät nicht verfügbar.';

  @override
  String get creationsHomeScreenAdded => 'Zum Startbildschirm hinzugefügt.';

  @override
  String get creationsHomeScreenFailed =>
      'Das konnte nicht zum Startbildschirm hinzugefügt werden.';

  @override
  String creationsExportedTo(String fileName) {
    return '$fileName gespeichert';
  }

  @override
  String get creationsExportDeck => 'Als PowerPoint exportieren';

  @override
  String get creationsAddToHomeScreen => 'Zum Startbildschirm hinzufügen';

  @override
  String get creationsWidgetPreview =>
      'So sieht es auf deinem Startbildschirm aus.';

  @override
  String get creationsKindApp => 'App';

  @override
  String get creationsKindWidget => 'Widget';

  @override
  String get creationsKindPresentation => 'Präsentation';

  @override
  String get creationsFilterApps => 'Apps';

  @override
  String get creationsFilterWidgets => 'Widgets';

  @override
  String get creationsFilterPresentations => 'Präsentationen';

  @override
  String get flowsSaveFailed => 'Dieser Flow konnte nicht gespeichert werden.';

  @override
  String get flowsBuiltForFinn => 'Für Finn gebaut';

  @override
  String get flowsBuiltForFinnSubtitle =>
      'Aktiviere nur, was du für jede Art von Arbeit brauchst.';

  @override
  String get flowsYourSkills => 'Deine Flows';

  @override
  String get flowsYourSkillsSubtitle =>
      'Erstelle wiederverwendbare Anweisungen für deine eigenen Workflows.';

  @override
  String get flowsNoneActive => 'Keine Flows aktiv';

  @override
  String flowsActiveCount(int count) {
    return '$count aktiv';
  }

  @override
  String get creationsExportedShared => 'Präsentation ist bereit zum Teilen.';

  @override
  String get creationsExportFailed =>
      'Diese Präsentation konnte nicht exportiert werden.';

  @override
  String get creationsResetApp => 'Zurücksetzen';

  @override
  String get creationsPreviousSlide => 'Vorherige Folie';

  @override
  String get creationsNextSlide => 'Nächste Folie';

  @override
  String creationsSlideOf(int index, int count) {
    return 'Folie $index von $count';
  }

  @override
  String creationsElementCount(int count) {
    return '$count Elemente';
  }

  @override
  String creationsRowCount(int count) {
    return '$count Zeilen';
  }

  @override
  String creationsSlideCount(int count) {
    return '$count Folien';
  }

  @override
  String get creationsStopTitle => 'Diese Kreation stoppen?';

  @override
  String get creationsStopBody =>
      'Das unfertige Ergebnis wird verworfen. Dein Prompt bleibt hier erhalten.';

  @override
  String get creationsDeleteTitle => 'Diese Kreation löschen?';

  @override
  String creationsDeleteBody(String title) {
    return '„$title“ wird von diesem Gerät entfernt.';
  }

  @override
  String get creationsOpening => 'Kreationen werden geöffnet';

  @override
  String get creationsGenerating => 'Wird generiert…';

  @override
  String get reportTitle => 'KI-Antwort melden';

  @override
  String get reportSubtitle =>
      'Hilf uns, sichere und korrekte KI-Antworten zu gewährleisten. Meldungen werden geprüft, um die Schutzmechanismen von FinnAI zu verbessern.';

  @override
  String get reportReasonLabel => 'Grund der Meldung';

  @override
  String get reportIncludePrompt => 'Meinen Prompt in diese Meldung aufnehmen';

  @override
  String get reportResponsePreview => 'Vorschau der gemeldeten Antwort';

  @override
  String get reportContinueHint =>
      'Weiter öffnet einen vollständigen Bericht an finn_org@proton.me. Es wird nichts gesendet, bis du ihn in deiner E-Mail-App prüfst und absendest.';

  @override
  String get reportContinueToEmail => 'Weiter zur E-Mail';

  @override
  String get reportReviewInEmail =>
      'Prüfe den Bericht in deiner E-Mail-App und sende ihn ab.';

  @override
  String get reportNotConfigured =>
      'Die E-Mail-Adresse für Meldungen ist nicht konfiguriert.';

  @override
  String get reportCategoryHarmful => 'Schädlich oder unsicher';

  @override
  String get reportCategoryIncorrect => 'Falsch oder irreführend';

  @override
  String get reportCategoryBiased => 'Voreingenommen oder unfair';

  @override
  String get reportCategoryOther => 'Sonstiges';

  @override
  String get snackModelMemoryReleased => 'Speicher freigegeben.';

  @override
  String get settingsSavedConversationsLabel => 'Gespeicherte Chats';

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
      'Bilderkennungen ist noch nicht eingerichtet. Füge den Bildsupport in den Einstellungen hinzu.';

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
  String get chatMoreActions => 'Weitere Aktionen';

  @override
  String get chatHideSources => 'Quellen ausblenden';

  @override
  String get chatShowSources => 'Quellen einblenden';

  @override
  String get chatRewriteHint => 'Nachricht neu formulieren';

  @override
  String get chatAskAnythingHint => 'Frag etwas';

  @override
  String get chatGreeting => 'Hi, was beschäftigt dich?';

  @override
  String get voiceGreeting => 'Was gibt\'s?';

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
  String get flowsActionsTooltip => 'Flow-Aktionen';

  @override
  String flowsNameSemantic(String name) {
    return '$name Flow';
  }

  @override
  String get flowsEditTitle => 'Flow bearbeiten';

  @override
  String get flowsEditorName => 'Name';

  @override
  String get flowsEditorNameHint => 'Was macht dieser Flow?';

  @override
  String get flowsEditorDescription => 'Kurze Beschreibung';

  @override
  String get flowsEditorDescriptionHint => 'Eine kurze Erinnerung für dich';

  @override
  String get flowsEditorInstructions => 'Anweisungen';

  @override
  String get flowsEditorInstructionsHint =>
      'Sag Finn, wie es diese Art von Aufgabe angehen soll';

  @override
  String get flowsCategoryWriting => 'Schreiben';

  @override
  String get flowsCategoryDevelopment => 'Entwicklung';

  @override
  String get flowsCategoryLearning => 'Lernen';

  @override
  String get flowsCategoryPlanning => 'Planung';

  @override
  String get flowsCategoryCustom => 'Benutzerdefiniert';

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

  @override
  String get deviceActionsTitle => 'Aktionen';

  @override
  String get deviceActionsIntro =>
      'Bitte Finn, etwas auf deinem Telefon zu erledigen — einen Wecker stellen, einen Timer starten oder eine Einstellung öffnen.';

  @override
  String get deviceActionsExamples => 'Probiere eine davon';

  @override
  String get deviceActionsHint => 'Was soll Finn tun?';

  @override
  String get deviceActionsRun => 'Weiter';

  @override
  String get deviceActionsResolving => 'Finn überlegt…';

  @override
  String get deviceActionsUnresolved =>
      'Daraus konnte ich keine Aktion machen. Nenne die Einstellung oder App direkt.';

  @override
  String get deviceActionsConfirm => 'Ausführen';

  @override
  String get deviceActionsCancel => 'Abbrechen';

  @override
  String get deviceActionsAgain => 'Etwas anderes tun';

  @override
  String get deviceActionsOpenNotice =>
      'Android erlaubt Apps nicht, Funk-Einstellungen selbst zu ändern. Finn öffnet den richtigen Bildschirm, du schaltest um.';

  @override
  String deviceActionsResultOpened(String detail) {
    return '$detail geöffnet';
  }

  @override
  String deviceActionsResultPerformed(String detail) {
    return 'Erledigt — $detail';
  }

  @override
  String get deviceActionsResultUnavailable => 'Dein Gerät kann das nicht';

  @override
  String get deviceActionsResultFailed => 'Das hat nicht funktioniert';

  @override
  String deviceActionsResultFailedDetail(String error) {
    return 'Das hat nicht funktioniert — $error';
  }

  @override
  String get deviceActionsExampleAlarm => 'Wecker für 7 Uhr stellen';

  @override
  String get deviceActionsExampleTimer => '10-Minuten-Timer starten';

  @override
  String get deviceActionsExampleWifi => 'WLAN-Einstellungen öffnen';

  @override
  String get deviceActionsExampleFlashlight => 'Taschenlampe einschalten';

  @override
  String get deviceActionsExampleBluetooth => 'Bluetooth-Einstellungen öffnen';

  @override
  String deviceActionSetAlarm(String time) {
    return 'Wecker auf $time stellen';
  }

  @override
  String deviceActionSetTimer(String duration) {
    return 'Timer auf $duration stellen';
  }

  @override
  String get deviceActionShowAlarms => 'Wecker öffnen';

  @override
  String get deviceActionTorchOn => 'Taschenlampe einschalten';

  @override
  String get deviceActionTorchOff => 'Taschenlampe ausschalten';

  @override
  String deviceActionMedia(String action) {
    return 'Musikwiedergabe: $action';
  }

  @override
  String deviceActionVolume(String direction) {
    return 'Lautstärke $direction';
  }

  @override
  String deviceActionOpenSettings(String screen) {
    return '$screen-Einstellungen öffnen';
  }

  @override
  String deviceActionOpenApp(String name) {
    return '$name öffnen';
  }

  @override
  String deviceActionDial(String number) {
    return 'Wählhilfe mit $number öffnen';
  }

  @override
  String get deviceActionComposeSms => 'Neue SMS verfassen';

  @override
  String get deviceActionComposeEmail => 'Neue E-Mail verfassen';

  @override
  String get deviceActionTakePhoto => 'Kamera öffnen';

  @override
  String deviceActionOpenUrl(String url) {
    return '$url öffnen';
  }

  @override
  String deviceActionNavigate(String query) {
    return 'Route nach $query';
  }

  @override
  String get deviceActionShare => 'Text über eine andere App teilen';

  @override
  String get deviceActionMediaPlay => 'wiedergeben';

  @override
  String get deviceActionMediaPause => 'pausieren';

  @override
  String get deviceActionMediaNext => 'nächster Titel';

  @override
  String get deviceActionMediaPrevious => 'vorheriger Titel';

  @override
  String get deviceActionVolumeUp => 'lauter';

  @override
  String get deviceActionVolumeDown => 'leiser';

  @override
  String get deviceActionVolumeMute => 'aus';

  @override
  String get deviceScreenWifi => 'WLAN';

  @override
  String get deviceScreenBluetooth => 'Bluetooth';

  @override
  String get deviceScreenAirplane => 'Flugmodus';

  @override
  String get deviceScreenHotspot => 'Hotspot';

  @override
  String get deviceScreenMobileData => 'Mobile Daten';

  @override
  String get deviceScreenBatterySaver => 'Energiesparen';

  @override
  String get deviceScreenBatteryUsage => 'Akkuverbrauch';

  @override
  String get deviceScreenDnd => 'Nicht stören';

  @override
  String get deviceScreenDisplay => 'Display';

  @override
  String get deviceScreenSound => 'Ton';

  @override
  String get deviceScreenLocation => 'Standort';

  @override
  String get deviceScreenStorage => 'Speicher';

  @override
  String get deviceScreenDateTime => 'Datum und Uhrzeit';

  @override
  String get deviceScreenKeyboard => 'Tastatur';

  @override
  String get deviceScreenLanguage => 'Sprache';

  @override
  String get deviceScreenAccessibility => 'Bedienungshilfen';

  @override
  String get deviceScreenApplications => 'Apps';

  @override
  String get deviceScreenNfc => 'NFC';

  @override
  String get deviceScreenCast => 'Übertragen';

  @override
  String get deviceScreenVpn => 'VPN';

  @override
  String get deviceScreenDeveloper => 'Entwickleroptionen';

  @override
  String get deviceScreenHome => 'Startbildschirm';

  @override
  String get deviceActionsResultDone => 'Erledigt';

  @override
  String get settingsActionsSection => 'Aktionen auf deinem Gerät';

  @override
  String get settingsActionsRow => 'Aktionen';

  @override
  String get deviceScreenSystem => 'Einstellungen';

  @override
  String get deviceActionsDismissed => 'Abgebrochen';

  @override
  String get creationsStopped => 'Gestoppt.';

  @override
  String get creationsLoadFailed =>
      'Finn konnte deine gespeicherten Kreationen nicht öffnen. Bitte versuche es erneut.';

  @override
  String get creationsDeleteFailed =>
      'Diese Kreation konnte nicht gelöscht werden. Bitte versuche es erneut.';

  @override
  String get hubModelTitle => 'FinnAI Foundation';

  @override
  String hubModelSub(String size) {
    return 'Auf diesem Gerät, $size';
  }

  @override
  String get hubVoiceTitle => 'Stimme und Sprache';

  @override
  String hubVoiceSub(String speed, String language) {
    return 'Tempo: $speed, $language';
  }

  @override
  String get hubAccessTitle => 'Gerätezugriff';

  @override
  String get hubAccessSub => 'Kalender, Kontakte, Dateien';

  @override
  String get hubYouTitle => 'Du';

  @override
  String get hubYouSub => 'Was FinnAI lernt und nutzt';

  @override
  String get hubDataTitle => 'Datenschutz und Daten';

  @override
  String get hubDataSub => 'Speicher, Export, Löschen';

  @override
  String get hubAboutTitle => 'Über';

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
    return '$size deines Speichers, heruntergeladen am $date.';
  }

  @override
  String modelStoredNoDate(String size) {
    return '$size deines Speichers.';
  }

  @override
  String get modelNotInstalled => 'Noch nicht heruntergeladen.';

  @override
  String get modelOffline => 'Offline arbeiten';

  @override
  String get modelOfflineSub => 'Alles läuft auf diesem Gerät';

  @override
  String get modelLookups => 'Online nachschlagen';

  @override
  String get modelLookupsSub =>
      'Nur wenn eine Frage es braucht. Deine Chats und Du bleiben hier.';

  @override
  String get modelUpdates => 'Nach Updates suchen';

  @override
  String get modelUpToDate => 'Aktuell';

  @override
  String get modelRemove => 'Modell entfernen';

  @override
  String modelRemoveSub(String size) {
    return 'Gibt $size frei';
  }

  @override
  String get modelRemoveTitle => 'Modell entfernen?';

  @override
  String get modelRemoveBody =>
      'FinnAI muss es erneut herunterladen, bevor du chatten kannst. Deine Chats bleiben.';

  @override
  String get modelRemoveConfirm => 'Entfernen';

  @override
  String get voiceReadAloud => 'Antworten vorlesen';

  @override
  String get voiceReadAloudSub => 'In Sprachchats';

  @override
  String get voiceTranscript => 'Live-Transkript anzeigen';

  @override
  String get voiceTranscriptSub => 'Während du sprichst';

  @override
  String get voiceSpeed => 'Sprechtempo';

  @override
  String get voiceSpeedSlow => 'Langsam';

  @override
  String get voiceSpeedNormal => 'Normal';

  @override
  String get voiceSpeedFast => 'Schnell';

  @override
  String get voiceLanguage => 'Sprache';

  @override
  String get voiceLanguageSub => 'Folgt deinem Telefon';

  @override
  String get accessIntro =>
      'FinnAI liest nur, was du erlaubst, und nur auf diesem Gerät.';

  @override
  String get accessMaster => 'Kontext von diesem Gerät nutzen';

  @override
  String get accessMasterSub => 'Ausschalten, damit FinnAI nichts liest';

  @override
  String get accessActions => 'Aktionen auf deinem Gerät';

  @override
  String get accessActionsSub => 'Wecker, Timer, Einstellungen';

  @override
  String get ctxCalendar => 'Kalender';

  @override
  String get ctxCalendarSub => 'Termine und freie Zeit';

  @override
  String get ctxContacts => 'Kontakte';

  @override
  String get ctxContactsSub => 'Namen und Beziehungen';

  @override
  String get ctxNotifications => 'Benachrichtigungen';

  @override
  String get ctxNotificationsSub => 'Was deine Aufmerksamkeit braucht';

  @override
  String get ctxPhotos => 'Fotos';

  @override
  String get ctxPhotosSub => 'Nur wenn du sie anhängst';

  @override
  String get ctxFiles => 'Dateien';

  @override
  String get ctxFilesSub => 'Dokumente, die du mit FinnAI öffnest';

  @override
  String get ctxLocation => 'Standort';

  @override
  String get ctxLocationSub => 'Nur solange die App geöffnet ist';

  @override
  String get dataStoredHere => 'Auf diesem Gerät gespeichert';

  @override
  String get dataChats => 'Chats';

  @override
  String get dataCreations => 'Kreationen';

  @override
  String get dataYou => 'Du';

  @override
  String get dataModel => 'FinnAI Foundation';

  @override
  String get dataExport => 'Alles exportieren';

  @override
  String get dataExportSub => 'Chats, Kreationen, Flows und Du';

  @override
  String get dataDeleteChats => 'Alle Chats löschen';

  @override
  String get dataDeleteChatsSub => 'Du bleibt unverändert';

  @override
  String get dataErase => 'Alles löschen';

  @override
  String get dataEraseSub => 'Setzt FinnAI auf diesem Gerät zurück';

  @override
  String get dataExportFailed => 'Export fehlgeschlagen. Versuche es erneut.';

  @override
  String get aboutBlurb =>
      'Ein privater Assistent, der auf deinem Gerät läuft.';

  @override
  String get aboutPrivacy => 'Datenschutzerklärung';

  @override
  String get aboutTerms => 'Nutzungsbedingungen';

  @override
  String get aboutLicences => 'Open-Source-Lizenzen';

  @override
  String get aboutFeedback => 'Feedback senden';

  @override
  String chatUsedFromYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sachen',
      one: '1 Sache',
    );
    return '$_temp0 aus Du genutzt';
  }

  @override
  String get youAboutTitle => 'Was FinnAI über dich weiß';

  @override
  String youUpdated(String when) {
    return 'Aktualisiert $when';
  }

  @override
  String youReviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Sachen zu prüfen',
      one: '1 neue Sache zu prüfen',
    );
    return '$_temp0';
  }

  @override
  String get youReviewSub => 'In deinen letzten Chats bemerkt';

  @override
  String youCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sachen',
      one: '1 Sache',
    );
    return '$_temp0';
  }

  @override
  String get youStoredOnly => 'Nur auf diesem Gerät gespeichert';

  @override
  String get youCatPeople => 'Personen';

  @override
  String get youCatWork => 'Arbeit';

  @override
  String get youCatRoutines => 'Routinen';

  @override
  String get youCatPreferences => 'Vorlieben';

  @override
  String get youCatPlaces => 'Orte';

  @override
  String get youCatInterests => 'Interessen';

  @override
  String get youEmptyTitle => 'FinnAI lernt dich noch kennen';

  @override
  String get youEmptyBody =>
      'Beim Chatten lernt FinnAI, was hilft, und behält es hier auf diesem Gerät. Du kannst auch selbst etwas aufschreiben.';

  @override
  String get youTellFinn => 'Erzähl FinnAI von dir';

  @override
  String get youPrivacyTitle => 'Datenschutz';

  @override
  String youCategoryIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Sachen, die sich FinnAI merkt. Tippe auf eine, um zu sehen, woher sie kommt.',
      one:
          '1 Sache, die sich FinnAI merkt. Tippe darauf, um zu sehen, woher sie kommt.',
    );
    return '$_temp0';
  }

  @override
  String get youCategoryEmpty =>
      'Hier ist noch nichts. Tippe auf Plus, um etwas hinzuzufügen.';

  @override
  String youSeenIn(String where) {
    return 'Gesehen in $where';
  }

  @override
  String get youSeenInLabel => 'Gesehen in';

  @override
  String get youAddedByYou => 'Von dir hinzugefügt';

  @override
  String youLearnedOn(String when) {
    return 'Gelernt $when. Auf diesem Gerät gespeichert.';
  }

  @override
  String get youEdit => 'Bearbeiten';

  @override
  String get youDoNotUse => 'Nicht in Chats verwenden';

  @override
  String get youForgetThis => 'Das vergessen';

  @override
  String get youForgetTitle => 'Das vergessen?';

  @override
  String get youForgetBody =>
      'FinnAI verwendet es nicht mehr in Chats. Wenn du es wieder erwähnst, kann es erneut gelernt werden.';

  @override
  String get youForgetConfirm => 'Vergessen';

  @override
  String get youAddLabel => 'In deinen eigenen Worten';

  @override
  String get youAddHint =>
      'Etwas, das sich FinnAI merken soll, etwa wie du gern arbeitest oder wer dir wichtig ist.';

  @override
  String get youWhereBelongs => 'Wohin es gehört';

  @override
  String get youUseEveryChat => 'In jedem Chat verwenden';

  @override
  String get youUseEveryChatSub =>
      'Ausschalten, um es nur auf Nachfrage zu nutzen';

  @override
  String get youSaveToYou => 'In Du speichern';

  @override
  String get youReviewTitleBar => 'Prüfen';

  @override
  String get youReviewIntro =>
      'FinnAI hat das in letzten Chats bemerkt. Behalte, was stimmt, und vergiss den Rest.';

  @override
  String get youReviewEmpty => 'Gerade nichts zu prüfen.';

  @override
  String get youKeep => 'Behalten';

  @override
  String youFrom(String category, String chat) {
    return '$category, aus $chat';
  }

  @override
  String get youPrivacyNote =>
      'Alles in Du wird auf diesem Gerät gespeichert. FinnAI sendet es nirgendwohin.';

  @override
  String get youLearn => 'Aus Gesprächen lernen';

  @override
  String get youLearnSub => 'FinnAI schlägt nach dem Chat Ergänzungen vor';

  @override
  String get youUseInChats => 'Du in neuen Chats verwenden';

  @override
  String get youUseInChatsSub => 'Du kannst es pro Chat ausschalten';

  @override
  String get youLearnAbout => 'Lernen über';

  @override
  String get youExport => 'Du exportieren';

  @override
  String get youExportSub => 'Eine Kopie als Datei sichern';

  @override
  String get youErase => 'Alles in Du löschen';

  @override
  String youEraseSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sachen',
      one: '1 Sache',
    );
    return 'Entfernt $_temp0';
  }

  @override
  String get youEraseTitle => 'Alles in Du löschen?';

  @override
  String get youEraseBody =>
      'Alles, was sich FinnAI merkt, wird von diesem Gerät entfernt. Deine Chats bleiben.';

  @override
  String get youEraseConfirm => 'Löschen';

  @override
  String get youPersonalise => 'Antwortstil und Anweisungen';

  @override
  String get youPersonaliseSub => 'Name, Ton und eigene Anweisungen';

  @override
  String get youRemembered => 'In Du gespeichert';

  @override
  String get youWhenToday => 'heute';

  @override
  String youWhenMinutes(int count) {
    return 'vor $count Minuten';
  }

  @override
  String youWhenHours(int count) {
    return 'vor $count Stunden';
  }

  @override
  String youWhenDays(int count) {
    return 'vor $count Tagen';
  }

  @override
  String get youWhenJustNow => 'gerade eben';

  @override
  String get searchHint => 'Suchen';

  @override
  String get searchChatsHeading => 'Chats';

  @override
  String get searchCreationsHeading => 'Kreationen';

  @override
  String get searchNothing => 'Nichts gefunden';

  @override
  String get searchPrompt => 'Durchsuche deine Chats, Kreationen und Du.';

  @override
  String get chatReadAloud => 'Vorlesen';

  @override
  String get chatRememberInYou => 'In Du merken';

  @override
  String get chatShare => 'Teilen';

  @override
  String get plusCreate => 'Erstellen';

  @override
  String get plusWidget => 'Widget';

  @override
  String get plusWidgetSub => 'Für deinen Startbildschirm';

  @override
  String get plusMiniApp => 'Mini-App';

  @override
  String get plusMiniAppSub => 'Ein kleines Werkzeug';

  @override
  String get plusPresentation => 'Präsentation';

  @override
  String get plusPresentationSub => 'Folien zum Teilen';

  @override
  String get plusFlow => 'Flow';

  @override
  String get plusFlowSub => 'Läuft von allein';

  @override
  String get plusAddToChat => 'Zum Chat hinzufügen';

  @override
  String get plusPhoto => 'Foto';

  @override
  String optionsStarted(String when) {
    return 'Begonnen $when. Auf diesem Gerät gespeichert.';
  }

  @override
  String get optionsPin => 'Chat anheften';

  @override
  String get optionsUnpin => 'Chat lösen';

  @override
  String get optionsExport => 'Als Text exportieren';

  @override
  String get optionsDelete => 'Chat löschen';

  @override
  String get deleteChatTitle => 'Diesen Chat löschen?';

  @override
  String get deleteChatBody =>
      'Er wird von diesem Gerät entfernt. Was FinnAI daraus gelernt hat, bleibt in Du, bis du es vergisst.';

  @override
  String get fromYouTitle => 'Aus Du';

  @override
  String get fromYouSub =>
      'FinnAI hat diese in diesem Chat genutzt. Nichts verlässt dein Gerät.';

  @override
  String get fromYouUse => 'Du in diesem Chat verwenden';

  @override
  String get fromYouOpen => 'Du öffnen';

  @override
  String get chatRenamePrompt => 'Chat umbenennen';

  @override
  String get flowsFilterAll => 'Alle';

  @override
  String get flowsFilterActive => 'Aktiv';

  @override
  String get flowsFilterPaused => 'Pausiert';

  @override
  String get flowsPhoneOn =>
      'Flows laufen auf diesem Gerät, dein Telefon muss also eingeschaltet sein.';

  @override
  String get flowsOnlyWhenAsked => 'Nur auf Nachfrage';

  @override
  String flowsLastRunLine(String when, String result) {
    return 'Letzter Lauf $when, $result';
  }

  @override
  String get flowsNeverRun => 'Noch nicht gelaufen';

  @override
  String get flowsPausedLine => 'Pausiert';

  @override
  String get flowsResultDone => 'fertig';

  @override
  String get flowsResultFailed => 'fehlgeschlagen';

  @override
  String get flowsResultStopped => 'gestoppt';

  @override
  String get flowsWhenToday => 'heute';

  @override
  String get flowsWhenYesterday => 'gestern';

  @override
  String get flowsEmptyTitle => 'Noch keine Flows';

  @override
  String get flowsEmptyBody =>
      'Ein Flow erledigt eine Aufgabe für dich nach Zeitplan oder wenn etwas passiert. Beschreibe einen im Chat.';

  @override
  String get flowsEmptyCreate => 'Flow erstellen';

  @override
  String get flowsNewTitle => 'Neuer Flow';

  @override
  String get flowsNewSub =>
      'Starte mit Worten, einer Zeit oder einem Ereignis.';

  @override
  String get flowsNewDescribe => 'Beschreibe es';

  @override
  String get flowsNewDescribeSub => 'Sag FinnAI, was passieren soll';

  @override
  String get flowsNewTime => 'Zu einer festen Zeit';

  @override
  String get flowsNewTimeSub => 'Jeden Tag, jede Woche oder jeden Monat';

  @override
  String get flowsNewEvent => 'Wenn etwas passiert';

  @override
  String get flowsNewEventSub => 'Laden, Ankommen, eine Benachrichtigung';

  @override
  String flowsDetailOn(String when) {
    return 'An, nächster Lauf $when';
  }

  @override
  String get flowsDetailOnManual => 'An, läuft auf Nachfrage';

  @override
  String get flowsDetailPaused => 'Pausiert';

  @override
  String get flowsWhen => 'Wann';

  @override
  String get flowsThen => 'Dann';

  @override
  String get flowsRecentRuns => 'Letzte Läufe';

  @override
  String get flowsNoRunsYet => 'Noch keine Läufe';

  @override
  String get flowsRunStatusDone => 'Fertig';

  @override
  String get flowsRunStatusFailed => 'Konnte nicht abschließen';

  @override
  String get flowsRunStatusDeclined => 'Nicht erlaubt';

  @override
  String get flowsRunStatusNeedsGrant => 'Braucht deine Erlaubnis';

  @override
  String get flowsRunStatusStopped => 'Gestoppt';

  @override
  String get flowsMenuEdit => 'Bearbeiten';

  @override
  String get flowsMenuPause => 'Pausieren';

  @override
  String get flowsMenuResume => 'Einschalten';

  @override
  String get flowsMenuDuplicate => 'Duplizieren';

  @override
  String get flowsMenuDelete => 'Löschen';

  @override
  String get flowsRunFinished => 'Abgeschlossen';

  @override
  String flowsRunFinishedIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds Sekunden',
      one: '1 Sekunde',
    );
    return 'Fertig in $_temp0';
  }

  @override
  String get flowsRunAgain => 'Erneut ausführen';

  @override
  String get flowsBuilderHint => 'Beschreibe, was passieren soll';

  @override
  String get flowsBuilderHere =>
      'Hier ist der Flow. Prüfe ihn und schalte ihn dann ein.';

  @override
  String get flowsBuilderNoMatch =>
      'Das kann ich noch nicht bauen. Wähle einen davon, dann richte ich ihn ein.';

  @override
  String get flowsBuilderTurnOn => 'Einschalten';

  @override
  String get flowsStartWhen => 'Starten, wenn';

  @override
  String get flowsTriggerTime => 'Zu einer festen Zeit';

  @override
  String get flowsTriggerTimeSub => 'Jeden Tag, jede Woche oder jeden Monat';

  @override
  String get flowsTriggerPlace => 'Ankommen oder Verlassen';

  @override
  String get flowsTriggerPlaceSub => 'Ein Ort deiner Wahl';

  @override
  String get flowsTriggerCharging => 'Laden';

  @override
  String get flowsTriggerChargingSub => 'Beim Anschließen oder Trennen';

  @override
  String get flowsTriggerBattery => 'Akkustand';

  @override
  String get flowsTriggerBatterySub => 'Unter oder über einem Wert';

  @override
  String get flowsTriggerNotification => 'Eine Benachrichtigung';

  @override
  String get flowsTriggerNotificationSub => 'Wenn eine von einer App kommt';

  @override
  String get flowsTriggerManual => 'Nur auf Nachfrage';

  @override
  String get flowsTriggerManualSub => 'Starte es selbst';

  @override
  String get flowsTriggerSoon => 'Noch nicht verfügbar';

  @override
  String get flowsScheduleSheetTitle => 'Zeitplan';

  @override
  String get flowsScheduleSave => 'Zeitplan speichern';

  @override
  String flowsAllowTitle(String name) {
    return '$name erlauben, auf deinem Telefon zu handeln?';
  }

  @override
  String get flowsAllowConfirm => 'Erlauben';

  @override
  String flowsDeleteNamed(String name) {
    return '$name löschen?';
  }

  @override
  String get flowsDeleteNamedBody =>
      'Seine bisherigen Läufe werden ebenfalls entfernt. Das lässt sich nicht rückgängig machen.';

  @override
  String get flowsGuidesTitle => 'Leitfäden';

  @override
  String flowsStepLookUp(String query) {
    return '$query nachschlagen';
  }

  @override
  String get flowsStepWrite => 'Die Antwort schreiben';

  @override
  String get creationsNewSheetSub =>
      'Beschreibe es im Chat. FinnAI baut es auf diesem Gerät.';

  @override
  String get creationsNewWidgetSub =>
      'Kleine Werkzeuge für deinen Startbildschirm';

  @override
  String get creationsNewAppSub =>
      'Ein einfaches Werkzeug, das in FinnAI läuft';

  @override
  String get creationsNewDeckSub => 'Folien zum Präsentieren oder Teilen';

  @override
  String get creationsMenuEditWithFinn => 'Mit FinnAI bearbeiten';

  @override
  String get creationsMenuDuplicate => 'Duplizieren';

  @override
  String get creationsMenuShare => 'Teilen';

  @override
  String creationsDeleteNamed(String name) {
    return '$name löschen?';
  }

  @override
  String get creationsDeleteNamedBody =>
      'Es wird aus Kreationen und von deinem Startbildschirm entfernt. Das lässt sich nicht rückgängig machen.';

  @override
  String get creationsSizeSmall => 'Klein';

  @override
  String get creationsSizeMedium => 'Mittel';

  @override
  String get creationsSizeLarge => 'Groß';

  @override
  String get creationsUpdatesOnDevice =>
      'Aktualisiert sich auf diesem Gerät. Nichts verlässt dein Telefon.';

  @override
  String get creationsMadeInChat => 'Im Chat erstellt';

  @override
  String get creationsDataLabel => 'Daten';

  @override
  String get creationsDataSub => 'In diesem Widget gespeichert';

  @override
  String creationsAddHomeTitle(String name) {
    return '$name zu deinem Startbildschirm hinzufügen?';
  }

  @override
  String get creationsAddHomeBody =>
      'Es sitzt wie jedes andere Widget. Du kannst es später verschieben oder entfernen.';

  @override
  String get creationsAddHomeConfirm => 'Hinzufügen';

  @override
  String get creationsBuilderTitleWidget => 'Neues Widget';

  @override
  String get creationsBuilderTitleApp => 'Neue Mini-App';

  @override
  String get creationsBuilderTitleDeck => 'Neue Präsentation';

  @override
  String get creationsBuilderHint => 'Beschreibe, was gebaut werden soll';

  @override
  String get creationsBuilderChangeHint => 'Änderungen anfragen';

  @override
  String get creationsBuilderGotIt =>
      'Verstanden. Ich baue es auf diesem Gerät.';

  @override
  String get creationsBuilderReady =>
      'Hier ist es. Öffne es oder bearbeite weiter.';

  @override
  String get creationsSaveToCreations => 'In Kreationen speichern';

  @override
  String get creationsKeepEditing => 'Weiter bearbeiten';

  @override
  String get creationsSpeakerNotes => 'Vortragsnotizen';

  @override
  String get creationsPresent => 'Präsentieren';

  @override
  String get creationsDuplicated => 'Dupliziert.';

  @override
  String get onboardingChooseTitle => 'Wähle, was FinnAI sehen darf';

  @override
  String get onboardingChooseBody =>
      'Du kannst das jederzeit in den Einstellungen ändern. Alles bleibt auf diesem Gerät.';

  @override
  String get onboardingDownloadPausedTitle => 'Download pausiert';

  @override
  String get onboardingDownloadPausedBody =>
      'Warte auf eine Verbindung, dein Fortschritt ist gespeichert.';

  @override
  String get onboardingDownloadPausedNote =>
      'Es geht weiter, sobald du wieder online bist.';

  @override
  String get flowsNewGuide => 'Neuer Leitfaden';

  @override
  String get flowsStepNotifyMe => 'Mich benachrichtigen';

  @override
  String get creationsTemplateTracker => 'Tracker';

  @override
  String get creationsSlotStep => 'Pro Tipp';

  @override
  String get creationsResetAppTitle => 'Diese App zurücksetzen?';

  @override
  String get creationsResetAppBody =>
      'Alles, was du hinzugefügt hast, wird gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get deviceActionVibrate => 'Das Telefon vibrieren lassen';

  @override
  String get flowsTrigManual => 'Nur wenn ich es starte';

  @override
  String get flowsTrigTimeOfDay => 'Zu einer festen Uhrzeit';

  @override
  String flowsTrigEveryMinutes(int n) {
    return 'Alle $n Minuten';
  }

  @override
  String flowsTrigEveryHours(int n) {
    return 'Alle $n Stunden';
  }

  @override
  String get flowsTrigEveryHour => 'Jede Stunde';

  @override
  String get flowsTrigInterval => 'Wiederholt';

  @override
  String get flowsTrigChargerOn => 'Ladegerät angeschlossen';

  @override
  String get flowsTrigChargerOff => 'Ladegerät getrennt';

  @override
  String flowsTrigBatteryLow(int n) {
    return 'Akku fällt auf $n %';
  }

  @override
  String get flowsTrigHeadsetOn => 'Kopfhörer verbunden';

  @override
  String get flowsTrigHeadsetOff => 'Kopfhörer getrennt';

  @override
  String get flowsTrigWifiOn => 'WLAN verbunden';

  @override
  String get flowsTrigWifiOff => 'WLAN getrennt';

  @override
  String get flowsTrigAirplaneOn => 'Flugmodus wird eingeschaltet';

  @override
  String get flowsTrigAirplaneOff => 'Flugmodus wird ausgeschaltet';

  @override
  String get flowsTrigBoot => 'Telefon startet';

  @override
  String get flowsTrigUnlock => 'Bildschirm entsperrt';

  @override
  String get flowsTrigGroupTime => 'Zeit';

  @override
  String get flowsTrigGroupPhone => 'Am Telefon';

  @override
  String get flowsTrigGroupHand => 'Von Hand';

  @override
  String flowsCondBatteryBelow(int n) {
    return 'Akku unter $n %';
  }

  @override
  String flowsCondBatteryAbove(int n) {
    return 'Akku über $n %';
  }

  @override
  String get flowsCondCharging => 'Lädt';

  @override
  String get flowsCondNotCharging => 'Lädt nicht';

  @override
  String flowsCondTimeBetween(String from, String to) {
    return 'Zwischen $from und $to';
  }

  @override
  String flowsCondDays(String days) {
    return 'Am $days';
  }

  @override
  String get flowsCondWifiOn => 'WLAN verbunden';

  @override
  String get flowsCondWifiOff => 'WLAN nicht verbunden';

  @override
  String get flowsCondHeadsetOn => 'Kopfhörer verbunden';

  @override
  String get flowsCondHeadsetOff => 'Kopfhörer nicht verbunden';

  @override
  String get flowsCondAirplaneOn => 'Flugmodus an';

  @override
  String get flowsCondAirplaneOff => 'Flugmodus aus';

  @override
  String flowsCondAnswer(String text) {
    return 'Die Antwort enthält „$text“';
  }

  @override
  String get flowsBlockAsk => 'FinnAI fragen';

  @override
  String get flowsBlockAskSub => 'Etwas mit dem Modell auf dem Gerät schreiben';

  @override
  String get flowsBlockWeb => 'Nachschlagen';

  @override
  String get flowsBlockWebSub => 'Nachrichten, Wetter oder Web';

  @override
  String get flowsBlockNotify => 'Mich benachrichtigen';

  @override
  String get flowsBlockNotifySub => 'Eine Benachrichtigung zeigen';

  @override
  String get flowsBlockSpeak => 'Laut sagen';

  @override
  String get flowsBlockSpeakSub => 'Mit der Stimme des Telefons sprechen';

  @override
  String get flowsBlockAction => 'Am Telefon ausführen';

  @override
  String get flowsBlockActionSub =>
      'Taschenlampe, Lautstärke, Wecker, App öffnen';

  @override
  String get flowsBlockWait => 'Warten';

  @override
  String get flowsBlockWaitSub => 'Ein paar Sekunden pausieren';

  @override
  String get flowsBlockBranch => 'Wenn … dann';

  @override
  String get flowsBlockBranchSub => 'Das eine oder das andere tun';

  @override
  String get flowsBlockSave => 'In Chat speichern';

  @override
  String get flowsBlockSaveSub => 'Die Antwort als Chat behalten';

  @override
  String get flowsBlockStop => 'Hier anhalten';

  @override
  String get flowsBlockStopSub => 'Den Flow beenden';

  @override
  String flowsSumAsk(String text) {
    return 'Fragen: $text';
  }

  @override
  String flowsSumWeb(String text) {
    return '$text nachschlagen';
  }

  @override
  String get flowsSumNotifyAnswer => 'Die Antwort zeigen';

  @override
  String get flowsSumSpeakAnswer => 'Die Antwort vorlesen';

  @override
  String flowsSumWait(int n) {
    return '$n s warten';
  }

  @override
  String flowsSumIf(String condition) {
    return 'Wenn $condition';
  }

  @override
  String get flowsEdWhen => 'Wann';

  @override
  String get flowsEdOnlyIf => 'Nur wenn';

  @override
  String get flowsEdThen => 'Dann';

  @override
  String get flowsEdOr => 'oder';

  @override
  String get flowsEdYes => 'Ja';

  @override
  String get flowsEdOtherwise => 'Sonst';

  @override
  String get flowsEdEnd => 'Fertig';

  @override
  String get flowsEdAddTrigger => 'Auslöser hinzufügen';

  @override
  String get flowsEdAddCondition => 'Bedingung hinzufügen';

  @override
  String get flowsEdAddStep => 'Schritt hinzufügen';

  @override
  String get flowsEdInsertHere => 'Hier einen Schritt hinzufügen';

  @override
  String get flowsEdNoSteps =>
      'Noch nichts zu tun. Füge den ersten Schritt hinzu.';

  @override
  String get flowsEdManualStart => 'Startet, wenn du auf Ausführen tippst';

  @override
  String get flowsEdMoveUp => 'Nach oben';

  @override
  String get flowsEdMoveDown => 'Nach unten';

  @override
  String get flowsEdRemove => 'Entfernen';

  @override
  String get flowsEdDone => 'Fertig';

  @override
  String get flowsEdChooseStep => 'Was soll passieren?';

  @override
  String get flowsEdChooseTrigger => 'Was startet es?';

  @override
  String get flowsEdChooseCondition => 'Nur wenn …';

  @override
  String get flowsEdConditionNote =>
      'Ist das nicht erfüllt, läuft der Flow nicht, wenn etwas anderes ihn startet.';

  @override
  String get flowsFieldPrompt => 'Was soll FinnAI schreiben?';

  @override
  String flowsFieldPromptHint(String input) {
    return '$input steht für die letzte Antwort';
  }

  @override
  String get flowsFieldQuery => 'Was nachschlagen';

  @override
  String get flowsFieldSource => 'Wo';

  @override
  String get flowsSourceWeb => 'Das Web';

  @override
  String get flowsSourceNews => 'Nachrichten';

  @override
  String get flowsSourceWeather => 'Wetter';

  @override
  String get flowsFieldTitle => 'Titel';

  @override
  String get flowsFieldMessage => 'Nachricht';

  @override
  String get flowsFieldMessageHint =>
      'Leer lassen, um die letzte Antwort zu zeigen';

  @override
  String get flowsFieldSay => 'Was sagen';

  @override
  String get flowsFieldSayHint =>
      'Leer lassen, um die letzte Antwort vorzulesen';

  @override
  String get flowsFieldSeconds => 'Wie viele Sekunden';

  @override
  String get flowsFieldAction => 'Was tun';

  @override
  String get flowsFieldCondition => 'Bedingung';

  @override
  String get flowsFieldLevel => 'Akkustand';

  @override
  String get flowsFieldFrom => 'Von';

  @override
  String get flowsFieldTo => 'Bis';

  @override
  String get flowsFieldDays => 'Tage';

  @override
  String get flowsFieldContains => 'Enthält';

  @override
  String get flowsFieldEveryMinutes => 'Wiederholen alle';

  @override
  String get flowsUnitMinutes => 'Minuten';

  @override
  String get flowsUnitHours => 'Stunden';

  @override
  String get flowsBgWorks => 'Funktioniert im Hintergrund';

  @override
  String get flowsBgNeedsScreen => 'Du musst eine Benachrichtigung antippen';

  @override
  String get flowsAutoTitle => 'Von selbst laufen lassen';

  @override
  String get flowsAutoNeedsAllow =>
      'Dieser Flow ändert dein Telefon. Erlaube ihm, zu laufen, wenn du nicht hinsiehst.';

  @override
  String get flowsListenerOn =>
      'FinnAI hört im Hintergrund auf diese Ereignisse.';

  @override
  String get flowsListenerNeedsNotify =>
      'Aktiviere Benachrichtigungen, damit FinnAI weiter zuhören kann.';

  @override
  String get flowsRunStatusSkipped => 'Bedingungen nicht erfüllt';

  @override
  String get flowsRunStatusNeedsScreen => 'Wartet auf dich';

  @override
  String get flowsRunSkipped => 'Übersprungen';

  @override
  String get flowsRunNeedsScreen => 'Zum Beenden tippen';

  @override
  String get flowsRunByEvent => 'Lief von selbst';

  @override
  String get flowsRunByChat => 'Aus dem Chat gestartet';

  @override
  String flowsNeedsScreenBody(String name) {
    return 'Tippen, um „$name“ zu beenden – es braucht den Bildschirm.';
  }

  @override
  String flowsNeedsGrantBody(String name) {
    return '„$name“ wollte laufen, braucht aber zuerst deine Erlaubnis.';
  }

  @override
  String get flowsStepWaiting => 'Wartet';

  @override
  String flowsPathStep(int n) {
    return 'Schritt $n';
  }

  @override
  String get flowsDescribeTitle => 'Beschreibe deinen Flow';

  @override
  String get flowsDescribeHint =>
      'Zum Beispiel: Wenn ich das Ladegerät anschließe, Taschenlampe einschalten';

  @override
  String get flowsDescribeBuild => 'Erstellen';

  @override
  String get flowsDescribeThinking => 'Wird erarbeitet …';

  @override
  String get flowsDescribeFailed =>
      'Daraus konnte ich keinen Flow machen. Sag, wann er startet und was er tun soll.';

  @override
  String flowsDescribeMissed(String parts) {
    return 'Nicht verstanden: $parts';
  }

  @override
  String get flowsDescribeExamples => 'Probiere eines davon';

  @override
  String get flowsExampleCharger =>
      'Wenn ich das Ladegerät anschließe, Taschenlampe einschalten';

  @override
  String get flowsExampleBattery =>
      'Wenn der Akku unter 15 % ist, erinnere mich ans Laden';

  @override
  String get flowsExampleNews =>
      'Jeden Morgen um 7 die Nachrichten zusammenfassen';

  @override
  String get flowsExampleHeadset =>
      'Wenn ich Kopfhörer verbinde, Musik abspielen';

  @override
  String get flowsNewBlank => 'Von Grund auf neu';

  @override
  String get flowsNewBlankSub => 'Schritt für Schritt aufbauen';

  @override
  String get flowsNewTemplates => 'Aus einer Vorlage';

  @override
  String get flowsNewTemplatesSub =>
      'Nachrichten, Erinnerung, niedriger Akku …';

  @override
  String get flowsTemplateLowBattery => 'Warnung bei niedrigem Akku';

  @override
  String get flowsTemplateLowBatteryBody =>
      'Warnt dich einmal, wenn der Akku niedrig ist.';

  @override
  String get flowsTemplateHeadset => 'Kopfhörer und Musik';

  @override
  String get flowsTemplateHeadsetBody =>
      'Spielt ab oder pausiert, wenn Kopfhörer verbunden werden.';

  @override
  String get flowsSlotLevel => 'Warnen bei (%)';

  @override
  String get flowsSlotWhat => 'Was tun';

  @override
  String get flowsSlotPlay => 'Abspielen';

  @override
  String get flowsSlotPause => 'Pause';

  @override
  String get flowsRunsTitle => 'Läufe';

  @override
  String get flowsRunsAll => 'Alle Läufe ansehen';

  @override
  String get flowsRenameTitle => 'Flow umbenennen';

  @override
  String get flowsSavedToast => 'Gespeichert';

  @override
  String get flowsStepOutcomeSkipped => 'Übersprungen';

  @override
  String flowsChatCreated(String name) {
    return 'Ich habe einen Flow erstellt: „$name“. Prüfe ihn und schalte ihn ein.';
  }

  @override
  String get flowsChatOpen => 'Flow öffnen';

  @override
  String get flowsChatTurnOn => 'Einschalten';

  @override
  String get flowsChatIsOn => 'Eingeschaltet';

  @override
  String get flowsChatDiscard => 'Verwerfen';

  @override
  String get flowsActSetAlarm => 'Wecker stellen';

  @override
  String get flowsActSetTimer => 'Timer starten';

  @override
  String get flowsActShowAlarms => 'Meine Wecker zeigen';

  @override
  String get flowsActTorch => 'Taschenlampe';

  @override
  String get flowsActMedia => 'Musik steuern';

  @override
  String get flowsActVolume => 'Lautstärke ändern';

  @override
  String get flowsActVibrate => 'Vibrieren';

  @override
  String get flowsActOpenSettings => 'Einstellungen öffnen';

  @override
  String get flowsActOpenApp => 'App öffnen';

  @override
  String get flowsActDial => 'Anruf starten';

  @override
  String get flowsActSms => 'SMS schreiben';

  @override
  String get flowsActEmail => 'E-Mail schreiben';

  @override
  String get flowsActPhoto => 'Kamera öffnen';

  @override
  String get flowsActUrl => 'Webadresse öffnen';

  @override
  String get flowsActNavigate => 'Route berechnen';

  @override
  String get flowsActShare => 'Text teilen';

  @override
  String get flowsOn => 'An';

  @override
  String get flowsOff => 'Aus';

  @override
  String get flowsParamState => 'Zustand';

  @override
  String get flowsParamDirection => 'Richtung';

  @override
  String get flowsParamScreen => 'Bildschirm';

  @override
  String get flowsParamTime => 'Uhrzeit';

  @override
  String get flowsParamSeconds => 'Sekunden';

  @override
  String get flowsParamMilliseconds => 'Millisekunden';

  @override
  String get flowsParamLabel => 'Bezeichnung';

  @override
  String get flowsParamName => 'App-Name';

  @override
  String get flowsParamNumber => 'Telefonnummer';

  @override
  String get flowsParamTo => 'An';

  @override
  String get flowsParamBody => 'Nachricht';

  @override
  String get flowsParamSubject => 'Betreff';

  @override
  String get flowsParamUrl => 'Webadresse';

  @override
  String get flowsParamQuery => 'Ort oder Adresse';

  @override
  String get flowsParamText => 'Text';

  @override
  String get flowsPickAction => 'Was soll das Telefon tun?';

  @override
  String get flowsEveryHowLong => 'Wiederholen alle';

  @override
  String get flowsIntervalNote =>
      'Das Telefon bündelt Timer, um Akku zu sparen – es kann ein paar Minuten später sein.';

  @override
  String get flowsBatteryLevelNote =>
      'Läuft einmal, wenn der Akku diesen Stand erreicht.';

  @override
  String get chatCreationReady =>
      'Hier ist es. Öffne es oder lege es auf deinen Startbildschirm.';

  @override
  String get chatCreationBuilding => 'Wird erstellt …';

  @override
  String get flowsDetailOnEvent => 'An, startet von selbst';

  @override
  String get voiceStyle => 'Stimme';

  @override
  String get voiceStyleF1 => 'Weiblich 1';

  @override
  String get voiceStyleF2 => 'Weiblich 2';

  @override
  String get voiceStyleM1 => 'Männlich 1';

  @override
  String get voiceStyleM2 => 'Männlich 2';
}
