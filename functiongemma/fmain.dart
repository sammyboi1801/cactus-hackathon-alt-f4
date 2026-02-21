import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

// FunctionGemma Model Configuration
class FunctionGemmaConfig {
  static String get modelPath {
    return 'assets/models/functiongemma-270m-it';
  }
}

//////////////////////////////////////////////////////////////
// GLOBAL MODEL CACHE
//////////////////////////////////////////////////////////////
dynamic _functionGemmaModel;

Future<dynamic> _getModel() async {
  if (_functionGemmaModel == null) {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String modelPath = '${appDir.path}/models/functiongemma-270m-it';
      _functionGemmaModel = await cactusInit(modelPath);
    } catch (e) {
      print("Error initializing model: $e");
    }
  }
  return _functionGemmaModel;
}

final Set<String> reservedWords = {
  'to', 'the', 'at', 'in', 'of', 'and', 'saying', 'say', 'text', 'message',
  'check', 'current', 'weather', 'is', 'for', 'about', 'find', 'search',
  'look', 'up', 'contact', 'contacts', 'send', 'tell', 'give', 'me', 'set',
  'play', 'get', 'what', 'how', 'a', 'an', 'some', 'any', 'my', 'me', 'him',
  'her', 'them', 'wake', 'up', 'reminder', 'remind', 'photo', 'photos',
  'picture', 'pictures', 'image', 'images', 'file', 'files', 'document',
  'documents', 'yesterday', 'today', 'last', 'week', 'month'
};

//////////////////////////////////////////////////////////////
// TOOL DEFINITIONS
//////////////////////////////////////////////////////////////

class ToolRegistry {
  static final List<Map<String, dynamic>> mobileTools = [
    {
      'name': 'search_photos',
      'description': 'Search for photos/images in the device gallery',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'What to search for'},
          'date': {'type': 'string', 'description': 'Time reference'},
          'location': {'type': 'string', 'description': 'Location context'}
        },
        'required': ['query']
      }
    },
    {
      'name': 'search_files',
      'description': 'Search for files/documents on the device',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'File name or content search'},
          'file_type': {'type': 'string', 'description': 'e.g. pdf, docx'},
          'date': {'type': 'string', 'description': 'Date reference'}
        },
        'required': ['query']
      }
    }
  ];
}

//////////////////////////////////////////////////////////////
// RECOVERY & POST-PROCESSING
//////////////////////////////////////////////////////////////

List<String> _extractJsonBlocks(String s) {
  if (s.isEmpty) return [];
  s = s.replaceAll('：', ':').replaceAll('，', ',').replaceAll('"', '"').replaceAll('"', '"');
  s = s.replaceAll('<escape>', '').replaceAll('<|im_end|>', '').replaceAll('<end_of_turn>', '');
  
  final List<String> blocks = [];
  final List<String> braceStack = [];
  int start = -1;
  
  for (int i = 0; i < s.length; i++) {
    if (s[i] == '{') {
      if (braceStack.isEmpty) start = i;
      braceStack.add('{');
    } else if (s[i] == '}') {
      if (braceStack.isNotEmpty) {
        braceStack.removeLast();
        if (braceStack.isEmpty) {
          blocks.add(s.substring(start, i + 1));
        }
      }
    }
  }
  return blocks;
}

Map<String, dynamic>? _robustParse(String rawStr) {
  final List<String> blocks = _extractJsonBlocks(rawStr);
  final List<Map<String, dynamic>> calls = [];
  
  for (final String b in blocks) {
    try {
      final Map<String, dynamic> data = jsonDecode(b);
      if (data.containsKey('function_calls')) {
        calls.addAll((data['function_calls'] as List).cast<Map<String, dynamic>>());
      } else if (data.containsKey('name')) {
        calls.add(data);
      }
    } catch (e) {
      try {
        // Simple regex fix for missing quotes around values
        final String fixed = b.replaceAllMapped(
          RegExp(r':\s*([a-zA-Z0-9_\-\.]+)\s*([,}])'),
          (match) => ':"${match.group(1)}"${match.group(2)}'
        );
        final Map<String, dynamic> data = jsonDecode(fixed);
        if (data.containsKey('function_calls')) {
          calls.addAll((data['function_calls'] as List).cast<Map<String, dynamic>>());
        } else if (data.containsKey('name')) {
          calls.add(data);
        }
      } catch (e2) {
        // Skip
      }
    }
  }
  return calls.isNotEmpty ? {'function_calls': calls} : null;
}

