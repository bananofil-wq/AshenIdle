#!/usr/bin/env python3
"""Fetch a curated CC0 Kenney sound palette for the Android build.

Source packs: Kenney RPG Audio, Impact Sounds, Sci-fi Sounds.
Original publisher: https://kenney.nl/assets/ (CC0 public domain).
Upstream mirror: https://github.com/GeorgeQLe/assets-sfx-combat
All selected clips are OGG and stored only at build time.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import urlopen

BASE = "https://raw.githubusercontent.com/GeorgeQLe/assets-sfx-combat/main/assets/kenney/"
ITEMS = {
    "sword_0": ("rpg-audio", "knifeSlice"),
    "sword_1": ("rpg-audio", "knifeSlice2"),
    "loot_0": ("rpg-audio", "handleCoins"),
    "loot_1": ("rpg-audio", "handleCoins2"),
    "legendary_0": ("impact-sounds", "impactBell_heavy_000"),
    "legendary_1": ("impact-sounds", "impactBell_heavy_001"),
    "knight_0": ("impact-sounds", "impactMetal_medium_000"),
    "knight_1": ("impact-sounds", "impactMetal_heavy_001"),
    "boss_0": ("sci-fi-sounds", "lowFrequency_explosion_000"),
    "boss_1": ("sci-fi-sounds", "explosionCrunch_000"),
    "ranger_0": ("rpg-audio", "drawKnife1"),
    "ranger_1": ("rpg-audio", "drawKnife2"),
    "mage_0": ("sci-fi-sounds", "forceField_000"),
    "mage_1": ("sci-fi-sounds", "forceField_001"),
    "reaper_0": ("sci-fi-sounds", "spaceEngineLow_000"),
    "reaper_1": ("sci-fi-sounds", "spaceEngineLow_001"),
    "chain_0": ("sci-fi-sounds", "laserLarge_000"),
    "chain_1": ("sci-fi-sounds", "laserLarge_001"),
    "level_0": ("impact-sounds", "impactBell_heavy_002"),
    "level_1": ("impact-sounds", "impactBell_heavy_003"),
}
for surface in ("concrete", "snow", "grass", "wood"):
    for i in range(2):
        ITEMS[f"step_{surface}_{i}"] = ("impact-sounds", f"footstep_{surface}_{i:03d}")

OUTPUT = Path("assets/sfx")
OUTPUT.mkdir(parents=True, exist_ok=True)


def fetch(item):
    name, (pack, src) = item
    url = f"{BASE}{pack}/Audio/{src}.ogg"
    data = None
    for attempt in range(3):
        try:
            with urlopen(url, timeout=30) as response:
                data = response.read()
            break
        except Exception:
            if attempt == 2:
                raise
    if not data or len(data) < 100 or not data.startswith(b"OggS"):
        raise ValueError(f"Missing/invalid OGG for {name}: {url}")
    (OUTPUT / f"{name}.ogg").write_bytes(data)
    return name, len(data)


if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(fetch, ITEMS.items()))
    print("CC0 AUDIO INSTALLED:", len(results), "clips,", sum(size for _, size in results), "bytes")
