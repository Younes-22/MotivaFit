class Reward {
  final String id;
  final String name;
  final int coinCost;
  final int minLevelRequired; // 1 for example
  final bool isUserDefined;   // Netflix for example = True

  Reward({
    required this.id,
    required this.name,
    required this.coinCost,
    this.minLevelRequired = 1,
    this.isUserDefined = true,
  });
}