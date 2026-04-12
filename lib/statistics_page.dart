import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'main.dart';
import 'episode.dart';
import 'widgets/persistent_cover_image.dart';
import 'package:provider/provider.dart';
import 'episode_state_provider.dart';
import 'episode_detail_page.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class StatisticsPage extends StatefulWidget {
  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  Map<String, dynamic>? statistics;
  final GlobalKey _sharePicKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateStatistics();
  }

  Future<void> _calculateStatistics() async {
    final episodeProvider =
    Provider.of<EpisodeStateProvider>(context, listen: false);
    final episodes = episodeProvider.episodes;

    // Überblick
    int totalEpisodes = episodes.length;
    int listenedEpisodes = episodes.where((ep) => ep.listened).length;
    double listenedPercentage =
    totalEpisodes > 0 ? (listenedEpisodes / totalEpisodes * 100) : 0.0;

    // Bewertung
    final ratedEpisodes = episodes.where((ep) => ep.rating > 0).toList();
    double averageRating = ratedEpisodes.isNotEmpty
        ? ratedEpisodes.fold<int>(0, (sum, ep) => sum + ep.rating) /
        ratedEpisodes.length
        : 0.0;

    // Bewertungsverteilung
    Map<int, int> ratingDistribution = {};
    for (int i = 0; i <= 5; i++) {
      ratingDistribution[i] = episodes.where((ep) => ep.rating == i).length;
    }

    // Top 10
    List<Episode> top10 = List<Episode>.from(ratedEpisodes)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    if (top10.length > 10) top10 = top10.sublist(0, 10);

    setState(() {
      statistics = {
        'totalEpisodes': totalEpisodes,
        'listenedEpisodes': listenedEpisodes,
        'listenedPercentage': listenedPercentage.toStringAsFixed(1),
        'averageRating': averageRating.toStringAsFixed(1),
        'ratingDistribution': ratingDistribution,
        'top10': top10,
      };
    });
  }

  Future<void> _shareStatisticsPic() async {
    try {
      RenderRepaintBoundary boundary =
      _sharePicKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/statistik_share.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Meine Drei ??? Hörstatistiken!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Teilen des Bildes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);
    final episodeProvider = Provider.of<EpisodeStateProvider>(context);
    final episodes = episodeProvider.episodes;

    // Gruppiere die Episoden nach Typ
    final mainEpisodes = episodes.where((e) => e.serieTyp == 'Serie').toList();
    final spezialEpisodes =
    episodes.where((e) => e.serieTyp == 'Spezial').toList();
    final kurzEpisodes =
    episodes.where((e) => e.serieTyp == 'Kurzgeschichte').toList();
    final kidsEpisodes = episodes.where((e) => e.serieTyp == 'Kids').toList();
    final dr3iEpisodes = episodes.where((e) => e.serieTyp == 'DR3i').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Statistiken'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            tooltip: 'Statistik als Bild teilen',
            onPressed: _shareStatisticsPic,
          ),
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
            ),
            onPressed: () => appState?.toggleTheme(),
          ),
        ],
      ),
      body: statistics == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _sharePicKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewSection(),
              SizedBox(height: 24),

              // Fortschritt pro Serie (rot/grüne Balken) in gewünschter Reihenfolge
              _buildProgressTimeline(mainEpisodes, '???'),
              _buildProgressTimeline(spezialEpisodes, 'Spezial'),
              _buildProgressTimeline(kurzEpisodes, 'Kurzgeschichten'),
              _buildProgressTimeline(kidsEpisodes, 'Kids'),
              _buildProgressTimeline(dr3iEpisodes, 'DR3i'),

              SizedBox(height: 24),
              _buildRatingDistributionSection(),

              SizedBox(height: 24),
              _buildTop10Section(),

              SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    final s = statistics!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Überblick',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow('Folgen insgesamt:', '${s['totalEpisodes']}'),
                SizedBox(height: 8),
                _buildStatRow('Gehörte Folgen:', '${s['listenedEpisodes']}'),
                SizedBox(height: 8),
                _buildStatRow('Fortschritt:', '${s['listenedPercentage']}%'),
                SizedBox(height: 8),
                _buildStatRow(
                    'Durchschnittliche Bewertung:', '${s['averageRating']} ⭐'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTop10Section() {
    final List<Episode> top10 =
    List<Episode>.from(statistics!['top10'] as List);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top 10 Lieblingsepisoden',
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: top10
                  .map(
                    (ep) => ListTile(
                  leading: ep.coverUrl != null && ep.coverUrl!.isNotEmpty
                      ? GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            EpisodeDetailPage(episode: ep),
                      ));
                    },
                    child: PersistentCoverImage(
                      imageUrl: ep.coverUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                      : Icon(Icons.album),
                  title: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EpisodeDetailPage(episode: ep),
                      ));
                    },
                    child: Text(
                      ep.formattedTitle,
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  subtitle: Row(
                    children: List.generate(
                      5,
                          (i) => Icon(
                        ep.rating > i ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingDistributionSection() {
    final Map<int, int> ratingDistribution =
    Map<int, int>.from(statistics!['ratingDistribution'] as Map);

    final maxCount =
    ratingDistribution.values.fold<int>(1, (max, c) => c > max ? c : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bewertungsverteilung',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                for (int i = 5; i >= 1; i--)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Row(
                            children: List.generate(
                              i,
                                  (index) => Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxCount > 0
                                  ? (ratingDistribution[i] ?? 0) / maxCount
                                  : 0,
                              minHeight: 16,
                              backgroundColor: Colors.grey[300],
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${ratingDistribution[i] ?? 0}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text('Keine'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxCount > 0
                              ? (ratingDistribution[0] ?? 0) / maxCount
                              : 0,
                          minHeight: 16,
                          backgroundColor: Colors.grey[300],
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.grey),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${ratingDistribution[0] ?? 0}',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTimeline(List<Episode> episodes, String title) {
    if (episodes.isEmpty) return SizedBox();

    // Chronologisch sortieren
    final sorted = List<Episode>.from(episodes)
      ..sort((a, b) =>
          (a.veroeffentlichungsdatum ?? '').compareTo(b.veroeffentlichungsdatum ?? ''));

    final total = sorted.length;
    final listened = sorted.where((e) => e.listened).length;

    // Maximal 100 Balken, jeder Balken steht für n Folgen
    const maxBars = 100;
    final bars = <Widget>[];
    final groupSize = (total / maxBars).ceil().clamp(1, total);

    for (int i = 0; i < total; i += groupSize) {
      final group = sorted.sublist(i, (i + groupSize).clamp(0, total));
      final listenedCount = group.where((e) => e.listened).length;
      final color =
      listenedCount >= (group.length / 2) ? Colors.green : Colors.red;

      bars.add(
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 0.5),
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: $listened/$total (${total > 0 ? ((listened / total) * 100).toStringAsFixed(1) : '0'}%)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: bars),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}