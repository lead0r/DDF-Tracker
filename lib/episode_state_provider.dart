import 'package:flutter/material.dart';
import 'episode.dart';
import 'database_service.dart';
import 'episode_data_service.dart';
import 'episode_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async'; // Für unawaited
import 'services/cover_storage/cover_prefetch_service.dart';

class EpisodeStateProvider extends ChangeNotifier {
  List<Episode> _episodes = [];
  bool _loading = false;
  String? _error;
  bool _backgroundUpdateFailed = false;
  List<String> _cachedRoles = [];

  List<Episode> get episodes => _episodes;
  bool get loading => _loading;
  String? get error => _error;
  bool get backgroundUpdateFailed => _backgroundUpdateFailed;
  List<String> get cachedRoles => _cachedRoles;

  Future<void> loadEpisodes() async {
    _loading = true;
    _error = null;
    _backgroundUpdateFailed = false;
    notifyListeners();

    final dataService = EpisodeDataService();
    try {
      // 1. Erst aus Cache laden (schnell)
      final results = await Future.wait([
        dataService.fetchEpisodes(type: 'Serie'),
        dataService.fetchEpisodes(type: 'Spezial'),
        dataService.fetchEpisodes(type: 'Kurzgeschichte'),
        dataService.fetchEpisodes(type: 'Kids'),
        dataService.fetchEpisodes(type: 'DR3i'),
        DatabaseService().getAllStates(),
        EpisodeCacheService.loadRolesFromCache(), // NEU: Rollen aus Cache laden
      ]);
      List<Episode> main = [...results[0] as List<Episode>, ...results[1] as List<Episode>, ...results[2] as List<Episode>];
      List<Episode> kids = results[3] as List<Episode>;
      List<Episode> dr3i = results[4] as List<Episode>;
      final dbStates = results[5] as List<Map<String, dynamic>>;
      _cachedRoles = results[6] as List<String>; // NEU: Gecachte Rollen speichern

      // --- Orphaned States bereinigen, bevor States angewendet werden ---
      final allEpisodeIds = [...main, ...kids, ...dr3i].map((e) => e.id).toList();
      await DatabaseService().removeOrphanedStates(allEpisodeIds);

      // Jetzt nochmal States laden, damit wirklich nur gültige States angewendet werden
      final cleanedDbStates = await DatabaseService().getAllStates();

      void applyState(List<Episode> episodes) {
        for (var ep in episodes) {
          final state = cleanedDbStates.firstWhere(
            (s) => s['episode_id'] == ep.id,
            orElse: () => {},
          );
          if (state.isNotEmpty) {
            ep.listened = (state['listened'] ?? 0) == 1;
            ep.rating = state['rating'] ?? 0;
            ep.note = state['note'] ?? '';
          }
        }
      }
      applyState(main);
      applyState(kids);
      applyState(dr3i);

      // Jetzt erst Episoden setzen und notifyListeners aufrufen!
      _episodes = [...main, ...kids, ...dr3i];
      _loading = false;
      _error = null;
      notifyListeners();

      unawaited(CoverWarmupService.instance.handleNewEpisodes(_episodes));

      // 2. Im Hintergrund: Frische Daten aus dem Netz laden und ggf. updaten
      unawaited(_backgroundUpdate(dataService));
    } catch (e) {
      _loading = false;
      // Zusatz nur einmal anhängen
      _error = 'Fehler beim Laden der Episoden. Bitte überprüfe deine Internetverbindung oder versuche es später erneut.\nLetzte gespeicherte Daten werden angezeigt.';
      notifyListeners();
    }
  }

