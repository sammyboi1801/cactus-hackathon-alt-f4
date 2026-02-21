# Stage 1 — Planner Model: Complete Implementation Strategy

## Local-First Android Flutter Agent · Cactus Compute SDK

---

## 1. Model Selection Recommendation

### Use qwen3-0.6, NOT 0.6B

| Factor           | Qwen3-0.6B                  | qwen3-0.6                   |
| ---------------- | --------------------------- | --------------------------- |
| JSON reliability | Unstable on complex outputs | Solid with proper prompting |
| Intent reasoning | Shallow                     | Multi-hop capable           |
| RAM usage        | ~500MB                      | ~1.2GB                      |
| Verdict          | Demo only                   | Production-ready            |

The Planner's entire job is **structured JSON output + intent classification**. A single malformed JSON breaks the entire pipeline. The 1.7B model's extra capacity pays for itself in reliability. If RAM is critically constrained, use 0.6B but add a JSON repair layer (see Section 5).

---

## 2. Planner Responsibilities (Strict Boundary)

The Planner ONLY does:

1. Classify user intent
2. Produce a `chat_response` (the user-facing conversational reply)
3. Identify `candidate_tools` (names only, no execution)
4. Extract `arguments` (parameters the tool will need)
5. Emit structured JSON — always, no exceptions

The Planner NEVER does:

