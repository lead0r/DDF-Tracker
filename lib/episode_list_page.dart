import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'episode.dart';
import 'episode_detail_page.dart';
import 'backup_service.dart';
import 'statistics_page.dart';
import 'settings_page.dart';
import 'main.dart';
import 'widgets/persistent_cover_image.dart';
import 'widgets/cover_warmup_banner.dart';
import 'episode_state_provider.dart';
import 'database_service.dart';
import 'random_episode_page.dart';
import 'services/cover_storage/cover_prefetch_service.dart';

class EpisodeListPage extends StatefulWidget {
  const EpisodeListPage({super.key});

  @override
  _EpisodeListPageState createState() => _EpisodeListPageState();
}

class _EpisodeListPageState extends State<EpisodeListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool _showFuture = false;
  String _sortBy = 'date';
  String _selectedAuthor = '';
  String _selectedYear = '';
  int _selectedRating = -1;
  String _selectedListened = '';
  String _selectedType = '';
  bool _onlyRated = false;
  String _selectedRole = '';
  List<Episode>? _cachedFilteredEpisodes;
  int? _cachedTabIndex;
  String? _cachedSearch;
  String? _cachedSortBy;
  String? _cachedSelectedAuthor;
  String? _cachedSelectedYear;
  int? _cachedSelectedRating;
  String? _cachedSelectedListened;
  String? _cachedSelectedType;
  bool? _cachedOnlyRated;
  List<Episode>? _cachedEpisodes;
  bool _snackbarShown = false;
  final Map<int, List<Episode>> _tabFilteredCache = {};
  int? _lastTabIndex;
  String? _lastSearch;
  String? _lastSortBy;
  String? _lastSelectedAuthor;
  String? _lastSelectedYear;
  int? _lastSelectedRating;
  String? _lastSelectedListened;
  String? _lastSelectedType;
  bool? _lastOnlyRated;
  List<Episode>? _lastEpisodes;
  String? _cachedSelectedRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _tabController.previousIndex) {
        setState(() {
          _tabFilteredCache.clear();
          _lastTabIndex = null;
          _lastSearch = null;
          _lastSortBy = null;
          _lastSelectedAuthor = null;
          _lastSelectedYear = null;
          _lastSelectedRating = null;
          _lastSelectedListened = null;
          _lastSelectedType = null;
          _lastOnlyRated = null;
          _lastEpisodes = null;
        });
      }
    });
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text;
      });
    });
  }

  List<Episode> getFilteredEpisodesForCurrentTab(List<Episode> episodes) {
    // Prüfe, ob sich relevante Parameter geändert haben
    if (_lastTabIndex == _tabController.index &&
        _lastSearch == _search &&
        _lastSortBy == _sortBy &&
        _lastSelectedAuthor == _selectedAuthor &&
        _lastSelectedYear == _selectedYear &&
        _lastSelectedRating == _selectedRating &&
        _lastSelectedListened == _selectedListened &&
        _lastSelectedType == _selectedType &&
        _lastOnlyRated == _onlyRated &&
        _lastEpisodes == episodes &&
        _tabFilteredCache.containsKey(_tabController.index)) {
      return _tabFilteredCache[_tabController.index]!;
    }

    // Filtere nach Tab - Optimierte Version
    List<Episode> filtered;
    switch (_tabController.index) {
      case 0:
        filtered = episodes.where((e) => e.serieTyp == 'Serie' || e.serieTyp == 'Spezial' || e.serieTyp == 'Kurzgeschichte').toList();
        break;
      case 1:
        filtered = episodes.where((e) => e.serieTyp == 'Kids').toList();
        break;
      case 2:
        filtered = episodes.where((e) => e.serieTyp == 'DR3i').toList();
        break;
      default:
        filtered = [];
    }

    // Optimierte Filterung: Kombiniere alle Filter in einer Schleife
    if (_search.isNotEmpty || _selectedAuthor.isNotEmpty || _selectedYear.isNotEmpty || 
        _selectedRating != -1 || _selectedListened.isNotEmpty || _selectedType.isNotEmpty || _onlyRated) {
      filtered = filtered.where((ep) {
        bool matches = true;
        
        // Suchtext
        if (_search.isNotEmpty) {
          matches = matches && (
            ep.titel.toLowerCase().contains(_search.toLowerCase()) ||
            ep.nummer.toString().contains(_search) ||
            ep.autor.toLowerCase().contains(_search.toLowerCase())
          );
        }
        
        // Autor
        if (_selectedAuthor.isNotEmpty) {
          matches = matches && ep.autor == _selectedAuthor;
        }
        
        // Jahr
        if (_selectedYear.isNotEmpty) {
          matches = matches && (ep.veroeffentlichungsdatum != null && 
            ep.veroeffentlichungsdatum!.startsWith(_selectedYear));
        }
        
        // Bewertung
        if (_selectedRating != -1) {
          matches = matches && ep.rating == _selectedRating;
        }
        
        // Gehört-Status
        if (_selectedListened.isNotEmpty) {
          matches = matches && (_selectedListened == 'true' ? ep.listened : !ep.listened);
        }
        
        // Typ
        if (_selectedType.isNotEmpty) {
          matches = matches && (
            (_selectedType == 'Regulaer' && (ep.serieTyp == 'Serie' || ep.serieTyp == null || ep.serieTyp!.isEmpty)) ||
            (_selectedType == 'Spezial' && ep.serieTyp == 'Spezial') ||
            (_selectedType == 'Kurzgeschichte' && ep.serieTyp == 'Kurzgeschichte')
          );
        }
        
        // Nur bewertete
        if (_onlyRated) {
          matches = matches && ep.rating > 0;
        }
        
        return matches;
      }).toList();
    }

    // Filter nach Rolle
    if (_selectedRole.isNotEmpty) {
      filtered = filtered.where((ep) =>
        (ep.sprechrollen ?? []).any((s) => (s['rolle'] ?? '') == _selectedRole)
      ).toList();
    }

    // Optimierte Sortierung
    switch (_sortBy) {
      case 'date':
        filtered.sort((a, b) => (b.veroeffentlichungsdatum ?? '').compareTo(a.veroeffentlichungsdatum ?? ''));
        break;
      case 'oldest':
        filtered.sort((a, b) => (a.veroeffentlichungsdatum ?? '').compareTo(b.veroeffentlichungsdatum ?? ''));
        break;
      case 'rating_high':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'rating_low':
        filtered.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case 'title':
        filtered.sort((a, b) => a.titel.toLowerCase().compareTo(b.titel.toLowerCase()));
        break;
      case 'number':
        filtered.sort((a, b) => b.nummer.compareTo(a.nummer));
        break;
    }

    // Cache aktualisieren
    _tabFilteredCache[_tabController.index] = filtered;
    _lastTabIndex = _tabController.index;
    _lastSearch = _search;
    _lastSortBy = _sortBy;
    _lastSelectedAuthor = _selectedAuthor;
    _lastSelectedYear = _selectedYear;
    _lastSelectedRating = _selectedRating;
    _lastSelectedListened = _selectedListened;
    _lastSelectedType = _selectedType;
    _lastOnlyRated = _onlyRated;
    _lastEpisodes = episodes;

    return filtered;
  }

  List<Episode> _futureEpisodes(List<Episode> episodes) =>
      episodes.where((ep) => ep.isFutureRelease).toList();
  List<Episode> _pastEpisodes(List<Episode> episodes) =>
      episodes.where((ep) => !ep.isFutureRelease).toList();

  Future<void> _showFilterDialog() async {
    final episodeProvider = Provider.of<EpisodeStateProvider>(context, listen: false);
    final episodes = episodeProvider.episodes;
    List<Episode> currentEpisodes = getFilteredEpisodesForCurrentTab(episodes);
    if (currentEpisodes.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Filter auswählen'),
          content: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Schließen'),
            ),
          ],
        ),
      );
      return;
    }
    final authors = <String>{};
    final years = <String>{};
    for (var ep in currentEpisodes) {
      if (ep.autor.isNotEmpty) {
        ep.autor.split(',').map((a) => a.trim()).forEach(authors.add);
      }
      if (ep.veroeffentlichungsdatum != null && ep.veroeffentlichungsdatum!.length >= 4) {
        years.add(ep.veroeffentlichungsdatum!.substring(0, 4));
      }
    }
    final sortedAuthors = authors.where((a) => a.isNotEmpty).toList()..sort();
    final sortedYears = years.where((y) => y.isNotEmpty).toList()..sort((a, b) => b.compareTo(a));
    final ratingList = List.generate(5, (i) => 5 - i);
    final listenedValues = ['', 'true', 'false'];
    final typeItems = [
      DropdownMenuItem(value: '', child: Text('Alle Folgen')),
      DropdownMenuItem(value: 'Regulaer', child: Text('Nur reguläre Folgen')),
      DropdownMenuItem(value: 'Spezial', child: Text('Nur Spezialfolgen')),
      DropdownMenuItem(value: 'Kurzgeschichte', child: Text('Nur Kurzgeschichten')),
    ];

    // Lokale Kopien der Filterwerte
    String authorValue = _selectedAuthor;
    String yearValue = _selectedYear;
    int ratingValue = _selectedRating;
    String listenedValue = _selectedListened;
    String typeValue = _selectedType;
    bool onlyRatedValue = _onlyRated;
    String roleValue = _selectedRole;

    // Wert auf gültigen Wert mappen
    if (!sortedAuthors.contains(authorValue)) authorValue = '';
    if (!sortedYears.contains(yearValue)) yearValue = '';
    if (!ratingList.contains(ratingValue)) ratingValue = -1;
    if (!listenedValues.contains(listenedValue)) listenedValue = '';
    if (!['', 'Regulaer', 'Spezial', 'Kurzgeschichte'].contains(typeValue)) typeValue = '';

    final authorItems = sortedAuthors.isEmpty
      ? [DropdownMenuItem(value: '', child: Text('Keine Autoren'))]
      : [DropdownMenuItem(value: '', child: Text('Alle Autoren'))] +
        sortedAuthors.map((a) => DropdownMenuItem(
          value: a,
          child: Container(
            constraints: BoxConstraints(maxWidth: 180),
            child: Text(a, overflow: TextOverflow.ellipsis),
          ),
        )).toList();

    final yearItems = sortedYears.isEmpty
      ? [DropdownMenuItem(value: '', child: Text('Keine Jahre'))]
      : [DropdownMenuItem(value: '', child: Text('Alle Jahre'))] +
        sortedYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList();

    final ratingItems = [DropdownMenuItem(value: -1, child: Text('Alle Bewertungen'))] +
      ratingList.map((r) => DropdownMenuItem(value: r, child: Text('$r Sterne'))).toList();

    final listenedItems = [
      DropdownMenuItem(value: '', child: Text('Alle')),
      DropdownMenuItem(value: 'true', child: Text('Gehört')),
      DropdownMenuItem(value: 'false', child: Text('Nicht gehört')),
    ];

    // NEU: Gecachte Rollen verwenden
    final sortedRoles = episodeProvider.cachedRoles;
    final roleItems = sortedRoles.isEmpty
      ? [DropdownMenuItem(value: '', child: Text('Keine Rollen'))]
      : [DropdownMenuItem(value: '', child: Text('Alle Rollen'))] +
        sortedRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Filter auswählen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: authorItems.any((item) => item.value == authorValue) ? authorValue : authorItems.first.value,
                  items: authorItems,
                  onChanged: (v) => setState(() => authorValue = v ?? ''),
                  decoration: InputDecoration(labelText: 'Autor'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: yearItems.any((item) => item.value == yearValue) ? yearValue : yearItems.first.value,
                  items: yearItems,
                  onChanged: (v) => setState(() => yearValue = v ?? ''),
                  decoration: InputDecoration(labelText: 'Jahr'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: ratingItems.any((item) => item.value == ratingValue) ? ratingValue : ratingItems.first.value,
                  items: ratingItems,
                  onChanged: (v) => setState(() => ratingValue = v ?? -1),
                  decoration: InputDecoration(labelText: 'Bewertung'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: listenedItems.any((item) => item.value == listenedValue) ? listenedValue : listenedItems.first.value,
                  items: listenedItems,
                  onChanged: (v) => setState(() => listenedValue = v ?? ''),
                  decoration: InputDecoration(labelText: 'Gehört-Status'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: typeValue,
                  items: typeItems,
                  onChanged: (v) => setState(() => typeValue = v ?? ''),
                  decoration: InputDecoration(labelText: 'Folgentyp'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: roleItems.any((item) => item.value == roleValue) ? roleValue : roleItems.first.value,
                  items: roleItems,
                  onChanged: (v) => setState(() => roleValue = v ?? ''),
                  decoration: InputDecoration(labelText: 'Rolle'),
                ),
                SizedBox(height: 8),
                CheckboxListTile(
                  value: onlyRatedValue,
                  onChanged: (v) => setState(() => onlyRatedValue = v ?? false),
                  title: Text('Nur bewertete Episoden'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'author': '',
                  'year': '',
                  'rating': -1,
                  'listened': '',
                  'type': '',
                  'onlyRated': false,
                  'role': '',
                });
              },
              child: Text('Zurücksetzen'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'author': authorValue,
                  'year': yearValue,
                  'rating': ratingValue,
                  'listened': listenedValue,
                  'type': typeValue,
                  'onlyRated': onlyRatedValue,
                  'role': roleValue,
                });
              },
              child: Text('Anwenden'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: Text('Schließen'),
            ),
          ],
        ),
      ),
    );

    // Nach dem Dialog: Filter im Haupt-Widget setzen und Liste neu bauen
    if (result != null) {
      setState(() {
        _selectedAuthor = result['author'];
        _selectedYear = result['year'];
        _selectedRating = result['rating'];
        _selectedListened = result['listened'];
        _selectedType = result['type'] ?? '';
        _onlyRated = result['onlyRated'] ?? false;
        _selectedRole = result['role'] ?? '';
      });
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Sortieren nach'),
        children: [
          RadioListTile<String>(
            value: 'date',
            groupValue: _sortBy,
            title: Text('Neueste zuerst'),
            onChanged: (v) {
              setState(() => _sortBy = v!);
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            value: 'oldest',
            groupValue: _sortBy,
            title: Text('Älteste zuerst'),
            onChanged: (v) {
              setState(() => _sortBy = v!);
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            value: 'rating_high',
            groupValue: _sortBy,
            title: Text('Höchste Bewertung'),
            onChanged: (v) {
              setState(() => _sortBy = v!);
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            value: 'rating_low',
            groupValue: _sortBy,
            title: Text('Niedrigste Bewertung'),
            onChanged: (v) {
              setState(() => _sortBy = v!);
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            value: 'title',
            groupValue: _sortBy,
            title: Text('Titel (A-Z)'),
            onChanged: (v) {
              setState(() => _sortBy = v!);
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            value: 'number',
            groupValue: _sortBy,
            title: Text('Folgen-Nummer absteigend'),
            onChanged: (v) {
              setState(() => _sortBy = v!);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);
    final episodeProvider = Provider.of<EpisodeStateProvider>(context);
    final episodes = episodeProvider.episodes;
    final loading = episodeProvider.loading;
    final error = episodeProvider.error;
    final backgroundUpdateFailed = episodeProvider.backgroundUpdateFailed;

    // --- Alle Sprechrollen extrahieren (außer Hauptrollen) ---
    final Set<String> allRoles = {};
    for (final ep in episodes) {
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

    // Fehler-Snackbar anzeigen, wenn error != null und noch nicht gezeigt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (error != null && !_snackbarShown && ScaffoldMessenger.of(context).mounted) {
        _snackbarShown = true;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error,
              style: TextStyle(color: Colors.red),
            ),
            backgroundColor: Colors.red[50],
            action: SnackBarAction(
              label: 'Erneut versuchen',
              textColor: Colors.red,
              onPressed: () {
                episodeProvider.loadEpisodes();
              },
            ),
            duration: Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (error == null && _snackbarShown) {
        _snackbarShown = false;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text('???'),
            if (backgroundUpdateFailed)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Tooltip(
                  message: 'Letztes Hintergrund-Update fehlgeschlagen',
                  child: Icon(Icons.warning, color: Colors.orange, size: 22),
                ),
              ),
          ],
        ),
        actions: [
          SizedBox(width: 6),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          SizedBox(width: 2),

          IconButton(
            icon: Icon(Icons.backup),
            tooltip: 'Backup',
            onPressed: () => BackupService.showBackupDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.sort),
            tooltip: 'Sortieren',
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: Icon(Icons.bar_chart),
            tooltip: 'Statistiken',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatisticsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_alt),
            tooltip: 'Filter',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.casino),
            tooltip: 'Zufällige Folge',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RandomEpisodePage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage())),
          ),
          IconButton(
            icon: Icon(appState?.themeMode == ThemeMode.dark ? Icons.wb_sunny : Icons.nightlight_round),
            tooltip: 'Dark/Light Mode',
            onPressed: () => appState?.toggleTheme(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '???'),
            Tab(text: 'Kids'),
            Tab(text: 'DR3i'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Suche Episoden...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _search = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
              ),
            ),
          ),
          const CoverWarmupBanner(),
          // Das Fehler-Banner nur anzeigen, wenn die Snackbar nicht gezeigt wird
          if (error != null && !_snackbarShown)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: MaterialBanner(
                content: Text(
                  error,
                  style: TextStyle(color: Colors.red),
                ),
                backgroundColor: Colors.red[50],
                actions: [
                  TextButton(
                    onPressed: () {
                      episodeProvider.loadEpisodes();
                    },
                    child: Text('Erneut versuchen'),
                  ),
                  TextButton(
                    onPressed: () {
                      episodeProvider.clearError();
                    },
                    child: Text('Schließen'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(getFilteredEpisodesForCurrentTab(episodes)),
                      _buildList(getFilteredEpisodesForCurrentTab(episodes)),
                      _buildList(getFilteredEpisodesForCurrentTab(episodes)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Episode> episodes) {
    final filteredEpisodes = getFilteredEpisodesForCurrentTab(episodes);
    final future = filteredEpisodes.where((ep) => ep.isFutureRelease).toList();
    final past = filteredEpisodes.where((ep) => !ep.isFutureRelease).toList();
    return ListView(
      children: [
        ExpansionTile(
          title: Text('Zukünftige Episoden (${future.length})'),
          initiallyExpanded: _showFuture,
          onExpansionChanged: (v) => setState(() => _showFuture = v),
          children: future.map((ep) => _buildTile(ep)).toList(),
        ),
        ...past.map((ep) => _buildTile(ep)),
      ],
    );
  }

  Widget _buildTile(Episode ep) {
    return ListTile(
      leading: ep.coverUrl != null && ep.coverUrl!.isNotEmpty
          ? PersistentCoverImage(
              imageUrl: ep.coverUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(6),
            )
          : Icon(Icons.album, size: 48),
      title: Text(ep.nummer != null && ep.nummer > 0 ? '${ep.nummer} / ${ep.titel}' : ep.titel),
      subtitle: Row(
        children: [
          ...List.generate(5, (i) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            if (ep.rating == 0) {
              return Icon(
                Icons.star_border,
                color: isDark ? Colors.white : Colors.grey[400],
                size: 20,
              );
            } else {
              return Icon(
                i < ep.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 20,
              );
            }
          }),
          SizedBox(width: 8),
          ep.listened
              ? Icon(Icons.check_circle, color: Colors.green, size: 22)
              : Icon(
                  Icons.radio_button_unchecked,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.grey[400],
                  size: 22,
                ),
          if (ep.serieTyp == 'Spezial')
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(Icons.auto_awesome, color: Colors.purple, size: 20, semanticLabel: 'Spezialfolge'),
            ),
          if (ep.serieTyp == 'Kurzgeschichte')
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(Icons.menu_book, color: Colors.blue, size: 20, semanticLabel: 'Kurzgeschichte'),
            ),
        ],
      ),
      trailing: ep.isFutureRelease
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('NEU', style: TextStyle(color: Colors.white)),
            )
          : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EpisodeDetailPage(episode: ep),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}  