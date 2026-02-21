// lib/services/agent_service.dart
//
// NEW ARCHITECTURE:
//
//   User message
//       │
//       ▼
//   Stage 1 — FunctionGemma (functiongemma-270m)
//       │  Uses CactusTool list (Cactus native tool calling)
//       │
//       ├── toolCalls NOT empty → execute Dart tool → return result
//       │
//       └── toolCalls empty → Stage 2 — Qwen3-1.7b (conversation)
//                                 └── natural language reply
//
// FunctionGemma owns tool routing.
// Qwen3-1.7b owns conversation.
// Both models stay loaded simultaneously.

import 'package:cactus/cactus.dart';
import 'planner_context_manager.dart';
import '../tools/tool_registry.dart';

// ---------------------------------------------------------------------------
// Result returned to the UI
// ---------------------------------------------------------------------------

enum AgentResponseType { toolResult, conversation }

class AgentResponse {
  final AgentResponseType type;

  /// Always present — shown in the chat bubble
  final String chatMessage;

  /// Only set when type == toolResult
  final String? toolName;
  final Map<String, dynamic>? toolArguments;
  final Map<String, dynamic>? toolResult;

  const AgentResponse({
    required this.type,
    required this.chatMessage,
    this.toolName,
    this.toolArguments,
    this.toolResult,
  });
}

// ---------------------------------------------------------------------------
// AgentService
// ---------------------------------------------------------------------------

class AgentService {
  // ── Model slugs ────────────────────────────────────────────────────────────
  static const String _toolModelSlug = 'qwen3-1.7'; // Stage 1
  static const String _chatModelSlug = 'qwen3-1.7'; // Stage 2

  // ── Cactus LM instances — one per model ───────────────────────────────────
  late CactusLM _toolLm; // FunctionGemma — tool calling
  late CactusLM _chatLm; // Qwen3-1.7b   — conversation

  final PlannerContextManager _context = PlannerContextManager();

  bool _isInitialized = false;

