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

/// Queues native-engine operations that must never overlap on one runtime.
///
/// A failed operation does not poison the queue; the next operation can still
/// run and surface its own result.
class SerializedAsyncGate {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }
}
