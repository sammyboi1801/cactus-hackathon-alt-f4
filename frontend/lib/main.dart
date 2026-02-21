import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';

void main() {
  runApp(const FileChatApp());
}

class FileChatApp extends StatelessWidget {
  const FileChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALT+F4',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13), // Deeper, richer dark background
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

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'type': 'text',
      });

      if (text.toLowerCase().contains('image')) {
        _messages.add({
          'isUser': false,
          'text': 'I found this image in your "Design" folder:',
          'type': 'image',
          'fileName': 'hero_background.png',
          'fileSize': '2.4 MB',
        });
      } else {
        _messages.add({
          'isUser': false,
          'text': 'Here is the document you requested:',
          'type': 'file',
          'fileName': 'Q3_Financial_Report.pdf',
          'fileSize': '845 KB',
        });
      }
    });

    // Auto-scroll to the bottom when a new message is added
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

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF16161A), 
        border: Border(
          right: BorderSide(color: Color(0xFF2A2A35), width: 1), 
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 24),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: const Icon(Icons.hub, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Altf4 Space',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              children: [
                _buildSidebarItem(Icons.folder_open, 'All Projects', true),
                _buildSidebarItem(Icons.image_outlined, 'Assets & Images', false),
                _buildSidebarItem(Icons.description_outlined, 'Documents', false),
                _buildSidebarItem(Icons.code, 'Source Code', false),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF2A2A35))),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withOpacity(0.3),
                        blurRadius: 8,
                      )
                    ]
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Text('GT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Galgotiya', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          )
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
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade500,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF16161A),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFF2A2A35)),
              ),
              title: const Text(
                'Altf4 Space',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
                // 1. Chat History ListView
                Positioned.fill(
                  child: ListView.builder(
                    controller: _scrollController,
                    // Add massive bottom padding so the last message isn't hidden behind the floating input
                    padding: EdgeInsets.only(
                      left: isMobile ? 16.0 : 32.0,
                      right: isMobile ? 16.0 : 32.0,
                      top: isMobile ? 16.0 : 32.0,
                      bottom: 120.0, 
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index], isMobile);
                    },
                  ),
                ),

                // 2. Glassmorphism Floating Input Area
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16.0 : 32.0, 
                          vertical: isMobile ? 16.0 : 24.0
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F13).withOpacity(0.6), // Translucent backdrop
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05), // Frosted glass input box
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
                                    hintText: isMobile ? 'Ask for a file...' : 'Ask for a file, folder, or image...',
                                    hintStyle: TextStyle(color: Colors.grey.shade500),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                                  ),
                                  onSubmitted: _handleSubmitted,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withOpacity(0.3),
                                      blurRadius: 8,
                                    )
                                  ]
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.send_rounded),
                                  color: Colors.white,
                                  onPressed: () => _handleSubmitted(_textController.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Top Header (Absolute positioned so it stays at the top)
                if (!isMobile)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          height: 70,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F13).withOpacity(0.6),
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey.shade500),
                              const SizedBox(width: 12),
                              Text(
                                'Search your workspace...',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                            ],
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
      padding: EdgeInsets.only(
        bottom: 24.0, 
        top: _messages.indexOf(msg) == 0 && !isMobile ? 80.0 : 0 // Push first message down below header
      ),
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
                // User gets a gradient, System gets a frosted glass look
                gradient: isUser ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
                color: isUser ? null : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: isUser ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ] : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg['text'],
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  if (msg['type'] == 'file' || msg['type'] == 'image') ...[
                    const SizedBox(height: 16),
                    _buildFileAttachment(msg, isMobile),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> msg, bool isMobile) {
    final isImage = msg['type'] == 'image';
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2), // Darker inset
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isImage 
                  ? [Colors.purple.shade400.withOpacity(0.2), Colors.purple.shade600.withOpacity(0.2)]
                  : [Colors.red.shade400.withOpacity(0.2), Colors.red.shade600.withOpacity(0.2)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isImage ? Colors.purple.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
            ),
            child: Icon(
              isImage ? Icons.image : Icons.picture_as_pdf,
              color: isImage ? Colors.purple.shade300 : Colors.red.shade300,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg['fileName'],
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  msg['fileSize'],
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.download_rounded),
              iconSize: 20,
              color: Colors.white,
              onPressed: () {}, 
            ),
          )
        ],
      ),
    );
  }
}