// lib/services/agent_pipeline.dart
//
// Replaces PlannerPipeline.
// Wraps AgentService with ChangeNotifier for Flutter UI.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'agent_service.dart';

enum AgentPipelineStatus { idle, downloading, ready, thinking, error }

class AgentPipelineState {
  final AgentPipelineStatus status;
  final String statusMessage;
  final double? downloadProgress;

  const AgentPipelineState({
    required this.status,
    this.statusMessage = '',
    this.downloadProgress,
  });

  static const initial = AgentPipelineState(
    status: AgentPipelineStatus.idle,
    statusMessage: 'Starting...',
  );
}

class AgentPipeline extends ChangeNotifier {
  final AgentService _service = AgentService();

  AgentPipelineState _state = AgentPipelineState.initial;
  AgentPipelineState get state => _state;
  bool get isReady => _state.status == AgentPipelineStatus.ready;

  Future<void> initialize() async {
    _update(const AgentPipelineState(
      status: AgentPipelineStatus.downloading,
      statusMessage: 'Downloading models...',
    ));

    try {
      await _service.initialize(
        onProgress: (progress, status, isError) {
          if (isError) {
            _update(AgentPipelineState(
              status: AgentPipelineStatus.error,
              statusMessage: status,
            ));
          } else {
            _update(AgentPipelineState(
              status: AgentPipelineStatus.downloading,
              statusMessage: status,
              downloadProgress: progress,
            ));
          }
        },
      );
      _update(const AgentPipelineState(
        status: AgentPipelineStatus.ready,
        statusMessage: 'Ready.',
      ));
    } catch (e) {
      _update(AgentPipelineState(
        status: AgentPipelineStatus.error,
        statusMessage: 'Init failed: $e',
      ));
    }
  }

  Future<AgentResponse> process(String userMessage) async {
    _update(const AgentPipelineState(
      status: AgentPipelineStatus.thinking,
      statusMessage: 'Thinking...',
    ));
    try {
      final response = await _service.process(userMessage);
      _update(const AgentPipelineState(
        status: AgentPipelineStatus.ready,
        statusMessage: 'Ready.',
      ));
      return response;
    } catch (e) {
      _update(AgentPipelineState(
        status: AgentPipelineStatus.error,
        statusMessage: 'Error: $e',
      ));
      rethrow;
    }
  }

  void clearContext() => _service.clearContext();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _update(AgentPipelineState s) {
    _state = s;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}
