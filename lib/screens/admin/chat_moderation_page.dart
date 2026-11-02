import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';

/// Chat moderation console.
///
/// Staff review flagged conversations, clear or escalate flags, and mute
/// threads. The previous build displayed moderation data but every action was
/// inert; these buttons mutate the shared repository.
class ChatModerationPage extends StatefulWidget {
  const ChatModerationPage({super.key});

  @override
  State<ChatModerationPage> createState() => _ChatModerationPageState();
}

class _ChatModerationPageState extends State<ChatModerationPage> {
  final TabangRepository _repo = TabangRepository.instance;

  String? _selectedThreadId;
  bool _onlyFlagged = true;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<ChatThread> get _threads {
    final all = _repo.threads;
    if (!_onlyFlagged) return all;
    return all.where((t) => t.hasFlaggedMessages).toList();
  }

  ChatThread? get _active {
    final threads = _threads;
    if (threads.isEmpty) return null;
    for (final t in threads) {
      if (t.id == _selectedThreadId) return t;
    }
    return threads.first;
  }

  @override
  Widget build(BuildContext context) {
    final threads = _threads;
    final active = _active;
    final flaggedTotal = _repo.threads
        .fold<int>(0, (sum, t) => sum + t.flaggedCount);
    final openReports = _repo.reports
        .where((r) => r.status == ReportStatus.open)
        .length;

    // Phones: one pane at a time. Wide screens keep the list + detail split.
    final compact = MediaQuery.sizeOf(context).width < 860;
    if (compact && _selectedThreadId != null && active != null) {
      return _buildDetail(
        context,
        active,
        onBack: () => setState(() => _selectedThreadId = null),
      );
    }
    if (compact) {
      return _buildCompactList(context, threads, flaggedTotal, openReports);
    }

    return Row(
      children: [
        // Thread list
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(right: BorderSide(color: context.border)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(TabangSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Moderation',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textColor,
                            ),
                          ),
                        ),
                        StatusPill(
                          '$flaggedTotal flagged',
                          tone: flaggedTotal > 0 ? Tone.danger : Tone.success,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: TabangSpace.sm),
                    Row(
                      children: [
                        Text(
                          'Flagged only',
                          style: TextStyle(
                              fontSize: 11, color: context.textMuted),
                        ),
                        const SizedBox(width: 6),
                        Switch(
                          value: _onlyFlagged,
                          onChanged: (v) => setState(() => _onlyFlagged = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: TabangSpace.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReportsDialog(context),
                        icon: const Icon(Icons.flag_outlined, size: 14),
                        label: Text(
                          openReports == 0
                              ? 'User reports'
                              : 'User reports ($openReports)',
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
                        art: TabangArt.messages,
                        title: 'No flagged conversations',
                        message: 'Nothing needs review right now.',
                      )
                    : ListView.builder(
                        itemCount: threads.length,
                        itemBuilder: (context, i) {
                          final thread = threads[i];
                          final selected = active?.id == thread.id;
                          return Material(
                            color: selected
                                ? (context.isDark
                                    ? const Color(0xFF3A1917)
                                    : TabangColors.crimsonSoft)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(
                                  () => _selectedThreadId = thread.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: TabangSpace.lg,
                                  vertical: TabangSpace.md,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${thread.participantAAlias} ↔ '
                                            '${thread.participantBAlias}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: context.textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (thread.hasFlaggedMessages)
                                          StatusPill(
                                            '${thread.flaggedCount}',
                                            tone: Tone.danger,
                                            dense: true,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      thread.lastMessage?.text ??
                                          'No messages',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        // Detail
        Expanded(
          child: active == null
              ? const EmptyState(
                  art: TabangArt.messages,
                  title: 'Select a conversation',
                  message:
                      'Flagged messages are highlighted in red with the reason '
                      'TABANG assigned automatically.',
                )
              : _buildDetail(context, active),
        ),
      ],
    );
  }

  /// Single-column moderation list for phones.
  Widget _buildCompactList(
    BuildContext context,
    List<ChatThread> threads,
    int flaggedTotal,
    int openReports,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(TabangSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Moderation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                  ),
                  StatusPill(
                    '$flaggedTotal flagged',
                    tone: flaggedTotal > 0 ? Tone.danger : Tone.success,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: TabangSpace.sm),
              Row(
                children: [
                  Text(
                    'Flagged only',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: _onlyFlagged,
                    onChanged: (v) => setState(() => _onlyFlagged = v),
                  ),
                ],
              ),
              const SizedBox(height: TabangSpace.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReportsDialog(context),
                  icon: const Icon(Icons.flag_outlined, size: 14),
                  label: Text(
                    openReports == 0
                        ? 'User reports'
                        : 'User reports ($openReports)',
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
                  art: TabangArt.messages,
                  title: 'No flagged conversations',
                  message: 'Nothing needs review right now.',
                )
              : ListView.builder(
                  itemCount: threads.length,
                  itemBuilder: (context, i) {
                    final thread = threads[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedThreadId = thread.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TabangSpace.lg,
                            vertical: TabangSpace.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${thread.participantAAlias} ↔ '
                                      '${thread.participantBAlias}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: context.textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (thread.hasFlaggedMessages)
                                    StatusPill(
                                      '${thread.flaggedCount}',
                                      tone: Tone.danger,
                                      dense: true,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                thread.lastMessage?.text ?? 'No messages',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetail(
    BuildContext context,
    ChatThread thread, {
    VoidCallback? onBack,
  }) {
    return Column(
      children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${thread.participantAAlias} ↔ ${thread.participantBAlias}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      'Room ${thread.id} · ${thread.messages.length} messages · '
                      '${thread.flaggedCount} flagged',
                      style:
                          TextStyle(fontSize: 10.5, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              if (onBack == null)
                OutlinedButton.icon(
                  onPressed: () =>
                      _repo.setThreadMuted(thread.id, !thread.isMuted),
                  icon: Icon(
                    thread.isMuted ? Icons.volume_up : Icons.volume_off,
                    size: 14,
                  ),
                  label: Text(thread.isMuted ? 'Unmute' : 'Mute'),
                )
              else
                IconButton(
                  tooltip: thread.isMuted ? 'Unmute' : 'Mute',
                  icon: Icon(
                    thread.isMuted
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                    size: 18,
                  ),
                  onPressed: () =>
                      _repo.setThreadMuted(thread.id, !thread.isMuted),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: context.surfaceAlt,
            child: ListView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600
                    ? 16
                    : TabangSpace.xl,
              ),
              children: thread.messages
                  .map((m) => _buildMessage(context, thread, m))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(
    BuildContext context,
    ChatThread thread,
    ChatMessage message,
  ) {
    final flagged = message.flag != ModerationFlag.clean;

    return Container(
      margin: const EdgeInsets.only(bottom: TabangSpace.md),
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(
          color: flagged ? TabangColors.danger : context.border,
          width: flagged ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.senderAlias,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              Text(
                formatRelative(message.sentAt),
                style: TextStyle(fontSize: 10, color: context.textMuted),
              ),
              const Spacer(),
              StatusPill(
                message.flag.label,
                tone: flagged ? Tone.danger : Tone.success,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.text,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: context.textColor,
            ),
          ),
          if (flagged) ...[
            const SizedBox(height: TabangSpace.sm),
            Wrap(
              spacing: TabangSpace.sm,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _repo.flagMessage(
                    thread.id,
                    message.id,
                    ModerationFlag.clean,
                  ),
                  icon: const Icon(Icons.check, size: 13),
                  label: const Text('Clear flag'),
                ),
                TextButton.icon(
                  onPressed: () => _showEscalate(context, thread, message),
                  icon: const Icon(Icons.gavel, size: 13),
                  label: const Text('Escalate to warning'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showReportsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final reports = _repo.reports;
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('User reports')),
                StatusPill(
                  '${reports.where((r) => r.status == ReportStatus.open).length} open',
                  tone: reports.any((r) => r.status == ReportStatus.open)
                      ? Tone.warning
                      : Tone.success,
                  dense: true,
                ),
              ],
            ),
            content: SizedBox(
              width: 640,
              height: 460,
              child: reports.isEmpty
                  ? const EmptyState(
                      art: TabangArt.messages,
                      title: 'No reports',
                      message: 'No community member has reported a conversation.',
                    )
                  : ListView.separated(
                      itemCount: reports.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final report = reports[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${report.reporterAlias} → '
                                      '${report.reportedAlias}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    report.status.label,
                                    tone: report.status == ReportStatus.open
                                        ? Tone.warning
                                        : Tone.neutral,
                                    dense: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.reason,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${report.id} · '
                                '${formatRelative(report.createdAt)}'
                                '${report.threadId == null ? '' : ' · ${report.threadId}'}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: context.textMuted,
                                ),
                              ),
                              if (report.status == ReportStatus.open) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        _repo.resolveReport(
                                          report.id,
                                          ReportStatus.resolved,
                                        );
                                        setDialogState(() {});
                                      },
                                      child: const Text('Resolve'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _repo.resolveReport(
                                          report.id,
                                          ReportStatus.dismissed,
                                        );
                                        setDialogState(() {});
                                      },
                                      child: const Text('Dismiss'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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

  void _showEscalate(
    BuildContext context,
    ChatThread thread,
    ChatMessage message,
  ) {
    final sender = _repo.userById(message.senderId);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issue a warning'),
        content: Text(
          sender == null
              ? 'This message was sent by an account that no longer exists.'
              : 'Issue a formal warning to ${sender.fullName} '
                  '(${sender.alias}) for this message?\n\n'
                  'Three warnings suspend the account automatically.',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (sender != null) _repo.warnUser(sender.id);
              _repo.flagMessage(
                thread.id,
                message.id,
                ModerationFlag.inappropriate,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Issue warning'),
          ),
        ],
      ),
    );
  }
}