double _similarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final List<List<int>> dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (int i = 1; i <= a.length; i++) {
    for (int j = 1; j <= b.length; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }
  return (2.0 * dp[a.length][b.length]) / (a.length + b.length);
}

String? _fuzzyMatch(dynamic query, List<String> choices, {double threshold = 0.25}) {
  if (query == null || choices.isEmpty) return null;
  final String q = query.toString().toLowerCase().trim();
  String? bestMatch;
  double maxScore = 0.0;
  
  for (final choice in choices) {
    double score = _similarity(q, choice.toLowerCase());
    if (q.contains(choice.toLowerCase()) || choice.toLowerCase().contains(q)) {
      score = max(score, 0.8);
    }
    if (score > maxScore) {
      maxScore = score;
      bestMatch = choice;
    }
  }
  return maxScore >= threshold ? bestMatch : null;
}

Map<String, dynamic>? _fixCall(Map<String, dynamic> call, Map<String, Map<String, dynamic>> toolMap, String userRequest) {
  final String? matchedName = _fuzzyMatch(call['name'], toolMap.keys.toList());
  if (matchedName == null) return null;
  
  final Map<String, dynamic> toolDef = toolMap[matchedName]!;
  final Map<String, dynamic> props = (toolDef['parameters'] as Map)['properties'] as Map<String, dynamic>;
  final dynamic rawArgsObj = call['arguments'] ?? {};
  final Map<String, dynamic> rawArgs = rawArgsObj is Map<String, dynamic> ? rawArgsObj : {};
  
  final Map<String, dynamic> fixedArgs = {};
  for (final entry in rawArgs.entries) {
    dynamic value = entry.value;
    if (value is Map && value.isNotEmpty) value = value.values.first;
    
    final String? matchedK = _fuzzyMatch(entry.key, props.keys.toList(), threshold: 0.1);
    if (matchedK != null) {
      fixedArgs[matchedK] = _coerce(value, (props[matchedK] as Map)['type'], matchedK, userRequest);
    }
  }
  
  final List required = (toolDef['parameters'] as Map)['required'] as List? ?? [];
  for (final req in required) {
    bool shouldScavenge = false;
    final String valS = fixedArgs[req]?.toString() ?? "";
    
    if (fixedArgs[req] == null) {
      shouldScavenge = true;
    } else if (['query', 'location', 'date', 'file_type'].contains(req)) {
      final List<String> words = valS.toLowerCase().split(RegExp(r'\s+'));
      bool hallucinated = words.any((w) => !userRequest.toLowerCase().contains(w) && !reservedWords.contains(w));
      if (hallucinated || valS.length < 2 || reservedWords.contains(valS.toLowerCase()) || !userRequest.toLowerCase().contains(valS.toLowerCase())) {
        shouldScavenge = true;
      }
    }
    
    if (shouldScavenge) {
      final val = _scavengeParam(userRequest, req.toString(), (props[req] as Map)['type'], matchedName);
      if (val != null) fixedArgs[req] = val;
    }
  }
  
  return {"name": matchedName, "arguments": fixedArgs};
}

dynamic _coerce(dynamic v, String? t, String k, String userRequest) {
  if (t == 'integer' || t == 'number') {
    final String sVal = v.toString();
    final Iterable<Match> matches = RegExp(r'\d+').allMatches(sVal);
    if (matches.isNotEmpty) return int.parse(matches.first.group(0)!);
    return 0;
  }
  String s = v.toString().trim().replaceAll(RegExp(r'^["' + "'" + r']|["' + "'" + r']$'), '');
  if (s.length > 100) s = s.substring(0, 100);
  return s.isEmpty ? null : s;
}

