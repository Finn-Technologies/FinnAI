// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get commonStop => 'Arrêter';

  @override
  String get commonDownload => 'Télécharger';

  @override
  String get commonResend => 'Renvoyer';

  @override
  String get commonSaveFlow => 'Enregistrer la compétence';

  @override
  String get commonKeepCreating => 'Continuer à créer';

  @override
  String get commonNotNow => 'Pas maintenant';

  @override
  String get commonPurge => 'Libérer';

  @override
  String get commonClearAll => 'Tout effacer';

  @override
  String get commonDeleteEverything => 'Tout supprimer';

  @override
  String get appTitle => 'Finn AI';

  @override
  String get appBrandFinnAI => 'FinnAI';

  @override
  String get unsupportedTitle =>
      'Finn AI ne peut pas s\'exécuter sur cet appareil';

  @override
  String get unsupportedBody =>
      'Finn AI nécessite au moins 3 Go de RAM et un processeur ARM 64 bits pour exécuter des modèles locaux de manière fiable. Aucun modèle n\'a été téléchargé.';

  @override
  String get onboardingWelcome => 'Bienvenue dans FinnAI';

  @override
  String get onboardingSwipeToStart => 'Balayez pour commencer';

  @override
  String get onboardingPrivacyTitle => 'FinnAI respecte votre vie privée';

  @override
  String get onboardingPrivacyLead =>
      'FinnAI place votre vie privée au premier plan.';

  @override
  String get onboardingPrivacyBody =>
      'Nous ne suivons ni ne stockons vos données : chaque requête est traitée localement sur votre appareil. ';

  @override
  String get onboardingPrivacyLink =>
      'En savoir plus dans notre Politique de confidentialité.';

  @override
  String get onboardingPrecautionsTitle =>
      'Avant de commencer, lisez les précautions';

  @override
  String get onboardingPrecautionOne =>
      'Traitement des prompts d\'IA sur l\'appareil';

  @override
  String get onboardingPrecautionTwo =>
      'Chat hors ligne après le téléchargement du modèle';

  @override
  String get onboardingPrecautionThree => 'Stockage chiffré des conversations';

  @override
  String get onboardingPrecautionFour => 'Conçu pour économiser la batterie';

  @override
  String get onboardingInstallTitleInstalling =>
      'Téléchargement de FinnAI Foundation';

  @override
  String get onboardingInstallTitleReady => 'FinnAI Foundation prête';

  @override
  String get onboardingDownloadLead => 'Configuration de FinnAI,';

  @override
  String get onboardingDownloadNote =>
      'la première utilisation prend quelques minutes.';

  @override
  String onboardingProgressPercent(Object percent) {
    return '$percent % effectués.';
  }

  @override
  String get onboardingProgressEtaTail => 'restant.';

  @override
  String onboardingProgressEtaAbout(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Environ $_temp0 restantes.';
  }

  @override
  String get onboardingInstallPreparing =>
      'Préparation de LFM2.5-VL 1.6B pour cet appareil…';

  @override
  String get onboardingInstallReadyForChat =>
      'Prêt pour le chat textuel privé sur cet appareil';

  @override
  String onboardingInstallModelWithComponent(String modelName, String size) {
    return '$modelName + prise en charge des images · $size';
  }

  @override
  String get onboardingInstallModelReady => 'Modèle prêt';

  @override
  String onboardingInstallProgressStatus(String status, String percent) {
    return '$status · $percent %';
  }

  @override
  String onboardingInstallBytesOf(String received, String total) {
    return '$received sur $total';
  }

  @override
  String onboardingInstallBytesLeft(String remaining) {
    return '$remaining restants';
  }

  @override
  String get onboardingInstallRetry => 'Réessayer';

  @override
  String get onboardingInstallRetryLabel =>
      'Relancer le téléchargement du modèle';

  @override
  String get onboardingInstallVerificationFailed =>
      'Échec de la vérification du modèle';

  @override
  String get onboardingUpgradeTitle => 'Mise à niveau logicielle FinnAI';

  @override
  String get onboardingUpgradeBody =>
      'Finn AI exécute désormais un modèle plus récent sur l\'appareil. Téléchargez-le pour continuer à discuter en privé.';

  @override
  String get onboardingReadyTitle => 'FinnAI est prêt !';

  @override
  String get onboardingReadyLead => 'FinnAI est prêt à l\'emploi !';

  @override
  String get onboardingReadyBody =>
      'Vous pouvez désormais utiliser FinnAI, en ligne comme hors ligne.\nNous espérons qu\'il vous plaira !';

  @override
  String get onboardingReadySubtitle => 'Tout est prêt. Finn AI est prêt.';

  @override
  String get onboardingConsentTitle =>
      'Autorisez-vous Finn AI à utiliser le contexte de votre appareil ?';

  @override
  String get onboardingConsentBody =>
      'Cela permet à FinnAI de lire votre agenda, vos notes et vos photos pour mieux adapter ses réponses. Tout reste sur cet appareil, rien n\'est envoyé ailleurs.';

  @override
  String get onboardingConsentRequiredHint =>
      'Choisissez Oui ou Non pour continuer';

  @override
  String get onboardingStartUsing => 'Commencer avec Finn AI';

  @override
  String get onboardingYouLabel => 'Vous';

  @override
  String get chatNewChat => 'Nouveau chat';

  @override
  String get chatHistory => 'Chats';

  @override
  String get chatNoHistory => 'Aucun historique';

  @override
  String get chatFinnGenerating => 'Finn génère…';

  @override
  String get chatFinnTyping => 'Finn écrit…';

  @override
  String get chatAskAnything =>
      'Posez-moi toutes vos questions — je fonctionne entièrement sur cet appareil, vos\nconversations ne quittent jamais votre appareil.';

  @override
  String get chatTryAsking => 'Essayez de demander';

  @override
  String get chatMessageHint => 'Message à Finn…';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatStopGeneration => 'Arrêter';

  @override
  String get chatCopy => 'Copier';

  @override
  String get chatEditMessage => 'Modifier le message';

  @override
  String get chatRenameTitle => 'Renommer le chat';

  @override
  String get chatRenameHint => 'Titre du chat';

  @override
  String get chatDeleteTitle => 'Supprimer le chat ?';

  @override
  String chatDeleteBody(String title) {
    return '« $title » sera supprimé. Cette action est irréversible.';
  }

  @override
  String get chatContinue => 'Continuer';

  @override
  String get chatSources => 'Sources';

  @override
  String get chatHistoryUnavailableNotice =>
      'Finn n\'a pas pu ouvrir votre historique de discussion sur cet appareil, les nouvelles réponses ne seront pas enregistrées.';

  @override
  String get chatOfflineNotice =>
      'Hors ligne — la réponse peut être moins précise. Connectez-vous pour obtenir des sources citées.';

  @override
  String get chatFinishingTask => 'Finn AI termine une autre tâche locale.';

  @override
  String get chatAttachmentPickFailed =>
      'Impossible d\'ouvrir le sélecteur. Veuillez réessayer.';

  @override
  String get chatCouldNotPrepare =>
      'Impossible de préparer le chat. Vérifiez le modèle et le stockage, puis réessayez.';

  @override
  String get chatEmptyReply =>
      'Finn n’a pas trouvé de réponse cette fois. Touchez « Réessayer » pour reposer la question.';

  @override
  String chatGeneratingIn(String title) {
    return 'Génération dans $title';
  }

  @override
  String get chatDownloadModelTitle =>
      'Télécharger le modèle d\'IA pour discuter hors ligne ?';

  @override
  String chatDownloadModelBody(String size) {
    return '$size est téléchargé une seule fois et vérifié avant utilisation. Le téléchargement reprend en toute sécurité après une interruption, et vos conversations restent sur cet appareil.';
  }

  @override
  String get chatHiPrefix => 'Salut, je suis Finn.';

  @override
  String get chatFinnAI => 'Finn AI';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsContextTitle => 'Contexte sur l\'appareil';

  @override
  String get settingsContextSubtitle =>
      'Autoriser Finn AI à utiliser le contexte de cet appareil';

  @override
  String get settingsAiModel => 'MODÈLE IA';

  @override
  String get settingsStorageData => 'STOCKAGE ET DONNÉES';

  @override
  String get settingsPrivacyLegal => 'CONFIDENTIALITÉ ET MENTIONS LÉGALES';

  @override
  String get settingsAbout => 'À PROPOS';

  @override
  String settingsSavedConversations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats (chiffrés)',
      one: '1 chat (chiffré)',
    );
    return '$_temp0';
  }

  @override
  String get settingsReleasingMemory => 'Libération de la mémoire…';

  @override
  String get settingsPurgeMemorySubtitle =>
      'Libère la RAM. Le modèle se recharge au prochain message.';

  @override
  String get settingsClearHistorySubtitle =>
      'Supprime toutes les discussions enregistrées. Action irréversible.';

  @override
  String get settingsDeleteAllDataSubtitle =>
      'Discussions, modèles, créations et préférences — comme au premier lancement.';

  @override
  String get settingsPurgeMemory => 'Libérer la mémoire';

  @override
  String get settingsPurgeMemoryTitle => 'Libérer la mémoire ?';

  @override
  String get settingsPurgeMemoryBody =>
      'Cela ferme le modèle d\'IA pour libérer de la mémoire. Il rouvrira à votre prochain message.';

  @override
  String get settingsPurgeMemoryReleased => 'Mémoire libérée.';

  @override
  String get settingsClearHistory => 'Effacer tout l\'historique des chats';

  @override
  String get settingsClearHistoryTitle => 'Effacer toutes les conversations ?';

  @override
  String get settingsClearHistoryBody =>
      'Cela supprimera définitivement tout l\'historique des chats. Cette action est irréversible.';

  @override
  String get settingsClearHistorySuccess =>
      'Toutes les conversations ont été effacées.';

  @override
  String get settingsClearHistoryFailure =>
      'Impossible d\'effacer les conversations. Vérifiez le stockage et réessayez.';

  @override
  String get settingsDeleteAllData => 'Supprimer toutes les données locales';

  @override
  String get settingsDeleteAllDataTitle =>
      'Supprimer toutes les données locales ?';

  @override
  String get settingsDeleteAllDataBody =>
      'Cette action supprime définitivement les conversations et clés chiffrées, les modèles d\'IA téléchargés, les créations, les préférences de profil, les Flows et l\'état d\'onboarding. FinnAI reviendra à un premier démarrage vierge.';

  @override
  String get settingsDeleteAllDataDeleting =>
      'Suppression de toutes les données locales…';

  @override
  String get settingsDeleteAllDataSuccess =>
      'Toutes les données locales ont été supprimées. Retour à l\'introduction.';

  @override
  String settingsDeleteAllDataPartialFailure(String items) {
    return 'Échec partiel de la suppression : impossible de supprimer $items.';
  }

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsPrivacyPolicyUnconfigured =>
      'Le lien vers la politique de confidentialité n\'est pas disponible dans cette version.';

  @override
  String settingsPrivacyPolicyLaunchFailed(String url) {
    return 'Impossible d\'ouvrir $url';
  }

  @override
  String get settingsTermsOfUse => 'Conditions d\'utilisation';

  @override
  String get settingsTermsUnconfigured =>
      'Le lien vers les conditions d\'utilisation n\'est pas disponible dans cette version.';

  @override
  String settingsTermsLaunchFailed(String url) {
    return 'Impossible d\'ouvrir $url';
  }

  @override
  String get settingsSupportContact => 'Contact du support';

  @override
  String get settingsSupportUnavailable =>
      'Le contact du support n\'est pas disponible.';

  @override
  String settingsSupportEmailLabel(String email) {
    return 'E-mail du support : $email';
  }

  @override
  String settingsSupportLaunchFailed(String url) {
    return 'Impossible d\'ouvrir $url';
  }

  @override
  String get settingsOpenSourceLicenses => 'Licences open source';

  @override
  String get settingsAppVersion => 'Version de l\'application';

  @override
  String get settingsInferenceEngine => 'Comment Finn fonctionne';

  @override
  String get settingsInferenceEngineValue => 'Entièrement sur cet appareil';

  @override
  String get settingsPrivacyMode => 'Mode de confidentialité';

  @override
  String get settingsPrivacyModeValue => 'Chiffré sur l\'appareil';

  @override
  String get settingsModelArchitecture => 'Architecture du modèle';

  @override
  String get settingsModelArchitectureValue => 'LFM2.5-VL 1.6B (Liquid)';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsSpokenResponses => 'Réponses vocales';

  @override
  String get settingsSpokenResponsesBody =>
      'Finn lit les réponses à voix haute en mode vocal. Ce que vous dites est converti en texte sur cet appareil et ne le quitte jamais.';

  @override
  String get voiceMicSemantic => 'Parler à Finn';

  @override
  String get voiceCancelSemantic => 'Annuler la saisie vocale';

  @override
  String get voiceExpandSemantic => 'Ouvrir le mode vocal complet';

  @override
  String get voiceListening => 'Écoute…';

  @override
  String get voiceTapToSpeak => 'Touchez le micro et parlez';

  @override
  String get voiceHeardYou => 'Je vous ai entendu';

  @override
  String get voiceDidNotCatch => 'Je n\'ai pas compris — réessayez';

  @override
  String get voiceThinking => 'Finn réfléchit…';

  @override
  String get voiceSpeaking => 'Finn parle — touchez pour interrompre';

  @override
  String get voiceMicDenied =>
      'L\'accès au microphone est désactivé. Activez-le dans les réglages système pour utiliser le mode vocal.';

  @override
  String get voiceUnavailable =>
      'La reconnaissance vocale n\'est pas disponible pour le moment. Saisissez votre message à la place.';

  @override
  String voiceModelNeeded(String size) {
    return 'Le mode vocal nécessite un téléchargement unique de $size. Votre voix est convertie en texte sur cet appareil et ne le quitte jamais.';
  }

  @override
  String get voiceModelDownload => 'Télécharger';

  @override
  String voiceModelDownloading(int percent) {
    return 'Téléchargement du modèle vocal… $percent %';
  }

  @override
  String get voiceModelFailed =>
      'Le téléchargement n\'a pas abouti. Vérifiez votre connexion et réessayez.';

  @override
  String get voiceModelRetry => 'Réessayer';

  @override
  String get voiceSpeakingLive => 'Parle…';

  @override
  String get voiceStopSemantic => 'Arrêter';

  @override
  String get voiceCloseSemantic => 'Fermer le mode vocal';

  @override
  String get youTitle => 'Vous';

  @override
  String get youIntroTitle => 'Faites de Finn le vôtre';

  @override
  String get youIntroBody =>
      'Vos préférences restent sur cet appareil et façonnent les réponses futures.';

  @override
  String get youAboutYou => 'À propos de vous';

  @override
  String get youNameLabel => 'Nom';

  @override
  String get youNameHint => 'Comment Finn doit-il vous appeler ?';

  @override
  String get youAboutLabel => 'À propos de vous';

  @override
  String get youAboutHint =>
      'Centres d\'intérêt, travail ou contexte que Finn doit retenir';

  @override
  String get youInstructionsLabel => 'Instructions personnalisées';

  @override
  String get youInstructionsHint =>
      'Comment Finn doit-il répondre ? Ton, longueur, style…';

  @override
  String get youResponseStyle => 'Style de réponse';

  @override
  String get youResponseStyleBalanced => 'Équilibré';

  @override
  String get youResponseStyleConcise => 'Concis';

  @override
  String get youResponseStyleDetailed => 'Détaillé';

  @override
  String get youResponseStyleCreative => 'Créatif';

  @override
  String get youSave => 'Enregistrer';

  @override
  String get youSaved => 'Personnalisation enregistrée localement.';

  @override
  String get youSaveFailed => 'Impossible d\'enregistrer les modifications.';

  @override
  String get flowsTitle => 'Flows';

  @override
  String flowsSubtitle(int count) {
    return '$count disponibles · les Flows guident des réponses pertinentes';
  }

  @override
  String get flowsDeleteTitle => 'Supprimer cette flow ?';

  @override
  String flowsDeleteBody(String name) {
    return '« $name » sera supprimé de cet appareil.';
  }

  @override
  String get flowsNameLabel => 'Nom de la flow';

  @override
  String get flowsRunAction => 'Exécuter maintenant';

  @override
  String get flowsRunRunning => 'En cours…';

  @override
  String get flowsGrantLabel => 'La laisser s\'exécuter seule';

  @override
  String get flowsGrantExplain =>
      'Un flux qui modifie votre téléphone a besoin de cela pour s\'exécuter sans vous. Vous pouvez le désactiver à tout moment.';

  @override
  String get flowsNeedsGrant =>
      'A besoin de votre autorisation pour s\'exécuter seule';

  @override
  String get flowsHistoryTitle => 'Exécutions récentes';

  @override
  String get flowsHistoryEmpty => 'Ce flux n\'a pas encore été exécuté.';

  @override
  String get flowsRunCompleted => 'Terminé';

  @override
  String get flowsRunDeclined => 'Vous avez refusé';

  @override
  String get flowsRunFailed => 'Arrêté en cours de route';

  @override
  String get flowsRunInterrupted => 'Annulé';

  @override
  String get flowsRunBySchedule => 'Exécuté automatiquement';

  @override
  String get flowsAutomationsTitle => 'Automatisations';

  @override
  String get flowsAutomationsSubtitle =>
      'Ce que Finn fait pour vous selon un horaire. Rien ne s’exécute sans votre accord.';

  @override
  String get flowsNewAutomation => 'Nouvelle automatisation';

  @override
  String get flowsNoAutomations =>
      'Pas encore d’automatisation. Commencez par un briefing du matin.';

  @override
  String get flowsTemplateMorningBrief => 'Briefing du matin';

  @override
  String get flowsTemplateMorningBriefBody =>
      'Les actualités qui vous intéressent et la météo, en quelques lignes.';

  @override
  String get flowsTemplateWebCheck => 'Veille web';

  @override
  String get flowsTemplateWebCheckBody =>
      'Surveille un sujet et vous dit ce qui est nouveau.';

  @override
  String get flowsTemplateReminder => 'Rappel';

  @override
  String get flowsTemplateReminderBody =>
      'Une notification avec vos propres mots.';

  @override
  String get flowsSlotTopics => 'Ce que vous suivez';

  @override
  String get flowsSlotCity => 'Ville pour la météo (facultatif)';

  @override
  String get flowsSlotTopic => 'Sujet';

  @override
  String get flowsSlotMessage => 'Message';

  @override
  String get flowsScheduleHeading => 'Quand';

  @override
  String flowsScheduleWeekdaysAt(String time) {
    return 'Jours ouvrés à $time';
  }

  @override
  String get flowsScheduleEveryDay => 'Tous les jours';

  @override
  String get flowsScheduleWeekdaysOnly => 'Jours ouvrés';

  @override
  String get flowsScheduleTime => 'Heure';

  @override
  String get flowsNotifyWhyTitle => 'Autoriser les notifications ?';

  @override
  String get flowsNotifyWhyBody =>
      'Finn envoie une notification quand cette automatisation est due. Sans elle, elle ne se lance que lorsque vous appuyez sur Lancer.';

  @override
  String get flowsNotifyAllow => 'Autoriser';

  @override
  String get flowsNotifyOff =>
      'Les notifications sont désactivées : cela ne se lancera pas seul.';

  @override
  String flowsRunning(String name) {
    return 'Exécution de $name…';
  }

  @override
  String flowsRunReady(String name) {
    return '$name est prêt';
  }

  @override
  String flowsRunCouldNotFinish(String name) {
    return '$name n’a pas pu se terminer';
  }

  @override
  String get flowsOpenResult => 'Ouvrir le résultat';

  @override
  String flowsNextRun(String when) {
    return 'Prochaine : $when';
  }

  @override
  String get flowsRunByYou => 'Lancée par vous';

  @override
  String get flowsStepsLabel => 'Étapes';

  @override
  String flowsStepCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return '$_temp0';
  }

  @override
  String get flowsStepPrompt => 'Demander';

  @override
  String get flowsStepDeviceAction => 'Agir sur le téléphone';

  @override
  String get flowsStepNotify => 'Mémo';

  @override
  String get flowsStepBrowse => 'Rechercher';

  @override
  String get flowsScheduleLabel => 'Exécution';

  @override
  String get flowsScheduleManual => 'Uniquement quand vous la lancez';

  @override
  String flowsScheduleDaily(String time) {
    return 'Tous les jours à $time';
  }

  @override
  String flowsScheduleWeekly(String days, String time) {
    return '$days à $time';
  }

  @override
  String get flowsScheduleAdd => 'Ajouter une heure';

  @override
  String get flowsScheduleRemove => 'L\'exécuter seulement quand je le demande';

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
  String get creationsNoneTitle => 'Aucune création pour l’instant.';

  @override
  String get creationsNoneBody =>
      'Ta créativité vit ici.\nEssaie de créer quelque chose avec FinnAI Creations.';

  @override
  String get creationsTitle => 'Créations';

  @override
  String get creationsSubtitle =>
      'Décrivez ce que vous voulez. Finn le crée sur l’appareil.';

  @override
  String get creationsWhatAreWeMaking => 'Que créons-nous ?';

  @override
  String get creationsOriginalBrief => 'Brief initial';

  @override
  String get creationsFinnAdapts => 'Finn adapte la structure au format.';

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
  String get creationsTemplateAuto => 'Laisser Finn choisir';

  @override
  String get creationsTemplateQuestion =>
      'Envie d’un point de départ ? Choisissez-en un ou décrivez simplement ce que vous voulez.';

  @override
  String get creationsTemplateCounter => 'Compteur';

  @override
  String get creationsTemplateChecklist => 'Liste à cocher';

  @override
  String get creationsTemplateList => 'Liste';

  @override
  String get creationsTemplateScoreboard => 'Tableau des scores';

  @override
  String get creationsTemplateStat => 'Grand chiffre';

  @override
  String get creationsTemplateRows => 'Lignes';

  @override
  String get creationsEdit => 'Modifier';

  @override
  String get creationsEditTitle => 'Modifier les détails';

  @override
  String get creationsSlotTitle => 'Nom';

  @override
  String get creationsSlotUnit => 'Ce que vous comptez';

  @override
  String get creationsSlotGoal => 'Objectif';

  @override
  String get creationsSlotEmoji => 'Emoji';

  @override
  String get creationsSlotAccent => 'Couleur';

  @override
  String get creationsSlotItems => 'Éléments';

  @override
  String get creationsSlotHint => 'Indication de saisie';

  @override
  String get creationsSlotEmpty => 'Message si vide';

  @override
  String get creationsSlotNameA => 'Premier nom';

  @override
  String get creationsSlotNameB => 'Deuxième nom';

  @override
  String get creationsSlotLabel => 'Libellé';

  @override
  String get creationsSlotValue => 'Valeur';

  @override
  String get creationsSlotFooter => 'Pied de page';

  @override
  String get creationsSlotRows => 'Lignes';

  @override
  String get creationsSlotOnePerLine => 'Un par ligne';

  @override
  String get creationsSlotRowFormat => 'Une par ligne, par ex. « Eau : 3 »';

  @override
  String get creationsAccentMint => 'Menthe';

  @override
  String get creationsAccentBlue => 'Bleu';

  @override
  String get creationsAccentLime => 'Citron vert';

  @override
  String get creationsAccentAmber => 'Ambre';

  @override
  String get creationsAccentRose => 'Rose';

  @override
  String get creationsAccentViolet => 'Violet';

  @override
  String get creationsAccentSky => 'Ciel';

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
  String get flowsSaveFailed => 'Impossible d\'enregistrer ce Flow.';

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
  String get creationsStopTitle => 'Arrêter cette création ?';

  @override
  String get creationsStopBody =>
      'Le résultat inachevé sera abandonné. Votre prompt restera ici.';

  @override
  String get creationsDeleteTitle => 'Supprimer cette création ?';

  @override
  String creationsDeleteBody(String title) {
    return '« $title » sera supprimé de cet appareil.';
  }

  @override
  String get creationsOpening => 'Ouverture des créations';

  @override
  String get creationsGenerating => 'Génération…';

  @override
  String get reportTitle => 'Signaler la réponse de l\'IA';

  @override
  String get reportSubtitle =>
      'Aidez-nous à maintenir des réponses d\'IA sûres et exactes. Les signalements sont examinés pour améliorer les garde-fous de FinnAI.';

  @override
  String get reportReasonLabel => 'Motif du signalement';

  @override
  String get reportIncludePrompt => 'Inclure mon prompt dans ce signalement';

  @override
  String get reportResponsePreview => 'Aperçu de la réponse signalée';

  @override
  String get reportContinueHint =>
      'Continuer ouvre un signalement complet adressé à finn_org@proton.me. Rien n\'est envoyé tant que vous ne l\'avez pas vérifié et envoyé depuis votre application de messagerie.';

  @override
  String get reportContinueToEmail => 'Continuer vers l\'e-mail';

  @override
  String get reportReviewInEmail =>
      'Vérifiez le signalement dans votre application de messagerie, puis envoyez-le.';

  @override
  String get reportNotConfigured =>
      'L\'adresse e-mail de signalement n\'est pas configurée.';

  @override
  String get reportCategoryHarmful => 'Nuisible ou dangereux';

  @override
  String get reportCategoryIncorrect => 'Incorrect ou trompeur';

  @override
  String get reportCategoryBiased => 'Partial ou injuste';

  @override
  String get reportCategoryOther => 'Autre';

  @override
  String get snackModelMemoryReleased => 'Mémoire libérée.';

  @override
  String get settingsSavedConversationsLabel => 'Conversations enregistrées';

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
      'L\'analyse d\'image n\'est pas encore configurée. Ajoutez la prise en charge des images dans les Réglages.';

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
  String get chatMoreActions => 'Plus d’actions';

  @override
  String get chatHideSources => 'Masquer les sources';

  @override
  String get chatShowSources => 'Afficher les sources';

  @override
  String get chatRewriteHint => 'Réécrivez votre message';

  @override
  String get chatAskAnythingHint => 'Posez votre question';

  @override
  String get chatGreeting => 'Salut, à quoi penses-tu ?';

  @override
  String get voiceGreeting => 'Quoi de neuf ?';

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
  String get flowsActionsTooltip => 'Actions du Flow';

  @override
  String flowsNameSemantic(String name) {
    return 'Flow $name';
  }

  @override
  String get flowsEditorNameHint => 'Que fait ce Flow ?';

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

  @override
  String get deviceActionsTitle => 'Actions';

  @override
  String get deviceActionsIntro =>
      'Demande à Finn d\'agir sur ton téléphone : régler une alarme, lancer un minuteur ou ouvrir un réglage.';

  @override
  String get deviceActionsExamples => 'Essaie l\'une de ces actions';

  @override
  String get deviceActionsHint => 'Que doit faire Finn ?';

  @override
  String get deviceActionsRun => 'Continuer';

  @override
  String get deviceActionsResolving => 'Je réfléchis…';

  @override
  String get deviceActionsUnresolved =>
      'Je n\'ai pas pu en faire une action. Nomme le réglage ou l\'app directement.';

  @override
  String get deviceActionsConfirm => 'Exécuter';

  @override
  String get deviceActionsCancel => 'Annuler';

  @override
  String get deviceActionsAgain => 'Faire autre chose';

  @override
  String get deviceActionsOpenNotice =>
      'Android n\'autorise pas les apps à modifier seules les réglages sans fil : Finn ouvre le bon écran et tu bascules l\'interrupteur.';

  @override
  String deviceActionsResultOpened(String detail) {
    return '$detail ouvert';
  }

  @override
  String deviceActionsResultPerformed(String detail) {
    return 'C\'est fait — $detail';
  }

  @override
  String get deviceActionsResultUnavailable =>
      'Ton appareil ne peut pas faire ça';

  @override
  String get deviceActionsResultFailed => 'Ça n\'a pas fonctionné';

  @override
  String deviceActionsResultFailedDetail(String error) {
    return 'Ça n\'a pas fonctionné — $error';
  }

  @override
  String get deviceActionsExampleAlarm => 'Régler une alarme à 7 h';

  @override
  String get deviceActionsExampleTimer => 'Lancer un minuteur de 10 minutes';

  @override
  String get deviceActionsExampleWifi => 'Ouvrir les réglages Wi-Fi';

  @override
  String get deviceActionsExampleFlashlight => 'Allumer la lampe torche';

  @override
  String get deviceActionsExampleBluetooth => 'Ouvrir les réglages Bluetooth';

  @override
  String deviceActionSetAlarm(String time) {
    return 'Régler une alarme à $time';
  }

  @override
  String deviceActionSetTimer(String duration) {
    return 'Lancer un minuteur de $duration';
  }

  @override
  String get deviceActionShowAlarms => 'Ouvrir le réveil';

  @override
  String get deviceActionTorchOn => 'Allumer la lampe torche';

  @override
  String get deviceActionTorchOff => 'Éteindre la lampe torche';

  @override
  String deviceActionMedia(String action) {
    return 'Lecture : $action';
  }

  @override
  String deviceActionVolume(String direction) {
    return 'Volume $direction';
  }

  @override
  String deviceActionOpenSettings(String screen) {
    return 'Ouvrir les réglages $screen';
  }

  @override
  String deviceActionOpenApp(String name) {
    return 'Ouvrir $name';
  }

  @override
  String deviceActionDial(String number) {
    return 'Ouvrir le clavier avec $number';
  }

  @override
  String get deviceActionComposeSms => 'Écrire un nouveau SMS';

  @override
  String get deviceActionComposeEmail => 'Écrire un nouvel e-mail';

  @override
  String get deviceActionTakePhoto => 'Ouvrir l\'appareil photo';

  @override
  String deviceActionOpenUrl(String url) {
    return 'Ouvrir $url';
  }

  @override
  String deviceActionNavigate(String query) {
    return 'Itinéraire vers $query';
  }

  @override
  String get deviceActionShare => 'Partager du texte avec une autre app';

  @override
  String get deviceActionMediaPlay => 'lire';

  @override
  String get deviceActionMediaPause => 'mettre en pause';

  @override
  String get deviceActionMediaNext => 'piste suivante';

  @override
  String get deviceActionMediaPrevious => 'piste précédente';

  @override
  String get deviceActionVolumeUp => 'monter';

  @override
  String get deviceActionVolumeDown => 'baisser';

  @override
  String get deviceActionVolumeMute => 'couper';

  @override
  String get deviceScreenWifi => 'Wi-Fi';

  @override
  String get deviceScreenBluetooth => 'Bluetooth';

  @override
  String get deviceScreenAirplane => 'Mode avion';

  @override
  String get deviceScreenHotspot => 'Partage de connexion';

  @override
  String get deviceScreenMobileData => 'Données mobiles';

  @override
  String get deviceScreenBatterySaver => 'Économiseur de batterie';

  @override
  String get deviceScreenBatteryUsage => 'Consommation de la batterie';

  @override
  String get deviceScreenDnd => 'Ne pas déranger';

  @override
  String get deviceScreenDisplay => 'Affichage';

  @override
  String get deviceScreenSound => 'Son';

  @override
  String get deviceScreenLocation => 'Localisation';

  @override
  String get deviceScreenStorage => 'Stockage';

  @override
  String get deviceScreenDateTime => 'Date et heure';

  @override
  String get deviceScreenKeyboard => 'Clavier';

  @override
  String get deviceScreenLanguage => 'Langue';

  @override
  String get deviceScreenAccessibility => 'Accessibilité';

  @override
  String get deviceScreenApplications => 'Applications';

  @override
  String get deviceScreenNfc => 'NFC';

  @override
  String get deviceScreenCast => 'Diffuser';

  @override
  String get deviceScreenVpn => 'VPN';

  @override
  String get deviceScreenDeveloper => 'Options pour les développeurs';

  @override
  String get deviceScreenHome => 'Écran d\'accueil';

  @override
  String get deviceActionsResultDone => 'C\'est fait';

  @override
  String get settingsActionsSection => 'Actions sur ton appareil';

  @override
  String get settingsActionsRow => 'Actions';

  @override
  String get deviceScreenSystem => 'Réglages';

  @override
  String get deviceActionsDismissed => 'Annulé';

  @override
  String get creationsStopped => 'Arrêté.';

  @override
  String get creationsLoadFailed =>
      'Finn n\'a pas pu ouvrir tes créations enregistrées. Réessaie.';

  @override
  String get creationsDeleteFailed =>
      'Cette création n\'a pas pu être supprimée. Réessaie.';

  @override
  String get hubModelTitle => 'FinnAI Foundation';

  @override
  String hubModelSub(String size) {
    return 'Sur cet appareil, $size';
  }

  @override
  String get hubVoiceTitle => 'Voix et langue';

  @override
  String hubVoiceSub(String speed, String language) {
    return 'Vitesse $speed, $language';
  }

  @override
  String get hubAccessTitle => 'Accès à l’appareil';

  @override
  String get hubAccessSub => 'Calendrier, contacts, fichiers';

  @override
  String get hubYouTitle => 'Toi';

  @override
  String get hubYouSub => 'Ce que FinnAI apprend et utilise';

  @override
  String get hubDataTitle => 'Confidentialité et données';

  @override
  String get hubDataSub => 'Stockage, export, effacement';

  @override
  String get hubAboutTitle => 'À propos';

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
    return '$size de votre stockage, téléchargé le $date.';
  }

  @override
  String modelStoredNoDate(String size) {
    return '$size de votre stockage.';
  }

  @override
  String get modelNotInstalled => 'Pas encore téléchargé.';

  @override
  String get modelOffline => 'Fonctionner hors ligne';

  @override
  String get modelOfflineSub => 'Tout fonctionne sur cet appareil';

  @override
  String get modelLookups => 'Chercher en ligne';

  @override
  String get modelLookupsSub =>
      'Seulement si une question en a besoin. Vos chats et Toi restent ici.';

  @override
  String get modelUpdates => 'Rechercher des mises à jour';

  @override
  String get modelUpToDate => 'À jour';

  @override
  String get modelRemove => 'Supprimer le modèle';

  @override
  String modelRemoveSub(String size) {
    return 'Libère $size';
  }

  @override
  String get modelRemoveTitle => 'Supprimer le modèle ?';

  @override
  String get modelRemoveBody =>
      'FinnAI doit le télécharger à nouveau avant que vous puissiez discuter. Vos chats restent.';

  @override
  String get modelRemoveConfirm => 'Supprimer';

  @override
  String get voiceReadAloud => 'Lire les réponses à voix haute';

  @override
  String get voiceReadAloudSub => 'Dans les chats vocaux';

  @override
  String get voiceTranscript => 'Afficher la transcription en direct';

  @override
  String get voiceTranscriptSub => 'Pendant que vous parlez';

  @override
  String get voiceSpeed => 'Vitesse de parole';

  @override
  String get voiceSpeedSlow => 'Lente';

  @override
  String get voiceSpeedNormal => 'Normale';

  @override
  String get voiceSpeedFast => 'Rapide';

  @override
  String get voiceLanguage => 'Langue';

  @override
  String get voiceLanguageSub => 'Suit votre appareil';

  @override
  String get accessIntro =>
      'FinnAI ne lit que ce que vous autorisez, et seulement sur cet appareil.';

  @override
  String get accessMaster => 'Utiliser le contexte de cet appareil';

  @override
  String get accessMasterSub => 'Désactivez pour que FinnAI ne lise rien';

  @override
  String get accessActions => 'Actions sur votre appareil';

  @override
  String get accessActionsSub => 'Alarmes, minuteurs, réglages';

  @override
  String get ctxCalendar => 'Calendrier';

  @override
  String get ctxCalendarSub => 'Événements et temps libre';

  @override
  String get ctxContacts => 'Contacts';

  @override
  String get ctxContactsSub => 'Noms et relations';

  @override
  String get ctxNotifications => 'Notifications';

  @override
  String get ctxNotificationsSub => 'Ce qui demande votre attention';

  @override
  String get ctxPhotos => 'Photos';

  @override
  String get ctxPhotosSub => 'Seulement si vous les joignez';

  @override
  String get ctxFiles => 'Fichiers';

  @override
  String get ctxFilesSub => 'Documents que vous ouvrez avec FinnAI';

  @override
  String get ctxLocation => 'Position';

  @override
  String get ctxLocationSub => 'Seulement quand l’app est ouverte';

  @override
  String get dataStoredHere => 'Stocké sur cet appareil';

  @override
  String get dataChats => 'Chats';

  @override
  String get dataCreations => 'Créations';

  @override
  String get dataYou => 'Toi';

  @override
  String get dataModel => 'FinnAI Foundation';

  @override
  String get dataExport => 'Tout exporter';

  @override
  String get dataExportSub => 'Chats, créations, flux et Toi';

  @override
  String get dataDeleteChats => 'Supprimer tous les chats';

  @override
  String get dataDeleteChatsSub => 'Toi reste tel quel';

  @override
  String get dataErase => 'Tout effacer';

  @override
  String get dataEraseSub => 'Réinitialise FinnAI sur cet appareil';

  @override
  String get dataExportFailed => 'Export impossible. Réessayez.';

  @override
  String get aboutBlurb =>
      'Un assistant privé qui fonctionne sur votre appareil.';

  @override
  String get aboutPrivacy => 'Politique de confidentialité';

  @override
  String get aboutTerms => 'Conditions d’utilisation';

  @override
  String get aboutLicences => 'Licences open source';

  @override
  String get aboutFeedback => 'Envoyer un avis';

  @override
  String chatUsedFromYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0 de Toi utilisé(s)';
  }

  @override
  String get youAboutTitle => 'Ce que FinnAI sait de vous';

  @override
  String youUpdated(String when) {
    return 'Mis à jour $when';
  }

  @override
  String youReviewTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveautés à vérifier',
      one: '1 nouveauté à vérifier',
    );
    return '$_temp0';
  }

  @override
  String get youReviewSub => 'Remarqué dans vos chats récents';

  @override
  String youCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get youStoredOnly => 'Stocké uniquement sur cet appareil';

  @override
  String get youCatPeople => 'Personnes';

  @override
  String get youCatWork => 'Travail';

  @override
  String get youCatRoutines => 'Habitudes';

  @override
  String get youCatPreferences => 'Préférences';

  @override
  String get youCatPlaces => 'Lieux';

  @override
  String get youCatInterests => 'Centres d’intérêt';

  @override
  String get youEmptyTitle => 'FinnAI apprend encore à vous connaître';

  @override
  String get youEmptyBody =>
      'Au fil des chats, FinnAI apprend ce qui aide et le garde ici, sur cet appareil. Vous pouvez aussi écrire quelque chose vous-même.';

  @override
  String get youTellFinn => 'Parlez de vous à FinnAI';

  @override
  String get youPrivacyTitle => 'Confidentialité';

  @override
  String youCategoryIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments dont FinnAI se souvient. Touchez-en un pour voir d’où il vient.',
      one:
          '1 élément dont FinnAI se souvient. Touchez-le pour voir d’où il vient.',
    );
    return '$_temp0';
  }

  @override
  String get youCategoryEmpty =>
      'Rien pour l’instant. Touchez plus pour ajouter quelque chose.';

  @override
  String youSeenIn(String where) {
    return 'Vu dans $where';
  }

  @override
  String get youSeenInLabel => 'Vu dans';

  @override
  String get youAddedByYou => 'Ajouté par vous';

  @override
  String youLearnedOn(String when) {
    return 'Appris $when. Stocké sur cet appareil.';
  }

  @override
  String get youEdit => 'Modifier';

  @override
  String get youDoNotUse => 'Ne pas utiliser dans les chats';

  @override
  String get youForgetThis => 'Oublier ceci';

  @override
  String get youForgetTitle => 'Oublier ceci ?';

  @override
  String get youForgetBody =>
      'FinnAI cesse de l’utiliser dans les chats. Si vous le mentionnez à nouveau, il pourra être réappris.';

  @override
  String get youForgetConfirm => 'Oublier';

  @override
  String get youAddLabel => 'Avec vos propres mots';

  @override
  String get youAddHint =>
      'Quelque chose que FinnAI doit retenir, comme votre façon de travailler ou les personnes qui comptent pour vous.';

  @override
  String get youWhereBelongs => 'Où le ranger';

  @override
  String get youUseEveryChat => 'Utiliser dans chaque chat';

  @override
  String get youUseEveryChatSub =>
      'Désactivez pour ne l’utiliser que sur demande';

  @override
  String get youSaveToYou => 'Enregistrer dans Toi';

  @override
  String get youReviewTitleBar => 'Vérifier';

  @override
  String get youReviewIntro =>
      'FinnAI a remarqué ceci dans des chats récents. Gardez ce qui est juste et oubliez le reste.';

  @override
  String get youReviewEmpty => 'Rien à vérifier pour l’instant.';

  @override
  String get youKeep => 'Garder';

  @override
  String youFrom(String category, String chat) {
    return '$category, depuis $chat';
  }

  @override
  String get youPrivacyNote =>
      'Tout ce qui est dans Toi est stocké sur cet appareil. FinnAI ne l’envoie jamais ailleurs.';

  @override
  String get youLearn => 'Apprendre des conversations';

  @override
  String get youLearnSub => 'FinnAI propose des ajouts après vos chats';

  @override
  String get youUseInChats => 'Utiliser Toi dans les nouveaux chats';

  @override
  String get youUseInChatsSub => 'Vous pouvez le désactiver par chat';

  @override
  String get youLearnAbout => 'Apprendre sur';

  @override
  String get youExport => 'Exporter Toi';

  @override
  String get youExportSub => 'Enregistrer une copie en fichier';

  @override
  String get youErase => 'Tout effacer dans Toi';

  @override
  String youEraseSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return 'Supprime $_temp0';
  }

  @override
  String get youEraseTitle => 'Tout effacer dans Toi ?';

  @override
  String get youEraseBody =>
      'Tout ce dont FinnAI se souvient est supprimé de cet appareil. Vos chats restent.';

  @override
  String get youEraseConfirm => 'Effacer';

  @override
  String get youPersonalise => 'Style et consignes de réponse';

  @override
  String get youPersonaliseSub => 'Nom, ton et consignes personnalisées';

  @override
  String get youRemembered => 'Enregistré dans Toi';

  @override
  String get youWhenToday => 'aujourd’hui';

  @override
  String youWhenMinutes(int count) {
    return 'il y a $count minutes';
  }

  @override
  String youWhenHours(int count) {
    return 'il y a $count heures';
  }

  @override
  String youWhenDays(int count) {
    return 'il y a $count jours';
  }

  @override
  String get youWhenJustNow => 'à l’instant';

  @override
  String get searchHint => 'Rechercher';

  @override
  String get searchChatsHeading => 'Chats';

  @override
  String get searchCreationsHeading => 'Créations';

  @override
  String get searchNothing => 'Rien trouvé';

  @override
  String get searchPrompt => 'Cherchez dans vos chats, créations et Toi.';

  @override
  String get chatReadAloud => 'Lire à voix haute';

  @override
  String get chatRememberInYou => 'Retenir dans Toi';

  @override
  String get chatShare => 'Partager';

  @override
  String get plusCreate => 'Créer';

  @override
  String get plusWidget => 'Widget';

  @override
  String get plusWidgetSub => 'Pour votre écran d’accueil';

  @override
  String get plusMiniApp => 'Mini-app';

  @override
  String get plusMiniAppSub => 'Un petit outil';

  @override
  String get plusPresentation => 'Présentation';

  @override
  String get plusPresentationSub => 'Diapositives à partager';

  @override
  String get plusFlow => 'Flux';

  @override
  String get plusFlowSub => 'Se lance tout seul';

  @override
  String get plusAddToChat => 'Ajouter au chat';

  @override
  String get plusPhoto => 'Photo';

  @override
  String optionsStarted(String when) {
    return 'Commencé $when. Stocké sur cet appareil.';
  }

  @override
  String get optionsPin => 'Épingler le chat';

  @override
  String get optionsUnpin => 'Désépingler le chat';

  @override
  String get optionsExport => 'Exporter en texte';

  @override
  String get optionsDelete => 'Supprimer le chat';

  @override
  String get deleteChatTitle => 'Supprimer ce chat ?';

  @override
  String get deleteChatBody =>
      'Il est supprimé de cet appareil. Ce que FinnAI en a appris reste dans Toi jusqu’à ce que vous l’oubliiez.';

  @override
  String get fromYouTitle => 'De Toi';

  @override
  String get fromYouSub =>
      'FinnAI a utilisé ceci dans ce chat. Rien ne quitte votre appareil.';

  @override
  String get fromYouUse => 'Utiliser Toi dans ce chat';

  @override
  String get fromYouOpen => 'Ouvrir Toi';

  @override
  String get chatRenamePrompt => 'Renommer le chat';

  @override
  String get flowsFilterAll => 'Tous';

  @override
  String get flowsFilterActive => 'Actifs';

  @override
  String get flowsFilterPaused => 'En pause';

  @override
  String get flowsPhoneOn =>
      'Les flux s’exécutent sur cet appareil, votre téléphone doit donc être allumé.';

  @override
  String get flowsOnlyWhenAsked => 'Seulement sur demande';

  @override
  String flowsLastRunLine(String when, String result) {
    return 'Dernière exécution $when, $result';
  }

  @override
  String get flowsNeverRun => 'Pas encore exécuté';

  @override
  String get flowsPausedLine => 'En pause';

  @override
  String get flowsResultDone => 'terminé';

  @override
  String get flowsResultFailed => 'échec';

  @override
  String get flowsResultStopped => 'arrêté';

  @override
  String get flowsWhenToday => 'aujourd’hui';

  @override
  String get flowsWhenYesterday => 'hier';

  @override
  String get flowsEmptyTitle => 'Aucun flux pour l’instant';

  @override
  String get flowsEmptyBody =>
      'Un flux accomplit une tâche pour vous à heure fixe ou quand quelque chose se passe. Décrivez-en un dans le chat.';

  @override
  String get flowsEmptyCreate => 'Créer un flux';

  @override
  String get flowsNewTitle => 'Nouveau flux';

  @override
  String get flowsNewSub =>
      'Commencez par des mots, une heure ou un événement.';

  @override
  String get flowsNewDescribe => 'Décrivez-le';

  @override
  String get flowsNewDescribeSub => 'Dites à FinnAI ce qui doit arriver';

  @override
  String get flowsNewTime => 'À heure fixe';

  @override
  String get flowsNewTimeSub => 'Chaque jour, semaine ou mois';

  @override
  String get flowsNewEvent => 'Quand quelque chose se passe';

  @override
  String get flowsNewEventSub => 'Recharge, arrivée, une notification';

  @override
  String flowsDetailOn(String when) {
    return 'Activé, prochaine exécution $when';
  }

  @override
  String get flowsDetailOnManual => 'Activé, s’exécute sur demande';

  @override
  String get flowsDetailPaused => 'En pause';

  @override
  String get flowsWhen => 'Quand';

  @override
  String get flowsThen => 'Ensuite';

  @override
  String get flowsRecentRuns => 'Exécutions récentes';

  @override
  String get flowsNoRunsYet => 'Aucune exécution';

  @override
  String get flowsRunStatusDone => 'Terminé';

  @override
  String get flowsRunStatusFailed => 'N’a pas pu se terminer';

  @override
  String get flowsRunStatusDeclined => 'Non autorisé';

  @override
  String get flowsRunStatusNeedsGrant => 'Nécessite votre autorisation';

  @override
  String get flowsRunStatusStopped => 'Arrêté';

  @override
  String get flowsMenuEdit => 'Modifier';

  @override
  String get flowsMenuPause => 'Mettre en pause';

  @override
  String get flowsMenuResume => 'Activer';

  @override
  String get flowsMenuDuplicate => 'Dupliquer';

  @override
  String get flowsMenuDelete => 'Supprimer';

  @override
  String get flowsRunFinished => 'Terminé';

  @override
  String flowsRunFinishedIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds secondes',
      one: '1 seconde',
    );
    return 'Terminé en $_temp0';
  }

  @override
  String get flowsRunAgain => 'Relancer';

  @override
  String get flowsBuilderHint => 'Décrivez ce qui doit arriver';

  @override
  String get flowsBuilderHere => 'Voici le flux. Vérifiez-le, puis activez-le.';

  @override
  String get flowsBuilderNoMatch =>
      'Je ne sais pas encore le construire. Choisissez-en un et je le prépare.';

  @override
  String get flowsBuilderTurnOn => 'Activer';

  @override
  String get flowsStartWhen => 'Démarrer quand';

  @override
  String get flowsTriggerTime => 'À heure fixe';

  @override
  String get flowsTriggerTimeSub => 'Chaque jour, semaine ou mois';

  @override
  String get flowsTriggerPlace => 'Arrivée ou départ';

  @override
  String get flowsTriggerPlaceSub => 'Un lieu de votre choix';

  @override
  String get flowsTriggerCharging => 'Recharge';

  @override
  String get flowsTriggerChargingSub => 'Au branchement ou débranchement';

  @override
  String get flowsTriggerBattery => 'Niveau de batterie';

  @override
  String get flowsTriggerBatterySub => 'En dessous ou au-dessus d’un niveau';

  @override
  String get flowsTriggerNotification => 'Une notification';

  @override
  String get flowsTriggerNotificationSub => 'Quand une arrive d’une app';

  @override
  String get flowsTriggerManual => 'Seulement sur demande';

  @override
  String get flowsTriggerManualSub => 'Lancez-le vous-même';

  @override
  String get flowsTriggerSoon => 'Pas encore disponible';

  @override
  String get flowsScheduleSheetTitle => 'Horaire';

  @override
  String get flowsScheduleSave => 'Enregistrer l’horaire';

  @override
  String flowsAllowTitle(String name) {
    return 'Autoriser $name à agir sur votre téléphone ?';
  }

  @override
  String get flowsAllowConfirm => 'Autoriser';

  @override
  String flowsDeleteNamed(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get flowsDeleteNamedBody =>
      'Ses exécutions passées sont aussi supprimées. Cette action est irréversible.';

  @override
  String flowsStepLookUp(String query) {
    return 'Chercher $query';
  }

  @override
  String get flowsStepWrite => 'Rédiger la réponse';

  @override
  String get creationsNewSheetSub =>
      'Décrivez-le dans le chat. FinnAI le crée sur cet appareil.';

  @override
  String get creationsNewWidgetSub =>
      'De petits outils pour votre écran d’accueil';

  @override
  String get creationsNewAppSub => 'Un outil simple qui fonctionne dans FinnAI';

  @override
  String get creationsNewDeckSub => 'Des diapositives à présenter ou partager';

  @override
  String get creationsMenuEditWithFinn => 'Modifier avec FinnAI';

  @override
  String get creationsMenuDuplicate => 'Dupliquer';

  @override
  String get creationsMenuShare => 'Partager';

  @override
  String creationsDeleteNamed(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get creationsDeleteNamedBody =>
      'Il est supprimé de Créations et de votre écran d’accueil. Cette action est irréversible.';

  @override
  String get creationsSizeSmall => 'Petit';

  @override
  String get creationsSizeMedium => 'Moyen';

  @override
  String get creationsSizeLarge => 'Grand';

  @override
  String get creationsUpdatesOnDevice =>
      'Se met à jour sur cet appareil. Rien ne quitte votre appareil.';

  @override
  String get creationsMadeInChat => 'Créé dans le chat';

  @override
  String get creationsDataLabel => 'Données';

  @override
  String get creationsDataSub => 'Stockées dans ce widget';

  @override
  String creationsAddHomeTitle(String name) {
    return 'Ajouter $name à votre écran d’accueil ?';
  }

  @override
  String get creationsAddHomeBody =>
      'Il se place comme n’importe quel widget. Vous pourrez le déplacer ou le retirer plus tard.';

  @override
  String get creationsAddHomeConfirm => 'Ajouter';

  @override
  String get creationsBuilderTitleWidget => 'Nouveau widget';

  @override
  String get creationsBuilderTitleApp => 'Nouvelle mini-app';

  @override
  String get creationsBuilderTitleDeck => 'Nouvelle présentation';

  @override
  String get creationsBuilderHint => 'Décrivez ce qu’il faut créer';

  @override
  String get creationsBuilderChangeHint => 'Demandez des modifications';

  @override
  String get creationsBuilderGotIt =>
      'Compris. Je le construis sur cet appareil.';

  @override
  String get creationsBuilderReady =>
      'Le voici. Ouvrez-le ou continuez à modifier.';

  @override
  String get creationsSaveToCreations => 'Enregistrer dans Créations';

  @override
  String get creationsKeepEditing => 'Continuer à modifier';

  @override
  String get creationsSpeakerNotes => 'Notes de l’orateur';

  @override
  String get creationsPresent => 'Présenter';

  @override
  String get creationsDuplicated => 'Dupliqué.';

  @override
  String get onboardingChooseTitle => 'Choisissez ce que FinnAI peut voir';

  @override
  String get onboardingChooseBody =>
      'Vous pouvez le modifier à tout moment dans les Réglages. Tout reste sur cet appareil.';

  @override
  String get onboardingDownloadPausedTitle => 'Téléchargement en pause';

  @override
  String get onboardingDownloadPausedBody =>
      'En attente d’une connexion, votre progression est enregistrée.';

  @override
  String get onboardingDownloadPausedNote =>
      'Il reprend quand vous êtes de nouveau en ligne.';

  @override
  String get flowsStepNotifyMe => 'Me prévenir';

  @override
  String get creationsTemplateTracker => 'Suivi';

  @override
  String get creationsSlotStep => 'Ajout par appui';

  @override
  String get creationsResetAppTitle => 'Réinitialiser cette app ?';

  @override
  String get creationsResetAppBody =>
      'Tout ce que vous y avez ajouté est effacé. Cette action est irréversible.';

  @override
  String get deviceActionVibrate => 'Faire vibrer le téléphone';

  @override
  String get flowsTrigManual => 'Seulement quand je le lance';

  @override
  String get flowsTrigTimeOfDay => 'À une heure précise';

  @override
  String flowsTrigEveryMinutes(int n) {
    return 'Toutes les $n minutes';
  }

  @override
  String flowsTrigEveryHours(int n) {
    return 'Toutes les $n heures';
  }

  @override
  String get flowsTrigEveryHour => 'Toutes les heures';

  @override
  String get flowsTrigInterval => 'Répété';

  @override
  String get flowsTrigChargerOn => 'Chargeur branché';

  @override
  String get flowsTrigChargerOff => 'Chargeur débranché';

  @override
  String flowsTrigBatteryLow(int n) {
    return 'La batterie descend à $n %';
  }

  @override
  String get flowsTrigHeadsetOn => 'Casque branché';

  @override
  String get flowsTrigHeadsetOff => 'Casque débranché';

  @override
  String get flowsTrigWifiOn => 'Wi‑Fi connecté';

  @override
  String get flowsTrigWifiOff => 'Wi‑Fi déconnecté';

  @override
  String get flowsTrigAirplaneOn => 'Le mode avion s’active';

  @override
  String get flowsTrigAirplaneOff => 'Le mode avion se désactive';

  @override
  String get flowsTrigBoot => 'Le téléphone démarre';

  @override
  String get flowsTrigUnlock => 'Écran déverrouillé';

  @override
  String get flowsTrigGroupTime => 'Heure';

  @override
  String get flowsTrigGroupPhone => 'Sur le téléphone';

  @override
  String get flowsTrigGroupHand => 'À la main';

  @override
  String flowsCondBatteryBelow(int n) {
    return 'Batterie sous $n %';
  }

  @override
  String flowsCondBatteryAbove(int n) {
    return 'Batterie au-dessus de $n %';
  }

  @override
  String get flowsCondCharging => 'En charge';

  @override
  String get flowsCondNotCharging => 'Ne charge pas';

  @override
  String flowsCondTimeBetween(String from, String to) {
    return 'Entre $from et $to';
  }

  @override
  String flowsCondDays(String days) {
    return 'Le $days';
  }

  @override
  String get flowsCondWifiOn => 'Wi‑Fi connecté';

  @override
  String get flowsCondWifiOff => 'Wi‑Fi non connecté';

  @override
  String get flowsCondHeadsetOn => 'Casque branché';

  @override
  String get flowsCondHeadsetOff => 'Casque non branché';

  @override
  String get flowsCondAirplaneOn => 'Mode avion activé';

  @override
  String get flowsCondAirplaneOff => 'Mode avion désactivé';

  @override
  String flowsCondAnswer(String text) {
    return 'La réponse mentionne « $text »';
  }

  @override
  String get flowsBlockAsk => 'Demander à FinnAI';

  @override
  String get flowsBlockAskSub => 'Écrire quelque chose avec le modèle local';

  @override
  String get flowsBlockWeb => 'Chercher';

  @override
  String get flowsBlockWebSub => 'Actualités, météo ou le web';

  @override
  String get flowsBlockNotify => 'Me notifier';

  @override
  String get flowsBlockNotifySub => 'Afficher une notification';

  @override
  String get flowsBlockSpeak => 'Le dire à voix haute';

  @override
  String get flowsBlockSpeakSub => 'Parler avec la voix du téléphone';

  @override
  String get flowsBlockAction => 'Faire sur le téléphone';

  @override
  String get flowsBlockActionSub => 'Lampe, volume, alarme, ouvrir une app';

  @override
  String get flowsBlockWait => 'Attendre';

  @override
  String get flowsBlockWaitSub => 'Faire une pause de quelques secondes';

  @override
  String get flowsBlockBranch => 'Si … alors';

  @override
  String get flowsBlockBranchSub => 'Faire une chose ou une autre';

  @override
  String get flowsBlockSave => 'Enregistrer dans le chat';

  @override
  String get flowsBlockSaveSub => 'Garder la réponse comme chat';

  @override
  String get flowsBlockStop => 'S’arrêter ici';

  @override
  String get flowsBlockStopSub => 'Terminer le flux';

  @override
  String flowsSumAsk(String text) {
    return 'Demander : $text';
  }

  @override
  String flowsSumWeb(String text) {
    return 'Chercher $text';
  }

  @override
  String get flowsSumNotifyAnswer => 'Afficher la réponse';

  @override
  String get flowsSumSpeakAnswer => 'Lire la réponse à voix haute';

  @override
  String flowsSumWait(int n) {
    return 'Attendre $n s';
  }

  @override
  String flowsSumIf(String condition) {
    return 'Si $condition';
  }

  @override
  String get flowsEdWhen => 'Quand';

  @override
  String get flowsEdOnlyIf => 'Seulement si';

  @override
  String get flowsEdThen => 'Alors';

  @override
  String get flowsEdOr => 'ou';

  @override
  String get flowsEdYes => 'Oui';

  @override
  String get flowsEdOtherwise => 'Sinon';

  @override
  String get flowsEdEnd => 'Terminé';

  @override
  String get flowsEdAddTrigger => 'Ajouter un déclencheur';

  @override
  String get flowsEdAddCondition => 'Ajouter une condition';

  @override
  String get flowsEdAddStep => 'Ajouter une étape';

  @override
  String get flowsEdInsertHere => 'Ajouter une étape ici';

  @override
  String get flowsEdNoSteps =>
      'Rien à faire pour l’instant. Ajoutez la première étape.';

  @override
  String get flowsEdManualStart => 'Démarre quand vous touchez Exécuter';

  @override
  String get flowsEdMoveUp => 'Monter';

  @override
  String get flowsEdMoveDown => 'Descendre';

  @override
  String get flowsEdRemove => 'Retirer';

  @override
  String get flowsEdDone => 'Terminé';

  @override
  String get flowsEdChooseStep => 'Que doit-il se passer ?';

  @override
  String get flowsEdChooseTrigger => 'Qu’est-ce qui le démarre ?';

  @override
  String get flowsEdChooseCondition => 'Seulement quand…';

  @override
  String get flowsEdConditionNote =>
      'Si ce n’est pas vrai, le flux ne s’exécute pas quand autre chose le démarre.';

  @override
  String get flowsFieldPrompt => 'Que doit écrire FinnAI ?';

  @override
  String flowsFieldPromptHint(String input) {
    return '$input représente la dernière réponse';
  }

  @override
  String get flowsFieldQuery => 'Que chercher';

  @override
  String get flowsFieldSource => 'Où';

  @override
  String get flowsSourceWeb => 'Le web';

  @override
  String get flowsSourceNews => 'Actualités';

  @override
  String get flowsSourceWeather => 'Météo';

  @override
  String get flowsFieldTitle => 'Titre';

  @override
  String get flowsFieldMessage => 'Message';

  @override
  String get flowsFieldMessageHint =>
      'Laissez vide pour afficher la dernière réponse';

  @override
  String get flowsFieldSay => 'Quoi dire';

  @override
  String get flowsFieldSayHint => 'Laissez vide pour lire la dernière réponse';

  @override
  String get flowsFieldSeconds => 'Combien de secondes';

  @override
  String get flowsFieldAction => 'Quoi faire';

  @override
  String get flowsFieldCondition => 'Condition';

  @override
  String get flowsFieldLevel => 'Niveau de batterie';

  @override
  String get flowsFieldFrom => 'De';

  @override
  String get flowsFieldTo => 'À';

  @override
  String get flowsFieldDays => 'Jours';

  @override
  String get flowsFieldContains => 'Contient';

  @override
  String get flowsFieldEveryMinutes => 'Répéter toutes les';

  @override
  String get flowsUnitMinutes => 'minutes';

  @override
  String get flowsUnitHours => 'heures';

  @override
  String get flowsBgWorks => 'Fonctionne en arrière-plan';

  @override
  String get flowsBgNeedsScreen => 'Vous devez toucher une notification';

  @override
  String get flowsAutoTitle => 'La laisser s’exécuter seule';

  @override
  String get flowsAutoNeedsAllow =>
      'Ce flux modifie votre téléphone. Autorisez-le à s’exécuter quand vous ne regardez pas.';

  @override
  String get flowsListenerOn => 'FinnAI écoute ces événements en arrière-plan.';

  @override
  String get flowsListenerNeedsNotify =>
      'Activez les notifications pour que FinnAI puisse continuer à écouter.';

  @override
  String get flowsRunStatusSkipped => 'Conditions non remplies';

  @override
  String get flowsRunStatusNeedsScreen => 'En attente de vous';

  @override
  String get flowsRunSkipped => 'Ignoré';

  @override
  String get flowsRunNeedsScreen => 'Touchez pour terminer';

  @override
  String get flowsRunByEvent => 'S’est exécuté seul';

  @override
  String get flowsRunByChat => 'Lancé depuis le chat';

  @override
  String flowsNeedsScreenBody(String name) {
    return 'Touchez pour terminer « $name » : l’écran est nécessaire.';
  }

  @override
  String flowsNeedsGrantBody(String name) {
    return '« $name » voulait s’exécuter mais a besoin de votre autorisation.';
  }

  @override
  String get flowsStepWaiting => 'En attente';

  @override
  String flowsPathStep(int n) {
    return 'Étape $n';
  }

  @override
  String get flowsDescribeTitle => 'Décrivez votre flux';

  @override
  String get flowsDescribeHint =>
      'Par exemple : quand je branche le chargeur, allume la lampe';

  @override
  String get flowsDescribeBuild => 'Créer';

  @override
  String get flowsDescribeThinking => 'Réflexion en cours…';

  @override
  String get flowsDescribeFailed =>
      'Je n’ai pas pu en faire un flux. Dites quand il démarre et ce qu’il doit faire.';

  @override
  String flowsDescribeMissed(String parts) {
    return 'Non compris : $parts';
  }

  @override
  String get flowsDescribeExamples => 'Essayez l’un d’eux';

  @override
  String get flowsExampleCharger =>
      'Quand je branche le chargeur, allume la lampe';

  @override
  String get flowsExampleBattery =>
      'Quand la batterie est sous 15 %, rappelle-moi de charger';

  @override
  String get flowsExampleNews => 'Chaque matin à 7 h, donne-moi les actualités';

  @override
  String get flowsExampleHeadset =>
      'Quand je branche le casque, lance la musique';

  @override
  String get flowsNewBlank => 'Partir de zéro';

  @override
  String get flowsNewBlankSub => 'Construisez-le étape par étape';

  @override
  String get flowsNewTemplates => 'À partir d’un modèle';

  @override
  String get flowsNewTemplatesSub =>
      'Brief d’actualités, rappel, batterie faible…';

  @override
  String get flowsTemplateLowBattery => 'Alerte batterie faible';

  @override
  String get flowsTemplateLowBatteryBody =>
      'Vous prévient une fois quand la batterie est faible.';

  @override
  String get flowsTemplateHeadset => 'Casque et musique';

  @override
  String get flowsTemplateHeadsetBody =>
      'Lit ou met en pause quand le casque se branche.';

  @override
  String get flowsSlotLevel => 'Prévenir à (%)';

  @override
  String get flowsSlotWhat => 'Quoi faire';

  @override
  String get flowsSlotPlay => 'Lire';

  @override
  String get flowsSlotPause => 'Pause';

  @override
  String get flowsRunsTitle => 'Exécutions';

  @override
  String get flowsRunsAll => 'Voir toutes les exécutions';

  @override
  String get flowsRenameTitle => 'Renommer le flux';

  @override
  String get flowsSavedToast => 'Enregistré';

  @override
  String get flowsStepOutcomeSkipped => 'Ignoré';

  @override
  String flowsChatCreated(String name) {
    return 'J’ai créé un flux : « $name ». Vérifiez-le puis activez-le.';
  }

  @override
  String get flowsChatOpen => 'Ouvrir le flux';

  @override
  String get flowsChatTurnOn => 'Activer';

  @override
  String get flowsChatIsOn => 'Activé';

  @override
  String get flowsChatDiscard => 'Ignorer';

  @override
  String get flowsActSetAlarm => 'Régler une alarme';

  @override
  String get flowsActSetTimer => 'Lancer un minuteur';

  @override
  String get flowsActShowAlarms => 'Afficher mes alarmes';

  @override
  String get flowsActTorch => 'Lampe de poche';

  @override
  String get flowsActMedia => 'Contrôler la musique';

  @override
  String get flowsActVolume => 'Changer le volume';

  @override
  String get flowsActVibrate => 'Faire vibrer';

  @override
  String get flowsActOpenSettings => 'Ouvrir un réglage';

  @override
  String get flowsActOpenApp => 'Ouvrir une app';

  @override
  String get flowsActDial => 'Lancer un appel';

  @override
  String get flowsActSms => 'Écrire un SMS';

  @override
  String get flowsActEmail => 'Écrire un e-mail';

  @override
  String get flowsActPhoto => 'Ouvrir l’appareil photo';

  @override
  String get flowsActUrl => 'Ouvrir une adresse web';

  @override
  String get flowsActNavigate => 'Obtenir un itinéraire';

  @override
  String get flowsActShare => 'Partager du texte';

  @override
  String get flowsOn => 'Activé';

  @override
  String get flowsOff => 'Désactivé';

  @override
  String get flowsParamState => 'État';

  @override
  String get flowsParamDirection => 'Direction';

  @override
  String get flowsParamScreen => 'Écran';

  @override
  String get flowsParamTime => 'Heure';

  @override
  String get flowsParamSeconds => 'Secondes';

  @override
  String get flowsParamMilliseconds => 'Millisecondes';

  @override
  String get flowsParamLabel => 'Libellé';

  @override
  String get flowsParamName => 'Nom de l’app';

  @override
  String get flowsParamNumber => 'Numéro de téléphone';

  @override
  String get flowsParamTo => 'À';

  @override
  String get flowsParamBody => 'Message';

  @override
  String get flowsParamSubject => 'Objet';

  @override
  String get flowsParamUrl => 'Adresse web';

  @override
  String get flowsParamQuery => 'Lieu ou adresse';

  @override
  String get flowsParamText => 'Texte';

  @override
  String get flowsPickAction => 'Que doit faire le téléphone ?';

  @override
  String get flowsEveryHowLong => 'Répéter toutes les';

  @override
  String get flowsIntervalNote =>
      'Le téléphone regroupe les minuteurs pour économiser la batterie, il peut donc avoir quelques minutes de retard.';

  @override
  String get flowsBatteryLevelNote =>
      'S’exécute une fois quand la batterie descend à ce niveau.';

  @override
  String get chatCreationReady =>
      'Le voici. Ouvrez-le ou mettez-le sur votre écran d’accueil.';

  @override
  String get chatCreationBuilding => 'Création en cours…';

  @override
  String get flowsDetailOnEvent => 'Activé, démarre tout seul';

  @override
  String get voiceStyle => 'Voix';

  @override
  String get voiceStyleF1 => 'Féminine 1';

  @override
  String get voiceStyleF2 => 'Féminine 2';

  @override
  String get voiceStyleM1 => 'Masculine 1';

  @override
  String get voiceStyleM2 => 'Masculine 2';

  @override
  String get appBrandFinnAICode => 'FinnAI Code';

  @override
  String get appModeSwitchSemantic => 'Passer de FinnAI à FinnAI Code';

  @override
  String get codeGreeting => 'Qu’allons-nous construire ?';

  @override
  String get codeGreetingCaption =>
      'Ton projet vit dans un dossier privé sur cet appareil.';

  @override
  String get codeComposerHint => 'Décris ce qu’il faut créer ou réparer';

  @override
  String get codeNewSession => 'Nouvelle session';

  @override
  String get codeSessionsTitle => 'Sessions';

  @override
  String get codeNoSessions => 'Aucune session pour l’instant';

  @override
  String get codeFilesTitle => 'Fichiers';

  @override
  String get codeTerminalTitle => 'Terminal';

  @override
  String get codeModelsTitle => 'Modèles';

  @override
  String get codeSettingsTitle => 'Réglages de Code';

  @override
  String get codeLocalLabel => 'FinnAI · sur l’appareil';

  @override
  String codeModelChipSemantic(String model) {
    return 'Choisir un modèle. Actuel : $model';
  }

  @override
  String get codePermissionAsk => 'Demander d’abord';

  @override
  String get codePermissionEdits => 'Édition auto';

  @override
  String get codePermissionAuto => 'Exécution auto';

  @override
  String codePermissionSemantic(String mode) {
    return 'Changer ce que l’agent peut faire. Actuel : $mode';
  }

  @override
  String get codeThinking => 'Réflexion…';

  @override
  String get codeActionRunCommand => 'Exécuter la commande';

  @override
  String codeActionWriteFile(String path) {
    return 'Écrire $path';
  }

  @override
  String get codeActionRun => 'Exécuter';

  @override
  String get codeActionAllow => 'Autoriser';

  @override
  String get codeActionSkip => 'Ignorer';

  @override
  String get codeActionRunning => 'En cours…';

  @override
  String get codeActionDone => 'Terminé';

  @override
  String codeActionFailedExit(String code) {
    return 'Échec (code $code)';
  }

  @override
  String get codeActionFailed => 'Échec';

  @override
  String get codeActionTimedOut => 'Délai dépassé';

  @override
  String get codeActionSkipped => 'Ignoré';

  @override
  String get codeActionDenied => 'Bloqué';

  @override
  String get codeActionOutput => 'Sortie';

  @override
  String get codeActionNoOutput => 'Aucune sortie';

  @override
  String get codeActionOutputCut => 'La sortie a été tronquée';

  @override
  String codeDeniedBlockedProgram(String program) {
    return '« $program » n’est pas autorisé ici.';
  }

  @override
  String get codeDeniedNetwork => 'Les commandes réseau sont désactivées.';

  @override
  String codeDeniedOutside(String path) {
    return '$path est en dehors du dossier du projet.';
  }

  @override
  String get codeDeniedParent => '« .. » n’est pas autorisé dans les chemins.';

  @override
  String get codeDeniedOther => 'Cette commande n’est pas autorisée.';

  @override
  String get codeErrorStepLimit => 'Arrêté à la limite d’étapes.';

  @override
  String get codeErrorRepeating => 'Arrêté : le modèle répétait la même étape.';

  @override
  String get codeErrorEmpty => 'Le modèle a envoyé une réponse vide.';

  @override
  String get codeErrorCutOff =>
      'La réponse a été coupée avant la fin de l’étape, rien n’a donc été exécuté.';

  @override
  String codeErrorEngine(String detail) {
    return 'Un problème est survenu : $detail';
  }

  @override
  String get codeErrorAuth =>
      'Le fournisseur a refusé la clé. Vérifie-la dans les réglages de Code.';

  @override
  String get codeErrorPlanNoApi =>
      'L’offre Go de Command Code n’a pas d’accès API. Passe à GOAT ou supérieur pour l’utiliser ici.';

  @override
  String get codeErrorPayment => 'Plus de crédit chez ce fournisseur.';

  @override
  String get codeErrorRate =>
      'Limite de requêtes atteinte. Réessaie dans un instant.';

  @override
  String get codeErrorWrongEndpoint =>
      'Ce fournisseur n’a pas pu servir ce modèle.';

  @override
  String get codeErrorBadRequest =>
      'Le fournisseur n’a pas pu accepter la requête.';

  @override
  String get codeErrorServer =>
      'Le fournisseur a rencontré un problème. Réessaie.';

  @override
  String get codeErrorNetwork =>
      'Impossible de joindre le fournisseur. Vérifie ta connexion.';

  @override
  String get codeErrorTimeout =>
      'Le fournisseur a mis trop de temps à répondre.';

  @override
  String get codeErrorMalformed =>
      'Le fournisseur a envoyé une réponse illisible.';

  @override
  String get codeErrorUnknown => 'Un problème est survenu avec le fournisseur.';

  @override
  String get codeSessionRename => 'Renommer';

  @override
  String get codeSessionRenameTitle => 'Renommer la session';

  @override
  String get codeSessionPin => 'Épingler';

  @override
  String get codeSessionUnpin => 'Détacher';

  @override
  String get codeSessionFiles => 'Fichiers du projet';

  @override
  String get codeSessionDelete => 'Supprimer la session';

  @override
  String get codeSessionDeleteTitle => 'Supprimer cette session ?';

  @override
  String get codeSessionDeleteBody =>
      'La conversation et ses fichiers de projet sont supprimés de cet appareil.';

  @override
  String codeCloudTitle(String provider) {
    return 'Utiliser $provider ?';
  }

  @override
  String codeCloudBody(String provider) {
    return '$provider fonctionne dans le cloud. Ce que tu écris, ainsi que le contenu des fichiers et la sortie des commandes lus par l’agent, est envoyé à $provider et traité selon ses conditions. FinnAI sur cet appareil garde tout sur le téléphone.';
  }

  @override
  String codeCloudConfirm(String provider) {
    return 'Utiliser $provider';
  }

  @override
  String get codeModelsSearchHint => 'Rechercher des modèles';

  @override
  String get codeModelsOnDeviceTitle => 'FinnAI';

  @override
  String get codeModelsOnDeviceSub =>
      'Fonctionne sur cet appareil. Privé, gratuit et utilisable hors ligne.';

  @override
  String get codeModelsAddProvider =>
      'Ajoute un fournisseur pour utiliser plus de modèles';

  @override
  String get codeModelsLoading => 'Chargement des modèles…';

  @override
  String get codeModelsLoad => 'Charger les modèles';

  @override
  String get codeModelsNone => 'Aucun modèle ne correspond';

  @override
  String get codeModelsFree => 'Gratuit';

  @override
  String codeModelsContext(String size) {
    return '$size de contexte';
  }

  @override
  String codeModelsPrice(String input, String output) {
    return '$input entrée · $output sortie par 1 M';
  }

  @override
  String codeModelsFetchFailed(String reason) {
    return 'Impossible de charger les modèles. $reason';
  }

  @override
  String get codeSettingsProviders => 'Fournisseurs';

  @override
  String get codeSettingsProvidersSubNone => 'FinnAI sur cet appareil';

  @override
  String codeSettingsProvidersSub(String count) {
    return 'FinnAI et $count connectés';
  }

  @override
  String get codeSettingsModel => 'Modèle';

  @override
  String get codeSettingsAgent => 'Agent';

  @override
  String get codeSettingsWorkspace => 'Dossiers de projet';

  @override
  String codeSettingsWorkspaceSub(String size) {
    return '$size sur cet appareil';
  }

  @override
  String get codeSettingsData => 'Confidentialité et données';

  @override
  String get codeSettingsDataSub => 'Clés, sessions et fichiers de projet';

  @override
  String get codeSettingsAbout => 'À propos de FinnAI Code';

  @override
  String get codeProvidersTitle => 'Fournisseurs';

  @override
  String get codeProvidersIntro =>
      'FinnAI sur ton téléphone est le choix par défaut. Ajoute ta propre clé API pour utiliser un modèle cloud dans FinnAI Code. Les clés restent dans le stockage sécurisé de ton téléphone.';

  @override
  String get codeProviderStatusLocal => 'Sur cet appareil';

  @override
  String codeProviderStatusConnected(String hint) {
    return 'Connecté · ••••$hint';
  }

  @override
  String get codeProviderStatusConnectedNoKey => 'Connecté';

  @override
  String get codeProviderStatusNotSet => 'Non configuré';

  @override
  String get codeProviderDescOpenRouter =>
      'Une clé pour des centaines de modèles, dont des gratuits.';

  @override
  String get codeProviderDescCommandCode =>
      'Les modèles de Command Code avec ta propre clé.';

  @override
  String get codeProviderDescZen =>
      'OpenCode Zen : des modèles à l’usage choisis pour le code.';

  @override
  String get codeProviderDescGo =>
      'OpenCode Go : une offre mensuelle fixe de modèles ouverts pour le code.';

  @override
  String get codeProviderDescCustom =>
      'Tout serveur compatible avec l’API OpenAI : le tien, Ollama, LM Studio et d’autres.';

  @override
  String get codeProviderCustomName => 'Personnalisé (compatible OpenAI)';

  @override
  String get codeProviderKeyLabel => 'Clé API';

  @override
  String get codeProviderKeyHint => 'Colle ta clé';

  @override
  String get codeProviderKeyOptionalHint =>
      'Colle une clé si ton serveur en demande une';

  @override
  String get codeProviderKeySave => 'Enregistrer la clé';

  @override
  String get codeProviderKeyReplace => 'Remplacer la clé';

  @override
  String get codeProviderKeyRemove => 'Supprimer la clé';

  @override
  String get codeProviderKeyRemoveTitle => 'Supprimer cette clé ?';

  @override
  String codeProviderKeyRemoveBody(String provider) {
    return 'FinnAI Code n’utilisera plus $provider tant que tu n’auras pas rajouté une clé.';
  }

  @override
  String get codeProviderKeyStored =>
      'Stockée de façon sécurisée sur cet appareil';

  @override
  String get codeProviderGetKey => 'Obtenir une clé';

  @override
  String get codeProviderTest => 'Tester la clé';

  @override
  String get codeProviderTesting => 'Test en cours…';

  @override
  String get codeProviderTestOk => 'La clé fonctionne.';

  @override
  String codeProviderTestFail(String reason) {
    return 'Le test a échoué. $reason';
  }

  @override
  String get codeProviderTestNeedsModel =>
      'Charge d’abord les modèles, puis teste.';

  @override
  String get codeProviderAddressLabel => 'Adresse du serveur';

  @override
  String get codeProviderAddressHint => 'https://ton-serveur/v1';

  @override
  String get codeProviderAddressInvalid =>
      'Utilise une adresse https, ou http pour un serveur de ton propre réseau.';

  @override
  String get codeProviderAddressSave => 'Enregistrer l’adresse';

  @override
  String get codeProviderPlanNote =>
      'Nécessite l’offre GOAT ou supérieure. L’offre Go n’a pas d’accès API et ne peut pas être utilisée ici.';

  @override
  String codeProviderPrivacy(String provider) {
    return 'Quand tu utilises l’un de ses modèles, tes messages, le contenu des fichiers et la sortie des commandes sont envoyés à $provider.';
  }

  @override
  String get codeProviderAllowance => 'Solde';

  @override
  String codeProviderAllowanceRemaining(String remaining, String limit) {
    return '$remaining restants sur $limit';
  }

  @override
  String get codeProviderAllowanceUnlimited =>
      'Aucune limite de dépense sur cette clé';

  @override
  String codeProviderAllowanceUsed(String used) {
    return '$used utilisés';
  }

  @override
  String codeProviderAllowanceToday(String amount) {
    return '$amount aujourd’hui';
  }

  @override
  String codeProviderAllowanceMonth(String amount) {
    return '$amount ce mois-ci';
  }

  @override
  String codeProviderAllowanceBalance(String balance) {
    return 'Crédit du compte $balance';
  }

  @override
  String get codeProviderAllowanceFree => 'Clé de l’offre gratuite';

  @override
  String codeProviderAllowanceNoApi(String provider) {
    return '$provider ne propose pas d’API d’utilisation. Consulte ton solde sur son tableau de bord.';
  }

  @override
  String get codeProviderOpenDashboard => 'Ouvrir le tableau de bord';

  @override
  String get codeProviderRefresh => 'Actualiser';

  @override
  String codeProviderModelsCount(String count) {
    return '$count modèles disponibles';
  }

  @override
  String get codeProviderModelsRefresh => 'Actualiser la liste des modèles';

  @override
  String get codeProviderChooseModel => 'Choisir un modèle';

  @override
  String codeProviderModelsLive(String provider) {
    return 'Récupérés en direct depuis $provider';
  }

  @override
  String get codeAgentTitle => 'Agent';

  @override
  String get codeAgentPermissionTitle => 'Quand l’agent agit';

  @override
  String get codeAgentAsk => 'Tout demander d’abord';

  @override
  String get codeAgentAskSub =>
      'Chaque commande et chaque écriture de fichier attend ton feu vert.';

  @override
  String get codeAgentEdits =>
      'Écrire les fichiers, demander pour les commandes';

  @override
  String get codeAgentEditsSub =>
      'Les fichiers sont écrits au fil de l’eau. Les commandes attendent ton feu vert.';

  @override
  String get codeAgentAuto => 'Tout exécuter';

  @override
  String get codeAgentAutoSub =>
      'Rien n’attend ton feu vert. Les commandes restent dans le dossier du projet.';

  @override
  String get codeAgentSteps => 'Étapes par demande';

  @override
  String get codeAgentStepsSub =>
      'Combien d’actions l’agent peut faire avant de s’arrêter et de demander à continuer.';

  @override
  String get codeAgentStepsAuto => 'Automatique';

  @override
  String codeAgentStepsValue(String count) {
    return '$count étapes';
  }

  @override
  String get codeAgentNetwork => 'Autoriser les commandes réseau';

  @override
  String get codeAgentNetworkSub =>
      'Permet à des commandes comme curl d’accéder à Internet. Désactivé, ton projet ne peut pas être envoyé par erreur.';

  @override
  String get codeAgentTimeout => 'Durée maximale des commandes';

  @override
  String codeAgentTimeoutValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get codeSandboxNote =>
      'Les commandes s’exécutent dans un dossier privé de ce téléphone, avec l’identité de l’app et une durée limitée. Ce n’est pas un système Linux complet : il n’y a ni python, ni git, ni compilateur, et rien ne peut être installé.';

  @override
  String get codeWorkspaceTitle => 'Dossiers de projet';

  @override
  String codeWorkspaceUsed(String size, String count) {
    return '$size dans $count dossiers de projet';
  }

  @override
  String get codeWorkspaceClear => 'Supprimer tous les fichiers de projet';

  @override
  String get codeWorkspaceClearTitle =>
      'Supprimer tous les fichiers de projet ?';

  @override
  String get codeWorkspaceClearBody =>
      'Le dossier de projet de chaque session est vidé. Les conversations restent.';

  @override
  String get codeDataTitle => 'Confidentialité et données';

  @override
  String get codeDataNote =>
      'Les sessions et les fichiers de projet sont stockés dans l’espace privé de cette app sur ton téléphone. Les clés API sont conservées dans le stockage sécurisé du système. Avec FinnAI sur cet appareil, rien ne quitte le téléphone.';

  @override
  String get codeDataDelete => 'Supprimer les données de FinnAI Code';

  @override
  String get codeDataDeleteSub =>
      'Sessions, fichiers de projet, clés enregistrées et réglages';

  @override
  String get codeDataDeleteTitle => 'Supprimer les données de FinnAI Code ?';

  @override
  String get codeDataDeleteBody =>
      'Toutes les sessions, tous les dossiers de projet, toutes les clés enregistrées et tous les réglages de Code sont supprimés. Les chats FinnAI ne sont pas touchés.';

  @override
  String get codeDataDeleted => 'Données de FinnAI Code supprimées.';

  @override
  String get codeAboutBody =>
      'FinnAI Code est un agent de programmation. Il fonctionne avec le modèle de ton téléphone ou avec tes propres clés de fournisseur, et peut lire et écrire des fichiers dans un dossier de projet privé et y exécuter des commandes simples.';

  @override
  String get codeFilesEmpty =>
      'Aucun fichier pour l’instant. Demande à l’agent de créer quelque chose.';

  @override
  String get codeFilesNoSession =>
      'Démarre une session pour obtenir un dossier de projet.';

  @override
  String get codeFileCopy => 'Copier';

  @override
  String get codeFileCopied => 'Copié';

  @override
  String get codeFileDelete => 'Supprimer le fichier';

  @override
  String codeFileDeleteTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get codeFileEmpty => 'Ce fichier est vide.';

  @override
  String get codeTerminalHint => 'Exécuter une commande';

  @override
  String get codeTerminalIntro =>
      'S’exécute dans le dossier de projet de cette session.';

  @override
  String get codeTerminalUnsupported =>
      'Les commandes ne peuvent pas s’exécuter sur cet appareil.';

  @override
  String get codeTerminalClear => 'Effacer';

  @override
  String get codeErrorMalformedAction =>
      'Le modèle a écrit une action inutilisable, rien n’a donc été exécuté.';

  @override
  String get codeCloudTitleCustom => 'Utiliser ce serveur ?';

  @override
  String codeCloudBodyCustom(String address) {
    return 'Ce que tu écris, ainsi que le contenu des fichiers et la sortie des commandes lus par l’agent, est envoyé à $address. FinnAI sur cet appareil garde tout sur le téléphone.';
  }

  @override
  String get codeCloudConfirmCustom => 'Utiliser ce serveur';

  @override
  String get windowMinimize => 'Réduire';

  @override
  String get windowMaximize => 'Agrandir';

  @override
  String get windowRestore => 'Restaurer';

  @override
  String get onboardingGetStarted => 'Commencer';
}
