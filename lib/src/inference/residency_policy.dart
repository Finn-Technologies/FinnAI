import 'dart:async';

import 'package:flutter/foundation.dart';

enum ModelResidencyLevel {
  unloaded,
  engineReady,
  basePrefixReady,
  conversationWarm,
}

enum MemoryReleaseTarget {
  inactiveConversationSessions,
  activeConversationSession,
  secondaryModelEngines,
  primaryModelEngine,
}

enum ResidencyLifecycleAction {
  keepResident,
  scheduleBackgroundRelease,
  releaseNow,
}

enum ResidencyLifecycleEvent {
  chatSwitch,
  sidebarOpen,
  pageTransition,
  generationComplete,
  inactive,
  paused,
  resumed,
  detached,
}

ResidencyLifecycleAction residencyActionFor(ResidencyLifecycleEvent event) =>
    switch (event) {
      ResidencyLifecycleEvent.paused =>
        ResidencyLifecycleAction.scheduleBackgroundRelease,
      ResidencyLifecycleEvent.detached => ResidencyLifecycleAction.releaseNow,
      _ => ResidencyLifecycleAction.keepResident,
    };

@immutable
class ConversationSessionCacheKey {
  const ConversationSessionCacheKey({
    required this.conversationId,
    required this.modelIdentity,
    required this.promptConfigurationHash,
  });

  final String conversationId;
  final String modelIdentity;
  final String promptConfigurationHash;

  @override
  bool operator ==(Object other) =>
      other is ConversationSessionCacheKey &&
      conversationId == other.conversationId &&
      modelIdentity == other.modelIdentity &&
      promptConfigurationHash == other.promptConfigurationHash;

  @override
  int get hashCode =>
      Object.hash(conversationId, modelIdentity, promptConfigurationHash);
}

@visibleForTesting
List<MemoryReleaseTarget> memoryPressureReleaseOrder() => const [
  MemoryReleaseTarget.inactiveConversationSessions,
  MemoryReleaseTarget.activeConversationSession,
  MemoryReleaseTarget.secondaryModelEngines,
  MemoryReleaseTarget.primaryModelEngine,
];

@immutable
class ThermalPolicy {
  const ThermalPolicy({
    required this.allowPrewarm,
    required this.batchThreadCeiling,
    required this.message,
  });

  final bool allowPrewarm;
  final int? batchThreadCeiling;
  final String? message;
}

ThermalPolicy thermalPolicyForStatus(int? status, double? headroom) {
  final constrained = (status ?? 0) >= 3 || (headroom ?? 0) >= .85;
  if (constrained) {
    return const ThermalPolicy(
      allowPrewarm: false,
      batchThreadCeiling: 4,
      message: 'Your device is hot, so local generation may start more slowly.',
    );
  }
  final warm = (status ?? 0) >= 2 || (headroom ?? 0) >= .65;
  return ThermalPolicy(
    allowPrewarm: !warm,
    batchThreadCeiling: warm ? 6 : null,
    message: warm
        ? 'Your device is warm, so local generation may start more slowly.'
        : null,
  );
}

/// Collapses callers onto one in-flight load and lets Send promote the exact
/// prewarm job instead of starting a competing model load.
class DeduplicatedLoadJob<K, V> {
  final Map<K, Future<V>> _jobs = {};

  Future<V> run(K key, Future<V> Function() load) {
    final existing = _jobs[key];
    if (existing != null) return existing;
    late final Future<V> tracked;
    tracked = load().whenComplete(() {
      if (identical(_jobs[key], tracked)) _jobs.remove(key);
    });
    _jobs[key] = tracked;
    return tracked;
  }

  bool contains(K key) => _jobs.containsKey(key);
  int get activeJobCount => _jobs.length;
}
