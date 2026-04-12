import 'dart:convert';

class Episode {
  final String id;
  final int nummer;
  final String titel;
  final String autor;
  final String beschreibung;
  final String? gesamtbeschreibung;
  final String? hoerspielskriptautor;
  final String? veroeffentlichungsdatum;
  final String? coverUrl;
  final String? serieTyp; // Serie, Spezial, Kurzgeschichte, Kids, DR3i
  final List<dynamic>? sprechrollen;
  int rating;
  bool listened;
  String? note;
  final String? spotifyUrl;
  final Map<String, String> links;

  Episode({
    required this.id,
    required this.nummer,
    required this.titel,
    required this.autor,
    required this.beschreibung,
    this.gesamtbeschreibung,
    this.hoerspielskriptautor,
    this.veroeffentlichungsdatum,
    this.coverUrl,
    this.serieTyp,
    this.sprechrollen,
    this.rating = 0,
    this.listened = false,
    this.note,
    this.spotifyUrl,
    Map<String, String>? links,
  }) : links = links ?? const {};

  static Map<String, String> _parseLinks(Map<String, dynamic>? jsonLinks) {
    if (jsonLinks == null) return {};
    return jsonLinks.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  String get formattedTitle => nummer > 0 ? '$nummer / $titel' : titel;


  factory Episode.fromSerieJson(Map<String, dynamic> json) {
    String id;
    final nummer = json['nummer'];
    if (nummer != null && nummer.toString().isNotEmpty && nummer != 'null') {
      id = 'serie_${nummer}';
    } else if (json['titel'] != null && json['titel'].toString().trim().isNotEmpty) {
      id = 'serie_' + json['titel'].toString().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    } else {
      id = 'serie_unbekannt_${DateTime.now().millisecondsSinceEpoch}';
    }
    return Episode(
      id: id,
      nummer: nummer ?? 0,
      titel: json['titel'] ?? '',
      autor: json['autor'] ?? '',
      beschreibung: json['beschreibung'] ?? '',
      gesamtbeschreibung: json['gesamtbeschreibung'],
      hoerspielskriptautor: json['hörspielskriptautor'],
      veroeffentlichungsdatum: json['veröffentlichungsdatum'],
      coverUrl: json['links']?['cover'] ?? json['coverUrl'],
      serieTyp: 'Serie',
      sprechrollen: json['sprechrollen'],
      spotifyUrl: json['spotify'],
      links: _parseLinks(json['links']),
    );
  }

  factory Episode.fromSpezialJson(Map<String, dynamic> json) {
    final nummer = json['nummer'];
    String id;
    if (nummer != null && nummer.toString().isNotEmpty && nummer != 'null') {
      id = 'spezial_${nummer}';
    } else if (json['titel'] != null && json['titel'].toString().trim().isNotEmpty) {
      id = generateSpezialId(json['titel']);
    } else {
      id = 'spezial_unbekannt_${DateTime.now().millisecondsSinceEpoch}';
    }
    return Episode(
      id: id,
      nummer: nummer ?? 0,
      titel: json['titel'] ?? '',
      autor: json['autor'] ?? '',
      beschreibung: json['beschreibung'] ?? '',
      gesamtbeschreibung: json['gesamtbeschreibung'],
      hoerspielskriptautor: json['hörspielskriptautor'],
      veroeffentlichungsdatum: json['veröffentlichungsdatum'],
      coverUrl: json['links']?['cover'] ?? json['coverUrl'],
      serieTyp: 'Spezial',
      sprechrollen: json['sprechrollen'],
      spotifyUrl: json['spotify'],
      links: _parseLinks(json['links']),
    );
  }

  factory Episode.fromKurzgeschichteJson(Map<String, dynamic> json) {
    final nummer = json['nummer'];
    String id;
    if (nummer != null && nummer.toString().isNotEmpty && nummer != 'null') {
      id = 'kurz_${nummer}';
    } else if (json['titel'] != null && json['titel'].toString().trim().isNotEmpty) {
      id = 'kurz_' + json['titel'].toString().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    } else {
      id = 'kurz_unbekannt_${DateTime.now().millisecondsSinceEpoch}';
    }
    return Episode(
      id: id,
      nummer: nummer ?? 0,
      titel: json['titel'] ?? '',
      autor: json['autor'] ?? '',
      beschreibung: json['beschreibung'] ?? '',
      gesamtbeschreibung: json['gesamtbeschreibung'],
      hoerspielskriptautor: json['hörspielskriptautor'],
      veroeffentlichungsdatum: json['veröffentlichungsdatum'],
      coverUrl: json['links']?['cover'] ?? json['coverUrl'],
      serieTyp: 'Kurzgeschichte',
      sprechrollen: json['sprechrollen'],
      spotifyUrl: json['spotify'],
      links: _parseLinks(json['links']),
    );
  }

  factory Episode.fromKidsJson(Map<String, dynamic> json) {
    final nummer = json['nummer'];
    String id;
    if (nummer != null && nummer.toString().isNotEmpty && nummer != 'null') {
      id = 'kids_${nummer}';
    } else if (json['titel'] != null && json['titel'].toString().trim().isNotEmpty) {
      id = 'kids_' + json['titel'].toString().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    } else {
      id = 'kids_unbekannt_${DateTime.now().millisecondsSinceEpoch}';
    }
    return Episode(
      id: id,
      nummer: nummer ?? 0,
      titel: json['titel'] ?? '',
      autor: json['autor'] ?? '',
      beschreibung: json['beschreibung'] ?? '',
      gesamtbeschreibung: json['gesamtbeschreibung'],
      hoerspielskriptautor: json['hörspielskriptautor'],
      veroeffentlichungsdatum: json['veröffentlichungsdatum'],
      coverUrl: json['links']?['cover'] ?? json['links']?['cover_itunes'] ?? json['coverUrl'],
      serieTyp: 'Kids',
      sprechrollen: json['sprechrollen'],
      spotifyUrl: json['spotify'],
      links: _parseLinks(json['links']),
    );
  }

  factory Episode.fromDr3iJson(Map<String, dynamic> json) {
    final nummer = json['nummer'];
    String id;
    if (nummer != null && nummer.toString().isNotEmpty && nummer != 'null') {
      id = 'dr3i_${nummer}';
    } else if (json['titel'] != null && json['titel'].toString().trim().isNotEmpty) {
      id = 'dr3i_' + json['titel'].toString().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    } else {
      id = 'dr3i_unbekannt_${DateTime.now().millisecondsSinceEpoch}';
    }
    return Episode(
      id: id,
      nummer: nummer ?? 0,
      titel: json['titel'] ?? '',
      autor: json['autor'] ?? '',
      beschreibung: json['beschreibung'] ?? '',
      gesamtbeschreibung: json['gesamtbeschreibung'],
      hoerspielskriptautor: json['hörspielskriptautor'],
      veroeffentlichungsdatum: json['veröffentlichungsdatum'],
      coverUrl: json['links']?['cover'] ?? json['coverUrl'],
      serieTyp: 'DR3i',
      sprechrollen: json['sprechrollen'],
      spotifyUrl: json['spotify'],
      links: _parseLinks(json['links']),
    );
  }

  bool get isFutureRelease {
    if (veroeffentlichungsdatum == null) return false;
    try {
      final releaseDate = DateTime.parse(veroeffentlichungsdatum!);
      return releaseDate.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nummer': nummer,
    'titel': titel,
    'autor': autor,
    'beschreibung': beschreibung,
    'gesamtbeschreibung': gesamtbeschreibung,
    'hoerspielskriptautor': hoerspielskriptautor,
    'veroeffentlichungsdatum': veroeffentlichungsdatum,
    'coverUrl': coverUrl,
    'serieTyp': serieTyp,
    'sprechrollen': sprechrollen,
    'rating': rating,
    'listened': listened,
    'note': note,
    'spotifyUrl': spotifyUrl,
    'links': links,
  };

  static Episode fromJson(Map<String, dynamic> json) => Episode(
    id: json['id'],
    nummer: json['nummer'],
    titel: json['titel'],
    autor: json['autor'],
    beschreibung: json['beschreibung'],
    gesamtbeschreibung: json['gesamtbeschreibung'],
    hoerspielskriptautor: json['hoerspielskriptautor'],
    veroeffentlichungsdatum: json['veroeffentlichungsdatum'],
    coverUrl: json['coverUrl'],
    serieTyp: json['serieTyp'],
    sprechrollen: json['sprechrollen'],
    rating: json['rating'] ?? 0,
    listened: json['listened'] ?? false,
    note: json['note'],
    spotifyUrl: json['spotifyUrl'],
    links: (json['links'] as Map?)?.cast<String, String>(),
  );

  static String generateSpezialId(String? title) {
    if (title == null || title.trim().isEmpty) {
      throw Exception('Spezialfolge ohne Titel!');
    }
    return 'spezial_' + title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}