- Execute any tool
- Call any Flutter platform channel
- Make decisions about WHICH tool to use (that is Stage 2's job)
- Hallucinate tool results

---

## 3. Dart Service Architecture

### File Structure

```
lib/
  services/
    planner/
      planner_service.dart         ← main entry point
      planner_prompt_builder.dart  ← system prompt + few-shot construction
      planner_output_parser.dart   ← JSON parsing + validation + repair
      planner_intent_types.dart    ← intent enums + schema definitions
      planner_context_manager.dart ← conversation history management
```

---

## 4. planner_intent_types.dart

```dart
// All possible intents the planner can classify
enum PlannerIntent {
  fileSearch,       // "find my resume"
  photoSearch,      // "photo near a tree"
  automation,       // "turn off wifi"
  calendarQuery,    // "what do I have tomorrow"
  contactLookup,    // "call mom"
  clipboardAction,  // "copy this text"
  generalQuestion,  // factual / conversational — no tools needed
  unclear,          // planner cannot determine intent
}

// The structured output contract between Planner → Stage 2
class PlannerOutput {
  final PlannerIntent intent;
  final String reasoningSummary;
  final String chatResponse;       // shown to user immediately
  final List<String> candidateTools;
  final Map<String, dynamic> arguments;
  final double confidence;         // 0.0–1.0 — your own scoring layer

  const PlannerOutput({
    required this.intent,
    required this.reasoningSummary,
    required this.chatResponse,
    required this.candidateTools,
    required this.arguments,
    required this.confidence,
  });

  // Convenience: does this output require Stage 2?
  bool get requiresToolExecution => candidateTools.isNotEmpty;

  factory PlannerOutput.fromJson(Map<String, dynamic> json) {
    return PlannerOutput(
      intent: _parseIntent(json['intent'] as String),
      reasoningSummary: json['reasoning_summary'] as String,
      chatResponse: json['chat_response'] as String,
      candidateTools: List<String>.from(json['candidate_tools'] ?? []),
      arguments: Map<String, dynamic>.from(json['arguments'] ?? {}),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

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
}
```

---

## 5. planner_prompt_builder.dart

This is the most important file. The system prompt IS your model's behavior.

```dart
class PlannerPromptBuilder {

  // The tool registry is injected so the prompt always reflects
  // available tools — no hardcoding tool names in the prompt
  final List<String> availableTools;

  PlannerPromptBuilder({required this.availableTools});

  String buildSystemPrompt() {
    final toolList = availableTools.join(', ');

    return '''
You are a planner agent running on an Android device. Your ONLY job is to understand the user's intent and produce a structured JSON plan.

RULES:
1. You MUST respond with ONLY valid JSON. No markdown, no explanation, no extra text.
2. You NEVER execute tools. You only suggest candidate tools.
3. candidate_tools must only contain tool names from this list: [$toolList]
4. If no tools are needed, candidate_tools must be an empty array [].
5. chat_response is the friendly message shown to the user. Keep it under 20 words.
6. confidence is a float from 0.0 to 1.0 reflecting how certain you are of the intent.

RESPONSE SCHEMA:
{
  "intent": "<one of: file_search | photo_search | automation | calendar_query | contact_lookup | clipboard_action | user_question | unclear>",
  "reasoning_summary": "<internal reasoning, 1 sentence>",
  "chat_response": "<user-facing message>",
  "candidate_tools": ["<tool_name>", ...],
  "arguments": { "<key>": "<value>", ... },
  "confidence": <float>
}

AVAILABLE TOOLS:
$toolList

${_buildFewShotExamples()}
''';
  }

  String _buildFewShotExamples() {
    return '''
EXAMPLES:

User: "Can you look for my most recent resume on my phone?"
Response:
{
  "intent": "file_search",
  "reasoning_summary": "User wants to locate a resume document from device storage, prioritizing recent files.",
  "chat_response": "On it! Searching your storage for recent resumes.",
  "candidate_tools": ["search_files_semantic", "search_files_recent"],
  "arguments": { "query": "resume", "priority": "recent", "mime_filter": "application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document" },
  "confidence": 0.95
}

User: "Show me a photo where I am standing near a tree"
Response:
{
  "intent": "photo_search",
  "reasoning_summary": "User wants a photo containing a tree and likely a person, semantic visual search required.",
  "chat_response": "Looking through your photos for one near a tree.",
  "candidate_tools": ["search_photos_semantic"],
  "arguments": { "query": "person standing near tree outdoor scenery", "limit": 5 },
  "confidence": 0.91
}

User: "Turn off WiFi and open the gallery app"
Response:
{
  "intent": "automation",
  "reasoning_summary": "User wants two sequential device actions: disable WiFi and launch gallery.",
  "chat_response": "Turning off WiFi and opening Gallery for you.",
  "candidate_tools": ["toggle_wifi", "open_app"],
  "arguments": { "wifi_state": false, "package_name": "com.android.gallery3d" },
  "confidence": 0.97
}

User: "Is February 28 the last day of February 2026?"
Response:
{
  "intent": "user_question",
  "reasoning_summary": "This is a factual calendar question answerable without any tools.",
  "chat_response": "Yes, February 28 is the last day of February 2026, since 2026 is not a leap year.",
  "candidate_tools": [],
  "arguments": {},
  "confidence": 0.99
}

User: "sdfksdf"
Response:
{
  "intent": "unclear",
  "reasoning_summary": "Input is unintelligible, cannot determine intent.",
  "chat_response": "Sorry, I did not understand that. Could you rephrase?",
  "candidate_tools": [],
  "arguments": {},
  "confidence": 0.1
}
''';
  }
}
```

### Why Few-Shot Examples Are Critical

Qwen3 at 1.7B will reliably replicate the JSON schema from examples. Without them, expect ~30% schema drift. The examples above cover all five major intent classes and the edge cases (unclear, no-tool question).

---

## 6. planner_output_parser.dart

Never trust raw model output. Always parse defensively.

````dart
import 'dart:convert';

class PlannerOutputParser {

  // Primary parse attempt
  static PlannerOutput? tryParse(String rawOutput) {
    final cleaned = _extractJson(rawOutput);
    if (cleaned == null) return null;

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      _validateSchema(json); // throws if invalid
      return PlannerOutput.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  // Strips any markdown fences, leading/trailing text
  static String? _extractJson(String raw) {
    // Model sometimes wraps in ```json ... ```
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final fenceMatch = fencePattern.firstMatch(raw);
    if (fenceMatch != null) return fenceMatch.group(1);

    // Try finding raw { ... } block
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start != -1 && end > start) {
      return raw.substring(start, end + 1);
    }
    return null;
  }

  // Hard schema validation — fail fast
  static void _validateSchema(Map<String, dynamic> json) {
    const required = ['intent', 'reasoning_summary', 'chat_response',
                      'candidate_tools', 'arguments'];
    for (final key in required) {
      if (!json.containsKey(key)) {
        throw FormatException('Missing required key: $key');
      }
    }

    if (json['candidate_tools'] is! List) {
      throw FormatException('candidate_tools must be a List');
    }
    if (json['arguments'] is! Map) {
      throw FormatException('arguments must be a Map');
    }
  }

  // Fallback: build a safe PlannerOutput when parsing fails
  static PlannerOutput buildFallback(String rawOutput) {
    return PlannerOutput(
      intent: PlannerIntent.unclear,
      reasoningSummary: 'Parser failed to extract structured output.',
      chatResponse: 'Sorry, something went wrong. Please try again.',
      candidateTools: [],
      arguments: {},
      confidence: 0.0,
    );
  }
}
````

---

## 7. planner_context_manager.dart

The Planner needs conversation history to handle follow-up messages like "find the newer one" (referring to a previous file search).

```dart
class PlannerContextManager {
  // Sliding window — keep last N turns in context
  static const int maxTurns = 6; // 3 user + 3 assistant = ~600 tokens

  final List<ChatMessage> _history = [];

  void addUserMessage(String content) {
    _history.add(ChatMessage(content: content, role: 'user'));
    _trim();
  }

  void addAssistantMessage(String plannerJson) {
    // Store only the chat_response for context, not full JSON
    // This prevents the model from being confused by its own JSON in history
    try {
      final parsed = jsonDecode(plannerJson);
      final chatResponse = parsed['chat_response'] as String;
      _history.add(ChatMessage(content: chatResponse, role: 'assistant'));
    } catch (_) {
      _history.add(ChatMessage(content: plannerJson, role: 'assistant'));
    }
    _trim();
  }

  List<ChatMessage> getMessages() => List.unmodifiable(_history);

  void _trim() {
    // Keep most recent maxTurns messages
    while (_history.length > maxTurns * 2) {
      _history.removeAt(0);
    }
  }

  void clear() => _history.clear();
}
```

**Key decision:** Only the `chat_response` string goes back into history, NOT the full JSON. If you feed the full JSON back as assistant history, Qwen3 starts trying to continue generating JSON in the next turn unprompted.

---

## 8. planner_service.dart — Main Orchestrator

```dart
class PlannerService {
  late CactusLM _lm;
  final PlannerContextManager _context = PlannerContextManager();
  late final PlannerPromptBuilder _promptBuilder;

  bool _isInitialized = false;

  // Inject available tool names at startup
  Future<void> initialize({required List<String> availableTools}) async {
    _lm = CactusLM(enableToolFiltering: false); // Planner does NOT use Cactus tool calling
    _promptBuilder = PlannerPromptBuilder(availableTools: availableTools);

    await _lm.downloadModel(model: 'qwen3-0.6');
    await _lm.initializeModel(
      params: CactusInitParams(
        model: 'qwen3-0.6',
        contextSize: 2048, // Sufficient for system prompt + 6-turn history + response
      ),
    );
    _isInitialized = true;
  }

  // Core method: process one user turn
  Future<PlannerOutput> plan(String userMessage) async {
    assert(_isInitialized, 'Call initialize() before plan()');

    _context.addUserMessage(userMessage);

    final messages = [
      ChatMessage(
        content: _promptBuilder.buildSystemPrompt(),
        role: 'system',
      ),
      ..._context.getMessages(),
    ];

    // Use non-streaming for Planner — we need the complete JSON
    final result = await _lm.generateCompletion(
      messages: messages,
      params: CactusCompletionParams(
        maxTokens: 350,           // JSON output is bounded — never needs more
        temperature: 0.1,         // LOW temperature: we want deterministic JSON
        stopSequences: ['\n\n\n', '<|im_end|>', '<end_of_turn>'],
      ),
    );

    if (!result.success) {
      return PlannerOutputParser.buildFallback('');
    }

    final parsed = PlannerOutputParser.tryParse(result.response);

    if (parsed == null) {
      // Optional: retry once with explicit repair instruction
      return await _retryWithRepair(result.response) ??
             PlannerOutputParser.buildFallback(result.response);
    }

    // Store assistant reply in context history
    _context.addAssistantMessage(result.response);

    return parsed;
  }

  // One retry: ask the model to fix its own broken JSON
  Future<PlannerOutput?> _retryWithRepair(String brokenOutput) async {
    final repairMessages = [
      ChatMessage(
        content: 'You output invalid JSON. Fix it. Output ONLY valid JSON, nothing else.',
        role: 'system',
      ),
      ChatMessage(
        content: 'Your previous output was:\n$brokenOutput\n\nFix it now.',
        role: 'user',
      ),
    ];

    final repairResult = await _lm.generateCompletion(
      messages: repairMessages,
      params: CactusCompletionParams(
        maxTokens: 350,
        temperature: 0.0, // zero temp on repair
      ),
    );

    if (!repairResult.success) return null;
    return PlannerOutputParser.tryParse(repairResult.response);
  }

  void dispose() {
    _lm.unload();
    _isInitialized = false;
  }
}
```

---

## 9. Model Routing Logic

```
User Message
     │
     ▼
PlannerService.plan()
     │
     ├── Builds: system_prompt + conversation_history + user_message
     │
     ▼
CactusLM (qwen3-0.6)
  temperature=0.1, maxTokens=350
     │
     ▼
PlannerOutputParser.tryParse()
     │
     ├── Parse OK → PlannerOutput
     │                   │
     │                   ├── requiresToolExecution == false
     │                   │         └── return chat_response to UI immediately
     │                   │
     │                   └── requiresToolExecution == true
     │                             └── pass PlannerOutput → Stage 2 (FunctionGemma)
     │
     └── Parse FAIL → _retryWithRepair()
                           │
                           ├── OK → PlannerOutput
                           └── FAIL → PlannerOutput.fallback (show error to user)
```

### Critical Routing Rule

If `candidateTools.isEmpty` → **skip Stage 2 entirely**. Return `chatResponse` directly to the UI. This keeps conversational exchanges fast (no second model invocation).

---

## 10. CactusCompletionParams Configuration Rationale

| Parameter             | Value | Why                                                                                               |
| --------------------- | ----- | ------------------------------------------------------------------------------------------------- |
| `temperature`         | 0.1   | JSON requires determinism. High temp = schema drift.                                              |
| `maxTokens`           | 350   | Full PlannerOutput JSON is ~200–300 tokens. Cap prevents runaway.                                 |
| `topK`                | 20    | Narrow sampling pool reinforces structured token patterns.                                        |
| `enableToolFiltering` | false | Planner does NOT use Cactus native tool calling — it does its own intent routing.                 |
| `contextSize`         | 2048  | System prompt (~600 tokens) + 6-turn history (~400 tokens) + response (350 tokens) = safe margin. |

---

## 11. Tool Name Registry

Define the canonical tool list in one place, injected into both the Planner prompt and Stage 2:

```dart
// lib/tools/tool_registry.dart
class ToolRegistry {
  static const List<String> allTools = [
    // File tools
    'search_files_semantic',
    'search_files_recent',
    'search_files_by_type',
    // Photo tools
    'search_photos_semantic',
    'search_photos_by_date',
    // Automation tools
    'toggle_wifi',
    'toggle_bluetooth',
    'toggle_flashlight',
    'open_app',
    'get_battery_status',
    // Clipboard tools
    'copy_text',
    'read_clipboard',
  ];
}
```

Pass `ToolRegistry.allTools` into `PlannerService.initialize()`. This ensures the Planner only suggests tools that actually exist.

---

## 12. What To Build Next (Stage 2 Handoff Contract)

When you hand `PlannerOutput` to Stage 2 (FunctionGemma), pass this exact structure:

```dart
// The Stage 2 contract — PlannerOutput is the input
// Stage 2 selects ONE tool from candidate_tools and executes it

class Stage2Input {
  final PlannerOutput plannerOutput;      // full planner result
  final Map<String, Function> toolMap;   // Dart function map by tool name

  Stage2Input({required this.plannerOutput, required this.toolMap});
}
```

Stage 2 never sees raw user text — only the structured `PlannerOutput`. This is the clean separation that makes the pipeline debuggable.

---

## 13. Performance Notes

- **Planner adds ~800ms–2s latency** on mid-range Android with qwen3-0.6.
- Emit `chatResponse` to UI **immediately** after parsing — before Stage 2 executes. The user sees a reply instantly while tools run in the background.
- Run `PlannerService` in a Dart Isolate to avoid blocking the UI thread.
- Keep the model loaded (`isLoaded()` check) — do NOT reload between turns. Reloading costs 3–5 seconds.
- Use `lm.reset()` (not `unload()`) between sessions to clear context without deallocating weights.

---

## 14. Common Failure Modes & Mitigations

| Failure                           | Cause                      | Fix                                                       |
| --------------------------------- | -------------------------- | --------------------------------------------------------- |
| JSON schema missing keys          | Low temperature not set    | Set `temperature=0.1`, add schema to system prompt        |
| Model suggests non-existent tools | Tools not listed in prompt | Always inject `ToolRegistry.allTools` into system prompt  |
| Follow-up messages lose context   | No history management      | Use `PlannerContextManager` with 6-turn window            |
| Slow first inference              | Model cold-start           | Pre-warm model on app launch, show loading state          |
| `candidate_tools` has 5+ tools    | Model over-suggesting      | Add: "suggest at most 2 candidate tools" to system prompt |
| Planner hallucinates tool results | Boundary confusion         | Reinforce "you NEVER execute tools" in system prompt      |
