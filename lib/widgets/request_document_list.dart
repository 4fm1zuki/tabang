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
/// when a preview is available, a thumbnail that opens full size. Seeded
/// requests use a bundled scan of the chapter copy instead of pretending to
/// have the original upload bytes.
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

/// One attached file, with an inline preview when possible.
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
    final preview = _previewImage(document);
    final subtitle = document.hasFile
        ? '${document.fileName}'
              '${document.sizeLabel.isEmpty ? '' : ' · ${document.sizeLabel}'}'
        : '${document.fileName} · chapter copy';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview != null)
          InkWell(
            borderRadius: BorderRadius.circular(TabangRadius.xs),
            onTap: () => _showPreview(context, preview),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TabangRadius.xs),
              child: SizedBox(
                width: dense ? 30 : 40,
                height: dense ? 30 : 40,
                child: Image(
                  image: preview,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _icon(context),
                ),
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
        if (preview != null)
          TextButton(
            onPressed: () => _showPreview(context, preview),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: const Text('View', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  /// Uploaded image bytes take priority; otherwise a bundled chapter scan.
  ImageProvider? _previewImage(RequestDocument document) {
    final bytes = document.bytes;
    if (bytes != null && isImageRequestDocument(document)) {
      return MemoryImage(bytes);
    }
    final asset = document.previewAsset;
    if (asset != null) return AssetImage(asset);
    return null;
  }

  Widget _icon(BuildContext context) {
    return Icon(
      document.hasPreview
          ? Icons.description_outlined
          : (document.hasFile
                ? Icons.description_outlined
                : Icons.verified_outlined),
      size: dense ? 16 : 18,
      color: document.hasPreview || document.hasFile
          ? TabangColors.crimson
          : TabangColors.success,
    );
  }

  void _showPreview(BuildContext context, ImageProvider preview) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          document.kind,
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: 560,
          child: InteractiveViewer(
            maxScale: 4,
            child: Image(
              image: preview,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(TabangSpace.lg),
                child: Text('This attachment could not be previewed.'),
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
