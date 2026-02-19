import 'package:flutter/material.dart';

import '../services/cover_storage/cover_prefetch_service.dart';

class CoverWarmupBanner extends StatelessWidget {
  const CoverWarmupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CoverWarmupProgress>(
      valueListenable: CoverWarmupService.instance.progressNotifier,
      builder: (context, progress, _) {
        if (!progress.shouldShowBanner) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final title = progress.isRunning
            ? 'Cover werden geladen'
            : 'Cover-Cache aktualisiert';
        final subtitle = progress.isRunning
            ? 'Läuft im Hintergrund – du kannst die App weiter nutzen.'
            : 'Alle verfügbaren Cover liegen jetzt lokal vor.';

        final coverLine = progress.totalCovers > 0
            ? '${progress.completedCovers}/${progress.totalCovers} Cover'
            : null;

        final bytesLine = progress.estimatedBytes > 0
            ? '${_formatBytes(progress.downloadedBytes)} von ${_formatBytes(progress.estimatedBytes)}'
            : progress.downloadedBytes > 0
                ? '${_formatBytes(progress.downloadedBytes)} geladen'
                : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        progress.isRunning ? Icons.cloud_download : Icons.check_circle,
                        color: progress.isRunning
                            ? theme.colorScheme.primary
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress.coverFraction > 0 ? progress.coverFraction : null,
                  ),
                  const SizedBox(height: 8),
                  if (coverLine != null || bytesLine != null)
                    Text(
                      [coverLine, bytesLine]
                          .whereType<String>()
                          .join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
}
