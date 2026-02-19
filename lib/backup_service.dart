import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'database_service.dart';
import 'episode_data_service.dart';

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
        subject: 'Drei ??? Guide Backup',
      );

      return 'Backup erfolgreich erstellt und geteilt';
    } catch (e) {
      return 'Fehler beim Erstellen des Backups: $e';
    }
  }

  static Future<String> importDataFromFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return 'Keine Datei ausgewählt';
      }

      final file = result.files.single;
      String? jsonString;

      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      }

      if (jsonString == null || jsonString.isEmpty) {
        return 'Datei konnte nicht gelesen werden';
      }

      try {
        final Map<String, dynamic> importData = json.decode(jsonString);

        if (!importData.containsKey('episode_state') || !importData.containsKey('episode_state_history')) {
          return 'Ungültiges Backup-Format';
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
          return 'Import abgebrochen';
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

        return 'Backup erfolgreich importiert';
      } catch (e) {
        return 'Fehler beim Parsen der Datei: $e';
      }
    } catch (e) {
      return 'Fehler beim Importieren des Backups: $e';
    }
  }

  static Future<void> showBackupDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Backup-Optionen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.upload),
              title: Text('Backup exportieren'),
              subtitle: Text('Notizen, Bewertungen und Hörstatus exportieren'),
              onTap: () async {
                Navigator.pop(context);
                final message = await createAndShareBackupFile();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.download),
              title: Text('Backup importieren'),
              subtitle: Text('Gespeicherte JSON-Backup-Datei auswählen und importieren'),
              onTap: () async {
                Navigator.pop(context);
                final message = await importDataFromFile(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Schließen'),
          ),
        ],
      ),
    );
  }
}