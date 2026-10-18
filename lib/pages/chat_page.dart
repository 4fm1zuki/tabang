import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final bool isDark;

  const ChatPage({super.key, required this.isDark});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int _selectedChatIndex = 0;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  final List<Map<String, dynamic>> _chats = [
    {
      'id': 'D801',
      'name': 'Donor #801',
      'initials': 'D801',
      'lastDonation': 'August 12, 2026',
      'totalDonations': 4,
      'status': 'Eligible',
      'location': 'Zone 1 (Pob.), Digos City',
      'isBlocked': false,
      'unblockedAt': null, // DateTime timestamp when unblocked
      'messages': [
        {'sender': 'them', 'text': 'Hello! I saw your urgent request for blood.', 'time': '17:28'},
        {'sender': 'me', 'text': 'Hi! Yes, we are currently looking for a donor at Digos Medical Center.', 'time': '17:29'},
        {'sender': 'them', 'text': 'I am available for donation tomorrow morning.', 'time': '17:30'},
      ],
    },
    {
      'id': 'U209',
      'name': 'User #209',
      'initials': 'U209',
      'lastDonation': 'N/A',
      'totalDonations': 0,
      'status': 'Recipient',
      'location': 'Digos City',
      'isBlocked': false,
      'unblockedAt': null,
      'messages': [
        {'sender': 'them', 'text': 'Thank you so much for responding to the request!', 'time': '16:45'},
      ],
    },
    {
      'id': 'D088',
      'name': 'Donor #088',
      'initials': 'D088',
      'lastDonation': 'June 10, 2026',
      'totalDonations': 2,
      'status': 'Eligible',
      'location': 'Tres de Mayo, Digos City',
      'isBlocked': false,
      'unblockedAt': null,
      'messages': [
        {'sender': 'them', 'text': 'What hospital are you currently located at?', 'time': '15:20'},
      ],
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final activeChat = _chats[_selectedChatIndex];
    if (activeChat['isBlocked'] == true) return;

    final now = TimeOfDay.now();
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      (activeChat['messages'] as List).add({
        'sender': 'me',
        'text': text,
        'time': formattedTime,
      });
      _messageController.clear();
    });
  }

  void _toggleBlockStatus(Map<String, dynamic> user) {
    final isCurrentlyBlocked = user['isBlocked'] == true;

    // Enforcement of 48-hour re-block rule
    if (isCurrentlyBlocked == false && user['unblockedAt'] != null) {
      final unblockTime = user['unblockedAt'] as DateTime;
      final timePassed = DateTime.now().difference(unblockTime);
      const cooldownPeriod = Duration(hours: 48);

      if (timePassed < cooldownPeriod) {
        final remaining = cooldownPeriod - timePassed;
        final hoursLeft = remaining.inHours;
        final minutesLeft = remaining.inMinutes.remainder(60);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Block User'),
            content: Text(
              'You recently unblocked ${user['name']}. To prevent harassment, you must wait 48 hours before you can block them again.\n\nTime remaining: ${hoursLeft}h ${minutesLeft}m.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() {
      if (isCurrentlyBlocked) {
        // Unblocking the user and setting timestamp
        user['isBlocked'] = false;
        user['unblockedAt'] = DateTime.now();
      } else {
        // Blocking the user
        user['isBlocked'] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCurrentlyBlocked
              ? 'Unblocked ${user['name']}. You must wait 48 hours before you can block them again.'
              : 'You blocked ${user['name']}. You can no longer message each other.',
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, Map<String, dynamic> user) {
    String? selectedReason;
    final TextEditingController otherReasonController = TextEditingController();
    final reasons = [
      'Spam or Scam',
      'Inappropriate messages',
      'Harassment or Bullying',
      'Fake donor / recipient profile',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isOtherSelected = selectedReason == 'Other';
            final canSubmit = selectedReason != null &&
                (!isOtherSelected || otherReasonController.text.trim().isNotEmpty);

            return AlertDialog(
              title: const Text('Report User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select a reason for reporting ${user['name']}:'),
                    const SizedBox(height: 12),
                    ...reasons.map((reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 13)),
                      value: reason,
                      groupValue: selectedReason,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setModalState(() {
                          selectedReason = val;
                        });
                      },
                    )),
                    if (isOtherSelected) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherReasonController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Please specify the reason...',
                          hintStyle: TextStyle(fontSize: 12),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: canSubmit
                      ? () {
                    // "Are you sure?" confirmation dialog
                    showDialog(
                      context: context,
                      builder: (confirmContext) {
                        return AlertDialog(
                          title: const Text('Confirm Report'),
                          content: Text('Are you sure you want to submit this report against ${user['name']}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmContext),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(confirmContext);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Report submitted for ${user['name']}.')),
                                );
                              },
                              child: const Text('Yes, Report'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                      : null,
                  child: const Text('Next'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProfileModal(BuildContext context, Map<String, dynamic> user) {
    final cardBg = widget.isDark ? const Color(0xFF242424) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final borderColor = widget.isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A1212),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user['initials'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ALIAS: ${user['name']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.favorite,
                      title: 'Total Donations',
                      value: '${user['totalDonations']}',
                      borderColor: borderColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.calendar_today,
                      title: 'Last Donated',
                      value: '${user['lastDonation']}',
                      borderColor: borderColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.verified_user,
                      title: 'Status',
                      value: '${user['status']}',
                      borderColor: borderColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Contact & Location Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: ListTile(
                  leading: Icon(Icons.location_on_outlined, color: textColor.withOpacity(0.7)),
                  title: Text(
                    'Barangay / Location',
                    style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.55)),
                  ),
                  subtitle: Text(
                    '${user['location']}',
                    style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color borderColor,
  }) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD32F2F), size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.55)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final cardBg = widget.isDark ? const Color(0xFF242424) : Colors.white;
    final listBg = widget.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF7F7F7);
    final borderColor = widget.isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0);
    final selectedTileBg = widget.isDark ? const Color(0xFF2D2D2D) : const Color(0xFFEBEBEB);

    final filteredChats = _chats.where((chat) {
      final query = _searchQuery.toLowerCase();
      final nameMatches = (chat['name'] as String).toLowerCase().contains(query);
      final idMatches = (chat['id'] as String).toLowerCase().contains(query);
      return nameMatches || idMatches;
    }).toList();

    final activeChat = _chats.isNotEmpty && _selectedChatIndex < _chats.length
        ? _chats[_selectedChatIndex]
        : null;
    final List messages = activeChat != null ? activeChat['messages'] : [];
    final isBlocked = activeChat != null && activeChat['isBlocked'] == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: listBg,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: textColor),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search donor/recipient ID...',
                        hintStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, size: 18, color: textColor.withOpacity(0.6)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                          child: Icon(Icons.clear, size: 16, color: textColor.withOpacity(0.6)),
                        )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Chat List
                Expanded(
                  child: filteredChats.isEmpty
                      ? Center(
                    child: Text(
                      'No chats found',
                      style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
                    ),
                  )
                      : ListView.builder(
                    itemCount: filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final originalIndex = _chats.indexOf(chat);
                      final isSelected = originalIndex == _selectedChatIndex;
                      final chatMsgs = chat['messages'] as List;
                      final recentMsg = chatMsgs.isNotEmpty ? chatMsgs.last : null;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedChatIndex = originalIndex;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? selectedTileBg : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(color: borderColor.withOpacity(0.5), width: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4A1212),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    chat['initials']!,
                                    style: const TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chat['name']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      recentMsg != null ? recentMsg['text'] : '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textColor.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (recentMsg != null)
                                Text(
                                  recentMsg['time'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textColor.withOpacity(0.45),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Chat Area
          Expanded(
            child: activeChat == null
                ? Center(
              child: Text(
                'Select a conversation to start messaging',
                style: TextStyle(color: textColor.withOpacity(0.5)),
              ),
            )
                : Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A1212),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            activeChat['initials']!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeChat['name']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            isBlocked ? 'Blocked' : 'Online',
                            style: TextStyle(
                              fontSize: 11,
                              color: isBlocked ? Colors.red : Colors.green.shade400,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.phone_outlined, size: 20),
                        color: textColor.withOpacity(0.7),
                        onPressed: () {},
                      ),

                      // Popup Menu Options
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 20, color: textColor.withOpacity(0.7)),
                        color: cardBg,
                        onSelected: (value) {
                          if (value == 'Profile') {
                            _showProfileModal(context, activeChat);
                          } else if (value == 'Block' || value == 'Unblock') {
                            _toggleBlockStatus(activeChat);
                          } else if (value == 'Report') {
                            _showReportDialog(context, activeChat);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'Profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: 18, color: textColor),
                                const SizedBox(width: 10),
                                Text('Profile', style: TextStyle(color: textColor, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: isBlocked ? 'Unblock' : 'Block',
                            child: Row(
                              children: [
                                Icon(
                                  isBlocked ? Icons.check_circle_outline : Icons.block_outlined,
                                  size: 18,
                                  color: textColor,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isBlocked ? 'Unblock' : 'Block',
                                  style: TextStyle(color: textColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'Report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 18, color: textColor),
                                const SizedBox(width: 10),
                                Text('Report', style: TextStyle(color: textColor, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Messages List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender'] == 'me';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 380),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFD32F2F) : cardBg,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
                            ),
                            border: isMe ? null : Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['text']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isMe ? Colors.white : textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  msg['time']!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white.withOpacity(0.7)
                                        : textColor.withOpacity(0.45),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Message Input Bar or Block Banner
                if (isBlocked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: cardBg,
                    child: Center(
                      child: Text(
                        'You have blocked ${activeChat['name']}. You cannot send or receive messages.',
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.mic_none_outlined, size: 20),
                          color: textColor.withOpacity(0.6),
                          onPressed: () {},
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: listBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: borderColor),
                            ),
                            child: TextField(
                              controller: _messageController,
                              style: TextStyle(fontSize: 13, color: textColor),
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, size: 20),
                          color: const Color(0xFFD32F2F),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}