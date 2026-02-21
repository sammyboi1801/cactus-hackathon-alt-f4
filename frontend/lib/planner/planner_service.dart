// lib/services/planner/planner_service.dart

import 'package:cactus/cactus.dart';
import 'planner_intent_types.dart';
import 'planner_prompt_builder.dart';
import 'planner_output_parser.dart';
import 'planner_context_manager.dart';
import '../../tools/tool_registry.dart';

class PlannerService {
  static const String _modelSlug = 'qwen3-1.7';
  static const int _contextSize = 2048;
  static const int _maxPlannerTokens = 350;   // JSON output — bounded
  static const int _maxChatTokens = 512;       // Free-form chat — more room
  static const double _plannerTemp = 0.1;      // Low: deterministic JSON
  static const double _chatTemp = 0.7;         // Higher: natural conversation

  late CactusLM _lm;
  late final PlannerPromptBuilder _promptBuilder;
  final PlannerContextManager _context = PlannerContextManager();
  bool _isInitialized = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize({CactusProgressCallback? onDownloadProgress}) async {
    if (_isInitialized) return;

    _lm = CactusLM(enableToolFiltering: false);
    _promptBuilder = PlannerPromptBuilder(availableTools: ToolRegistry.allTools);

    await _lm.downloadModel(
      model: _modelSlug,
      downloadProcessCallback: onDownloadProgress,
    );

    await _lm.initializeModel(
      params: CactusInitParams(
        model: _modelSlug,
        contextSize: _contextSize,
      ),
    );

    _isInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // Core: two-pass plan
  //
  // Pass 1 — Planner prompt (JSON schema) → classify intent
  // Pass 2 — If generalQuestion OR JSON failed → chat prompt → real reply
  // ---------------------------------------------------------------------------

  Future<PlannerOutput> plan(String userMessage) async {
    assert(_isInitialized, 'Call initialize() before plan()');

    _context.addUserMessage(userMessage);

    // ── Pass 1: classify intent via JSON planner ─────────────────────────────
    final plannerMessages = _buildPlannerMessages();

    final plannerResult = await _lm.generateCompletion(
      messages: plannerMessages,
      params: CactusCompletionParams(
        maxTokens: _maxPlannerTokens,
        temperature: _plannerTemp,
        topK: 20,
        stopSequences: ['\n\n\n', '<|im_end|>', '<end_of_turn>'],
        completionMode: CompletionMode.local,
      ),
    );

    PlannerOutput? output;

    if (plannerResult.success) {
      output = PlannerOutputParser.tryParse(plannerResult.response);
      if (output == null) {
        output = await _retryWithRepair(plannerResult.response);
      }
    }

    print(output);

    // ── Pass 2: generate real chat reply ─────────────────────────────────────
    // Triggered when:
    //   a) Planner classified as generalQuestion (no tools needed), OR
    //   b) JSON parsing failed entirely (model replied conversationally)
    final needsChatReply = output == null ||
        output.intent == PlannerIntent.generalQuestion ||
        output.intent == PlannerIntent.unclear;

    if (needsChatReply) {
      final chatReply = await _generateChatReply(userMessage);

      // If we have a valid planner output (generalQuestion), merge the real reply in
      // If parsing failed entirely, wrap the chat reply as a generalQuestion output
      output = PlannerOutput(
        intent: PlannerIntent.generalQuestion,
        reasoningSummary: 'Conversational message — no tools required.',
        chatResponse: chatReply,
        candidateTools: [],
        arguments: {},
        confidence: 0.9,
      );
    }

    // ── Sanitize tool names ───────────────────────────────────────────────────
    final sanitizedTools = ToolRegistry.filterValid(output!.candidateTools);
    if (sanitizedTools.length != output.candidateTools.length) {
      output = PlannerOutput(
        intent: output.intent,
        reasoningSummary: output.reasoningSummary,
        chatResponse: output.chatResponse,
        candidateTools: sanitizedTools,
        arguments: output.arguments,
        confidence: output.confidence,
      );
    }

    _context.addAssistantMessage(output.chatResponse);
    return output;
  }

  // ---------------------------------------------------------------------------
  // Pass 2: plain conversational completion
  // No JSON schema. No tool list. Just talk.
  // ---------------------------------------------------------------------------

  Future<String> _generateChatReply(String userMessage) async {
    final chatMessages = [
      ChatMessage(
        content: 'You are a helpful, friendly personal assistant running on the user\'s phone. '
                 'Respond naturally and conversationally. '
                 'Keep replies concise — 1 to 3 sentences unless more detail is genuinely needed.',
        role: 'system',
      ),
      // Include conversation history so follow-ups make sense
      ..._context.getMessageMaps().map((m) => ChatMessage(
            content: m['content']!,
            role: m['role']!,
          )),
    ];

    final result = await _lm.generateCompletion(
      messages: chatMessages,
      params: CactusCompletionParams(
        maxTokens: _maxChatTokens,
        temperature: _chatTemp,
        topK: 40,
        stopSequences: ['<|im_end|>', '<end_of_turn>'],
        completionMode: CompletionMode.local,
      ),
    );

    if (!result.success || result.response.trim().isEmpty) {
      return "Sorry, I didn't catch that. Could you try again?";
    }

    return _stripModelOutput(result.response);
  }

  // ---------------------------------------------------------------------------
  // Streaming variant — streams the chat reply token by token
  // Use this in the UI for a typewriter effect on conversational replies
  // ---------------------------------------------------------------------------

  Future<CactusStreamedCompletionResult> planStream(String userMessage) async {
    assert(_isInitialized, 'Call initialize() before planStream()');
    _context.addUserMessage(userMessage);

    return _lm.generateCompletionStream(
      messages: _buildPlannerMessages(),
      params: CactusCompletionParams(
        maxTokens: _maxPlannerTokens,
        temperature: _plannerTemp,
        topK: 20,
        stopSequences: ['\n\n\n', '<|im_end|>', '<end_of_turn>'],
        completionMode: CompletionMode.local,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Repair pass — ask model to fix its own broken JSON
  // ---------------------------------------------------------------------------

  Future<PlannerOutput?> _retryWithRepair(String brokenOutput) async {
    final result = await _lm.generateCompletion(
      messages: [
        ChatMessage(
          content: 'You are a JSON repair assistant. '
                   'Fix the following broken JSON and output ONLY the corrected JSON. '
                   'No explanation. No markdown.',
          role: 'system',
        ),
        ChatMessage(content: 'Fix this:\n$brokenOutput', role: 'user'),
      ],
      params: CactusCompletionParams(
        maxTokens: _maxPlannerTokens,
        temperature: 0.0,
        stopSequences: ['<|im_end|>', '<end_of_turn>'],
        completionMode: CompletionMode.local,
      ),
    );

    if (!result.success) return null;
    return PlannerOutputParser.tryParse(_stripModelOutput(result.response));
  }

  // ---------------------------------------------------------------------------
  // Message builders
  // ---------------------------------------------------------------------------

  List<ChatMessage> _buildPlannerMessages() {
    return [
      ChatMessage(
        content: _promptBuilder.buildSystemPrompt(),
        role: 'system',
      ),
      ..._context.getMessageMaps().map((m) => ChatMessage(
            content: m['content']!,
            role: m['role']!,
          )),
    ];
  }

  // ---------------------------------------------------------------------------
  // Context / lifecycle
  // ---------------------------------------------------------------------------


  /// Strips Qwen3 think tags and control tokens from raw model output.
  /// Must be applied to ALL model responses before showing to user or parsing.
  static String _stripModelOutput(String raw) {
    // Remove <think>...</think> blocks (Qwen3 reasoning traces)
    var result = raw.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '');
    // Remove control tokens
    result = result.replaceAll(RegExp(r'<\|im_end\|>|<end_of_turn>|<\|im_start\|>\w*'), '');
    return result.trim();
  }

  void clearContext() {
    _context.clear();
    _lm.reset();
  }

  bool get isReady => _isInitialized && _lm.isLoaded();

  void dispose() {
    if (_isInitialized) {
      _lm.unload();
      _isInitialized = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Debug helper — prints all valid Cactus model slugs
  // ---------------------------------------------------------------------------

  static Future<void> debugPrintAvailableModels() async {
    final lm = CactusLM(enableToolFiltering: false);
    try {
      final models = await lm.getModels();
      print('=== AVAILABLE CACTUS MODEL SLUGS ===');
      for (final m in models) {
        print('  slug: "${m.slug}"  name: ${m.name}  size: ${m.sizeMb}MB  tools: ${m.supportsToolCalling}');
      }
      print('=====================================');
    } finally {
      lm.unload();
    }
  }
}