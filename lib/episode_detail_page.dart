import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'episode.dart';
import 'database_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'episode_state_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/persistent_cover_image.dart';

class EpisodeDetailPage extends StatefulWidget {
  final Episode episode;
  const EpisodeDetailPage({Key? key, required this.episode}) : super(key: key);

  @override
  _EpisodeDetailPageState createState() => _EpisodeDetailPageState();
}

class _EpisodeDetailPageState extends State<EpisodeDetailPage> {
  late TextEditingController _noteController;
  int _rating = 0;
  bool _listened = false;
  bool _saving = false;
  bool _editingNote = false;
  bool _showLargeCover = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.episode.note ?? '');
    _rating = widget.episode.rating;
    _listened = widget.episode.listened;
    _editingNote = (widget.episode.note == null || widget.episode.note!.isEmpty);
  }

  Future<void> _saveState() async {
    setState(() => _saving = true);
    await Provider.of<EpisodeStateProvider>(context, listen: false).updateEpisode(
      widget.episode,
      note: _noteController.text,
      rating: _rating,
      listened: _listened,
    );
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gespeichert!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    await Provider.of<EpisodeStateProvider>(context, listen: false).updateEpisode(
      widget.episode,
      note: _noteController.text,
      rating: _rating,
      listened: _listened,
    );
    setState(() {
      _saving = false;
      _editingNote = false;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notiz gespeichert!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deleteNote() async {
    setState(() => _saving = true);
    await Provider.of<EpisodeStateProvider>(context, listen: false).updateEpisode(
      widget.episode,
      note: '',
      rating: _rating,
      listened: _listened,
    );
    _noteController.clear();
    setState(() {
      _saving = false;
      _editingNote = true;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notiz gelöscht!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _share() {
    final numberPart = widget.episode.nummer > 0 ? ' (#${widget.episode.nummer})' : '';
    final text = 'Meine Bewertung für ${widget.episode.titel}$numberPart: $_rating Sterne\n${_noteController.text}';
    Share.share(text);
  }

  String _providerToLinkKey(String provider) {
    switch (provider) {
      case 'StreamingProvider.spotify':
        return 'spotify';
      case 'StreamingProvider.appleMusic':
        return 'appleMusic';
      case 'StreamingProvider.bookbeat':
        return 'bookbeat';
      case 'StreamingProvider.amazonMusic':
        return 'amazonMusic';
      case 'StreamingProvider.amazon':
        return 'amazon';
      case 'StreamingProvider.youtubeMusic':
        return 'youtubeMusic';
      default:
        return 'spotify';
    }
  }

  void _openStreaming() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('streaming_provider') ?? 'StreamingProvider.spotify';
    final linkKey = _providerToLinkKey(provider);
    final url = widget.episode.links[linkKey] ?? widget.episode.spotifyUrl;
    if (url != null && await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Streaming-Link für den gewählten Anbieter nicht verfügbar.')),
      );
    }
  }

  Future<String> _getProviderName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('streaming_provider');
    switch (name) {
      case 'StreamingProvider.spotify': return 'Spotify';
      case 'StreamingProvider.appleMusic': return 'Apple Music';
      case 'StreamingProvider.bookbeat': return 'Bookbeat';
      case 'StreamingProvider.amazonMusic': return 'Amazon Music';
      case 'StreamingProvider.amazon': return 'Amazon';
      case 'StreamingProvider.youtubeMusic': return 'YouTube Music';
      default: return 'Spotify';
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.length < 10) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatHistoryDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodeProvider = Provider.of<EpisodeStateProvider>(context);
    final ep = episodeProvider.episodes.firstWhere((e) => e.id == widget.episode.id, orElse: () => widget.episode);

    return Scaffold(
      appBar: AppBar(
        title: Text(ep.formattedTitle),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _share,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ep.coverUrl != null && ep.coverUrl!.isNotEmpty)
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showLargeCover = true;
                        });
                      },
                      child: PersistentCoverImage(
                        imageUrl: ep.coverUrl!,
                        height: 200,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text('Autor: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(ep.autor),
                  ],
                ),
                SizedBox(height: 8),
                if (ep.veroeffentlichungsdatum != null)
                  Row(
                    children: [
                      Text('Veröffentlichung: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_formatDate(ep.veroeffentlichungsdatum)),
                    ],
                  ),
                SizedBox(height: 16),
                Text(ep.beschreibung, style: TextStyle(fontSize: 16)),
                SizedBox(height: 16),
                if (ep.serieTyp != 'DR3i') ...[
                  FutureBuilder<String>(
                    future: _getProviderName(),
                    builder: (context, snapshot) {
                      final provider = snapshot.data ?? 'Spotify';
                      return ElevatedButton.icon(
                        icon: Icon(Icons.play_arrow),
                        label: Text('Auf $provider abspielen'),
                        onPressed: _openStreaming,
                      );
                    },
                  ),
                  SizedBox(height: 16),
                ],
                SizedBox(height: 16),
                if (ep.sprechrollen != null && ep.sprechrollen!.isNotEmpty) ...[
                  Text('Sprecher:', style: Theme.of(context).textTheme.titleMedium),
                  ...ep.sprechrollen!.map<Widget>((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text('${s['rolle'] ?? ''}: ${s['sprecher'] ?? ''}'),
                  )),
                  SizedBox(height: 12),
                ],
                if (ep.links['dreifragezeichen'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.link),
                      label: Text('Offizielle Episodenseite'),
                      onPressed: () async {
                        final url = ep.links['dreifragezeichen'];
                        if (url != null && await canLaunch(url)) {
                          await launch(url);
                        }
                      },
                    ),
                  ),
                SizedBox(height: 12),
                Text('Notiz', style: Theme.of(context).textTheme.titleMedium),
                if (_editingNote) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Deine Notiz zur Folge...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.save, color: Colors.blue),
                        tooltip: 'Notiz speichern',
                        onPressed: () {
                          if (_noteController.text.trim().isNotEmpty) {
                            _saveNote();
                          }
                        },
                      ),
                    ],
                  ),
                ] else if ((ep.note ?? '').isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              _editingNote = true;
                              _noteController.text = ep.note ?? '';
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ep.note ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Bearbeiten',
                            onPressed: () {
                              setState(() {
                                _editingNote = true;
                                _noteController.text = ep.note ?? '';
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Löschen',
                            onPressed: _deleteNote,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 8),
                Text('Bewertung', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: List.generate(5, (i) => IconButton(
                    icon: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_rating == i + 1) {
                          _rating = 0;
                        } else {
                          _rating = i + 1;
                        }
                      });
                      _saveState();
                    },
                  )),
                ),
                SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    setState(() => _listened = !_listened);
                    _saveState();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _listened ? Icons.check_box : Icons.check_box_outline_blank,
                        color: _listened ? Colors.green : null,
                      ),
                      SizedBox(width: 8),
                      Text('Gehört'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseService().getHistory(ep.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return SizedBox();
                    final history = snapshot.data!;
                    return ExpansionTile(
                      title: Text('Änderungsverlauf', style: Theme.of(context).textTheme.bodySmall),
                      initiallyExpanded: false,
                      children: [
                        ...history.take(5).map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16),
                          child: Text(
                            '${_formatHistoryDate(h['timestamp'])}: '
                            'Notiz: ${h['note'] ?? ''} | Bewertung: ${h['rating'] ?? ''} | Gehört: ${(h['listened'] ?? 0) == 1 ? 'Ja' : 'Nein'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )),
                      ],
                    );
                  },
                ),
                SizedBox(height: 48),
                if (_saving) ...[
                  SizedBox(height: 16),
                  Center(child: CircularProgressIndicator()),
                ],
                SizedBox(height: 32),
              ],
            ),
          ),
          if (_showLargeCover)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showLargeCover = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.95),
                  child: Stack(
                    children: [
                      Center(
                        child: PersistentCoverImage(
                          imageUrl: ep.coverUrl!,
                          fit: BoxFit.contain,
                          errorIconColor: Colors.white,
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 24,
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.white, size: 36),
                          onPressed: () {
                            setState(() {
                              _showLargeCover = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 