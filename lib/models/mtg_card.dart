class MtgCard {
  final String name;
  final int? basePower;
  final int? baseToughness;
  final Set<String> keywords;
  final int powerBonus;
  final int toughnessBonus;
  final List<String> abilities;
  final String? imageUrl;
  final String? oracleText;
  final Set<String> removedKeywords;
  final Set<String> grantedKeywords;
  


  const MtgCard({
    required this.name,
    this.basePower,
    this.baseToughness,
    this.keywords = const {},
    this.powerBonus = 0,
    this.toughnessBonus = 0,
    this.abilities = const [],
    this.imageUrl,
    this.oracleText,
    this.removedKeywords = const {},
    this.grantedKeywords = const {},
  });
}
