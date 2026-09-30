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
      'Posez-moi toutes vos questions — je fonctionne entièrement sur cet appareil, vos\nconversations ne quittent jamais votre téléphone.';

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
  String get settingsInferenceEngineValue => 'Entièrement sur ce téléphone';

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
      'Finn lit les réponses à voix haute en mode vocal. La transcription de votre voix est traitée par la reconnaissance vocale de votre appareil, qui peut avoir besoin d\'internet.';

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
  String get flowsNewSkill => 'Nouvelle flow';

  @override
  String get flowsNoSkills =>
      'Aucune flow personnalisée pour l\'instant. Créez-en une pour un flux de travail répétitif.';

  @override
  String get flowsInstructionHint =>
      'Écrivez une instruction réutilisable que Finn doit appliquer si nécessaire.';

  @override
  String get flowsDeleteTitle => 'Supprimer cette flow ?';

  @override
  String flowsDeleteBody(String name) {
    return '« $name » sera supprimé de cet appareil.';
  }

  @override
  String get flowsLimitReached =>
      'Limite de flows atteinte (4). Supprimez-en une pour en ajouter une autre.';

  @override
  String get flowsNameLabel => 'Nom de la flow';

  @override
  String get flowsInstructionLabel => 'Instruction';

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
  String get flowsBuiltForFinn => 'Conçu pour Finn';

  @override
  String get flowsBuiltForFinnSubtitle =>
      'Activez uniquement ce dont vous avez besoin pour chaque type de travail.';

  @override
  String get flowsYourSkills => 'Vos Flows';

  @override
  String get flowsYourSkillsSubtitle =>
      'Créez des instructions réutilisables pour vos propres flux de travail.';

  @override
  String get flowsNoneActive => 'Aucun Flow actif';

  @override
  String flowsActiveCount(int count) {
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
  String get flowsEditTitle => 'Modifier le Flow';

  @override
  String get flowsEditorName => 'Nom';

  @override
  String get flowsEditorNameHint => 'Que fait ce Flow ?';

  @override
  String get flowsEditorDescription => 'Brève description';

  @override
  String get flowsEditorDescriptionHint => 'Un petit rappel pour vous';

  @override
  String get flowsEditorInstructions => 'Instructions';

  @override
  String get flowsEditorInstructionsHint =>
      'Dites à Finn comment aborder ce type de tâche';

  @override
  String get flowsCategoryWriting => 'Rédaction';

  @override
  String get flowsCategoryDevelopment => 'Développement';

  @override
  String get flowsCategoryLearning => 'Apprentissage';

  @override
  String get flowsCategoryPlanning => 'Planification';

  @override
  String get flowsCategoryCustom => 'Personnalisé';

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
}
