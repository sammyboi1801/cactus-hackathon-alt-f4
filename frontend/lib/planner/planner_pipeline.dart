// lib/services/planner/planner_pipeline.dart
//
// Simplified pipeline — runs PlannerService directly (no Isolate).
// The Isolate was causing progress callbacks to be missed because
// onDownloadProgress was assigned after start() had already begun.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'planner_intent_types.dart';
import 'planner_service.dart';

enum PlannerPipelineStatus {
  idle,
  downloading,
  initializing,
  ready,
  planning,
  error,
}

class PlannerPipelineState {
  final PlannerPipelineStatus status;
  final String statusMessage;
  final double? downloadProgress;

  const PlannerPipelineState({
    required this.status,
    this.statusMessage = '',
    this.downloadProgress,
  });

  static const initial = PlannerPipelineState(
    status: PlannerPipelineStatus.idle,
    statusMessage: 'Starting...',
  );
}

class PlannerPipelineResult {
  final String chatResponse;
  final PlannerOutput plannerOutput;
  const PlannerPipelineResult({
    required this.chatResponse,
    required this.plannerOutput,
  });
}

class PlannerPipeline extends ChangeNotifier {
  final PlannerService _service = PlannerService();

  PlannerPipelineState _state = PlannerPipelineState.initial;
  PlannerPipelineState get state => _state;

  Future<void> initialize() async {
    _update(const PlannerPipelineState(
      status: PlannerPipelineStatus.downloading,
      statusMessage: 'Connecting...',
    ));

    try {
      await _service.initialize(
        onDownloadProgress: (progress, statusMsg, isError) {
          if (isError) {
            _update(PlannerPipelineState(
              status: PlannerPipelineStatus.error,
              statusMessage: statusMsg,
            ));
          } else {
            _update(PlannerPipelineState(
              status: PlannerPipelineStatus.downloading,
              statusMessage: statusMsg,
              downloadProgress: progress,
            ));
          }
        },
      );

      _update(const PlannerPipelineState(
        status: PlannerPipelineStatus.ready,
        statusMessage: 'Assistant ready.',
      ));
    } catch (e) {
      _update(PlannerPipelineState(
        status: PlannerPipelineStatus.error,
        statusMessage: 'Init failed: $e',
      ));
    }
  }

  Future<PlannerPipelineResult> plan(String userMessage) async {
    if (_state.status != PlannerPipelineStatus.ready) {
      throw StateError('Planner not ready: ${_state.status}');
    }

    _update(const PlannerPipelineState(
      status: PlannerPipelineStatus.planning,
      statusMessage: 'Thinking...',
    ));

    try {
      final output = await _service.plan(userMessage);
      _update(const PlannerPipelineState(
        status: PlannerPipelineStatus.ready,
        statusMessage: 'Assistant ready.',
      ));
      return PlannerPipelineResult(
        chatResponse: output.chatResponse,
        plannerOutput: output,
      );
    } catch (e) {
      _update(PlannerPipelineState(
        status: PlannerPipelineStatus.error,
        statusMessage: 'Planning failed: $e',
      ));
      rethrow;
    }
  }

  void clearContext() => _service.clearContext();
  bool get isReady => _state.status == PlannerPipelineStatus.ready;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _update(PlannerPipelineState newState) {
    _state = newState;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}