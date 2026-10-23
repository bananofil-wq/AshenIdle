extends RefCounted
# Four irreversible ascensions, each with three class-specific evolution paths.
# Milestones are independent: a player can mix branches at later ascensions.
const MILESTONES := [75, 170, 250, 500]
const PHASES := ["AWAKENING", "TRANSCENDENCE", "ASCENDANCY", "APOTHEOSIS"]
const BRANCH_NAMES := [
    ["CINDER VANGUARD", "IRON BASTION", "RUNE TEMPLAR"],
    ["BLOODTRAIL HUNTER", "WILDWARDEN", "STORMSEEKER"],
    ["PYROMANCER", "ARCANE GUARDIAN", "TEMPEST WEAVER"],
    ["SOUL EXECUTIONER", "DREAD SENTINEL", "VOIDCALLER"]
]
const BRANCH_FEATURES := [
    ["EMBER CLEAVE", "UNBREAKABLE AEGIS", "RUNEBLADE ECHO"],
    ["HUNTER'S FRENZY", "PRIMAL RECOVERY", "STORM ARROWS"],
    ["SPELLFIRE RUPTURE", "ARCANE WARD", "LIGHTNING MASTERY"],
    ["SOUL REND", "DEATHLESS PACT", "VOID RESONANCE"]
]
# Later tiers upgrade the chosen branch with stronger passive/triggered effects.
const WEIGHTS := [1.0, 1.5, 2.1, 3.2]
const CLASS_UNIQUES := [
    ["Warrior: burning cleave.", "Knight: extra boss mitigation.", "Templar: faster runic casting."],
    ["Ranger: deadly precision.", "Warden: stronger kill-healing.", "Seeker: wider arrow storms."],
    ["Mage: blazing spell damage.", "Guardian: reinforced magic defense.", "Weaver: extra lightning jumps."],
    ["Reaper: life-stealing strikes.", "Sentinel: empowered regeneration.", "Caller: MP restored on casting."]
]

static func valid_choices(raw: Variant) -> Array:
    var result: Array = [-1, -1, -1, -1]
    if raw is Array:
        for i in range(mini(4, raw.size())):
            var branch: int = int(raw[i])
            result[i] = branch if branch >= 0 and branch <= 2 else -1
    return result

static func next_tier(level: int, choices: Array) -> int:
    for tier in range(MILESTONES.size()):
        if level >= int(MILESTONES[tier]) and (tier >= choices.size() or int(choices[tier]) == -1):
            return tier
    return -1

static func count_branch(choices: Array, branch: int) -> int:
    var total := 0
    for picked in choices:
        if int(picked) == branch:
            total += 1
    return total

static func branch_weight(choices: Array, branch: int) -> float:
    var total := 0.0
    for tier in range(mini(MILESTONES.size(), choices.size())):
        if int(choices[tier]) == branch:
            total += float(WEIGHTS[tier])
    return total

static func total_evolutions(choices: Array) -> int:
    var total := 0
    for picked in choices:
        if int(picked) >= 0 and int(picked) <= 2:
            total += 1
    return total

static func perk_description(class_id: int, tier: int, branch: int) -> String:
    if class_id < 0 or class_id >= 4 or tier < 0 or tier >= 4 or branch < 0 or branch >= 3:
        return ""
    var weight: float = float(WEIGHTS[tier])
    match branch:
        0:
            return "%s\n+%d%% damage  •  +%d%% crit\nEvery fifth strike cleaves nearby foes.\n%s" % [
                BRANCH_FEATURES[class_id][0], int(round(7.0 * weight)), int(round(3.0 * weight)), CLASS_UNIQUES[class_id][0]
            ]
        1:
            return "%s\n+%d%% maximum health  •  +%d%% defense\nHeal on every kill.\n%s" % [
                BRANCH_FEATURES[class_id][1], int(round(12.0 * weight)), int(round(2.2 * weight)), CLASS_UNIQUES[class_id][1]
            ]
        2:
            return "%s\n+%d%% spell damage  •  -%d%% cooldowns\nExtra MP and mana recovery.\n%s" % [
                BRANCH_FEATURES[class_id][2], int(round(12.0 * weight)), int(round(6.0 * weight)), CLASS_UNIQUES[class_id][2]
            ]
    return ""

static func next_level(level: int, choices: Array) -> int:
    for tier in range(4):
        if tier >= choices.size() or int(choices[tier]) < 0:
            return int(MILESTONES[tier])
    return -1
