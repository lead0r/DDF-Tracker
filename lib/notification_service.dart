import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'episode.dart';

class NotificationService {
  static Future<void> initialize() async {
    // Vereinfachte Initialisierung ohne Benachrichtigungen
    print('Benachrichtigungsdienst initialisiert (vereinfachte Version)');
  }

  static Future<void> checkForNewEpisodes(List<Episode> currentEpisodes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckDate = prefs.getString('last_notification_check');

      // Speichere das heutige Datum als letztes Prüfdatum
      await prefs.setString('last_notification_check', DateTime.now().toIso8601String());

      // Wenn wir die Episode-IDs bereits kennen, laden wir sie
      final knownEpisodeIds = prefs.getStringList('known_episode_ids') ?? [];

      // Aktuelle Episode-IDs extrahieren
      final currentEpisodeIds = currentEpisodes.map((e) => e.id).toList();

      // Neue Episoden finden
      final newEpisodeIds = currentEpisodeIds
          .where((id) => !knownEpisodeIds.contains(id))
          .toList();

      if (newEpisodeIds.isEmpty) {
        print('Keine neuen Episoden gefunden');
        return;
      }

      // Neue Episoden speichern
      await prefs.setStringList('known_episode_ids', currentEpisodeIds);

      // Nur Benachrichtigung in der Konsole ausgeben
      if (lastCheckDate != null) {
        final newEpisodes = currentEpisodes
            .where((e) => newEpisodeIds.contains(e.id))
            .toList();

        for (var episode in newEpisodes) {
          final numberPart = episode.nummer > 0 ? ' (${episode.nummer})' : '';
          print('Neue Folge verfügbar: ${episode.titel}$numberPart');
        }
      }
    } catch (e) {
      print('Fehler bei der Prüfung auf neue Episoden: $e');
    }
  }

  static Future<void> scheduleReminder() async {
    print('Erinnerung an ungehörte Folgen geplant (vereinfachte Version)');
  }

  // Diese Methode zeigt nur eine In-App-Benachrichtigung (SnackBar) an
  static void showInAppNotification(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(message),
          ],
        ),
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}