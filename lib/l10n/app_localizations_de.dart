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
  String get commonSaveSkill => 'Skill speichern';

  @override
  String get commonKeepCreating => 'Weiter erstellen';

  @override
  String get commonNotNow => 'Nicht jetzt';

  @override
  String get commonPurge => 'Leeren';

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
  String get onboardingWelcome => 'Willkommen bei Finn AI!';

  @override
  String get onboardingSwipeToStart => 'Zum Starten wischen';

  @override
  String get onboardingPrivacyTitle => 'Finn AI schützt deine Privatsphäre';

  @override
  String get onboardingPrivacyBody =>
      'Finn AI wurde entwickelt, um deine Privatsphäre zu respektieren.\n\nDie KI-Verarbeitung und der Gesprächsverlauf bleiben auf diesem Gerät. Wenn eine Anfrage aktuelle Informationen benötigt, sendet Finn AI möglicherweise nur diese Anfrage als Websuchanfrage und zeigt die verwendeten Quellen an. Dein Verlauf und dein persönliches Profil werden niemals einbezogen.\n\nFinn AI ist proprietäre Software und nicht quelloffen.';

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
      'LFM2.5-VL 1.6B wird installiert';

  @override
  String get onboardingInstallTitleReady => 'LFM2.5-VL 1.6B ist bereit';

  @override
  String get onboardingInstallPreparing =>
      'LFM2.5-VL 1.6B wird für dieses Gerät vorbereitet…';

  @override
  String get onboardingInstallReadyForChat =>
      'Bereit für privaten Textchat auf diesem Gerät';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + multimodale Komponente · $size';
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
  String get onboardingReadyTitle => 'Finn AI ist bereit!';

  @override
  String get onboardingReadySubtitle =>
      'Du bist startklar. Finn AI ist bereit.';

  @override
  String get onboardingYouLabel => 'Du';

  @override
  String get chatNewChat => 'Neuer Chat';

  @override
  String get chatHistory => 'Chatverlauf';

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
  String get settingsPurgeMemory => 'KI-Speicher leeren';

  @override
  String get settingsPurgeMemoryTitle => 'KI-Speicher leeren?';

  @override
  String get settingsPurgeMemoryBody =>
      'Dadurch wird das KI-Modell aus dem RAM entladen. Es wird bei der nächsten Nachricht automatisch neu geladen.';

  @override
  String get settingsPurgeMemoryReleased => 'KI-Modellspeicher freigegeben.';

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
      'Dies löscht endgültig verschlüsselte Unterhaltungen und Schlüssel, heruntergeladene KI-Modelle, Kreationen, Profileinstellungen, Skills und den Onboarding-Zustand. FinnAI kehrt zu einem sauberen Erststart zurück.';

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
      'URL der Datenschutzerklärung ist nicht konfiguriert (setze FINN_PRIVACY_POLICY_URL).';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return '$url konnte nicht geöffnet werden';
  }

  @override
  String get settingsTermsOfUse => 'Nutzungsbedingungen';

  @override
  String get settingsTermsUnconfigured =>
      'URL der Nutzungsbedingungen ist nicht konfiguriert (setze FINN_TERMS_URL).';

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
  String get settingsInferenceEngine => 'Inferenz-Engine';

  @override
  String get settingsInferenceEngineValue => 'llama.cpp · GGUF';

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
      'Finn liest Antworten im Sprachmodus vor. Dein Sprachtranskript wird von der Spracherkennung deines Geräts verarbeitet, die Internet benötigen kann.';

  @override
  String get voiceMicSemantic => 'Sprich mit Finn';

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
  String get skillsTitle => 'Skills';

  @override
  String skillsSubtitle(int count) {
    return '$count verfügbar · Skills steuern relevante Antworten';
  }

  @override
  String get skillsNewSkill => 'Neuer Skill';

  @override
  String get skillsNoSkills =>
      'Noch keine eigenen Skills. Erstelle einen für einen wiederkehrenden Ablauf.';

  @override
  String get skillsInstructionHint =>
      'Schreibe eine wiederverwendbare Anweisung, die Finn bei Bedarf anwendet.';

  @override
  String get skillsDeleteTitle => 'Diesen Skill löschen?';

  @override
  String skillsDeleteBody(String name) {
    return '„$name“ wird von diesem Gerät entfernt.';
  }

  @override
  String get skillsLimitReached =>
      'Skill-Limit erreicht (4). Lösche einen, um einen weiteren hinzuzufügen.';

  @override
  String get skillsNameLabel => 'Skill-Name';

  @override
  String get skillsInstructionLabel => 'Anweisung';

  @override
  String get chatBrowseTooltip => 'Für diese Nachricht im Web suchen';

  @override
  String get chatBrowseOnSemantic => 'Websuche aktiv';

  @override
  String get chatBrowseOffSemantic => 'Websuche aus';

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
  String get snackModelMemoryReleased => 'KI-Modellspeicher freigegeben.';

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
}
