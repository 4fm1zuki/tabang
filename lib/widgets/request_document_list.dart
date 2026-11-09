import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../theme.dart';

/// Whether a request document can be previewed as an image.
bool isImageRequestDocument(RequestDocument document) {
  final name = document.fileName.toLowerCase();
  return name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.png');
}

/// Lists the files attached to a blood request.
///
/// Staff used to see only ticked checklist labels, which could not prove the
/// requester had sent anything. This renders the actual file name, size and,
/// when the payload is available, a thumbnail that opens full size. Seeded
/// requests say "on file at the chapter" instead of pretending to have bytes.
class RequestDocumentList extends StatelessWidget {
  const RequestDocumentList({
    super.key,
    required this.documents,
    this.dense = false,
  });

  final List<RequestDocument> documents;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Text(
        'No documents attached.',
        style: TextStyle(fontSize: 12, color: context.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final document in documents)
          Padding(
            padding: EdgeInsets.only(bottom: dense ? 4 : 6),
            child: RequestDocumentRow(document: document, dense: dense),
          ),
      ],
    );
  }
}

/// One attached file, with an inline image preview when possible.
class RequestDocumentRow extends StatelessWidget {
  const RequestDocumentRow({
    super.key,
    required this.document,
    this.dense = false,
  });

  final RequestDocument document;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bytes = document.bytes;
    final image = bytes != null && isImageRequestDocument(document);
    final subtitle = document.hasFile
        ? '${document.fileName}'
              '${document.sizeLabel.isEmpty ? '' : ' · ${document.sizeLabel}'}'
        : '${document.fileName} · on file at the chapter';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image)
          InkWell(
            borderRadius: BorderRadius.circular(TabangRadius.xs),
            onTap: () => _showPreview(context, document, bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TabangRadius.xs),
              child: Image.memory(
                bytes,
                width: dense ? 28 : 38,
                height: dense ? 28 : 38,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _icon(context),
              ),
            ),
          )
        else
          _icon(context),
        const SizedBox(width: TabangSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.kind,
                style: TextStyle(
                  fontSize: dense ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: dense ? 10.5 : 11.5,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (image)
          TextButton(
            onPressed: () => _showPreview(context, document, bytes),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: const Text('View', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  Widget _icon(BuildContext context) {
    return Icon(
      document.hasFile ? Icons.description_outlined : Icons.verified_outlined,
      size: dense ? 16 : 18,
      color: document.hasFile ? TabangColors.crimson : TabangColors.success,
    );
  }

  void _showPreview(
    BuildContext context,
    RequestDocument document,
    Uint8List bytes,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          document.kind,
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: 520,
          child: InteractiveViewer(
            maxScale: 4,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(TabangSpace.lg),
                child: Text('This image could not be previewed.'),
              ),
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
}
