import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mtg_card.dart';

class ScryfallService {
  static const _headers = {
    "User-Agent": "MTGVoltronCalc/1.0",
    "Accept": "application/json;q=0.9,*/*;q=0.8",
  };

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  Future<List<String>> searchCards(String query) async {
    final uri = Uri.https(
      "api.scryfall.com",
      "/cards/autocomplete",
      {
        "q": query,
      },
    );

    final response = await http.get(
      uri,
      headers: _headers,
    );

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body);
    final names = data["data"] as List;

    return names
        .cast<String>()
        .where(
          (name) => name.toLowerCase().startsWith(query.toLowerCase()),
        )
        .toList();
  }

  Future<List<String>> searchCreatures(String query) async {
    final uri = Uri.https(
      "api.scryfall.com",
      "/cards/search",
      {
        "q": 't:creature name:$query',
      },
    );

    final response = await http.get(
      uri,
      headers: _headers,
    );

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body);
    final cards = data["data"] as List;

    return cards
        .map((card) => card["name"] as String)
        .where(
          (name) => name.toLowerCase().startsWith(query.toLowerCase()),
        )
        .toList();
  }

  // ------------------------------------------------------------
  // FETCH CARD
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> getCardByName(String name) async {
    final uri = Uri.https(
      "api.scryfall.com",
      "/cards/named",
      {
        "exact": name,
      },
    );

    final response = await http.get(
      uri,
      headers: _headers,
    );

    if (response.statusCode != 200) {
      return null;
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<MtgCard?> getMtgCardByName(String name) async {
    final json = await getCardByName(name);

    if (json == null) {
      return null;
    }

    return cardFromJson(json);
  }

  // ------------------------------------------------------------
  // CONVERT SCRYFALL CARD
  // ------------------------------------------------------------

  MtgCard cardFromJson(Map<String, dynamic> json) {
    final oracleText = json["oracle_text"] as String?;

    return MtgCard(
      name: json["name"] as String,

      basePower: int.tryParse(
        json["power"]?.toString() ?? "",
      ),

      baseToughness: int.tryParse(
        json["toughness"]?.toString() ?? "",
      ),

      imageUrl: json["image_uris"]?["art_crop"] as String?,
      oracleText: oracleText,

      // Keywords printed on the card itself.
      keywords: getCreatureKeywords(json),

      // Keywords another card grants/removes.
      grantedKeywords: getGrantedKeywords(oracleText),
      removedKeywords: getRemovedKeywords(oracleText),

      // Fixed P/T effects.
      powerBonus: getPowerBonus(oracleText),
      toughnessBonus: getToughnessBonus(oracleText),

      abilities: getRelevantAbilities(oracleText),
    );
  }

  // ------------------------------------------------------------
  // DETERMINE WHETHER A LINE AFFECTS THE TRACKED CREATURE
  // ------------------------------------------------------------

  bool lineAffectsCreature(String line) {
    final text = line.toLowerCase().trim();

    return text.contains("equipped creature") ||
        text.contains("enchanted creature") ||
        text.contains("permanents you control") ||
        text.startsWith("creatures you control ");
  }

  // ------------------------------------------------------------
  // FIXED POWER / TOUGHNESS
  // ------------------------------------------------------------

  int getPowerBonus(String? oracleText) {
    if (oracleText == null) return 0;

    for (final line in oracleText.split('\n')) {
      if (!lineAffectsCreature(line)) {
        continue;
      }

      final match = RegExp(
        r'gets \+(\d+)/[+-]\d+',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }

    return 0;
  }

  int getToughnessBonus(String? oracleText) {
    if (oracleText == null) return 0;

    for (final line in oracleText.split('\n')) {
      if (!lineAffectsCreature(line)) {
        continue;
      }

      final match = RegExp(
        r'gets [+-]\d+/\+(\d+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }

    return 0;
  }

  // ------------------------------------------------------------
  // GRANTED KEYWORDS
  // ------------------------------------------------------------

  Set<String> getGrantedKeywords(String? oracleText) {
    if (oracleText == null) return {};

    final keywords = <String>{};

    const knownKeywords = [
      "Flying",
      "First Strike",
      "Double Strike",
      "Deathtouch",
      "Haste",
      "Hexproof",
      "Indestructible",
      "Lifelink",
      "Menace",
      "Protection",
      "Reach",
      "Shroud",
      "Trample",
      "Vigilance",
      "Ward",
    ];

    final lines = oracleText.toLowerCase().split('\n');

    for (final line in lines) {
      if (!lineAffectsCreature(line)) {
        continue;
      }

      String? grantedText;

      if (line.contains(" has ")) {
        grantedText = line.split(" has ").last;
      } else if (line.contains(" have ")) {
        grantedText = line.split(" have ").last;
      } else if (line.contains(" gains ")) {
        grantedText = line.split(" gains ").last;
      } else if (line.contains(" gain ")) {
        grantedText = line.split(" gain ").last;
      }

      if (grantedText == null) {
        continue;
      }

      for (final keyword in knownKeywords) {
        if (grantedText.contains(keyword.toLowerCase())) {
          keywords.add(keyword);
        }
      }
    }

    return keywords;
  }

  // ------------------------------------------------------------
  // REMOVED KEYWORDS
  // ------------------------------------------------------------

  Set<String> getRemovedKeywords(String? oracleText) {
    if (oracleText == null) return {};

    final keywords = <String>{};

    const knownKeywords = [
      "Flying",
      "First Strike",
      "Double Strike",
      "Deathtouch",
      "Haste",
      "Hexproof",
      "Indestructible",
      "Lifelink",
      "Menace",
      "Protection",
      "Reach",
      "Shroud",
      "Trample",
      "Vigilance",
      "Ward",
    ];

    final lines = oracleText.toLowerCase().split('\n');

    for (final line in lines) {
      if (!lineAffectsCreature(line)) {
        continue;
      }

      for (final keyword in knownKeywords) {
        final lowerKeyword = keyword.toLowerCase();

        if (line.contains("loses $lowerKeyword") ||
            line.contains("lose $lowerKeyword")) {
          keywords.add(keyword);
        }
      }
    }

    return keywords;
  }

  // ------------------------------------------------------------
  // RELEVANT ABILITIES
  // ------------------------------------------------------------

  List<String> getRelevantAbilities(String? oracleText) {
    if (oracleText == null) return [];

    final abilities = <String>[];

    for (final line in oracleText.split('\n')) {
      if (lineAffectsCreature(line)) {
        abilities.add(line);
      }
    }

    return abilities;
  }

  // ------------------------------------------------------------
  // CREATURE'S OWN KEYWORDS
  // ------------------------------------------------------------

  Set<String> getCreatureKeywords(Map<String, dynamic> json) {
    final scryfallKeywords =
        Set<String>.from(json["keywords"] ?? []);

    const creatureKeywords = {
      "Deathtouch",
      "Defender",
      "Double Strike",
      "First Strike",
      "Flash",
      "Flying",
      "Haste",
      "Hexproof",
      "Indestructible",
      "Lifelink",
      "Menace",
      "Protection",
      "Reach",
      "Shroud",
      "Trample",
      "Vigilance",
      "Ward",
    };

    return scryfallKeywords
        .where(
          (keyword) => creatureKeywords.contains(keyword),
        )
        .toSet();
  }
}