// lib/services/planner/planner_intent_types.dart

/// All intents the Planner can classify.
/// Maps 1:1 with the intent strings in the system prompt.
enum PlannerIntent {
  fileSearch,
  photoSearch,
  automation,
  calendarQuery,
  contactLookup,
  clipboardAction,
  generalQuestion,
  unclear,
}

/// The structured output contract between Stage 1 (Planner) → Stage 2 (FunctionGemma).
/// Every field is required. No nulls escape this class.
class PlannerOutput {
  final PlannerIntent intent;

  /// Internal reasoning — sent to Stage 2 for context, not shown to user.
  final String reasoningSummary;

  /// The user-facing reply. Shown immediately in the chat UI before Stage 2 runs.
  final String chatResponse;

  /// Tool names from ToolRegistry. Stage 2 picks one from this list.
  final List<String> candidateTools;

  /// Pre-extracted arguments. Stage 2 may refine these.
  final Map<String, dynamic> arguments;

  /// Model's self-reported confidence. Used for routing decisions.
  final double confidence;

  const PlannerOutput({
    required this.intent,
    required this.reasoningSummary,
    required this.chatResponse,
    required this.candidateTools,
    required this.arguments,
    required this.confidence,
  });

  /// If false, skip Stage 2 entirely and return chatResponse to UI directly.
  bool get requiresToolExecution => candidateTools.isNotEmpty;

  /// Deserialize from model JSON output.
  factory PlannerOutput.fromJson(Map<String, dynamic> json) {
    return PlannerOutput(
      intent: _parseIntent(json['intent'] as String? ?? 'unclear'),
      reasoningSummary: json['reasoning_summary'] as String? ?? '',
      chatResponse: json['chat_response'] as String? ?? 'Let me help you with that.',
      candidateTools: List<String>.from(json['candidate_tools'] as List? ?? []),
      arguments: Map<String, dynamic>.from(json['arguments'] as Map? ?? {}),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// Serialize — used when passing to Stage 2 as context.
  Map<String, dynamic> toJson() => {
    'intent': _intentToString(intent),
    'reasoning_summary': reasoningSummary,
    'chat_response': chatResponse,
    'candidate_tools': candidateTools,
    'arguments': arguments,
    'confidence': confidence,
  };

  static PlannerIntent _parseIntent(String raw) {
    const map = {
      'file_search': PlannerIntent.fileSearch,
      'photo_search': PlannerIntent.photoSearch,
      'automation': PlannerIntent.automation,
      'calendar_query': PlannerIntent.calendarQuery,
      'contact_lookup': PlannerIntent.contactLookup,
      'clipboard_action': PlannerIntent.clipboardAction,
      'user_question': PlannerIntent.generalQuestion,
      'unclear': PlannerIntent.unclear,
    };
    return map[raw] ?? PlannerIntent.unclear;
  }

  static String _intentToString(PlannerIntent intent) {
    const map = {
      PlannerIntent.fileSearch: 'file_search',
      PlannerIntent.photoSearch: 'photo_search',
      PlannerIntent.automation: 'automation',
      PlannerIntent.calendarQuery: 'calendar_query',
      PlannerIntent.contactLookup: 'contact_lookup',
      PlannerIntent.clipboardAction: 'clipboard_action',
      PlannerIntent.generalQuestion: 'user_question',
      PlannerIntent.unclear: 'unclear',
    };
    return map[intent] ?? 'unclear';
  }

  @override
  String toString() =>
      'PlannerOutput(intent: $intent, tools: $candidateTools, confidence: $confidence)';
}
