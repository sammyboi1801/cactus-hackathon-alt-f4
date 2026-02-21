// lib/services/planner/planner_output_parser.dart

import 'dart:convert';
import 'planner_intent_types.dart';

class PlannerOutputParser {

  static PlannerOutput? tryParse(String rawOutput) {
    print(rawOutput);
    final stripped = _stripThinkTags(rawOutput);
    final extracted = _extractJsonString(stripped);
    if (extracted == null) return null;

    try {
      final decoded = jsonDecode(extracted);
      if (decoded is! Map<String, dynamic>) return null;
      _validateSchema(decoded);
      return PlannerOutput.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }

  /// Removes Qwen3 <think>...</think> reasoning blocks entirely.
  /// Also strips <|im_end|> and <end_of_turn> tokens.
  static String _stripThinkTags(String raw) {
    // Remove <think> ... </think> blocks (including multiline)
    var result = raw.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    // Remove any leftover control tokens
    result = result.replaceAll(RegExp(r'<\|im_end\|>|<end_of_turn>|<\|im_start\|>\w*'), '');
    return result.trim();
  }

  static String? _extractJsonString(String raw) {
    final trimmed = raw.trim();

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final fenceMatch = fencePattern.firstMatch(trimmed);
    if (fenceMatch != null) {
      final inner = fenceMatch.group(1)?.trim();
      if (inner != null && inner.startsWith('{')) return inner;
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start != -1 && end > start) return trimmed.substring(start, end + 1);

    return null;
  }

  static void _validateSchema(Map<String, dynamic> json) {
    const required = ['intent', 'reasoning_summary', 'chat_response',
                      'candidate_tools', 'arguments'];
    for (final key in required) {
      if (!json.containsKey(key)) throw FormatException('Missing key: $key');
    }
    if (json['candidate_tools'] is! List) throw FormatException('candidate_tools must be a List');
    if (json['arguments'] is! Map) throw FormatException('arguments must be a Map');
  }

  static PlannerOutput buildFallback({String? rawOutput}) {
    return const PlannerOutput(
      intent: PlannerIntent.unclear,
      reasoningSummary: 'Parser failed.',
      chatResponse: 'Sorry, something went wrong. Please try again.',
      candidateTools: [],
      arguments: {},
      confidence: 0.0,
    );
  }
}