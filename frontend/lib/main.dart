import 'dart:ui';
import 'package:flutter/material.dart';

// ── Planner imports ────────────────────────────────────────────────────────
import 'planner/agent_pipeline.dart';
import 'planner/agent_service.dart';


void main() {
  runApp(const FileChatApp());
}

class FileChatApp extends StatelessWidget {
  const FileChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FxnGemma Workspace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const ChatLayoutScreen(),
    );
  }
}

class ChatLayoutScreen extends StatefulWidget {
  const ChatLayoutScreen({super.key});

  @override
  State<ChatLayoutScreen> createState() => _ChatLayoutScreenState();
}

class _ChatLayoutScreenState extends State<ChatLayoutScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  // ── Planner pipeline ──────────────────────────────────────────────────────
  final AgentPipeline _planner = AgentPipeline();
  bool _plannerReady = false;
  double? _downloadProgress;
  String _statusMessage = 'Starting up...';

  @override
  void initState() {
    super.initState();
    _initPlanner();
  }

  @override
  void dispose() {
    _planner.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Planner init ──────────────────────────────────────────────────────────
  Future<void> _initPlanner() async {
    // Listen to pipeline state changes to drive the UI status banner
    _planner.addListener(() {
      final s = _planner.state;
      setState(() {
        _downloadProgress = s.downloadProgress;
        _statusMessage = s.statusMessage ?? '';
        _plannerReady = s.status == AgentPipelineStatus.ready;
      });
    });

    await _planner.initialize();
  }

  // ── Send a message through the real planner ───────────────────────────────
  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty || !_plannerReady) return;
    _textController.clear();

    setState(() {
      _messages.add({'isUser': true, 'text': text, 'type': 'text'});
      // Optimistic "thinking" bubble while the model runs
      _messages.add({'isUser': false, 'text': '', 'type': 'thinking'});
    });
    _scrollToBottom();

    // ── Agent: FunctionGemma (tool) → Qwen3-1.7b (conversation) ──────────────
    final response = await _planner.process(text);

    setState(() {
      _messages.removeWhere((m) => m['type'] == 'thinking');

      if (response.type == AgentResponseType.conversation) {
        // Qwen3-1.7b handled it — plain conversational reply
        _messages.add({
          'isUser': false,
          'text': response.chatMessage,
          'type': 'text',
        });
      } else {
        // FunctionGemma called a tool
        _messages.add({
          'isUser': false,
          'text': response.chatMessage, // ack message e.g. "Searching for resume..."
          'type': 'text',
        });

        // Show tool result card based on which tool was called
        _messages.add(_buildToolResultCard(response));
      }
    });

    _scrollToBottom();
  }

  // ── Build result card based on tool name ─────────────────────────────────

  Map<String, dynamic> _buildToolResultCard(AgentResponse response) {
    final tool = response.toolName ?? '';
    final args = response.toolArguments ?? {};

    if (tool.startsWith('search_files')) {
      final query = args['query'] ?? args['mime_type'] ?? 'document';
      return {
        'isUser': false,
        'text': 'Best match for "$query":',
        'type': 'file',
        'fileName': '${query}_2024.pdf',
        'fileSize': '842 KB',
        'toolUsed': tool,
      };
    }

    if (tool.startsWith('search_photos')) {
      return {
        'isUser': false,
        'text': 'Closest matching photo:',
        'type': 'image',
        'imageUrl': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop',
        'toolUsed': tool,
      };
    }

    if (tool.startsWith('toggle_') || tool == 'open_app' || tool == 'get_battery_status') {
      return {
        'isUser': false,
        'text': 'Done.',
        'type': 'automation',
        'toolsRan': tool,
        'arguments': args,
      };
    }

    if (tool == 'read_clipboard') {
      return {
        'isUser': false,
        'text': 'Clipboard contents:',
        'type': 'clipboard',
        'content': '— clipboard read placeholder —',
      };
    }

    return {
      'isUser': false,
      'text': 'Done.',
      'type': 'tool_result',
      'toolsRan': tool,
    };
  }

  // ── Scroll helper ─────────────────────────────────────────────────────────
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Full-screen image viewer ──────────────────────────────────────────────
  void _showExpandedImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.expand(),
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF16161A),
        border: Border(right: BorderSide(color: Color(0xFF2A2A35), width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 24),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 8)
                    ],
                  ),
                  child: const Icon(Icons.hub, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('GP Console',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
          // ── Model status indicator ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildModelStatus(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              children: [
                _buildSidebarItem(Icons.chat_bubble_outline, 'General Purpose', true),
                _buildSidebarItem(Icons.folder_open, 'DB: Files', false),
                _buildSidebarItem(Icons.image_outlined, 'DB: Photos', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows model loading / download progress in the sidebar.
  Widget _buildModelStatus() {
    if (_plannerReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: Colors.greenAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text('Planner ready',
                style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_downloadProgress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              minHeight: 2,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 4),
            Text(
              '${((_downloadProgress ?? 0) * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: Colors.white.withOpacity(0.1))
            : null,
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected ? Colors.white : Colors.grey.shade500, size: 22),
        title: Text(title,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade500,
                fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF16161A),
              elevation: 0,
              title: const Text('GP Console',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      drawer: isMobile
          ? Drawer(
              backgroundColor: const Color(0xFF16161A),
              child: _buildSidebar())
          : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _messages.isEmpty && !_plannerReady
                      ? _buildLoadingScreen()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            left: isMobile ? 16.0 : 32.0,
                            right: isMobile ? 16.0 : 32.0,
                            top: isMobile ? 16.0 : 32.0,
                            bottom: 120.0,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) =>
                              _buildMessageBubble(_messages[index], isMobile),
                        ),
                ),
                // ── Input bar ─────────────────────────────────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16.0 : 32.0,
                            vertical: isMobile ? 16.0 : 24.0),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0F0F13).withOpacity(0.6),
                          border: Border(
                              top: BorderSide(
                                  color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _plannerReady
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(30.0),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 20),
                              Icon(Icons.auto_awesome,
                                  color: _plannerReady
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.grey.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  enabled: _plannerReady,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: _plannerReady
                                        ? 'Ask your assistant...'
                                        : _statusMessage,
                                    hintStyle: TextStyle(
                                        color: Colors.grey.shade500),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 18),
                                  ),
                                  onSubmitted: _handleSubmitted,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.send_rounded,
                                    color: _plannerReady
                                        ? const Color(0xFF6366F1)
                                        : Colors.grey.shade700),
                                onPressed: _plannerReady
                                    ? () =>
                                        _handleSubmitted(_textController.text)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Full-screen loading / download state ─────────────────────────────────
  Widget _buildLoadingScreen() {
    final isDownloading = _downloadProgress != null;
    final percent = ((_downloadProgress ?? 0) * 100).toStringAsFixed(0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 20)
                ],
              ),
              child: Icon(
                isDownloading ? Icons.download : Icons.memory,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 28),

            // Title
            Text(
              isDownloading ? 'Downloading Model' : 'Initializing Model',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),

            // Status message (e.g. "Downloading qwen3-0.6b...")
            Text(
              _statusMessage,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // ── Download progress bar ─────────────────────────────────────
            if (isDownloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                  Text('$percent%',
                      style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1)),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 10),
              // MB downloaded / total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${((_downloadProgress ?? 0) * _modelTotalMb).toStringAsFixed(0)} MB',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11),
                  ),
                  Text(
                    '~$_modelTotalMb MB total',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            ] else ...[
              // Indeterminate spinner while model initializes (post-download)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading weights into memory...',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              Text(
                'Takes ~10–20s on first run',
                style:
                    TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
            ],

            const SizedBox(height: 32),

            // Info footer
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.grey.shade600, size: 14),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isDownloading
                          ? 'Downloaded once — cached on device after this'
                          : 'Model stays loaded between conversations',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Change this to match your model slug:
  ///   gemma3-270m  → 270
  ///   qwen3-0.6b   → 400
  ///   qwen3-1.7b   → 1100
  static const int _modelTotalMb = 400;

  // ── Message bubble dispatcher ─────────────────────────────────────────────
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMobile) {
    final isUser = msg['isUser'] as bool;

    return Padding(
      padding: EdgeInsets.only(
          bottom: 24.0,
          top: _messages.indexOf(msg) == 0 && !isMobile ? 20.0 : 0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser && !isMobile) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.memory, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
          ],
          Flexible(
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: isMobile ? 300 : 550),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                    : null,
                color: isUser ? null : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: _buildMessageContent(msg, isMobile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> msg, bool isMobile) {
    final type = msg['type'] as String;

    switch (type) {
      // ── Thinking indicator ──────────────────────────────────────────────
      case 'thinking':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _buildDot(i)),
        );

      // ── Plain text + optional intent badge ──────────────────────────────
      case 'text':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['text'] as String,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.4)),
            if (msg['intent'] != null && msg['intent'] != 'generalQuestion') ...[
              const SizedBox(height: 10),
              _buildIntentBadge(msg['intent'] as String,
                  msg['confidence'] as double? ?? 0.0),
            ],
          ],
        );

      // ── File card ────────────────────────────────────────────────────────
      case 'file':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['text'] as String,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.4)),
            const SizedBox(height: 16),
            _buildClickableFile(msg, isMobile),
            if (msg['toolUsed'] != null)
              _buildToolBadge(msg['toolUsed'] as String),
          ],
        );

      // ── Image card ───────────────────────────────────────────────────────
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['text'] as String,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.4)),
            const SizedBox(height: 16),
            _buildClickableImage(msg['imageUrl'] as String),
            if (msg['toolUsed'] != null)
              _buildToolBadge(msg['toolUsed'] as String),
          ],
        );

      // ── Automation result ────────────────────────────────────────────────
      case 'automation':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['text'] as String,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.4)),
            const SizedBox(height: 12),
            _buildAutomationCard(
              toolsRan: msg['toolsRan'] as String,
              arguments: msg['arguments'] as Map<String, dynamic>? ?? {},
            ),
          ],
        );

      // ── Clipboard result ─────────────────────────────────────────────────
      case 'clipboard':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['text'] as String,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text(msg['content'] as String,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.grey.shade300,
                      fontSize: 13)),
            ),
          ],
        );

      // ── Generic tool result ──────────────────────────────────────────────
      case 'tool_result':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['text'] as String,
                style: const TextStyle(
                    fontSize: 15, color: Colors.white, height: 1.4)),
            const SizedBox(height: 12),
            _buildToolBadge(msg['toolsRan'] as String? ?? ''),
          ],
        );

      default:
        return Text(msg['text'] as String? ?? '',
            style: const TextStyle(
                fontSize: 15, color: Colors.white, height: 1.4));
    }
  }

  // ── Thinking dots animation ───────────────────────────────────────────────
  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            color: Color(0xFF8B5CF6), shape: BoxShape.circle),
      ),
    );
  }

  // ── Intent badge (shown under planner's chat_response) ───────────────────
  Widget _buildIntentBadge(String intent, double confidence) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
          ),
          child: Text(
            intent.replaceAll('_', ' '),
            style: const TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(confidence * 100).toStringAsFixed(0)}% conf.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        ),
      ],
    );
  }

  // ── Tool badge (shown under tool results) ────────────────────────────────
  Widget _buildToolBadge(String toolName) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.functions,
                color: Colors.grey.shade500, size: 11),
            const SizedBox(width: 5),
            Text(toolName,
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                    fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  // ── Automation result card ───────────────────────────────────────────────
  Widget _buildAutomationCard(
      {required String toolsRan,
      required Map<String, dynamic> arguments}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.greenAccent.shade400, size: 16),
              const SizedBox(width: 8),
              Text('Executed: $toolsRan',
                  style: TextStyle(
                      color: Colors.greenAccent.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (arguments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...arguments.entries.map(
              (e) => Text('${e.key}: ${e.value}',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ),
          ],
        ],
      ),
    );
  }

  // ── Clickable file card (unchanged from original) ────────────────────────
  Widget _buildClickableFile(Map<String, dynamic> msg, bool isMobile) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening ${msg['fileName']}...'),
            backgroundColor: const Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              height: 48, width: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.red.shade400.withOpacity(0.2),
                  Colors.red.shade600.withOpacity(0.2)
                ]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Icon(Icons.picture_as_pdf, color: Colors.red.shade300),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg['fileName'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(msg['fileSize'] as String,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.open_in_new,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Clickable image that enlarges (unchanged from original) ─────────────
  Widget _buildClickableImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showExpandedImage(context, imageUrl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                      height: 200,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF8B5CF6))));
                },
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle),
                child: const Icon(Icons.zoom_in,
                    color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}