dynamic _scavengeParam(String text, String key, String? ptype, String tool) {
  if (ptype == 'integer' || ptype == 'number') {
    final Iterable<Match> matches = RegExp(r'\d+').allMatches(text);
    if (matches.isNotEmpty) return int.parse(matches.first.group(0)!);
    return 0;
  }
  
  final Map<String, String> patterns = {
    'location': r'(?:in|at|to|weather for|weather in|of|near|is the weather in|weather like in|about|weather in)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
    'query': r'(?:Find|Look up|Search for|search|look up|finding|for|photo|picture|image|file|document)s?\s+(?:of|about|named)?\s*([a-zA-Z0-9\s]+?)(?:\s+from|\s+in|$)',
    'date': r'(yesterday|today|last week|last month|monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
    'file_type': r'(pdf|docx|xlsx|txt|jpg|png|ppt|csv)'
  };
  
  if (patterns.containsKey(key)) {
    final Match? m = RegExp(patterns[key]!, caseSensitive: false).firstMatch(text);
    if (m != null) {
      final String val = m.group(1)!.trim();
      if (!reservedWords.contains(val.toLowerCase())) return val;
    }
  }
  
  if (['location', 'query'].contains(key)) {
    final Iterable<Match> words = RegExp(r'[A-Z][a-z]+').allMatches(text);
    for (final w in words) {
      if (!reservedWords.contains(w.group(0)!.toLowerCase())) return w.group(0);
    }
  }
  return null;
}

//////////////////////////////////////////////////////////////
// CLOUD FALLBACK
//////////////////////////////////////////////////////////////

Future<Map<String, dynamic>> _generateCloud(List<Map<String, dynamic>> messages, List<Map<String, dynamic>> tools) async {
  print("☁️ Falling back to Cloud (Gemini) for request...");
  // This is a placeholder for the actual Gemini API call
  // In the real app, this would use a package like google_generative_ai
  
  final String userText = messages.where((m) => m['role'] == 'user').map((m) => m['content']).join(" ");
  
  // Mocking cloud response based on user input
  final List<Map<String, dynamic>> calls = [];
  if (userText.contains('photo')) {
    calls.add({
      'name': 'search_photos',
      'arguments': {'query': _scavengeParam(userText, 'query', 'string', 'search_photos') ?? 'cloud_extracted_query'}
    });
  } else if (userText.contains('file')) {
    calls.add({
      'name': 'search_files',
      'arguments': {'query': _scavengeParam(userText, 'query', 'string', 'search_files') ?? 'cloud_extracted_query'}
    });
  }
  
  return {
    "function_calls": calls,
    "total_time_ms": 500.0,
    "source": "cloud (fallback)"
  };
}

//////////////////////////////////////////////////////////////
// PROMPTS
//////////////////////////////////////////////////////////////

const String systemPrompt = """You are a robotic tool-calling assistant. Respond ONLY with valid JSON.
Format: {"function_calls": [{"name": "tool_name", "arguments": {"param": "value"}}]}
RULES:
1. Provide a JSON object for EVERY action requested.
2. Use EXACT words and numbers found in the user request.

EXAMPLES:
User: search for photos of garden from yesterday.
Assistant: {"function_calls": [{"name": "search_photos", "arguments": {"query": "garden", "date": "yesterday"}}]}

User: find the pdf file named tax report.
Assistant: {"function_calls": [{"name": "search_files", "arguments": {"query": "tax report", "file_type": "pdf"}}]}
""";

String _getPrompt(List<Map<String, dynamic>> tools) {
  final String desc = tools.map((t) => "- ${t['name']}: ${t['description']} (${(t['parameters']['properties'] as Map).keys.toList()})").join("\n");
  return "$systemPrompt\nAVAILABLE TOOLS:\n$desc";
}

//////////////////////////////////////////////////////////////
// CORE
//////////////////////////////////////////////////////////////

