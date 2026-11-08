import 'package:flutter/material.dart';

import '../core/repository.dart';
import '../theme.dart';

/// Circular chapter mark: the Philippine Red Cross emblem.
///
/// The bundled PNG carries the official navy ring, arc lettering and red
/// cross, so the mark stays recognisable at a glance. The previous build drew
/// a plain blue circle with a plus; the drawn version remains the fallback if
/// the asset is missing from a stripped-down build.
class ChapterMark extends StatelessWidget {
  const ChapterMark({super.key, this.size = 40});

  /// Bundled emblem, public domain (PD-ineligible) per Wikimedia Commons.
  /// Use of the Red Cross symbol is regulated by the Geneva Conventions.
  static const String asset = 'assets/branding/prc_logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Philippine Red Cross emblem',
          errorBuilder: (context, error, stackTrace) =>
              _DrawnChapterMark(size: size),
        ),
      ),
    );
  }
}

/// Fallback mark for builds without the bundled emblem.
class _DrawnChapterMark extends StatelessWidget {
  const _DrawnChapterMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF16337F),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.10),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          size: size * 0.52,
          color: const Color(0xFFD61F26),
        ),
      ),
    );
  }
}

/// The blue verified tick used wherever the chapter account appears.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified chapter account',
      child: Icon(Icons.verified, size: size, color: const Color(0xFF1D9BF0)),
    );
  }
}

/// Opens the official chapter identity card: who the account is, where the
/// chapter sits, and what the thread is for.
Future<void> showChapterIdentityDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          ChapterMark(size: 34),
          SizedBox(width: TabangSpace.sm),
          Expanded(child: Text('Chapter account')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    TabangRepository.chapterName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: dialogContext.textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const VerifiedBadge(size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              TabangRepository.chapterSubtitle,
              style: TextStyle(fontSize: 12, color: dialogContext.textMuted),
            ),
            const SizedBox(height: TabangSpace.md),
            Text(
              'This thread is the official channel of the chapter that runs '
              'TABANG. Donor registrations, document requests and feedback all '
              'land here. Messages are answered during office hours (Mon–Sat, '
              '8:00 AM – 5:00 PM). Staff identities stay private; only the '
              'organization is shown.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: dialogContext.textMuted,
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
    ),
  );
}
