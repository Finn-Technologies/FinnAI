import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finn_ai/l10n/app_localizations.dart';
import 'package:finn_ai/src/features/chat/flow_wiring.dart';
import 'package:finn_ai/src/features/conversations/conversation_store.dart';
import 'package:finn_ai/src/features/flows/flows_store.dart';
import 'package:finn_ai/src/features/search/web_search_service.dart';
import 'package:finn_ai/src/inference/finn_inference.dart';
import 'package:finn_ai/src/platform/openharmony_path_provider.dart';
import 'package:finn_ai/src/shared/config/licenses.dart';

/// Entry point of the second, screenless Flutter engine that runs a flow when
/// the app is closed (see `FlowBackgroundRunner.kt`).
///
/// It does the same thing the app does for a flow something else started: load
/// the flows, run the one that was named with the stored grant, and say so if
/// it needs the user. It never shows UI.
@pragma('vm:entry-point')
Future<void> flowBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  OpenHarmonyPathProvider.registerIfNeeded();
  registerModelLicenses();

  const channel = MethodChannel('finn_ai/flow_background');
  channel.setMethodCallHandler((call) async {
    if (call.method != 'run') return null;
    final args = call.arguments as Map<Object?, Object?>;
    await runFlowInBackground(
      args['flowId']! as String,
      args['source'] as String? ?? 'schedule',
    );
    return null;
  });
  await channel.invokeMethod<void>('ready');
}

/// Runs one flow with no screen and reports whatever needs the user.
Future<void> runFlowInBackground(String flowId, String source) async {
  final store = FlowsStore.instance;
  await store.initialize();
  final flow = store.flows.where((f) => f.id == flowId).firstOrNull;
  if (flow == null || !flow.enabled || !flow.isAutomation) return;

  final conversations = ConversationStore.instance;
  final needsModel = flow.allBlocks.any((b) => b.kind == FlowBlockKind.ask);
  final needsChat =
      flow.allBlocks.any((b) => b.kind == FlowBlockKind.saveToChat);
  if (needsChat) await conversations.initialize();
  if (needsModel) await FinnInference.instance.initialize();

  final host = FlowHost(
    conversations: conversations,
    webSearch: WebSearchService(),
  );
  final run =
      await host.runner.run(flow, triggeredBy: source, background: true);
  await tellAboutFlowRun(host.scheduler, flow, run, _l10n());
}

AppLocalizations _l10n() => lookupAppLocalizations(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
