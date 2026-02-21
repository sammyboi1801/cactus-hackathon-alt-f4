// lib/services/planner/planner_context_manager.dart

import 'dart:convert';

// Reference the ChatMessage class from the cactus package
// import 'package:cactus/cactus.dart';

/// Manages the sliding conversation history window for the Planner model.
///
/// IMPORTANT: Only the chat_response string is stored as assistant history,
/// NOT the full JSON. Feeding full JSON back as assistant turns causes the
/// model to try continuing JSON generation unprompted on the next turn.
class PlannerContextManager {
  /// Maximum number of complete turns (user + assistant) to keep in context.
  /// 6 turns = ~12 messages = ~400–600 tokens. Safe margin within 2048 context.
  static const int maxTurns = 6;

  final List<_TurnEntry> _history = [];

  /// Add a user message to history.
  void addUserMessage(String content) {
    _history.add(_TurnEntry(role: 'user', content: content));
    _trim();
  }

  /// Add the assistant reply to history.
  /// Extracts only chat_response from the planner JSON — not the full JSON.
  void addAssistantMessage(String plannerJsonOrText) {
    final content = _extractChatResponse(plannerJsonOrText);
    _history.add(_TurnEntry(role: 'assistant', content: content));
    _trim();
  }

  /// Returns the current history as ChatMessage-compatible maps.
  /// Cast to your ChatMessage constructor as needed.
  List<Map<String, String>> getMessageMaps() {
    return _history.map((e) => {'role': e.role, 'content': e.content}).toList();
  }

  /// Clears all history. Call between separate sessions (e.g., app restart).
  void clear() => _history.clear();

  /// Returns number of stored messages (not turns).
  int get messageCount => _history.length;

  /// Returns true if there is prior context to include.
  bool get hasHistory => _history.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Extract only the chat_response field from planner JSON.
  /// Falls back to the raw string if JSON parsing fails.
  String _extractChatResponse(String raw) {
    try {
      // Strip markdown fences if present
      final cleaned = raw.replaceAll(RegExp(r'```(?:json)?|```'), '').trim();
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      return decoded['chat_response'] as String? ?? raw;
    } catch (_) {
      // If it's not JSON, just store the raw string (shouldn't normally happen)
      return raw;
    }
  }

  /// Trim history to stay within maxTurns.
  /// Removes oldest messages first while ensuring we never split a turn pair.
  void _trim() {
    // Each turn = 1 user + 1 assistant = 2 messages
    final maxMessages = maxTurns * 2;
    while (_history.length > maxMessages) {
      _history.removeAt(0);
    }
  }
}

/// Internal turn representation.
class _TurnEntry {
  final String role;
  final String content;
  const _TurnEntry({required this.role, required this.content});
}
