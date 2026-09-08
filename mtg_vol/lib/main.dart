import 'package:flutter/material.dart';
import 'models/mtg_card.dart';
import 'services/scryfall_service.dart';

void main() {
  runApp(const VoltronApp());
}

class VoltronApp extends StatelessWidget {
  const VoltronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTG Voltron Calc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MtgCard? creature;

  String searchText = "";
  List<String> searchResults = [];

  int plusOneCounters = 0;

  // Used when a creature has non-numeric P/T such as */*
  int manualBasePower = 0;
  int manualBaseToughness = 0;

  // Whether the tracked creature is currently attacking
  bool isAttacking = false;

  final List<MtgCard> activeCards = [];
  final ScryfallService scryfallService = ScryfallService();

  // ------------------------------------------------------------
  // ATTACKING EFFECT HELPERS
  // ------------------------------------------------------------

  bool isAttackingEffect(String line) {
    final text = line.toLowerCase();

    return text.contains("attacking creatures you control");
  }

  int attackingPowerBonus(MtgCard card) {
    if (!isAttacking || card.oracleText == null) {
      return 0;
    }

    int total = 0;

    for (final line in card.oracleText!.split('\n')) {
      if (!isAttackingEffect(line)) {
        continue;
      }

      final match = RegExp(
        r'gets ([+-]\d+)/([+-]\d+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        total += int.parse(match.group(1)!);
      }
    }

    return total;
  }

  int attackingToughnessBonus(MtgCard card) {
    if (!isAttacking || card.oracleText == null) {
      return 0;
    }

    int total = 0;

    for (final line in card.oracleText!.split('\n')) {
      if (!isAttackingEffect(line)) {
        continue;
      }

      final match = RegExp(
        r'gets ([+-]\d+)/([+-]\d+)',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        total += int.parse(match.group(2)!);
      }
    }

    return total;
  }

  Set<String> attackingGrantedKeywords(MtgCard card) {
    if (!isAttacking || card.oracleText == null) {
      return {};
    }

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

    for (final line in card.oracleText!.split('\n')) {
      if (!isAttackingEffect(line)) {
        continue;
      }

      final text = line.toLowerCase();

      for (final keyword in knownKeywords) {
        if (text.contains(keyword.toLowerCase())) {
          keywords.add(keyword);
        }
      }
    }

    return keywords;
  }

  List<String> attackingAbilities(MtgCard card) {
    if (!isAttacking || card.oracleText == null) {
      return [];
    }

    final abilities = <String>[];

    for (final line in card.oracleText!.split('\n')) {
      if (isAttackingEffect(line)) {
        abilities.add(line);
      }
    }

    return abilities;
  }

  // ------------------------------------------------------------
  // CURRENT POWER / TOUGHNESS
  // ------------------------------------------------------------

  int currentPower() {
    if (creature == null) return 0;

    int total =
        (creature!.basePower ?? manualBasePower) + plusOneCounters;

    for (final card in activeCards) {
      total += card.powerBonus;
      total += attackingPowerBonus(card);
    }

    return total;
  }

  int currentToughness() {
    if (creature == null) return 0;

    int total =
        (creature!.baseToughness ?? manualBaseToughness) +
        plusOneCounters;

    for (final card in activeCards) {
      total += card.toughnessBonus;
      total += attackingToughnessBonus(card);
    }

    return total;
  }

  // ------------------------------------------------------------
  // KEYWORDS
  // ------------------------------------------------------------

  Set<String> currentKeywords() {
    final keywords = <String>{};

    if (creature != null) {
      keywords.addAll(creature!.keywords);
    }

    for (final card in activeCards) {
      keywords.addAll(card.grantedKeywords);

      if (isAttacking) {
        keywords.addAll(attackingGrantedKeywords(card));
      }
    }

    for (final card in activeCards) {
      keywords.removeAll(card.removedKeywords);
    }

    return keywords;
  }

  List<String> keywordSources(String keyword) {
    final sources = <String>[];

    if (creature != null && creature!.keywords.contains(keyword)) {
      sources.add(creature!.name);
    }

    for (final card in activeCards) {
      if (card.grantedKeywords.contains(keyword)) {
        sources.add(card.name);
      }

      if (isAttacking &&
          attackingGrantedKeywords(card).contains(keyword) &&
          !sources.contains(card.name)) {
        sources.add(card.name);
      }
    }

    return sources;
  }

  // ------------------------------------------------------------
  // ABILITIES
  // ------------------------------------------------------------

  List<String> currentAbilities() {
    final abilities = <String>[];

    if (creature != null) {
      abilities.addAll(creature!.abilities);
    }

    for (final card in activeCards) {
      abilities.addAll(card.abilities);

      if (isAttacking) {
        abilities.addAll(attackingAbilities(card));
      }
    }

    return abilities.toSet().toList();
  }

