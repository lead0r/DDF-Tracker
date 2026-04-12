import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'episode.dart';
import 'episode_state_provider.dart';
import 'episode_detail_page.dart';
import 'main.dart';

class RandomEpisodePage extends StatefulWidget {
  @override
  State<RandomEpisodePage> createState() => _RandomEpisodePageState();
}

class _RandomEpisodePageState extends State<RandomEpisodePage>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  Episode? _selected;

  bool includeDdf = true;
  bool includeKids = true;
  bool includeDr3i = true;
  bool includeSpecial = true;
  bool includeShort = true;

  String listenedFilter = 'both'; // both | listened | unlistened

  late final AnimationController _diceCtrl;
  late final Animation<double> _shake;
  late final Animation<double> _scale;

  bool _isRolling = false;

  @override
  void initState() {
    super.initState();

    _diceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _shake = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.08, end: 0.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.08, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_diceCtrl);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_diceCtrl);
  }

  @override
  void dispose() {
    _diceCtrl.dispose();
    super.dispose();
  }

  List<Episode> _filtered(List<Episode> all) {
    return all.where((e) {
      final type = e.serieTyp ?? '';

      if (!includeDdf && type == 'Serie') return false;
      if (!includeKids && type == 'Kids') return false;
      if (!includeDr3i && type == 'DR3i') return false;
      if (!includeSpecial && type == 'Spezial') return false;
      if (!includeShort && type == 'Kurzgeschichte') return false;

      if (listenedFilter == 'listened' && !e.listened) return false;
      if (listenedFilter == 'unlistened' && e.listened) return false;

      return true;
    }).toList();
  }

  Future<void> _rollAnimated(List<Episode> pool) async {
    if (_isRolling) return;

    if (pool.isEmpty) {
      setState(() => _selected = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Folgen passen zu den Filtern.')),
      );
      return;
    }

    setState(() => _isRolling = true);

    try {
      await _diceCtrl.forward(from: 0);
      setState(() {
        _selected = pool[_rng.nextInt(pool.length)];
      });
    } finally {
      setState(() => _isRolling = false);
    }
  }

  String _seriesLabel(Episode e) {
    switch (e.serieTyp) {
      case 'Serie':
        return 'Die Drei ???';
      case 'Kids':
        return 'Die Drei ??? Kids';
      case 'DR3i':
        return 'DiE DR3i';
      case 'Spezial':
        return 'Die Drei ??? Spezialfolge';
      case 'Kurzgeschichte':
        return 'Die Drei ??? Kurzgeschichte';
      default:
        return e.serieTyp ?? '';
    }
  }

  String _episodeTitle(Episode e) {
    return e.formattedTitle;
  }

  @override
  Widget build(BuildContext context) {
    final episodes = context.watch<EpisodeStateProvider>().episodes;
    final pool = _filtered(episodes);

    final cs = Theme.of(context).colorScheme;

    // Grayscale-ish colors (theme aware)
    final neutralBg = cs.surface;
    final neutralSelectedBg = cs.surfaceContainerHighest;
    final neutralBorder = cs.outlineVariant;
    final neutralText = cs.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zufällige Folge'),
        actions: [
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Light mode'
                : 'Dark mode',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => MyApp.of(context)?.toggleTheme(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ Serien Filter
          const Text('Serien', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                label: 'Die drei ???',
                selected: includeDdf,
                onChanged: (v) => setState(() => includeDdf = v),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
              _filterChip(
                label: 'Kids',
                selected: includeKids,
                onChanged: (v) => setState(() => includeKids = v),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
              _filterChip(
                label: 'DR3i',
                selected: includeDr3i,
                onChanged: (v) => setState(() => includeDr3i = v),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
              _filterChip(
                label: 'Spezialfolgen',
                selected: includeSpecial,
                onChanged: (v) => setState(() => includeSpecial = v),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
              _filterChip(
                label: 'Kurzgeschichten',
                selected: includeShort,
                onChanged: (v) => setState(() => includeShort = v),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ Status Filter
          const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip(
                label: 'beide',
                selected: listenedFilter == 'both',
                onTap: () => setState(() => listenedFilter = 'both'),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
              _choiceChip(
                label: 'ungehört',
                selected: listenedFilter == 'unlistened',
                onTap: () => setState(() => listenedFilter = 'unlistened'),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
              _choiceChip(
                label: 'gehört',
                selected: listenedFilter == 'listened',
                onTap: () => setState(() => listenedFilter = 'listened'),
                bg: neutralBg,
                selectedBg: neutralSelectedBg,
                border: neutralBorder,
                text: neutralText,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ✅ Info-Card
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: neutralText),
              title: Text(
                pool.isEmpty
                    ? 'Keine passenden Folgen für die aktuellen Filter.'
                    : 'Würfeln aus ${pool.length} möglichen Folgen',
                style: TextStyle(color: neutralText),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ Animated dice
          Center(
            child: AnimatedBuilder(
              animation: _diceCtrl,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _shake.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                );
              },
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _isRolling ? null : () => _rollAnimated(pool),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: neutralSelectedBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: neutralBorder),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.casino, size: 80, color: neutralText),
                      if (_isRolling)
                        Positioned(
                          bottom: 14,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: neutralText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ✅ Result with cover preview + nicer series name
          if (_selected != null)
            Card(
              child: ListTile(
                leading: _CoverPreview(
                  // Wenn dein Feld anders heißt: hier anpassen.
                  coverUrl: _selected!.coverUrl,
                  fallbackColor: neutralSelectedBg,
                  borderColor: neutralBorder,
                  iconColor: neutralText,
                ),
                title: Text(_episodeTitle(_selected!)),
                subtitle: Text(
                  '${_seriesLabel(_selected!)} • '
                  '${_selected!.listened ? "gehört" : "ungehört"}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EpisodeDetailPage(episode: _selected!),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onChanged,
    required Color bg,
    required Color selectedBg,
    required Color border,
    required Color text,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      backgroundColor: bg,
      selectedColor: selectedBg,
      labelStyle: TextStyle(color: text),
      checkmarkColor: text,
      side: BorderSide(color: border),
      showCheckmark: true,
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color bg,
    required Color selectedBg,
    required Color border,
    required Color text,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: bg,
      selectedColor: selectedBg,
      labelStyle: TextStyle(color: text),
      side: BorderSide(color: border),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.coverUrl,
    required this.fallbackColor,
    required this.borderColor,
    required this.iconColor,
  });

  final String? coverUrl;
  final Color fallbackColor;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    if (url == null || url.isEmpty) {
      return _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Image.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Icon(Icons.music_note, color: iconColor),
    );
  }
}