  // ── Cactus tool definitions (mirrors ToolRegistry) ────────────────────────
  // These are passed directly to CactusCompletionParams.tools
  // FunctionGemma uses these to decide which tool to call.
  static final List<CactusTool> _cactusTools = [
    // File tools
    CactusTool(
      name: 'search_files_semantic',
      description:
          'Search device storage for files using semantic similarity. Use for queries like "find my resume" or "look for the project proposal".',
      parameters: ToolParametersSchema(
        properties: {
          'query': ToolParameter(
            type: 'string',
            description: 'Search query describing the file',
            required: true,
          ),
          'mime_filter': ToolParameter(
            type: 'string',
            description:
                'Optional comma-separated mime types e.g. application/pdf',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'search_files_recent',
      description:
          'Find the most recently modified or opened files. Use when user says "latest", "most recent", "last edited".',
      parameters: ToolParametersSchema(
        properties: {
          'query': ToolParameter(
            type: 'string',
            description: 'File type or name hint',
            required: true,
          ),
          'limit': ToolParameter(
            type: 'string',
            description: 'Max number of results',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'search_files_by_type',
      description:
          'Find files by type or extension. Use for "show me all PDFs" or "find my images".',
      parameters: ToolParametersSchema(
        properties: {
          'mime_type': ToolParameter(
            type: 'string',
            description: 'Mime type to filter by e.g. application/pdf',
            required: true,
          ),
        },
      ),
    ),
    // Photo tools
    CactusTool(
      name: 'search_photos_semantic',
      description:
          'Search photos using a text description of the scene or content. Use for "photo near a tree" or "picture at the beach".',
      parameters: ToolParametersSchema(
        properties: {
          'query': ToolParameter(
            type: 'string',
            description: 'Text description of the photo scene or content',
            required: true,
          ),
          'limit': ToolParameter(
            type: 'string',
            description: 'Max number of results',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'search_photos_by_date',
      description: 'Find photos taken within a date range.',
      parameters: ToolParametersSchema(
        properties: {
          'from_date': ToolParameter(
            type: 'string',
            description: 'Start date in YYYY-MM-DD format',
            required: false,
          ),
          'to_date': ToolParameter(
            type: 'string',
            description: 'End date in YYYY-MM-DD format',
            required: false,
          ),
        },
      ),
    ),
    // Automation tools
    CactusTool(
      name: 'toggle_wifi',
      description: 'Enable or disable WiFi on the device.',
      parameters: ToolParametersSchema(
        properties: {
          'enabled': ToolParameter(
            type: 'string',
            description: 'true to enable, false to disable',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'toggle_bluetooth',
      description: 'Enable or disable Bluetooth on the device.',
      parameters: ToolParametersSchema(
        properties: {
          'enabled': ToolParameter(
            type: 'string',
            description: 'true to enable, false to disable',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'toggle_flashlight',
      description: 'Turn the device flashlight/torch on or off.',
      parameters: ToolParametersSchema(
        properties: {
          'enabled': ToolParameter(
            type: 'string',
            description: 'true to turn on, false to turn off',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'open_app',
      description: 'Launch an installed Android app by package name.',
      parameters: ToolParametersSchema(
        properties: {
          'package_name': ToolParameter(
            type: 'string',
            description: 'Android package name e.g. com.android.gallery3d',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_battery_status',
      description: 'Get the current battery level and charging state.',
      parameters: ToolParametersSchema(properties: {}),
    ),
    // Clipboard tools
    CactusTool(
      name: 'copy_text',
      description: 'Copy text to the device clipboard.',
      parameters: ToolParametersSchema(
        properties: {
          'text': ToolParameter(
            type: 'string',
            description: 'Text to copy to clipboard',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'read_clipboard',
      description: 'Read the current contents of the device clipboard.',
      parameters: ToolParametersSchema(properties: {}),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Initialize — loads BOTH models
  // ---------------------------------------------------------------------------

  Future<void> initialize({CactusProgressCallback? onProgress}) async {
    if (_isInitialized) return;

    // FunctionGemma — tool router
    _toolLm = CactusLM(enableToolFiltering: false);
    await _toolLm.downloadModel(
      model: _toolModelSlug,
      downloadProcessCallback: (progress, status, isError) {
        onProgress?.call(progress, '[Tool model] $status', isError);
      },
    );
    await _toolLm.initializeModel(
      params: CactusInitParams(model: _toolModelSlug, contextSize: 1024),
    );

    // Qwen3-1.7b — conversational fallback
    _chatLm = CactusLM(enableToolFiltering: false);
    await _chatLm.downloadModel(
      model: _chatModelSlug,
      downloadProcessCallback: (progress, status, isError) {
        onProgress?.call(progress, '[Chat model] $status', isError);
      },
    );
    await _chatLm.initializeModel(
      params: CactusInitParams(model: _chatModelSlug, contextSize: 2048),
    );

    _isInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // Core: process one user message
  // ---------------------------------------------------------------------------

  Future<AgentResponse> process(String userMessage) async {
    assert(_isInitialized, 'Call initialize() first');

    _context.addUserMessage(userMessage);

    // ── Stage 1: FunctionGemma with Cactus native tool calling ───────────────
    final toolResult = await _toolLm.generateCompletion(
      messages: [
        ChatMessage(
          content:
              'You are a device assistant. Use the available tools when the user '
              'wants to find files, search photos, control device settings, or use the clipboard. '
              'If the user is just having a conversation, do NOT call any tool.',
          role: 'system',
        ),
        ..._buildHistory(),
      ],
      params: CactusCompletionParams(
        tools: _cactusTools,
        maxTokens: 256,
        temperature: 0.1,
        stopSequences: ['<|im_end|>', '<end_of_turn>'],
        completionMode: CompletionMode.local,
      ),
    );

    print(toolResult.toString()+toolResult.toolCalls.toString());
    for (var i in toolResult.toolCalls){
      print(i.name+" "+i.arguments.toString());
    }
    // ── Route on tool call result ─────────────────────────────────────────────
    if (toolResult.success && toolResult.toolCalls.isNotEmpty) {
      // FunctionGemma decided to call a tool
      final call = toolResult.toolCalls.first;

      // Convert string arguments to dynamic map
      final args = Map<String, dynamic>.from(call.arguments);

      // Build a friendly acknowledgement message
      final ackMessage = _toolAckMessage(call.name, args);
      _context.addAssistantMessage(ackMessage);

      return AgentResponse(
        type: AgentResponseType.toolResult,
        chatMessage: ackMessage,
        toolName: call.name,
        toolArguments: args,
        // toolResult is filled in by the caller (main.dart) after executing the Dart function
      );
    }

    // ── Stage 2: Qwen3-1.7b for conversation ─────────────────────────────────
    final chatResult = await _chatLm.generateCompletion(
      messages: [
        ChatMessage(
          content:
              'You are a helpful, friendly personal assistant on the user\'s phone. '
              'Respond naturally and concisely — 1 to 3 sentences.',
          role: 'system',
        ),
        ..._buildHistory(),
      ],
      params: CactusCompletionParams(
        maxTokens: 512,
        temperature: 0.7,
        topK: 40,
        stopSequences: ['<|im_end|>', '<end_of_turn>'],
        completionMode: CompletionMode.local,
      ),
    );

    final reply = chatResult.success
        ? _stripModelOutput(chatResult.response)
        : "Sorry, I didn't catch that. Could you try again?";

    _context.addAssistantMessage(reply);

    return AgentResponse(
      type: AgentResponseType.conversation,
      chatMessage: reply,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<ChatMessage> _buildHistory() {
    return _context
        .getMessageMaps()
        .map((m) => ChatMessage(content: m['content']!, role: m['role']!))
        .toList();
  }

  /// Human-friendly acknowledgement shown immediately when a tool is called.
  String _toolAckMessage(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case 'search_files_semantic':
      case 'search_files_recent':
      case 'search_files_by_type':
        final q = args['query'] ?? args['mime_type'] ?? 'files';
        return 'Searching your storage for "$q"...';
      case 'search_photos_semantic':
        return 'Looking through your photos for "${args['query'] ?? 'matching photos'}"...';
      case 'search_photos_by_date':
        return 'Fetching photos from that date range...';
      case 'toggle_wifi':
        final on = args['enabled'].toString() == 'true';
        return on ? 'Turning WiFi on...' : 'Turning WiFi off...';
      case 'toggle_bluetooth':
        final on = args['enabled'].toString() == 'true';
        return on ? 'Turning Bluetooth on...' : 'Turning Bluetooth off...';
      case 'toggle_flashlight':
        final on = args['enabled'].toString() == 'true';
        return on ? 'Flashlight on.' : 'Flashlight off.';
      case 'open_app':
        return 'Opening ${args['package_name']}...';
      case 'get_battery_status':
        return 'Checking battery...';
      case 'read_clipboard':
        return 'Reading clipboard...';
      case 'copy_text':
        return 'Copied to clipboard.';
      default:
        return 'On it...';
    }
  }

  /// Strips Qwen3 think tags and control tokens.
  static String _stripModelOutput(String raw) {
    var result = raw.replaceAll(
      RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false),
      '',
    );
    result = result.replaceAll(
      RegExp(r'<\|im_end\|>|<end_of_turn>|<\|im_start\|>\w*'),
      '',
    );
    return result.trim();
  }

  void clearContext() {
    _context.clear();
    _toolLm.reset();
    _chatLm.reset();
  }

  bool get isReady => _isInitialized;

  void dispose() {
    if (_isInitialized) {
      _toolLm.unload();
      _chatLm.unload();
      _isInitialized = false;
    }
  }

  // Debug helper
  static Future<void> debugPrintAvailableModels() async {
    final lm = CactusLM(enableToolFiltering: false);
    try {
      final models = await lm.getModels();
      print('=== CACTUS MODEL SLUGS ===');
      for (final m in models) {
        print('  "${m.slug}"  ${m.sizeMb}MB  tools:${m.supportsToolCalling}');
      }
    } finally {
      lm.unload();
    }
  }
}
