part of '../finn_accelerator.dart';

extension FinnAcceleratorTurn on FinnAccelerator {
  Stream<String> _generateForModel(
    FinnModelSpec model,
    String prompt, {
    required String conversationId,
    required List<LocalChatTurn> history,
    String systemContext = '',
    String groundedContext = '',
    List<WebSource> sources = const [],
    PromptAnalysis? analysis,
    String? modelPath,
    TtftTrace? trace,
    IntentSamplerProfile? samplerProfile,
  }) {
    late StreamController<String> output;
    var nativeFinished = false;
    output = StreamController<String>(
      onListen: () async {
        _activeOutput = output;
        final generationEpoch = _generationEpoch;
        final runWatch = Stopwatch()..start();
        Duration? firstTokenAt;
        var emittedTokens = 0;
        final promptAnalysis =
            analysis ?? const PromptIntentClassifier().classify(prompt);
        final outputBudget = _outputBudget(promptAnalysis);
        _lastGenerationReport = GenerationReport(
          model: model,
          intent: promptAnalysis.intent,
          route: model.tier,
          outputBudget: outputBudget,
          // Native completion is the default. Explicit stopGeneration()
          // changes this to userCancellation synchronously.
          finishReason: GenerationFinishReason.eos,
          firstTokenLatency: null,
          totalGenerationTime: Duration.zero,
          outputTokens: 0,
          tokensPerSecond: 0,
        );
        try {
          if (modelPath == null && !await isInstalled(model)) {
            await install(model);
          }
          _throwIfGenerationCancelled(generationEpoch);
          final path = modelPath ?? (await _modelFile(model)).path;
          final alreadyResident = _runtimes.containsKey(model.tier);
          trace
            ?..modelTier = model.tier.name
            ..modelAlreadyResident = alreadyResident
            ..mark(TtftPhase.modelLoadRequested);
          await _ensureProjectorIfNeeded(model, history);
          final runtime = await _ensureLoaded(model, path);
          trace?.mark(TtftPhase.modelReady);
          _throwIfGenerationCancelled(generationEpoch);
          final combinedContext = [
            systemContext,
            groundedContext,
          ].where((s) => s.trim().isNotEmpty).join('\n\n');
          final prepared = await _prepareSession(
            runtime,
            conversationId,
            history,
            combinedContext,
            // Part of the session's identity: the task instruction is a system
            // block that lives in the KV cache for the session's whole life, so
            // an intent switch has to start a fresh session rather than append
            // a conflicting instruction over the resident one.
            taskInstruction: PromptIntentPolicy.taskInstruction(promptAnalysis),
          );
          trace
            ?..conversationSessionCacheHit = prepared.cacheHit
            ..basePrefixCacheHit = prepared.prefix.cacheHit
            ..prefixStateTokens = prepared.prefix.tokens
            ..prefixStateBytes = prepared.prefix.fileBytes
            ..prefixStatePreparationMicros =
                prepared.prefix.preparation.inMicroseconds
            ..prefixStateRestorationMicros =
                prepared.prefix.restoration.inMicroseconds
            ..prefixPromptTokensPerSecond =
                prepared.prefix.promptTokensPerSecond
            ..mark(TtftPhase.sessionReady);
          _throwIfGenerationCancelled(generationEpoch);
          final entry = prepared.entry;
          final session = entry.session;
          // Only the newest attachment is fed back as media, and the current
          // turn's own attachment always wins. When this turn has no
          // attachment, the newest earlier image is reused so a follow-up
          // about a photo still has its pixels after a session reset.
          //
          // Re-sending *every* historic image was what broke documents:
          // attaching a file after a photo left the old picture in front of
          // the model as media (with a media marker immediately before the
          // prompt), and a 1.6B model answered about the picture and ignored
          // the file it had just been handed.
          final latestAttachment = newestAttachmentTurn(history);
          final candidatePaths = <String>[];
          final candidateBytes = <Uint8List?>[];
          if (latestAttachment != null) {
            if (latestAttachment.imageBytes != null) {
              candidatePaths.add(latestAttachment.imagePath ?? 'memory');
              candidateBytes.add(latestAttachment.imageBytes);
            } else if (latestAttachment.imagePath != null) {
              candidatePaths.add(latestAttachment.imagePath!);
              candidateBytes.add(null);
            }
          }

          final mediaList = <LlamaMedia>[];
          final skippedHeicPaths = <String>[];
          for (var i = 0; i < candidatePaths.length; i++) {
            final path = candidatePaths[i];
            final bytes = candidateBytes[i];
            if (bytes != null) {
              final isHeic = FinnAccelerator._isHeicPath(path);
              if (isHeic) {
                skippedHeicPaths.add(path);
                debugPrint('FINN_HEIC skipped in-memory HEIC for $path');
                continue;
              }
              try {
                mediaList.add(LlamaMedia.imageBytes(bytes));
              } catch (e) {
                debugPrint('FINN_MEDIA imageBytes failed for $path: $e');
              }
            } else {
              final isHeic = FinnAccelerator._isHeicPath(path);
              final isImageExt = FinnAccelerator._isImageFile(path);
              if (!isImageExt && !isHeic) continue;
              try {
                final exists = await File(path).exists();
                if (!exists) continue;
                final fileBytes = await File(path).readAsBytes();
                // stb_image cannot decode HEIC; treat as skipped, not crash
                if (isHeic &&
                    !FinnAccelerator._bytesLookLikeImage(fileBytes, path)) {
                  skippedHeicPaths.add(path);
                  debugPrint(
                      'FINN_HEIC skipped HEIC at $path (stb_image unsupported)');
                  continue;
                }
                if (!FinnAccelerator._bytesLookLikeImage(fileBytes, path) &&
                    isHeic) {
                  skippedHeicPaths.add(path);
                  continue;
                }
                mediaList.add(LlamaMedia.imageBytes(fileBytes));
              } catch (e) {
                if (isHeic) {
                  skippedHeicPaths.add(path);
                  debugPrint('FINN_HEIC failed for $path: $e');
                } else {
                  debugPrint('FINN_MEDIA load failed for $path: $e');
                }
              }
            }
          }

          final hasAttachedImage = mediaList.isNotEmpty;
          final useMediaMarker =
              hasAttachedImage && runtime.engine.multimodalLoaded;
          // Cap at reasonable N for prompt token budget; native supports N
          final cappedMediaList =
              mediaList.length > 4 ? mediaList.sublist(0, 4) : mediaList;
          final effectiveMediaList = cappedMediaList;

          String? attachedDocContext;
          // A non-image attachment is read from disk and handed to the model as
          // a system block. Only the most recent one is used: the composer
          // holds a single attachment, so a later turn's file supersedes an
          // earlier turn's.
          final docPath = history.reversed
              .where((t) => t.imagePath != null && t.imagePath!.isNotEmpty)
              .firstOrNull
              ?.imagePath;
          if (docPath != null &&
              !FinnAccelerator._isImageFile(docPath) &&
              !FinnAccelerator._isHeicPath(docPath)) {
            final docName = docPath.split(Platform.pathSeparator).last;
            try {
              final content = await File(docPath).readAsString();
              final truncated = content.length > 4000
                  ? '${content.substring(0, 4000)}\n[... content truncated]'
                  : content;
              attachedDocContext =
                  'Attached document ($docName):\n```\n$truncated\n```';
              debugPrint('FINN_DOC attached=$docName chars=${content.length}');
            } catch (e) {
              // The picker hands back a cache copy, so the path can be gone by
              // the time the turn is generated — or after a restart. Doing
              // nothing here is what made an attached document look ignored:
              // the reply arrived with no sign the file was ever missing.
              debugPrint('FINN_DOC unreadable path=$docPath error=$e');
              attachedDocContext =
                  'Note: the user attached "$docName" but it could not be read '
                  'on this device. Tell them the attachment is unavailable and '
                  'ask them to attach it again.';
            }
          }
          if (skippedHeicPaths.isNotEmpty && !useMediaMarker) {
            final heicNote =
                'Note: ${skippedHeicPaths.length} HEIC image(s) could not be decoded on this device (unsupported format). Ask the user to share as JPEG/PNG.';
            final previousContext = attachedDocContext;
            attachedDocContext =
                (previousContext == null || previousContext.isEmpty)
                    ? heicNote
                    : '$previousContext\n\n$heicNote';
          }

          final taskInstruction = PromptIntentPolicy.taskInstruction(
            promptAnalysis,
          );
          final includeTaskInstruction =
              !entry.primed || entry.lastTaskInstruction != taskInstruction;
          // This runtime is intentionally single-model (LFM2.5-VL 1.6B). Its
          // non-thinking ChatML template
          // needs an empty reasoning block to avoid hidden-chain generation
          // while keeping everyday replies fast.
          const primeEmptyThinking = true;
          var renderedPrompt = _renderPrompt(
            entry,
            prompt,
            history,
            systemContext: systemContext,
            groundedContext: groundedContext,
            analysis: promptAnalysis,
            includeTaskInstruction: includeTaskInstruction,
            primeEmptyThinking: primeEmptyThinking,
            includeMediaMarker: useMediaMarker,
            mediaCount: useMediaMarker ? effectiveMediaList.length : 0,
            attachedDocContext: attachedDocContext,
          );
          // The token-breakdown re-renders the prompt a second time purely
          // for diagnostics. Skip it (and the full-prompt log) in release
          // builds: it is duplicate prefill-side work on every generation,
          // and the full prompt must never reach production logs.
          if (!kReleaseMode) {
            final promptBreakdown = promptTokenBreakdownForTest(
              prompt: prompt,
              history: history,
              systemContext: combinedContext,
              primed: entry.primed,
              basePrefixReady: entry.basePrefixReady,
              includeTaskInstruction: includeTaskInstruction,
              primeEmptyThinking: primeEmptyThinking,
            );
            debugPrint('FINN_PROMPT ${jsonEncode(promptBreakdown)}');
          }
          final profile = _deviceProfile;
          final plan = _plan;
          trace
            ?..promptTokenCount = (renderedPrompt.length / 3.2).ceil()
            ..availableRamBytes = profile?.availableRamBytes
            ..lowMemory = profile?.lowMemory ?? false
            ..threads = plan?.threads
            ..batchThreads = plan?.batchThreads
            ..batchSize = plan?.batchSize
            ..microBatchSize = plan?.microBatchSize
            ..kvType = runtime.compactKv ? runtime.kvType.name : 'f16'
            ..flashAttention = plan?.flashAttention == true ? 'on' : 'off'
            ..mark(TtftPhase.promptRendered);

          // If multimodal not loaded but user attached image, surface fallback
          if (hasAttachedImage && !runtime.engine.multimodalLoaded) {
            debugPrint(
                'FINN_MEDIA fallback: multimodal not loaded, answering without image');
            // Inject a system note so answer acknowledges missing vision capability
            final fallbackNote =
                'Note: The user attached ${effectiveMediaList.length} image(s) but the image component is not installed. Explain that image analysis is unavailable on this device and ask them to describe the image or install the image component.';
            final previousContext = attachedDocContext;
            attachedDocContext =
                (previousContext == null || previousContext.isEmpty)
                    ? fallbackNote
                    : '$previousContext\n\n$fallbackNote';
            // Re-render without media marker so text path still works
            renderedPrompt = _renderPrompt(
              entry,
              prompt,
              history,
              systemContext: systemContext,
              groundedContext: groundedContext,
              analysis: promptAnalysis,
              includeTaskInstruction: includeTaskInstruction,
              primeEmptyThinking: primeEmptyThinking,
              includeMediaMarker: false,
              mediaCount: 0,
              attachedDocContext: attachedDocContext,
            );
          }
          // HEIC graceful fallback: if we had skipped HEICs, note it
          if (skippedHeicPaths.isNotEmpty &&
              effectiveMediaList.isEmpty &&
              hasAttachedImage == false) {
            // Already noted in attachedDocContext above
          }
          _setStatus(
            InferencePhase.generating,
            'Thinking on this device',
            key: FinnStatusKey.thinkingOnDevice,
          );
          // Structural, content-free diagnostics. The prompt text itself is
          // never logged outside debug builds (see the breakdown guard above),
          // and neither is this: it only says which prompt shape was used, so a
          // mis-shaped turn can be diagnosed from a device log alone.
          debugPrint(
            'FINN_PROMPT primed=${entry.primed} '
            'basePrefix=${entry.basePrefixReady} '
            'media=${(hasAttachedImage && runtime.engine.multimodalLoaded) ? effectiveMediaList.length : 0} '
            'docChars=${attachedDocContext?.length ?? 0} '
            'historyTurns=${history.length} '
            'promptChars=${renderedPrompt.length}',
          );
          trace?.mark(TtftPhase.generationRequested);
          var attemptId = 0;
          var retryBudget = 1;
          var visibleEmitted = 0;
          StreamSubscription<GenerationEvent> attempt(
            String promptText, {
            required bool addSpecial,
            required int id,
          }) =>
              session
                  .generate(
                prompt: promptText,
                addSpecial: addSpecial,
                parseSpecial: true,
                maxTokens: outputBudget,
                media: (hasAttachedImage && runtime.engine.multimodalLoaded)
                    ? effectiveMediaList
                    : const <LlamaMedia>[],
                shiftPolicy:
                    runtime.engine.canShift && effectiveMediaList.isEmpty
                        ? ContextShiftPolicy.auto
                        : ContextShiftPolicy.off,
                shift: ContextShift(
                  nKeep: entry.basePrefixReady ? 321 : 0,
                ),
                sampler: (samplerProfile ??
                        PromptIntentPolicy.sampler(promptAnalysis.intent))
                    .params
                    .copyWith(seed: _nextGenerationSeed()),
              )
                  .listen(
                (event) {
                  if (generationEpoch != _generationEpoch) return;
                  if (event case TokenEvent(:final text)) {
                    emittedTokens++;
                    trace?.mark(TtftPhase.nativeToken);
                    if (text.isNotEmpty && firstTokenAt == null) {
                      firstTokenAt = runWatch.elapsed;
                      if (PerfLogSampler.sample()) {
                        debugPrint(
                          'FINN_PERF first_token_ms=${firstTokenAt!.inMilliseconds} '
                          'model=${model.tier.name} '
                          'ctx=${_plan?.contextSize} threads=${_plan?.threads}',
                        );
                      }
                    }
                    if (text.isNotEmpty) {
                      visibleEmitted++;
                      output.add(text);
                    }
                  } else if (event
                      case DoneEvent(
                        :final trailingText,
                        :final generatedCount,
                        :final reason,
                      )) {
                    // A reply that ended at once with nothing visible is a rare
                    // native hiccup (the eval saw one in ~40 turns, on a greeting).
                    // One fresh attempt on a cleared session is cheap and turns a
                    // silent empty turn into an answer; a second empty result is
                    // reported as it is.
                    if (retryBudget > 0 &&
                        visibleEmitted == 0 &&
                        trailingText.isEmpty &&
                        finishReasonFromStopReason(reason) ==
                            GenerationFinishReason.eos) {
                      retryBudget--;
                      attemptId++;
                      debugPrint('FINN_RETRY empty reply; retrying once');
                      unawaited(() async {
                        try {
                          await session.clear();
                          entry.primed = false;
                          entry.basePrefixReady = false;
                          emittedTokens = 0;
                          final again = _renderPrompt(
                            entry,
                            prompt,
                            history,
                            systemContext: systemContext,
                            groundedContext: groundedContext,
                            analysis: promptAnalysis,
                            includeTaskInstruction: true,
                            primeEmptyThinking: primeEmptyThinking,
                            includeMediaMarker: useMediaMarker,
                            mediaCount:
                                useMediaMarker ? effectiveMediaList.length : 0,
                            attachedDocContext: attachedDocContext,
                          );
                          if (generationEpoch != _generationEpoch) return;
                          _generation =
                              attempt(again, addSpecial: true, id: attemptId);
                        } catch (error, stack) {
                          output.addError(error, stack);
                          await output.close();
                        }
                      }());
                      return;
                    }
                    nativeFinished = true;
                    if (trailingText.isNotEmpty) output.add(trailingText);
                    final total = runWatch.elapsed;
                    final decodeMs = total.inMilliseconds -
                        (firstTokenAt?.inMilliseconds ?? total.inMilliseconds);
                    final decodeTokens = math.max(0, generatedCount - 1);
                    final tokensPerSecond =
                        decodeMs <= 0 ? 0.0 : decodeTokens * 1000 / decodeMs;
                    _lastGenerationReport = GenerationReport(
                      model: model,
                      intent: promptAnalysis.intent,
                      route: model.tier,
                      outputBudget: outputBudget,
                      finishReason: finishReasonFromStopReason(reason),
                      firstTokenLatency: firstTokenAt,
                      totalGenerationTime: total,
                      outputTokens: generatedCount,
                      tokensPerSecond: tokensPerSecond,
                    );
                    if (PerfLogSampler.sample()) {
                      final totalMs = total.inMilliseconds;
                      debugPrint(
                        'FINN_PERF done total_ms=$totalMs decode_ms=$decodeMs '
                        'tokens=$generatedCount emitted=$emittedTokens '
                        'tps=${tokensPerSecond.toStringAsFixed(2)}',
                      );
                    }
                  }
                },
                onError: (Object error, StackTrace stack) {
                  _lastGenerationReport = GenerationReport(
                    model: model,
                    intent: promptAnalysis.intent,
                    route: model.tier,
                    outputBudget: outputBudget,
                    finishReason: GenerationFinishReason.error,
                    firstTokenLatency: firstTokenAt,
                    totalGenerationTime: runWatch.elapsed,
                    outputTokens: emittedTokens,
                    tokensPerSecond: 0,
                  );
                  _setStatus(
                    InferencePhase.error,
                    _friendlyError(error),
                    key: FinnStatusKey.error,
                  );
                  output.addError(error, stack);
                  unawaited(output.close());
                  unawaited(_recoverAfterError());
                },
                onDone: () {
                  // A retried attempt owns the turn now; the first one just ended.
                  if (id != attemptId) return;
                  _generation = null;
                  if (identical(_activeOutput, output)) {
                    _activeOutput = null;
                  }
                  _lastSources = sources;
                  entry.primed = true;
                  entry.lastTaskInstruction = taskInstruction;
                  entry.messageCount = history.length + 2;
                  entry.lastUsed = ++runtime.useSequence;
                  _setStatus(
                    InferencePhase.idle,
                    'Generated locally',
                    key: FinnStatusKey.generatedLocally,
                  );
                  unawaited(output.close());
                },
                cancelOnError: true,
              );

          _generation = attempt(
            renderedPrompt,
            addSpecial: !entry.primed && !entry.basePrefixReady,
            id: attemptId,
          );
        } on _GenerationCancelled {
          if (identical(_activeOutput, output)) _activeOutput = null;
          if (!output.isClosed) await output.close();
        } catch (error, stack) {
          if (identical(_activeOutput, output)) _activeOutput = null;
          _lastGenerationReport = GenerationReport(
            model: model,
            intent: promptAnalysis.intent,
            route: model.tier,
            outputBudget: outputBudget,
            finishReason: GenerationFinishReason.error,
            firstTokenLatency: firstTokenAt,
            totalGenerationTime: runWatch.elapsed,
            outputTokens: emittedTokens,
            tokensPerSecond: 0,
          );
          _setStatus(
            InferencePhase.error,
            _friendlyError(error),
            key: FinnStatusKey.error,
          );
          output.addError(error, stack);
          await output.close();
          unawaited(_recoverAfterError());
        }
      },
      onCancel: () async {
        _generationEpoch++;
        if (!nativeFinished) _markCancelled();
        await _generation?.cancel();
        _generation = null;
        if (identical(_activeOutput, output)) _activeOutput = null;
        if (_phase == InferencePhase.generating ||
            _phase == InferencePhase.loading) {
          _setStatus(
            InferencePhase.idle,
            'Stopped',
            key: FinnStatusKey.stopped,
          );
        }
      },
    );
    return output.stream;
  }
}