  Future<void> _backgroundUpdate(EpisodeDataService dataService) async {
    try {
      final freshResults = await Future.wait([
        dataService.fetchEpisodes(type: 'Serie', forceNetwork: true),
        dataService.fetchEpisodes(type: 'Spezial', forceNetwork: true),
        dataService.fetchEpisodes(type: 'Kurzgeschichte', forceNetwork: true),
        dataService.fetchEpisodes(type: 'Kids', forceNetwork: true),
        dataService.fetchEpisodes(type: 'DR3i', forceNetwork: true),
        DatabaseService().getAllStates(),
      ]);
      List<Episode> freshMain = [...freshResults[0] as List<Episode>, ...freshResults[1] as List<Episode>, ...freshResults[2] as List<Episode>];
      List<Episode> freshKids = freshResults[3] as List<Episode>;
      List<Episode> freshDr3i = freshResults[4] as List<Episode>;
      final freshDbStates = freshResults[5] as List<Map<String, dynamic>>;

      void applyState(List<Episode> episodes) {
        for (var ep in episodes) {
          final state = freshDbStates.firstWhere(
            (s) => s['episode_id'] == ep.id,
            orElse: () => {},
          );
          if (state.isNotEmpty) {
            ep.listened = (state['listened'] ?? 0) == 1;
            ep.rating = state['rating'] ?? 0;
            ep.note = state['note'] ?? '';
          }
        }
      }
      applyState(freshMain);
      applyState(freshKids);
      applyState(freshDr3i);

      final freshEpisodes = [...freshMain, ...freshKids, ...freshDr3i];
      
      // NEU: Rollen im Hintergrund aktualisieren
      final Set<String> allRoles = {};
      for (final ep in freshEpisodes) {
        if (ep.sprechrollen != null) {
          for (final s in ep.sprechrollen!) {
            final rolle = (s['rolle'] ?? '').toString();
            if (rolle.isNotEmpty &&
                rolle != 'Justus Jonas, Erster Detektiv' &&
                rolle != 'Peter Shaw, zweiter Detektiv' &&
                rolle != 'Bob Andrews, Recherchen und Archiv') {
              allRoles.add(rolle);
            }
          }
        }
      }
      final sortedRoles = allRoles.toList()..sort();
      if (!_listEquals(_cachedRoles, sortedRoles)) {
        _cachedRoles = sortedRoles;
        await EpisodeCacheService.saveRolesToCache(sortedRoles);
        notifyListeners();
      }

      // Hash-Vergleich statt nur ID-Vergleich
      if (!_listEqualsWithHash(_episodes, freshEpisodes)) {
        _episodes = freshEpisodes;
        notifyListeners();
        unawaited(CoverWarmupService.instance.handleNewEpisodes(_episodes));
      }
      _backgroundUpdateFailed = false;
      notifyListeners();
    } catch (e) {
      print('[ERROR] Fehler beim Hintergrund-Update der Episoden: $e');
      _backgroundUpdateFailed = true;
      notifyListeners();
    }
  }

  // Hash-Vergleich für Episodenlisten
  bool _listEqualsWithHash(List<Episode> a, List<Episode> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].toJson().toString() != b[i].toJson().toString()) return false;
    }
    return true;
  }

  Future<void> updateEpisode(Episode episode, {String? note, int? rating, bool? listened}) async {
    await DatabaseService().updateEpisodeState(
      episode.id,
      note: note,
      rating: rating,
      listened: listened,
    );
    // Lade neuen State aus DB
    final state = await DatabaseService().getEpisodeState(episode.id);
    if (state != null) {
      final idx = _episodes.indexWhere((e) => e.id == episode.id);
      if (idx != -1) {
        _episodes[idx] = Episode(
          id: episode.id,
          nummer: episode.nummer,
          titel: episode.titel,
          autor: episode.autor,
          beschreibung: episode.beschreibung,
          gesamtbeschreibung: episode.gesamtbeschreibung,
          hoerspielskriptautor: episode.hoerspielskriptautor,
          veroeffentlichungsdatum: episode.veroeffentlichungsdatum,
          coverUrl: episode.coverUrl,
          serieTyp: episode.serieTyp,
          sprechrollen: episode.sprechrollen,
          rating: state['rating'] ?? 0,
          listened: (state['listened'] ?? 0) == 1,
          note: state['note'] ?? '',
          spotifyUrl: episode.spotifyUrl,
          links: episode.links,
        );
      }
    }
    notifyListeners();
  }

  // Hilfsfunktion zum Vergleichen von Listen
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
