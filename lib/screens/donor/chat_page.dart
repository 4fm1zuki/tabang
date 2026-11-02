import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';

/// Messaging between donors and recipients.
///
/// Preserves the original two-pane layout and search. Messages, reports and
/// blocks persist in the repository. The double-blind rule from p.34 of the
/// paper is enforced bilaterally: one participant requests a reveal, the other
/// must accept before real names and contact details are shown. Reports appear
/// in the staff moderation queue, and a 48-hour re-block cooldown matches the
/// Help FAQ.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.user});

  final AppUser user;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final TextEditingController _composer = TextEditingController();
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _selectedThreadId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    _composer.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<ChatThread> get _threads {
    final all = _repo.threadsFor(widget.user.id);
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((t) {
      return _otherAlias(t).toLowerCase().contains(q) ||
          t.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();
  }

  String _otherAlias(ChatThread thread) {
    return thread.participantAId == widget.user.id
        ? thread.participantBAlias
        : thread.participantAAlias;
  }

  String _otherId(ChatThread thread) {
    return thread.participantAId == widget.user.id
        ? thread.participantBId
        : thread.participantAId;
  }

  AppUser? _otherUser(ChatThread thread) =>
      _repo.userById(_otherId(thread));

  /// Real names appear only after both participants consent. Until then the
  /// thread shows the alias from the paper's double-blind design.
  String _displayName(ChatThread thread) {
    final other = _otherUser(thread);
    if (thread.identityRevealed && other != null) return other.fullName;
    return _otherAlias(thread);
  }

  bool _blockedByMe(ChatThread thread) =>
      _repo.isBlocked(widget.user.id, _otherId(thread));

  bool _blockedByOther(ChatThread thread) =>
      _repo.isBlocked(_otherId(thread), widget.user.id);

  bool _isBlocked(ChatThread thread) =>
      _blockedByMe(thread) || _blockedByOther(thread);

  ChatThread? get _active {
    final threads = _threads;
    if (threads.isEmpty) return null;
    for (final t in threads) {
      if (t.id == _selectedThreadId) return t;
    }
    return threads.first;
  }

  void _send() {
    final thread = _active;
    final text = _composer.text.trim();
    if (thread == null || text.isEmpty) return;

    _repo.sendMessage(thread.id, widget.user.id, text);
    _composer.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final threads = _threads;
    final active = _active;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones get one pane at a time: the list, or a full-width thread with
        // a back button. Tablets and desktops keep the two-pane layout.
        final compact = constraints.maxWidth < 820;

        if (!compact) {
          return Row(
            children: [
              _buildThreadList(context, threads, width: 300),
              Expanded(
                child: active == null
                    ? const EmptyState(
                        art: TabangArt.messages,
                        title: 'No conversations yet',
                        message:
                            'A coordination thread is created after a requester '
                            'selects your response.',
                      )
                    : _buildConversation(context, active),
              ),
            ],
          );
        }

        final showConversation = _selectedThreadId != null && active != null;
        if (showConversation) {
          return _buildConversation(
            context,
            active,
            onBack: () => setState(() => _selectedThreadId = null),
          );
        }
        return _buildThreadList(context, threads);
      },
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    List<ChatThread> threads, {
    double? width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.surface,
        border: width == null
            ? null
            : Border(right: BorderSide(color: context.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(TabangSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: TabangSpace.sm),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search conversations',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          Expanded(
            child: threads.isEmpty
                ? const EmptyState(
                    art: TabangArt.search,
                    title: 'No conversations',
                  )
                : ListView.builder(
                    itemCount: threads.length,
                    itemBuilder: (context, i) =>
                        _buildThreadTile(context, threads[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadTile(BuildContext context, ChatThread thread) {
    final active = _active?.id == thread.id;
    final last = thread.lastMessage;

    return Material(
      color: active
          ? (context.isDark ? const Color(0xFF3A1917) : TabangColors.crimsonSoft)
          : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedThreadId = thread.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TabangSpace.lg,
            vertical: TabangSpace.md,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: TabangColors.crimson,
                child: Text(
                  _displayName(thread).substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayName(thread),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isBlocked(thread))
                          const Icon(Icons.block,
                              size: 12, color: TabangColors.danger),
                        if (thread.hasFlaggedMessages)
                          const StatusPill('!', tone: Tone.danger, dense: true),
                        if (thread.isMuted) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.volume_off,
                              size: 12, color: context.textMuted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last?.text ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One overflow menu for narrow screens: the header cannot fit the reveal,
  /// mute, report and block controls side by side on a phone.
  Widget _buildCompactConversationMenu(
    BuildContext context,
    ChatThread thread, {
    required bool blockedByMe,
    required bool blockedByOther,
    required bool requestedByMe,
    required bool requestedByOther,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Conversation options',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) {
        switch (value) {
          case 'accept':
            _acceptReveal(context, thread);
          case 'decline':
            _repo.declineIdentityReveal(thread.id, widget.user.id);
          case 'reveal':
            _requestReveal(context, thread);
          case 'mute':
            _repo.setThreadMuted(thread.id, !thread.isMuted);
          case 'report':
            _showReportDialog(context, thread);
          case 'block':
            _block(context, thread);
          case 'unblock':
            _unblock(context, thread);
        }
      },
      itemBuilder: (context) => [
        if (!thread.identityRevealed && requestedByOther) ...[
          const PopupMenuItem(value: 'accept', child: Text('Accept reveal')),
          const PopupMenuItem(value: 'decline', child: Text('Decline reveal')),
        ] else if (!thread.identityRevealed && !requestedByMe)
          const PopupMenuItem(value: 'reveal', child: Text('Request reveal')),
        PopupMenuItem(
          value: 'mute',
          child: Text(thread.isMuted ? 'Unmute' : 'Mute'),
        ),
        const PopupMenuItem(value: 'report', child: Text('Report')),
        if (!blockedByOther)
          PopupMenuItem(
            value: blockedByMe ? 'unblock' : 'block',
            child: Text(blockedByMe ? 'Unblock user' : 'Block user'),
          ),
      ],
    );
  }

  Widget _buildConversation(
    BuildContext context,
    ChatThread thread, {
    VoidCallback? onBack,
  }) {
    final messages = thread.messages;
    final other = _otherUser(thread);
    final blockedByMe = _blockedByMe(thread);
    final blockedByOther = _blockedByOther(thread);
    final blocked = blockedByMe || blockedByOther;
    final requestedBy = thread.identityRevealRequestedBy;
    final requestedByMe = requestedBy == widget.user.id;
    final requestedByOther = requestedBy != null && !requestedByMe;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TabangSpace.xl,
            vertical: TabangSpace.md,
          ),
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(bottom: BorderSide(color: context.border)),
          ),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Back to conversations',
                  icon: const Icon(Icons.arrow_back, size: 18),
                  onPressed: onBack,
                ),
              CircleAvatar(
                radius: 17,
                backgroundColor: TabangColors.crimson,
                child: Text(
                  _displayName(thread).substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(thread),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          thread.identityRevealed
                              ? Icons.lock_open
                              : Icons.lock_outline,
                          size: 10,
                          color: context.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            thread.identityRevealed
                                ? (other?.phone ??
                                    'Contact shared by mutual consent')
                                : requestedByOther
                                    ? 'They requested identity reveal'
                                    : requestedByMe
                                        ? 'Reveal requested — waiting'
                                        : 'Identity protected',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onBack != null)
                _buildCompactConversationMenu(
                  context,
                  thread,
                  blockedByMe: blockedByMe,
                  blockedByOther: blockedByOther,
                  requestedByMe: requestedByMe,
                  requestedByOther: requestedByOther,
                )
              else ...[
                if (!thread.identityRevealed && requestedByOther) ...[
                  TextButton.icon(
                    onPressed: () => _acceptReveal(context, thread),
                    icon: const Icon(Icons.lock_open, size: 14),
                    label: const Text('Accept reveal'),
                  ),
                  IconButton(
                    tooltip: 'Decline reveal',
                    icon: const Icon(Icons.close, size: 15),
                    onPressed: () =>
                        _repo.declineIdentityReveal(thread.id, widget.user.id),
                  ),
                ] else if (!thread.identityRevealed && requestedByMe)
                  const StatusPill(
                    'Reveal requested',
                    tone: Tone.info,
                    dense: true,
                  )
                else if (!thread.identityRevealed)
                  TextButton.icon(
                    onPressed: () => _requestReveal(context, thread),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Request reveal'),
                  ),
                IconButton(
                  tooltip: thread.isMuted ? 'Unmute' : 'Mute',
                  icon: Icon(
                    thread.isMuted
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                    size: 17,
                  ),
                  onPressed: () =>
                      _repo.setThreadMuted(thread.id, !thread.isMuted),
                ),
                IconButton(
                  tooltip: 'Report',
                  icon: const Icon(Icons.flag_outlined, size: 17),
                  onPressed: () => _showReportDialog(context, thread),
                ),
                if (!blockedByOther)
                  PopupMenuButton<String>(
                    tooltip: 'Safety options',
                    icon: const Icon(Icons.more_vert, size: 17),
                    onSelected: (value) {
                      if (value == 'block') {
                        _block(context, thread);
                      } else if (value == 'unblock') {
                        _unblock(context, thread);
                      }
                    },
                    itemBuilder: (context) => [
                      if (blockedByMe)
                        const PopupMenuItem(
                          value: 'unblock',
                          child: Text('Unblock user'),
                        )
                      else
                        const PopupMenuItem(
                          value: 'block',
                          child: Text('Block user'),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
        if (blocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: TabangSpace.xl,
              vertical: TabangSpace.sm,
            ),
            color: context.dangerBg,
            child: Row(
              children: [
                const Icon(Icons.block,
                    size: 14, color: TabangColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    blockedByOther
                        ? 'This user has blocked you. Messages are disabled.'
                        : 'You blocked this user. Unblock to send messages.',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),

        // Messages
        Expanded(
          child: Container(
            color: context.surfaceAlt,
            child: messages.isEmpty
                ? const EmptyState(
                    art: TabangArt.messages,
                    title: 'No messages yet',
                    message: 'Say hello to start the conversation.',
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: context.pagePadding,
                    itemCount: messages.length,
                    itemBuilder: (context, i) =>
                        _buildBubble(context, messages[i]),
                  ),
          ),
        ),

        // Composer
        Container(
          padding: const EdgeInsets.all(TabangSpace.md),
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(top: BorderSide(color: context.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  enabled: !thread.isMuted && !blocked,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: blocked
                        ? 'Messaging disabled while blocked'
                        : thread.isMuted
                            ? 'This conversation is muted'
                            : 'Write a message',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              IconButton.filled(
                onPressed: thread.isMuted || blocked ? null : _send,
                icon: const Icon(Icons.send, size: 17),
                style: IconButton.styleFrom(
                  backgroundColor: TabangColors.crimson,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context, ChatMessage message) {
    final mine = message.senderId == widget.user.id;
    final flagged = message.flag != ModerationFlag.clean;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: TabangSpace.md),
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.md,
          vertical: TabangSpace.sm,
        ),
        decoration: BoxDecoration(
          color: mine ? TabangColors.crimson : context.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(TabangRadius.md),
            topRight: const Radius.circular(TabangRadius.md),
            bottomLeft: Radius.circular(mine ? TabangRadius.md : 3),
            bottomRight: Radius.circular(mine ? 3 : TabangRadius.md),
          ),
          border: mine ? null : Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: mine ? Colors.white : context.textColor,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatRelative(message.sentAt),
                  style: TextStyle(
                    fontSize: 9,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.7)
                        : context.textMuted,
                  ),
                ),
                if (flagged) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 10,
                    color: mine ? Colors.white : TabangColors.danger,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _requestReveal(BuildContext context, ChatThread thread) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request identity reveal?'),
        content: const Text(
          'TABANG keeps both parties anonymous until both explicitly agree. '
          'This sends a request; your real name and contact number are shown '
          'only after the other party accepts.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep anonymous'),
          ),
          ElevatedButton(
            onPressed: () {
              _repo.requestIdentityReveal(thread.id, widget.user.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reveal request sent. Waiting for consent.'),
                ),
              );
            },
            child: const Text('Send request'),
          ),
        ],
      ),
    );
  }

  void _acceptReveal(BuildContext context, ChatThread thread) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept identity reveal?'),
        content: const Text(
          'Both of you have now agreed. Your real name and contact number '
          'will be visible to the other party for this conversation.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _repo.acceptIdentityReveal(thread.id, widget.user.id);
              Navigator.pop(context);
            },
            child: const Text('Accept reveal'),
          ),
        ],
      ),
    );
  }

  void _block(BuildContext context, ChatThread thread) {
    final otherId = _otherId(thread);
    if (!_repo.canBlock(widget.user.id, otherId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can re-block this user 48 hours after unblocking them.',
          ),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'They will not be able to send you messages in this conversation. '
          'Reports already submitted remain with chapter staff.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _repo.blockUser(widget.user.id, otherId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User blocked.')),
              );
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _unblock(BuildContext context, ChatThread thread) {
    _repo.unblockUser(widget.user.id, _otherId(thread));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'User unblocked. Re-blocking is available after 48 hours.',
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, ChatThread thread) {
    String? reason;
    final other = _otherAlias(thread);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Report $other'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a reason. Reports are reviewed by chapter staff.',
                  style: TextStyle(
                      fontSize: 12, color: dialogContext.textMuted),
                ),
                const SizedBox(height: TabangSpace.md),
                RadioGroup<String>(
                  groupValue: reason,
                  onChanged: (v) => setDialogState(() => reason = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      'Paid blood solicitation',
                      'Spam or scam',
                      'Harassment or bullying',
                      'Fake donor or recipient profile',
                      'Other',
                    ]
                        .map(
                          (r) => RadioListTile<String>(
                            value: r,
                            title:
                                Text(r, style: const TextStyle(fontSize: 12.5)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: reason == null
                  ? null
                  : () {
                      _repo.submitReport(
                        reporterId: widget.user.id,
                        reportedUserId: _otherId(thread),
                        reason: reason!,
                        threadId: thread.id,
                      );
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Report submitted against $other. Chapter staff '
                            'will review it.',
                          ),
                        ),
                      );
                    },
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}
