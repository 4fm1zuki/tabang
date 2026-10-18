import 'package:flutter/material.dart';
import 'admin_data/chat_moderation_service.dart';

class ChatModerationPage extends StatefulWidget {
  final bool isDark;

  const ChatModerationPage({super.key, required this.isDark});

  @override
  State<ChatModerationPage> createState() => _ChatModerationPageState();
}

class _ChatModerationPageState extends State<ChatModerationPage> {
  late List<ChatSession> _chatSessions;
  ChatSession? _selectedSession;
  String _searchQuery = '';
  bool _showOnlyFlagged = false;

  @override
  void initState() {
    super.initState();
    _chatSessions = ChatModerationService.getInitialChatSessions();
    if (_chatSessions.isNotEmpty) {
      _selectedSession = _chatSessions.first;
    }
  }

  // Action to Mute/Unmute Chat Room
  void _toggleMuteChatRoom(ChatSession session) {
    setState(() {
      session.isMuted = !session.isMuted;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(session.isMuted
            ? 'Chat room ${session.chatRoomId} muted. Users cannot send new messages.'
            : 'Chat room ${session.chatRoomId} unmuted.'),
        backgroundColor: session.isMuted ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
      ),
    );
  }

  // Action to Red Flag / Warn Message
  void _updateMessageFlag(ChatMessage message, ModerationFlag newFlag) {
    setState(() {
      message.flag = newFlag;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message ${message.messageId} status updated to ${newFlag.name.toUpperCase()}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filtering logic for chat session list
    final filteredSessions = _chatSessions.where((session) {
      final matchesSearch = session.recipientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.donorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.barangay.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.chatRoomId.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFlag = !_showOnlyFlagged || session.hasFlaggedMessages;

      return matchesSearch && matchesFlag;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title Header
            _buildPageHeader(theme),
            const SizedBox(height: 20),

            // Main Split-View Console (Left: Chat Session List, Right: Live Log Viewer)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    // LEFT PANEL: Chat Rooms Sidebar
                    SizedBox(
                      width: 320,
                      child: _buildChatSessionList(filteredSessions, theme),
                    ),
                    VerticalDivider(width: 1, color: theme.dividerColor.withOpacity(0.15)),

                    // RIGHT PANEL: Chat Inspection & Moderation Controls
                    Expanded(
                      child: _selectedSession == null
                          ? const Center(child: Text('Select a chat room to view log history.'))
                          : _buildChatLogViewer(_selectedSession!, theme),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat Moderation & Logs',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitor participant communication, audit reported messages, and enforce chat policy restrictions.',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // LEFT PANEL: CHAT SESSION LIST
  // ===========================================================================
  Widget _buildChatSessionList(List<ChatSession> sessions, ThemeData theme) {
    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search chat room, user...',
                  hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark ? theme.colorScheme.surface : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _showOnlyFlagged,
                    activeColor: const Color(0xFF7A1C1E),
                    onChanged: (val) {
                      if (val != null) setState(() => _showOnlyFlagged = val);
                    },
                  ),
                  const Text('Show only reported/flagged', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Chat List
        Expanded(
          child: sessions.isEmpty
              ? Center(
            child: Text(
              'No chat sessions found.',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          )
              : ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isSelected = _selectedSession?.chatRoomId == session.chatRoomId;

              return ListTile(
                selected: isSelected,
                selectedTileColor: const Color(0xFF7A1C1E).withOpacity(0.08),
                onTap: () => setState(() => _selectedSession = session),
                title: Row(
                  children: [
                    Text(
                      session.chatRoomId,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (session.hasFlaggedMessages)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('FLAGGED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.recipientName} ↔ ${session.donorName}',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${session.bloodType} • ${session.barangay}',
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // RIGHT PANEL: LIVE CHAT LOG & MODERATION ACTION VIEWER
  // ===========================================================================
  Widget _buildChatLogViewer(ChatSession session, ThemeData theme) {
    return Column(
      children: [
        // Top Inspection Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.15))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chat Room: ${session.chatRoomId}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Participants: ${session.recipientName} and ${session.donorName}',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _toggleMuteChatRoom(session),
                icon: Icon(session.isMuted ? Icons.volume_up : Icons.volume_off, size: 14),
                label: Text(session.isMuted ? 'Unmute Room' : 'Mute Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: session.isMuted ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // Chat Message Log Stream
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: session.messages.length,
            itemBuilder: (context, index) {
              final msg = session.messages[index];
              return _buildMessageBubble(msg, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, ThemeData theme) {
    final isFlagged = msg.flag != ModerationFlag.clean;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFlagged ? Colors.red.withOpacity(0.05) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFlagged ? Colors.red.withOpacity(0.4) : theme.dividerColor.withOpacity(0.15),
          width: isFlagged ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    msg.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A1C1E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      msg.senderRole,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7A1C1E)),
                    ),
                  ),
                ],
              ),
              Text(
                '${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg.text,
            style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Message Moderation Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFlagBadge(msg.flag),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _updateMessageFlag(msg, ModerationFlag.clean),
                    child: const Text('Mark Clean', style: TextStyle(fontSize: 11, color: Colors.green)),
                  ),
                  TextButton(
                    onPressed: () => _updateMessageFlag(msg, ModerationFlag.inappropriate),
                    child: const Text('Flag Violation', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlagBadge(ModerationFlag flag) {
    Color color;
    switch (flag) {
      case ModerationFlag.inappropriate:
        color = Colors.red;
        break;
      case ModerationFlag.spam:
        color = Colors.orange;
        break;
      case ModerationFlag.flagged:
        color = Colors.amber.shade800;
        break;
      case ModerationFlag.clean:
      default:
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(
        flag.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}