Future<Map<String, dynamic>> _generateCactusAttempt(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    int expected,
    {double temperature = 0.0, String? hint}) async {
  
  final dynamic model = await _getModel();
  cactusReset(model);
  
  final List<Map<String, dynamic>> msgs = [
    {'role': 'system', 'content': _getPrompt(tools)},
    ...messages
  ];
  if (hint != null) msgs.add({'role': 'user', 'content': 'IMPORTANT: $hint'});
  
  final List<Map<String, dynamic>> cactusTools = tools.map((t) => {'type': 'function', 'function': t}).toList();
  final Map<String, Map<String, dynamic>> toolMap = {for (final t in tools) t['name'] as String: t};
  
  final int startTime = DateTime.now().millisecondsSinceEpoch;
  final String rawStr = cactusComplete(
    model,
    msgs,
    tools: cactusTools,
    forceTools: true,
    temperature: temperature,
    maxTokens: 192
  );
  final int totalTime = DateTime.now().millisecondsSinceEpoch - startTime;
  
  final Map<String, dynamic>? data = _robustParse(rawStr);
  final String userReq = messages.where((m) => m['role'] == 'user').map((m) => m['content']).join(" ");
  
  final List<Map<String, dynamic>> fixedCalls = [];
  final Set<String> seen = {};
  
  if (data != null) {
    for (final c in (data['function_calls'] as List)) {
      final fixed = _fixCall(c as Map<String, dynamic>, toolMap, userReq);
      if (fixed != null) {
        final String sig = jsonEncode(fixed);
        if (!seen.contains(sig)) {
          fixedCalls.add(fixed);
          seen.add(sig);
        }
      }
    }
  }
  
  double confidence = 0.5;
  try {
    final Map<String, dynamic> meta = jsonDecode(rawStr);
    confidence = meta['confidence']?.toDouble() ?? 0.5;
  } catch (e) {
    // rawStr might be pure JSON function call
  }
  
  return {
    "function_calls": fixedCalls,
    "confidence": confidence,
    "total_time_ms": totalTime.toDouble()
  };
}

Future<Map<String, dynamic>> generateHybrid(String qwenInput) async {
  final tools = ToolRegistry.mobileTools;
  final List<Map<String, dynamic>> messages = [{'role': 'user', 'content': qwenInput}];
  
  int expected = 1;
  final String lowerText = qwenInput.toLowerCase();
  if (RegExp(r'\s+(and|then|also|plus)\s+|,\s+').hasMatch(lowerText)) expected = 2;
  if (lowerText.split(' and ').length + lowerText.split(',').length >= 3) expected = 3;
  
  // Pass 1: Deterministic
  Map<String, dynamic> res = await _generateCactusAttempt(messages, tools, expected, temperature: 0.0);
  
  // Split logic fallback for multi-call
  if ((res["confidence"] < 0.8 || (res["function_calls"] as List).length < expected) && expected > 1) {
    final List<String> parts = qwenInput.split(RegExp(r'\s+(?:and|then|also|plus)\s+|,\s+', caseSensitive: false))
        .map((p) => p.trim())
        .where((p) => p.length > 4)
        .toList();
    
    if (parts.length >= expected) {
      final List<Map<String, dynamic>> splitCalls = [];
      double splitTime = res["total_time_ms"];
      
      for (final p in parts.take(expected)) {
        Map<String, dynamic> sRes = await _generateCactusAttempt([{'role': 'user', 'content': p}], tools, 1, temperature: 0.0, hint: "Extract ONLY ONE action.");
        if ((sRes["function_calls"] as List).isEmpty) {
          sRes = await _generateCactusAttempt([{'role': 'user', 'content': p}], tools, 1, temperature: 0.7);
        }
        splitCalls.addAll((sRes["function_calls"] as List).cast<Map<String, dynamic>>());
        splitTime += sRes["total_time_ms"];
      }
      
      if (splitCalls.length > (res["function_calls"] as List).length) {
        res = {"function_calls": splitCalls, "confidence": 0.9, "total_time_ms": splitTime, "source": "on-device"};
        return res;
      }
    }
  }
  
  // Stochastic retries
  if (res["confidence"] < 0.7 || (res["function_calls"] as List).length < expected) {
    final List<Map<String, dynamic>> attempts = [res];
    for (int i = 0; i < 2; i++) {
      attempts.add(await _generateCactusAttempt(messages, tools, expected, temperature: 0.7));
    }
    
    Map<String, dynamic> bestRes = res;
    double bestScore = -100.0;
    
    for (final a in attempts) {
      final int num = (a["function_calls"] as List).length;
      double score = (min(num, expected) * 60.0) + (a["confidence"] * 10.0);
      if (num == expected) score += 100.0;
      if (score > bestScore) {
        bestScore = score;
        bestRes = a;
      }
    }
    res = bestRes;
    res["total_time_ms"] = attempts.fold(0.0, (sum, a) => sum + (a["total_time_ms"] as double));
  }
  
  // Cloud Fallback
  const double minConfidence = 0.6;
  const double minCallsRatio = 0.7;
  final int numCalls = (res["function_calls"] as List).length;
  final double callsRatio = numCalls / max(1, expected);
  
  if ((res["confidence"] < minConfidence && callsRatio < minCallsRatio) || numCalls == 0) {
    final Map<String, dynamic> cloud = await _generateCloud(messages, tools);
    cloud["total_time_ms"] = (cloud["total_time_ms"] as double) + (res["total_time_ms"] as double);
    return cloud;
  }
  
  res["source"] = "on-device";
  return res;
}

