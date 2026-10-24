extends RefCounted
## Pinned imported PBR models replace generic humanoid chess pieces and
## spherical four-legged creatures in every biome, not only forest levels.
## Full-size 3D geometry, skin weights, albedo/normal/ORM maps and native clips.
const KNOWN: Dictionary = {
    "hd_gloom_stalker": true,
    "hd_hollow_warden": true,
    "hd_marsh_direwolf": true,
    "hd_ashfen_ranger": true
}

func model_for_enemy(species: String, biome: int, boss: bool, elite: bool) -> String:
    var name: String = species.to_upper()
    # Keep large elemental / root creatures as distinct organic silhouettes;
    # human armor would be a poor stand-in for a treant or elemental.
    if biome == 1 and boss:
        return ""
    if name.contains("SPIDER") or name.contains("SCORPION") or name.contains("BAT"):
        return ""
    if name.contains("SLIME") or name.contains("ELEMENTAL") or name.contains("GOLEM"):
        return ""
    if name.contains("TITAN") or name.contains("COLOSSUS") or name.contains("WYRM"):
        return ""
    if name.contains("WOLF") or name.contains("HOUND") or name.contains("HYENA") or name.contains("BEAST"):
        return "hd_marsh_direwolf"
    if name.contains("WRAITH") or name.contains("REVENANT") or name.contains("GHOST") or name.contains("SPIRIT") or name.contains("BANSHEE") or name.contains("REAPER"):
        return "hd_gloom_stalker"
    if name.contains("ARCHER") or name.contains("RANGER") or name.contains("SHAMAN") or name.contains("WITCH") or name.contains("MAGE") or name.contains("SORCERER") or name.contains("SPELLCASTER"):
        return "hd_ashfen_ranger"
    if name.contains("GOBLIN") or name.contains("IMP") or name.contains("ZOMBIE") or name.contains("MUMMY") or name.contains("PLAGUE") or name.contains("DEMON"):
        return "hd_gloom_stalker"
    if name.contains("KNIGHT") or name.contains("GUARD") or name.contains("SENTINEL") or name.contains("WARRIOR") or name.contains("CULTIST") or name.contains("RAIDER") or name.contains("BANDIT"):
        return "hd_hollow_warden"
    if elite or boss:
        return "hd_hollow_warden"
    if name.contains("TREANT") or name.contains("SAPLING") or name.contains("TOAD"):
        return ""
    # For every other humanoid: no more default ashen_ranger/skeleton clones.
    return "hd_gloom_stalker"

func model_for_hero(character: String) -> String:
    match character:
        "Knight": return "hd_hollow_warden"
        "Rogue": return "hd_ashfen_ranger"
    return ""
