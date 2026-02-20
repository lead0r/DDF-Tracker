import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'database_service.dart';
import 'episode_data_service.dart';
import 'episode_state_provider.dart';

class BackupImportResult {
  final bool success;
  final String message;

  const BackupImportResult({required this.success, required this.message});
}

class BackupService {
  static Future<Map<String, dynamic>> getExportData() async {
    // Hole Daten aus SQLite
    final db = DatabaseService();
    return await db.exportAllToJson();
  }

  static Future<String> createAndShareBackupFile() async {
    try {
      final exportData = await getExportData();
      final jsonString = json.encode(exportData);

      // Temporäre Datei erstellen
      final directory = await getTemporaryDirectory();
      final backupFilePath = '${directory.path}/ddfguide_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(backupFilePath);
      await file.writeAsString(jsonString);

      // Datei teilen
      await Share.shareXFiles(
        [XFile(backupFilePath)],
        subject: '??? Tracker Backup',
      );

      return 'Backup erfolgreich erstellt und geteilt';
    } catch (e) {
      return 'Fehler beim Erstellen des Backups: $e';
    }
  }

  static Future<BackupImportResult> importDataFromFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return const BackupImportResult(success: false, message: 'Keine Datei ausgewählt');
      }

      final file = result.files.single;
      String? jsonString;

      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else if (file.readStream != null) {
        final buffer = await file.readStream!
            .fold<List<int>>([], (previous, element) => previous..addAll(element));
        jsonString = utf8.decode(buffer);
      }

      if (jsonString == null || jsonString.isEmpty) {
        return const BackupImportResult(success: false, message: 'Datei konnte nicht gelesen werden');
      }

      try {
        final Map<String, dynamic> importData = json.decode(jsonString);

        if (!importData.containsKey('episode_state') || !importData.containsKey('episode_state_history')) {
          return const BackupImportResult(success: false, message: 'Ungültiges Backup-Format');
        }

        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Backup importieren'),
            content: Text(
              'Möchtest du wirklich dieses Backup importieren? '
              'Dies überschreibt alle aktuellen Notizen, Bewertungen und Hörstatus.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Importieren'),
              ),
            ],
          ),
        );

        if (confirm != true) {
          return const BackupImportResult(success: false, message: 'Import abgebrochen');
        }

        final db = DatabaseService();
        await db.importAllFromJson(importData);

        await db.removeNullSpezialStates();

        final dataService = EpisodeDataService();
        final main = await dataService.fetchAllMainEpisodes();
        final kids = await dataService.fetchKidsEpisodes();
        final dr3i = await dataService.fetchDr3iEpisodes();
        final allEpisodeIds = [...main, ...kids, ...dr3i].map((e) => e.id).toList();
        await db.removeOrphanedStates(allEpisodeIds);

        final provider = context.read<EpisodeStateProvider>();
        await provider.loadEpisodes();

        return const BackupImportResult(success: true, message: 'Backup erfolgreich importiert');
      } catch (e) {
        return BackupImportResult(success: false, message: 'Fehler beim Parsen der Datei: $e');
      }
    } catch (e) {
      return BackupImportResult(success: false, message: 'Fehler beim Importieren des Backups: $e');
    }
  }

  static Future<void> showBackupDialog(BuildContext context) async {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('Backup-Optionen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.upload),
              title: Text('Backup exportieren'),
              subtitle: Text('Notizen, Bewertungen und Hörstatus exportieren'),
              onTap: () async {
                Navigator.pop(dialogContext);
                final message = await createAndShareBackupFile();
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.download),
              title: Text('Backup importieren'),
              subtitle: Text('Gespeicherte JSON-Backup-Datei auswählen und importieren'),
              onTap: () async {
                Navigator.pop(dialogContext);
                final result = await importDataFromFile(rootContext);
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Schließen'),
          ),
        ],
      ),
    );
  }
}