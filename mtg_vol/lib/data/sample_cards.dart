import '../models/mtg_card.dart';

const jaws = MtgCard(
  name: 'JAWS, Relentless Predator',
  basePower: 5,
  baseToughness: 5,
  keywords: {
    'Trample',
    'Haste',
  },
);

const uril = MtgCard(
  name: "Uril, the Miststalker",
  basePower: 5,
  baseToughness: 5,
  keywords: {},
);

const rafiq = MtgCard(
  name: "Rafiq of the Many",
  basePower: 3,
  baseToughness: 3,
  keywords: {
    "Exalted",
    "Double Strike",
  },
);

const skullbriar = MtgCard(
  name: "Skullbriar, the Walking Grave",
  basePower: 1,
  baseToughness: 1,
  keywords: {
    "Haste",
  },
);

const lightpaws = MtgCard(
  name: "Light-Paws, Emperor's Voice",
  basePower: 2,
  baseToughness: 2,
  keywords: {},
);

const yoshimaru = MtgCard(
  name: "Yoshimaru, Ever Faithful",
  basePower: 1,
  baseToughness: 1,
  keywords: {},
);

const sram = MtgCard(
  name: "Sram, Senior Edificer",
  basePower: 2,
  baseToughness: 2,
  keywords: {},
);

const syrGwyn = MtgCard(
  name: "Syr Gwyn, Hero of Ashvale",
  basePower: 5,
  baseToughness: 5,
  keywords: {
    "Vigilance",
    "Menace",
  },
);

const akroma = MtgCard(
  name: "Akroma, Vision of Ixidor",
  basePower: 6,
  baseToughness: 6,
  keywords: {
    "Flying",
    "First Strike",
    "Vigilance",
    "Trample",
    "Lifelink",
    "Protection from Black",
    "Protection from Red",
  },
);

const zetalpa = MtgCard(
  name: "Zetalpa, Primal Dawn",
  basePower: 4,
  baseToughness: 8,
  keywords: {
    "Flying",
    "Double Strike",
    "Vigilance",
    "Trample",
    "Indestructible",
  },
);

const lightningGreaves = MtgCard(
  name: "Lightning Greaves",
  keywords: {
    "Haste",
    "Shroud",
  },
);

const blackbladeReforged = MtgCard(
  name: "Blackblade Reforged",
  // Variable bonus - handled manually later
);

const allThatGlitters = MtgCard(
  name: "All That Glitters",
  // Variable bonus - handled manually later
);

const rancor = MtgCard(
  name: "Rancor",
  powerBonus: 2,
  toughnessBonus: 0,
  keywords: {
    "Trample",
  },
  abilities: [
  "When Rancor is put into a graveyard, return it to its owner's hand.",
  ],
);

const swordOfFireAndIce = MtgCard(
  name: "Sword of Fire and Ice",
  powerBonus: 2,
  toughnessBonus: 2,
  keywords: {
    "Protection from Red",
    "Protection from Blue",
  },
  abilities: [
  "Whenever equipped creature deals combat damage to a player, Sword of Fire and Ice deals 2 damage to any target and you draw a card.",
  ],
);

const fireshrieker = MtgCard(
  name: "Fireshrieker",
  keywords: {
    "Double Strike",
  },
);

const sampleCards = [
  jaws,
  uril,
  rafiq,
  skullbriar,
  lightpaws,
  yoshimaru,
  sram,
  syrGwyn,
  akroma,
  zetalpa,

  lightningGreaves,
  blackbladeReforged,
  allThatGlitters,
  rancor,
  swordOfFireAndIce,
  fireshrieker,
];