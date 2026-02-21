// lib/services/planner/planner_isolate_runner.dart
//
// Runs the PlannerService in a separate Dart Isolate to prevent
// model inference from blocking the Flutter UI thread.
//
// Architecture:
//   Main Isolate (UI) ──SendPort──▶ Planner Isolate
//                     ◀──SendPort── Planner Isolate
//
// The Planner Isolate owns the CactusLM instance for its entire lifetime.
// Communication is via message passing (no shared memory).

import 'dart:async';
import 'dart:isolate';
import 'planner_service.dart';
import 'planner_intent_types.dart';

// ---------------------------------------------------------------------------
// Messages (plain classes — must be sendable across Isolate boundary)
// ---------------------------------------------------------------------------

/// Sent from main isolate → planner isolate to request a plan.
class PlanRequestMessage {
  final String userMessage;
  final String requestId; // correlate responses to requests
  const PlanRequestMessage({
    required this.userMessage,
    required this.requestId,
  });
}

/// Sent from planner isolate → main isolate with the result.
class PlanResponseMessage {
  final String requestId;
  final Map<String, dynamic>? outputJson; // null means failure
  final String? errorMessage;

  const PlanResponseMessage({
    required this.requestId,
    this.outputJson,
    this.errorMessage,
  });

  bool get isSuccess => outputJson != null;
}

/// Sent from main isolate → planner isolate for lifecycle control.
class PlannerControlMessage {
  final PlannerControlCommand command;
  const PlannerControlMessage({required this.command});
}

enum PlannerControlCommand { clearContext, dispose }

// ---------------------------------------------------------------------------
// Planner Isolate entry point
// ---------------------------------------------------------------------------

/// Entry point for the Planner Isolate.
/// This function runs in the spawned isolate — never in the main isolate.
Future<void> plannerIsolateEntry(SendPort mainSendPort) async {
  final receivePort = ReceivePort();

  // Send our receive port back to main so it can message us
  mainSendPort.send(receivePort.sendPort);

  final service = PlannerService();

  // Initialize — this downloads/loads the model inside the isolate
  await service.initialize(
    onDownloadProgress: (progress, status, isError) {
      // Forward download progress to main isolate
      mainSendPort.send({
        'type': 'download_progress',
        'progress': progress,
        'status': status,
        'isError': isError,
      });
    },
  );

  // Signal ready
  mainSendPort.send({'type': 'ready'});

  // Listen for messages from main isolate
  await for (final message in receivePort) {
    if (message is PlanRequestMessage) {
      try {
        final output = await service.plan(message.userMessage);
        mainSendPort.send(
          PlanResponseMessage(
            requestId: message.requestId,
            outputJson: output.toJson(),
          ),
        );
      } catch (e) {
        mainSendPort.send(
          PlanResponseMessage(
            requestId: message.requestId,
            errorMessage: e.toString(),
          ),
        );
      }
    } else if (message is PlannerControlMessage) {
      switch (message.command) {
        case PlannerControlCommand.clearContext:
          service.clearContext();
          break;
        case PlannerControlCommand.dispose:
          service.dispose();
          receivePort.close();
          return;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// PlannerIsolateRunner — used from the main isolate / UI layer
// ---------------------------------------------------------------------------

/// Manages the Planner Isolate lifecycle from the main isolate.
///
/// Usage:
///   final runner = PlannerIsolateRunner();
///   await runner.start();
///   final output = await runner.plan("Find my resume");
///   runner.stop();
class PlannerIsolateRunner {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  final _pendingRequests = <String, _PendingRequest>{};
  int _requestCounter = 0;

  // Callbacks for lifecycle events
  void Function(double? progress, String status, bool isError)?
  onDownloadProgress;
  void Function()? onReady;

  /// Spawn the isolate and wait for it to signal ready.
  Future<void> start() async {
    _receivePort = ReceivePort();

    _isolate = await Isolate.spawn(plannerIsolateEntry, _receivePort!.sendPort);

    // Wait for the isolate to send us its SendPort + ready signal
    await for (final message in _receivePort!) {
      if (message is SendPort) {
        _sendPort = message;
      } else if (message is Map && message['type'] == 'download_progress') {
        onDownloadProgress?.call(
          message['progress'] as double?,
          message['status'] as String,
          message['isError'] as bool,
        );
      } else if (message is Map && message['type'] == 'ready') {
        onReady?.call();
        break; // Done with setup, switch to normal message handling
      } else if (message is PlanResponseMessage) {
        _handleResponse(message);
      }
    }

    // Continue processing responses in background
    _receivePort!.listen((message) {
      if (message is PlanResponseMessage) {
        _handleResponse(message);
      }
    });
  }

  /// Send a user message to the planner and get back a PlannerOutput.
  Future<PlannerOutput> plan(String userMessage) async {
    final requestId = 'req_${_requestCounter++}';
    final completer = _PendingRequest();
    _pendingRequests[requestId] = completer;

    _sendPort!.send(
      PlanRequestMessage(userMessage: userMessage, requestId: requestId),
    );

    return completer.future;
  }

  /// Clear conversation context in the isolate.
  void clearContext() {
    _sendPort?.send(
      const PlannerControlMessage(command: PlannerControlCommand.clearContext),
    );
  }

  /// Shut down the isolate and free all resources.
  void stop() {
    _sendPort?.send(
      const PlannerControlMessage(command: PlannerControlCommand.dispose),
    );
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
  }

  void _handleResponse(PlanResponseMessage response) {
    final pending = _pendingRequests.remove(response.requestId);
    if (pending == null) return;

    if (response.isSuccess) {
      pending.complete(PlannerOutput.fromJson(response.outputJson!));
    } else {
      pending.completeError(
        Exception(response.errorMessage ?? 'Unknown planner error'),
      );
    }
  }
}

/// Internal: pairs a request ID with its Future completer.
class _PendingRequest {
  final Completer<PlannerOutput> _completer = Completer<PlannerOutput>();

  Future<PlannerOutput> get future => _completer.future;

  void complete(PlannerOutput output) => _completer.complete(output);
  void completeError(Object error) => _completer.completeError(error);
}