  List<String> relevantAbilities() {
    return currentAbilities().where((ability) {
      final text = ability.toLowerCase();

      return text.contains("equipped creature") ||
          text.contains("enchanted creature") ||
          text.contains("creatures you control") ||
          text.contains("permanents you control");
    }).toList();
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MTG Voltron Calc'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                // ------------------------------------------------
                // CHANGE CREATURE
                // ------------------------------------------------

                case 'changeCreature':
                  searchText = "";
                  searchResults = [];

                  showDialog(
                    context: context,
                    builder: (context) {
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          return AlertDialog(
                            title: const Text("Select Creature"),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 400,
                              child: Column(
                                children: [
                                  TextField(
                                    onChanged: (value) async {
                                      searchText = value;

                                      if (value.length < 3) {
                                        setDialogState(() {
                                          searchResults = [];
                                        });

                                        return;
                                      }

                                      final results =
                                          await scryfallService
                                              .searchCreatures(value);

                                      setDialogState(() {
                                        searchResults = results;
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      labelText: "Creature name",
                                      hintText: "Start typing a card name",
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Expanded(
                                    child: ListView(
                                      children: searchResults
                                          .map(
                                            (name) => ListTile(
                                              title: Text(name),
                                              onTap: () async {
                                                final card =
                                                    await scryfallService
                                                        .getMtgCardByName(
                                                          name,
                                                        );

                                                if (card != null) {
                                                  setState(() {
                                                    creature = card;

                                                    manualBasePower = 0;
                                                    manualBaseToughness = 0;

                                                    isAttacking = false;
                                                  });
                                                }

                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                }
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );

                  break;

                // ------------------------------------------------
                // ADD CARD
                // ------------------------------------------------

                case 'addCard':
                  searchText = "";
                  searchResults = [];

                  showDialog(
                    context: context,
                    builder: (context) {
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          return AlertDialog(
                            title: const Text("Add Card"),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 400,
                              child: Column(
                                children: [
                                  TextField(
                                    onChanged: (value) async {
                                      searchText = value;

                                      if (value.length < 3) {
                                        setDialogState(() {
                                          searchResults = [];
                                        });

                                        return;
                                      }

                                      final results =
                                          await scryfallService
                                              .searchCards(value);

                                      setDialogState(() {
                                        searchResults = results;
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      labelText: "Card name",
                                      hintText: "Start typing a card name",
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Expanded(
                                    child: ListView(
                                      children: searchResults
                                          .map(
                                            (name) => ListTile(
                                              title: Text(name),
                                              onTap: () async {
                                                final card =
                                                    await scryfallService
                                                        .getMtgCardByName(
                                                          name,
                                                        );

                                                if (card != null) {
                                                  setState(() {
                                                    activeCards.add(card);
                                                  });
                                                }

                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                }
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );

                  break;

                // ------------------------------------------------
                // CLEAR ADDED CARDS
                // ------------------------------------------------

                case 'clearAddedCards':
                  setState(() {
                    activeCards.clear();
                  });

                  break;

                // ------------------------------------------------
                // RESET ALL
                // ------------------------------------------------

                case 'resetAll':
                  setState(() {
                    creature = null;

                    plusOneCounters = 0;

                    manualBasePower = 0;
                    manualBaseToughness = 0;

                    isAttacking = false;

                    activeCards.clear();
                  });

                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'changeCreature',
                child: Text('Change Creature'),
              ),
              PopupMenuItem(
                value: 'addCard',
                child: Text('Add Card'),
              ),
              PopupMenuItem(
                value: 'clearAddedCards',
                child: Text('Clear Added Cards'),
              ),
              PopupMenuItem(
                value: 'resetAll',
                child: Text('Reset All'),
              ),
            ],
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --------------------------------------------------
              // CREATURE CARD
              // --------------------------------------------------

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        creature?.name ?? "No creature selected",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 12),

                      if (creature?.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            creature!.imageUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                      if (creature?.imageUrl != null)
                        const SizedBox(height: 16),

                      Text(
                        "${currentPower()} / ${currentToughness()}",
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (creature != null &&
                          (creature!.basePower == null ||
                              creature!.baseToughness == null)) ...[
                        const SizedBox(height: 12),

                        const Text(
                          "Set Base P/T",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 70,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  labelText: "Power",
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    manualBasePower =
                                        int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                "/",
                                style: TextStyle(fontSize: 24),
                              ),
                            ),

                            SizedBox(
                              width: 70,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  labelText: "Toughness",
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    manualBaseToughness =
                                        int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // KEYWORDS
              // --------------------------------------------------

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Keywords",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentKeywords()
                            .map(
                              (keyword) {
                                final isBaseKeyword =
                                    creature?.keywords.contains(keyword) ??
                                        false;

                                return ActionChip(
                                  label: Text(keyword),
                                  backgroundColor: isBaseKeyword
                                      ? null
                                      : Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                  onPressed: () {
                                    final sources =
                                        keywordSources(keyword);

                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text(keyword),
                                          content: Column(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: sources
                                                .map(
                                                  (source) =>
                                                      Text(source),
                                                )
                                                .toList(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // ATTACKING
              // --------------------------------------------------

              Card(
                child: SwitchListTile(
                  title: const Text(
                    "Attacking",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Apply effects that only affect attacking creatures",
                  ),
                  value: isAttacking,
                  onChanged: (value) {
                    setState(() {
                      isAttacking = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // +1/+1 COUNTERS
              // --------------------------------------------------

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "+1/+1",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              setState(() {
                                plusOneCounters = 0;
                              });
                            },
                            icon: const Icon(Icons.restart_alt),
                            tooltip: "Reset +1/+1 Counters",
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 52,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  if (plusOneCounters > 0) {
                                    plusOneCounters--;
                                  }
                                });
                              },
                              child: const Text(
                                "-",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          Text(
                            plusOneCounters.toString(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            width: 80,
                            height: 52,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  plusOneCounters++;
                                });
                              },
                              child: const Text(
                                "+",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // ABILITIES & TRIGGERS
              // --------------------------------------------------

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Abilities & Triggers",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 12),

                      ...relevantAbilities().map(
                        (ability) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: Text("• $ability"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // ACTIVE CARDS
              // --------------------------------------------------

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Active Cards",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activeCards
                            .map(
                              (card) => Chip(
                                label: Text(card.name),
                                onDeleted: () {
                                  setState(() {
                                    activeCards.remove(card);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}