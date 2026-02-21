import 'dart:ui';
import 'package:flutter/material.dart';

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

  // ==========================================
  // HACKATHON MOCK BACKEND (GP -> FxnGemma)
  // ==========================================
  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();

    setState(() {
      // 1. User sends message to GP
      _messages.add({'isUser': true, 'text': text, 'type': 'text'});

      // 2. FxnGemma routes the request based on context
      if (text.toLowerCase().contains('image') || text.toLowerCase().contains('photo')) {
        // Simulates FxnGemma calling photo(args) -> DB Photo
        _messages.add({
          'isUser': false,
          'text': 'Here is the image from the photo database:',
          'type': 'image',
          // Using a placeholder image for the hackathon UI demo
          'imageUrl': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop', 
        });
      } else {
        // Simulates FxnGemma calling file(args) -> DB Files
        _messages.add({
          'isUser': false,
          'text': 'I retrieved this file from the database:',
          'type': 'file',
          'fileName': 'FxnGemma_Architecture.pdf',
          'fileSize': '1.2 MB',
        });
      }
    });

    // Auto-scroll to bottom
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

  // ==========================================
  // FEATURE: FULL SCREEN IMAGE VIEWER
  // ==========================================
  void _showExpandedImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Backdrop filter to blur the chat behind the image
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.expand(),
            ),
            // Interactive viewer allows pinch-to-zoom on iOS/Android!
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            // Close button
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

  // ==========================================
  // UI BUILDERS
  // ==========================================
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
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 8)]
                  ),
                  child: const Icon(Icons.hub, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('GP Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
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

  Widget _buildSidebarItem(IconData icon, String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade500, size: 22),
        title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade500, fontSize: 14)),
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
              title: const Text('GP Console', style: TextStyle(color: Colors.white, fontSize: 16)),
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      drawer: isMobile ? Drawer(backgroundColor: const Color(0xFF16161A), child: _buildSidebar()) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      left: isMobile ? 16.0 : 32.0,
                      right: isMobile ? 16.0 : 32.0,
                      top: isMobile ? 16.0 : 32.0,
                      bottom: 120.0, 
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index], isMobile),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 32.0, vertical: isMobile ? 16.0 : 24.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F13).withOpacity(0.6),
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(30.0),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 20),
                              const Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Prompt GP to call FxnGemma...',
                                    hintStyle: TextStyle(color: Colors.grey.shade500),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                                  ),
                                  onSubmitted: _handleSubmitted,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
                                onPressed: () => _handleSubmitted(_textController.text),
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

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMobile) {
    final isUser = msg['isUser'];

    return Padding(
      padding: EdgeInsets.only(bottom: 24.0, top: _messages.indexOf(msg) == 0 && !isMobile ? 20.0 : 0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              constraints: BoxConstraints(maxWidth: isMobile ? 300 : 550),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: isUser ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]) : null,
                color: isUser ? null : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg['text'], style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4)),
                  
                  // ROUTE: Render Document
                  if (msg['type'] == 'file') ...[
                    const SizedBox(height: 16),
                    _buildClickableFile(msg, isMobile),
                  ],

                  // ROUTE: Render Image
                  if (msg['type'] == 'image') ...[
                    const SizedBox(height: 16),
                    _buildClickableImage(msg['imageUrl']),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FEATURE 1: CLICKABLE FILE
  Widget _buildClickableFile(Map<String, dynamic> msg, bool isMobile) {
    return GestureDetector(
      onTap: () {
        // Handle file click! For hackathon, we show a snackbar.
        // You can replace this with code to download or open the file.
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
                gradient: LinearGradient(colors: [Colors.red.shade400.withOpacity(0.2), Colors.red.shade600.withOpacity(0.2)]),
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
                  Text(msg['fileName'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(msg['fileSize'], style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  // FEATURE 2: CLICKABLE IMAGE THAT ENLARGES
  Widget _buildClickableImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showExpandedImage(context, imageUrl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
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
                // Loading builder makes it look professional if the internet is slow during the demo
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 200, 
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                  );
                },
              ),
              // Add a subtle magnifying glass icon overlay
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}