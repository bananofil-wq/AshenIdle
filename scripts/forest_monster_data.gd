extends RefCounted
## The enchanted forest's six distinct monsters. Stable IDs decouple art
## from older saves, combat UI and boss milestone keys.
const SPECS := {
    "sapling": {"name": "CORRUPTED SAPLING", "role": "raider", "health": 0.75, "speed": 1.20, "scale": 0.83, "accent": Color("e99a57")},
    "hound": {"name": "MOSS HOUND", "role": "flanker", "health": 0.90, "speed": 1.36, "scale": 1.00, "accent": Color("e8b879")},
    "spider": {"name": "BROOD SPIDER", "role": "flanker", "health": 0.85, "speed": 1.04, "scale": 1.04, "accent": Color("a7d660")},
    "revenant": {"name": "REVENANT WANDERER", "role": "caster", "health": 1.25, "speed": 0.97, "scale": 1.25, "accent": Color("78d9cd")},
    "brute": {"name": "THORN BRUTE", "role": "guardian", "health": 2.6, "speed": 0.70, "scale": 1.45, "accent": Color("e78e42")},
    "rot_treant": {"name": "ANCIENT ROT TREANT", "role": "boss", "health": 1.0, "speed": 0.62, "scale": 2.05, "accent": Color("ff9a4d")}
}
const COMMON := ["sapling", "hound", "spider", "revenant"]

func identify(species: String, elite: bool = false, boss: bool = false) -> String:
    if boss:
        return "rot_treant"
    var name: String = species.to_upper()
    if name.contains("SPIDER") or name.contains("BROOD"):
        return "spider"
    if name.contains("HOUND") or name.contains("WOLF") or name.contains("SATYR"):
        return "hound"
    if name.contains("BRUTE") or name.contains("TREANT"):
        return "brute"
    if name.contains("REVENANT") or name.contains("WRAITH") or name.contains("ARCHER") or name.contains("FAERIE") or name.contains("ELF"):
        return "revenant"
    if name.contains("SAPLING") or name.contains("STALKER") or name.contains("THORN"):
        return "sapling"
    if elite:
        return "brute"
    return "sapling"

func spec(id: String) -> Dictionary:
    return SPECS.get(id, {}) as Dictionary
