import 'package:flutter/material.dart';

void main() {
  runApp(const FileChatApp());
}

class FileChatApp extends StatelessWidget {
  const FileChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Altf4 Workspace',
      debugShowCheckedModeBanner: false,
      // 1. Set the overall app theme to Dark Mode
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Deep background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Slightly lighter Indigo for dark mode
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
  }

  // ==============================
  // SIDEBAR WIDGET (DARK)
  // ==============================
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Elevated dark surface
        border: Border(
          right: BorderSide(color: Color(0xFF333333), width: 1), // Subtle dark border
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
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.hub, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Altf4 Space',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
              border: Border(top: BorderSide(color: Color(0xFF333333))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade800,
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                const Text('Admin User', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
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
        color: isSelected ? const Color(0xFF2D2D30) : Colors.transparent, // Highlight color
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade400, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade400,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {},
      ),
    );
  }

  // ==============================
  // MAIN BUILD METHOD
  // ==============================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF1E1E1E),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFF333333)),
              ),
              title: const Text(
                'Altf4 Space',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
          
      drawer: isMobile ? Drawer(backgroundColor: const Color(0xFF1E1E1E), child: _buildSidebar()) : null,
      
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),

          Expanded(
            child: Column(
              children: [
                // Top Search Header
                if (!isMobile)
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF333333))),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey.shade500),
                        const SizedBox(width: 12),
                        Text(
                          'Search your files...',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                // Chat History
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index], isMobile);
                    },
                  ),
                ),

                // Dark Input Area
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16.0 : 32.0, 
                    vertical: isMobile ? 16.0 : 24.0
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E), // Dark input background
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2), // Stronger shadow for dark mode
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white), // White typing text
                            decoration: InputDecoration(
                              hintText: isMobile ? 'Ask for a file...' : 'Ask for a file, folder, or image...',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            onSubmitted: _handleSubmitted,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded),
                          color: const Color(0xFF6366F1),
                          onPressed: () => _handleSubmitted(_textController.text),
                        ),
                        const SizedBox(width: 8),
                      ],
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
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser && !isMobile) ...[
            CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
              child: const Icon(Icons.memory, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 16),
          ],
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: isMobile ? 300 : 550),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF4F46E5) : const Color(0xFF1E1E1E), // Dark system bubble
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg['text'],
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white, // All text inside bubbles is white now
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
          
          if (isUser && !isMobile) ...[
            const SizedBox(width: 16),
            CircleAvatar(
              backgroundColor: Colors.grey.shade700,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> msg, bool isMobile) {
    final isImage = msg['type'] == 'image';
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212), // Darker inset for the file card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: isImage ? Colors.purple.withOpacity(0.2) : Colors.red.withOpacity(0.2), // Tinted dark bg
              borderRadius: BorderRadius.circular(8),
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
          IconButton(
            icon: const Icon(Icons.download_rounded),
            iconSize: 20,
            color: Colors.grey.shade400,
            onPressed: () {}, 
          )
        ],
      ),
    );
  }
}