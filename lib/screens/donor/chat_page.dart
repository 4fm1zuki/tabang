import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/chapter_identity.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/photo.dart';
import '../../widgets/user_record_dialog.dart';

/// How the conversation list is ordered. Both modes sort the chapter thread
/// alongside people; it is an organization, not an exception to the list.
enum _ThreadSort { recent, alpha }

/// Messaging between donors and recipients.
///
/// Preserves the original two-pane layout and search. Messages, reports and
/// blocks persist in the repository. The double-blind rule from p.34 of the
/// paper is enforced bilaterally: one participant requests a reveal, the other
/// must accept before real names and contact details are shown. Reports appear
/// in the staff moderation queue, and a 48-hour re-block cooldown matches the
/// Help FAQ.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.user,
    this.allowNewConversation = false,
    this.initialThreadId,
  });

  final AppUser user;

  /// Staff and admins can open a new conversation with any community account.
  /// Donor/recipient messaging stays tied to coordination threads.
  final bool allowNewConversation;

  /// Deep-link straight into a conversation (for example from a staff user
  /// record).
  final String? initialThreadId;

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
  _ThreadSort _sort = _ThreadSort.recent;

  /// Guards against stacking post-frame read receipts while a rebuild is
  /// already on its way.
  String? _pendingReadThreadId;

  @override
  void initState() {
    super.initState();
    _selectedThreadId = widget.initialThreadId;
    _repo.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialThreadId != oldWidget.initialThreadId &&
        widget.initialThreadId != null) {
      _selectedThreadId = widget.initialThreadId;
    }
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

  /// Marks the conversation currently on screen as read without notifying the
  /// repository during build. The guard prevents a loop when several rebuilds
  /// happen before the frame callback runs.
  void _scheduleMarkRead(ChatThread thread) {
    if (!thread.hasUnreadFor(widget.user.id)) return;
    if (_pendingReadThreadId == thread.id) return;
    _pendingReadThreadId = thread.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingReadThreadId = null;
      if (!mounted) return;
      _repo.markThreadRead(thread.id, widget.user.id);
    });
  }

  List<ChatThread> get _threads {
    var all = _repo.threadsFor(widget.user.id);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      all = all.where((t) {
        return _displayName(t).toLowerCase().contains(q) ||
            (t.identityRevealed && _otherUser(t) != null
                ? _repo
                      .displayNameFor(t, widget.user.id)
                      .toLowerCase()
                      .contains(q)
                : false) ||
            t.messages.any((m) => m.text.toLowerCase().contains(q));
      }).toList();
    }
    switch (_sort) {
      case _ThreadSort.recent:
        all.sort((a, b) {
          final aTime =
              a.lastMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.lastMessage?.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final byTime = bTime.compareTo(aTime);
          if (byTime != 0) return byTime;
          return _displayName(a).compareTo(_displayName(b));
        });
      case _ThreadSort.alpha:
        all.sort(
          (a, b) =>
              _displayName(a)
                  .toLowerCase()
                  .compareTo(_displayName(b).toLowerCase()),
        );
    }
    return all;
  }

  /// The chapter thread is an organization, not a person: it never reveals a
  /// staff member's real name and always shows the chapter brand.
  bool _isChapter(ChatThread thread) => _repo.isChapterThread(thread);

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

  AppUser? _otherUser(ChatThread thread) => _repo.userById(_otherId(thread));

  /// Real names appear only after both participants consent. Until then the
  /// thread shows the alias from the paper's double-blind design. The chapter
  /// thread is the exception: it is an organization identity, so it always
  /// reads as the Philippine Red Cross chapter rather than a staff member.
  String _displayName(ChatThread thread) {
    if (_isChapter(thread)) return TabangRepository.chapterName;
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

        // A conversation is "seen" when it is the one drawn on screen. Mark it
        // read after the frame so the navigation badges clear immediately.
        if (active != null && (!compact || _selectedThreadId != null)) {
          _scheduleMarkRead(active);
        }

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
            padding: const EdgeInsets.fromLTRB(
              TabangSpace.lg,
              TabangSpace.lg,
              TabangSpace.lg,
              TabangSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // The two-pane layout gives this list a fixed 300 px, so
                    // the title has to flex instead of pushing the sort and
                    // compose controls past the edge.
                    Expanded(
                      child: Text(
                        'Conversations',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: context.textColor,
                        ),
                      ),
                    ),
                    if (threads.isNotEmpty)
                      StatusPill(
                        '${threads.length}',
                        tone: Tone.neutral,
                        dense: true,
                      ),
                    const SizedBox(width: 4),
                    PopupMenuButton<_ThreadSort>(
                      tooltip: 'Sort conversations',
                      initialValue: _sort,
                      onSelected: (v) => setState(() => _sort = v),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _ThreadSort.recent,
                          child: Text(
                            'Most recent',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ThreadSort.alpha,
                          child: Text(
                            'Alphabetical (A–Z)',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort, size: 15, color: context.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            _sort == _ThreadSort.recent ? 'Recent' : 'A–Z',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.allowNewConversation) ...[
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: 'New conversation',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        onPressed: () => _showNewConversationDialog(context),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: TabangSpace.md),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search people or messages',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 17),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close, size: 15),
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
                ? EmptyState(
                    art: TabangArt.search,
                    title: 'No conversations',
                    message: widget.allowNewConversation
                        ? 'Start a conversation with a community member, donor '
                              'or another staff account.'
                        : null,
                    action: widget.allowNewConversation
                        ? OutlinedButton.icon(
                            onPressed: () =>
                                _showNewConversationDialog(context),
                            icon: const Icon(
                              Icons.add_comment_outlined,
                              size: 15,
                            ),
                            label: const Text('New conversation'),
                          )
                        : null,
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
    final other = _otherUser(thread);
    final type = other?.bloodType;
    final unread = thread.unreadCountFor(widget.user.id);

    // A left accent bar marks the open thread. The old full-row pink fill made
    // every conversation look selected once the page had focus.
    return Material(
      color: active
          ? (context.isDark
                ? const Color(0xFF331715)
                : TabangColors.crimsonSoft.withValues(alpha: 0.55))
          : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedThreadId = thread.id),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? TabangColors.crimson : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: context.border.withValues(alpha: 0.6)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            13,
            TabangSpace.md,
            TabangSpace.lg,
            TabangSpace.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isChapter(thread))
                const ChapterMark(size: 40)
              else
                ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: TabangPhoto(
                      other?.photoAsset,
                      semanticLabel:
                          '${_displayName(thread)} profile illustration',
                      creditLabel: _displayName(thread),
                      fallbackIcon: Icons.person_outline,
                      fallbackIconSize: 20,
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
                        Flexible(
                          child: Text(
                            _displayName(thread),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isChapter(thread)) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(),
                        ],
                        if (thread.identityRevealed) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.lock_open,
                            size: 12,
                            color: TabangColors.teal,
                          ),
                        ],
                        if (_isBlocked(thread)) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.block,
                            size: 12,
                            color: TabangColors.danger,
                          ),
                        ],
                        if (thread.hasFlaggedMessages) ...[
                          const SizedBox(width: 4),
                          const StatusPill('!', tone: Tone.danger, dense: true),
                        ],
                        if (thread.isMuted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.volume_off,
                            size: 12,
                            color: context.textMuted,
                          ),
                        ],
                        const Spacer(),
                        if (unread > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: TabangColors.crimson,
                              borderRadius: BorderRadius.circular(
                                TabangRadius.pill,
                              ),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (last != null)
                          Text(
                            formatRelative(last.sentAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: unread > 0
                                  ? TabangColors.crimson
                                  : context.textMuted,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      last?.text ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: unread > 0
                            ? context.textColor
                            : context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (type != null) ...[
                          BloodTypeChip(type, size: 20),
                          const SizedBox(width: 6),
                        ],
                        StatusPill(
                          thread.identityRevealed
                              ? 'Identities shared'
                              : 'Identity protected',
                          tone: thread.identityRevealed
                              ? Tone.success
                              : Tone.neutral,
                          dense: true,
                        ),
                        const Spacer(),
                        if (last != null && last.senderId == widget.user.id)
                          Text(
                            'You',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                      ],
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
    final chapter = _isChapter(thread);
    return PopupMenuButton<String>(
      tooltip: 'Conversation options',
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) {
        switch (value) {
          case 'about':
            showChapterIdentityDialog(context);
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
        if (chapter)
          const PopupMenuItem(value: 'about', child: Text('About this account'))
        else ...[
          if (!thread.identityRevealed && requestedByOther) ...[
            const PopupMenuItem(value: 'accept', child: Text('Accept reveal')),
            const PopupMenuItem(
              value: 'decline',
              child: Text('Decline reveal'),
            ),
          ] else if (!thread.identityRevealed && !requestedByMe)
            const PopupMenuItem(value: 'reveal', child: Text('Request reveal')),
        ],
        PopupMenuItem(
          value: 'mute',
          child: Text(thread.isMuted ? 'Unmute' : 'Mute'),
        ),
        if (!chapter) ...[
          const PopupMenuItem(value: 'report', child: Text('Report')),
          if (!blockedByOther)
            PopupMenuItem(
              value: blockedByMe ? 'unblock' : 'block',
              child: Text(blockedByMe ? 'Unblock user' : 'Block user'),
            ),
        ],
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
              if (_isChapter(thread))
                const ChapterMark(size: 42)
              else
                ClipOval(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: TabangPhoto(
                      other?.photoAsset,
                      semanticLabel:
                          '${_displayName(thread)} profile illustration',
                      creditLabel: _displayName(thread),
                      fallbackIcon: Icons.person_outline,
                      fallbackIconSize: 20,
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
                        Flexible(
                          child: Text(
                            _displayName(thread),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: context.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isChapter(thread))
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: VerifiedBadge(size: 16),
                          )
                        else if (other?.bloodType != null) ...[
                          const SizedBox(width: 6),
                          BloodTypeChip(other!.bloodType!, size: 20),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          _isChapter(thread)
                              ? Icons.verified_user_outlined
                              : thread.identityRevealed
                              ? Icons.lock_open
                              : Icons.lock_outline,
                          size: 12,
                          color: thread.identityRevealed && !_isChapter(thread)
                              ? TabangColors.teal
                              : context.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _isChapter(thread)
                                ? TabangRepository.chapterSubtitle
                                : thread.identityRevealed
                                ? (other?.phone ??
                                      'Contact shared by mutual consent')
                                : requestedByOther
                                ? 'They requested identity reveal'
                                : requestedByMe
                                ? 'Reveal requested — waiting'
                                : 'Identity protected',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
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
                if (!_isChapter(thread) &&
                    widget.user.role.isAdminSide &&
                    other != null)
                  // Staff/admin conversations still hide the alias, but the
                  // chapter record is one tap away so staff can act on it.
                  IconButton(
                    tooltip: 'Show details for ${other.alias}',
                    icon: const Icon(Icons.badge_outlined, size: 17),
                    onPressed: () => showUserRecordDialog(context, other),
                  ),
                if (_isChapter(thread))
                  // The chapter is an organization: no identity reveal, no
                  // blocking or reporting the official support channel.
                  IconButton(
                    tooltip: 'About this account',
                    icon: const Icon(Icons.info_outline, size: 17),
                    onPressed: () => showChapterIdentityDialog(context),
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
                      onPressed: () => _repo.declineIdentityReveal(
                        thread.id,
                        widget.user.id,
                      ),
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
                const Icon(Icons.block, size: 14, color: TabangColors.danger),
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
                : Builder(
                    builder: (context) {
                      // "Seen" marks the newest own message the other side has
                      // actually read, using the same read marker as unread
                      // counters.
                      final otherReadAt = thread.readAtFor(_otherId(thread));
                      var lastSeenIndex = -1;
                      if (otherReadAt != null) {
                        for (var i = 0; i < messages.length; i++) {
                          final message = messages[i];
                          if (message.senderId == widget.user.id &&
                              !message.sentAt.isAfter(otherReadAt)) {
                            lastSeenIndex = i;
                          }
                        }
                      }
                      return ListView.builder(
                        controller: _scroll,
                        padding: context.pagePadding,
                        itemCount: messages.length,
                        itemBuilder: (context, i) => _buildBubble(
                          context,
                          messages[i],
                          previous: i > 0 ? messages[i - 1] : null,
                          showSeen: i == lastSeenIndex,
                        ),
                      );
                    },
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

  Widget _buildBubble(
    BuildContext context,
    ChatMessage message, {
    ChatMessage? previous,
    bool showSeen = false,
  }) {
    final mine = message.senderId == widget.user.id;
    final flagged = message.flag != ModerationFlag.clean;
    // Name the sender only when the speaker changes, the way chat apps group
    // consecutive messages. It keeps the double-blind aliases visible without
    // repeating them on every bubble.
    final showAlias =
        !mine && (previous == null || previous.senderId != message.senderId);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showAlias) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      message.senderId == TabangRepository.chapterAccountId
                          ? TabangRepository.chapterName
                          : message.senderAlias,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                  if (message.senderId == TabangRepository.chapterAccountId)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: VerifiedBadge(size: 13),
                    ),
                ],
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.only(bottom: TabangSpace.md),
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.symmetric(
              horizontal: TabangSpace.md,
              vertical: 10,
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
                    fontSize: 13.5,
                    height: 1.45,
                    color: mine ? Colors.white : context.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatRelative(message.sentAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: mine
                            ? Colors.white.withValues(alpha: 0.78)
                            : context.textMuted,
                      ),
                    ),
                    if (flagged) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: mine ? Colors.white : TabangColors.danger,
                      ),
                    ],
                    if (showSeen) ...[
                      const SizedBox(width: 5),
                      Text(
                        '· Seen',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: mine
                              ? Colors.white.withValues(alpha: 0.88)
                              : TabangColors.info,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Staff compose flow: search every active account and open (or reuse) a
  /// private thread. Community members reach people through coordination
  /// threads or the chapter account instead.
  void _showNewConversationDialog(BuildContext context) {
    String query = '';

    int roleRank(UserRole role) => role.isAdminSide ? 0 : 1;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final q = query.trim().toLowerCase();
          final candidates =
              _repo.users.where((u) {
                if (u.id == widget.user.id) return false;
                if (u.status == AccountStatus.suspended) return false;
                if (_repo.isBlockedBetween(widget.user.id, u.id)) {
                  return false;
                }
                if (q.isEmpty) return true;
                return u.fullName.toLowerCase().contains(q) ||
                    u.alias.toLowerCase().contains(q) ||
                    u.email.toLowerCase().contains(q) ||
                    u.role.label.toLowerCase().contains(q) ||
                    u.barangay.toLowerCase().contains(q);
              }).toList()..sort((a, b) {
                final byRole = roleRank(a.role).compareTo(roleRank(b.role));
                if (byRole != 0) return byRole;
                return a.alias.toLowerCase().compareTo(b.alias.toLowerCase());
              });

          return AlertDialog(
            title: const Text('New conversation'),
            content: SizedBox(
              width: 430,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) => setDialogState(() => query = value),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search staff, donors or community members',
                      prefixIcon: Icon(Icons.search, size: 17),
                    ),
                  ),
                  const SizedBox(height: TabangSpace.md),
                  Expanded(
                    child: candidates.isEmpty
                        ? Center(
                            child: Text(
                              'No accounts match that search.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: dialogContext.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: candidates.length,
                            itemBuilder: (context, i) {
                              final candidate = candidates[i];
                              return ListTile(
                                key: ValueKey(
                                  'newConversation-${candidate.id}',
                                ),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: ClipOval(
                                  child: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: TabangPhoto(
                                      candidate.photoAsset,
                                      semanticLabel:
                                          '${candidate.alias} profile photo',
                                      creditLabel: candidate.alias,
                                      fallbackIcon: Icons.person_outline,
                                      fallbackIconSize: 17,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  candidate.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${candidate.alias} · ${candidate.role.label}'
                                  ' · ${candidate.barangay}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 16,
                                ),
                                onTap: () {
                                  final thread = _repo.startConversation(
                                    initiatorId: widget.user.id,
                                    otherId: candidate.id,
                                  );
                                  if (thread == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'That conversation cannot be '
                                          'opened right now.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(dialogContext);
                                  setState(() => _selectedThreadId = thread.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
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
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('User blocked.')));
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
    String details = '';
    final other = _otherAlias(thread);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text('Report $other'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a reason and explain what happened. Reports are '
                  'reviewed by chapter staff.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: dialogContext.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                RadioGroup<String>(
                  groupValue: reason,
                  onChanged: (v) => setDialogState(() => reason = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        const [
                              'Paid blood solicitation',
                              'Spam or scam',
                              'Harassment or bullying',
                              'Fake donor or recipient profile',
                              'Other',
                            ]
                            .map(
                              (r) => RadioListTile<String>(
                                value: r,
                                title: Text(
                                  r,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                TextField(
                  onChanged: (value) => details = value,
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    labelText: 'Explain what happened',
                    hintText:
                        'Add the context staff need — what was said, when it '
                        'happened, or anything else relevant.',
                    alignLabelWithHint: true,
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
                        details: details,
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