//////////////////////////////////////////////////////////////
// FFI BINDINGS (STUBS)
//////////////////////////////////////////////////////////////

Future<dynamic> cactusInit(String path) async {
  print("Native Gemma Model Init: $path");
  return "PTR_GEMMA_01";
}

String cactusComplete(dynamic model, List<Map<String, dynamic>> messages, {List<Map<String, dynamic>>? tools, bool forceTools = false, double temperature = 0.0, int maxTokens = 128}) {
  final String input = messages.last['content'] as String;
  
  // Simulated responses for testing
  if (input.contains('photo')) {
    return '{"function_calls": [{"name": "search_photos", "arguments": {"query": "garden", "date": "yesterday"}}], "confidence": 0.9}';
  } else if (input.contains('file')) {
    return '{"function_calls": [{"name": "search_files", "arguments": {"query": "report", "file_type": "pdf"}}], "confidence": 0.9}';
  }
  return '{"function_calls": [], "confidence": 0.3}';
}

void cactusReset(dynamic model) {}
void cactusDestroy(dynamic model) {}

//////////////////////////////////////////////////////////////
// PUBLIC API FOR FLUTTER APP
//////////////////////////////////////////////////////////////

class FunctionGemmaService {
  static final FunctionGemmaService _instance = FunctionGemmaService._internal();
  factory FunctionGemmaService() => _instance;
  FunctionGemmaService._internal();
  
  bool _initialized = false;
  
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _getModel();
      _initialized = true;
    } catch (e) {
      print("Failed to initialize local model: $e.");
    }
  }
  
  Future<Map<String, dynamic>> processRequest(String qwenInput) async {
    final plan = await generateHybrid(qwenInput);
    
    final List<Map<String, dynamic>> results = [];
    final List calls = plan['function_calls'] ?? [];
    
    for (final call in calls) {
      if (call is Map<String, dynamic>) {
        final String name = (call['name'] ?? '').toString();
        final Map<String, dynamic> args = (call['arguments'] ?? {}) as Map<String, dynamic>;
        
        try {
          if (name == 'search_photos') {
            results.add(await _invokePhotosFunction(args));
          } else if (name == 'search_files') {
            results.add(await _invokeFilesFunction(args));
          } else {
            print("⚠️ Unknown function: $name");
          }
        } catch (e) {
          results.add({'error': 'Execution failed for $name', 'details': e.toString()});
        }
      }
    }
    
    return {
      'qwen_input': qwenInput,
      'gemma_plan': plan,
      'execution_results': results,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  Future<Map<String, dynamic>> _invokePhotosFunction(Map<String, dynamic> arguments) async {
    print("📷 Route: Invoking Photos Function with: $arguments");
    return {
      'status': 'invoked',
      'type': 'photo_action',
      'arguments': arguments,
    };
  }

  Future<Map<String, dynamic>> _invokeFilesFunction(Map<String, dynamic> arguments) async {
    print("📂 Route: Invoking File Function with: $arguments");
    return {
      'status': 'invoked',
      'type': 'file_action',
      'arguments': arguments,
    };
  }

  void dispose() {
    if (_functionGemmaModel != null) {
      cactusDestroy(_functionGemmaModel);
      _functionGemmaModel = null;
      _initialized = false;
    }
  }
}
