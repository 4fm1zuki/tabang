import 'package:flutter/material.dart';

import '../core/eligibility.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';
import 'common.dart';
import 'photo.dart';

/// Read-only identity card for an account mentioned in a queue, request, hold
/// or chat.
///
/// The editable record lives in User management; this dialog exists so staff
/// can answer "who is this person?" from wherever the alias appears instead of
/// leaving the page and searching. It reads the live repository entry so the
/// details always match the account currently on file.
Future<void> showUserRecordDialog(BuildContext context, AppUser user) {
  final repo = TabangRepository.instance;
  final record = repo.userById(user.id) ?? user;
  final eligibility = EligibilityEngine.evaluate(record);
  final isDonor = record.role == UserRole.donor;

  Widget detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12.5, color: context.textColor),
          ),
        ),
      ],
    ),
  );

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 38,
              height: 38,
              child: TabangPhoto(
                record.photoAsset,
                semanticLabel: '${record.alias} profile illustration',
                creditLabel: record.alias,
                fallbackIcon: Icons.person_outline,
                fallbackIconSize: 18,
              ),
            ),
          ),
          const SizedBox(width: TabangSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.fullName, style: const TextStyle(fontSize: 15)),
                Text(
                  '${record.alias} · ${record.role.label}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: dialogContext.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  StatusPill(
                    record.status.label,
                    tone: toneForAccount(record.status),
                    dense: true,
                  ),
                  StatusPill(
                    record.role.label,
                    tone: Tone.neutral,
                    dense: true,
                  ),
                  if (record.warningCount > 0)
                    StatusPill(
                      '${record.warningCount} warning'
                      '${record.warningCount == 1 ? '' : 's'}',
                      tone: Tone.warning,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: TabangSpace.md),
              detail('Email', record.email),
              detail('Phone', record.phone),
              detail('Barangay', record.barangay),
              detail('Registered', formatDate(record.registeredOn)),
              if (isDonor) ...[
                const Divider(height: TabangSpace.xl),
                detail('Blood type', record.bloodType?.label ?? 'Not recorded'),
                detail(
                  'Birth date',
                  record.birthDate == null
                      ? 'Not recorded'
                      : formatDate(record.birthDate!),
                ),
                detail(
                  'Weight',
                  record.weightKg == null
                      ? 'Not recorded'
                      : '${record.weightKg!.toStringAsFixed(0)} kg',
                ),
                detail('Donations', '${record.totalDonations}'),
                detail(
                  'Last donation',
                  record.lastDonationDate == null
                      ? 'None recorded'
                      : formatDate(record.lastDonationDate!),
                ),
                detail(
                  'Blood card',
                  record.bloodCardVerified ? 'Verified' : 'Not verified',
                ),
                detail(
                  'Directory',
                  record.isAvailable ? 'Visible' : 'Hidden by donor',
                ),
                detail('Eligibility', eligibility.summary),
              ],
              if (record.suspensionReason != null) ...[
                const Divider(height: TabangSpace.xl),
                detail('Suspension reason', record.suspensionReason!),
              ],
              const SizedBox(height: TabangSpace.md),
              Text(
                'Contact details and this record are visible to chapter staff '
                'and administrators only.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: dialogContext.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// A tappable alias token.
///
/// Staff/admin lists mention accounts by alias; wrapping the token here gives
/// every mention the same "show details" affordance without duplicating an
/// icon button per row. Falls back to plain text when the account no longer
/// exists so a deleted reference cannot crash the list.
class UserMention extends StatelessWidget {
  const UserMention({
    super.key,
    required this.userId,
    this.fallback,
    this.prefix,
    this.style,
  });

  final String? userId;
  final String? fallback;
  final String? prefix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final user = userId == null
        ? null
        : TabangRepository.instance.userById(userId!);
    final label = user?.alias ?? fallback ?? 'unknown';
    final baseStyle =
        style ??
        TextStyle(fontSize: 12, color: context.textMuted, height: 1.35);
    if (user == null) {
      return Text(prefix == null ? label : '$prefix$label', style: baseStyle);
    }
    return Tooltip(
      message: 'Show details for ${user.alias}',
      child: InkWell(
        onTap: () => showUserRecordDialog(context, user),
        borderRadius: BorderRadius.circular(3),
        child: Text(
          prefix == null ? label : '$prefix$label',
          style: baseStyle.copyWith(
            color: TabangColors.crimson,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: TabangColors.crimson.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
