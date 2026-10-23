#!/usr/bin/env python3
"""Download official Poly Haven CC0 1k PBR maps, optional by channel.

Names stay unchanged to allow precise Godot material selection and source audit.
No brittle texture dependency: offline/dev builds use procedural terrain fallback.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import urlopen
from urllib.error import URLError
import time

MATERIALS = ["snow_02", "forest_ground_01", "rock_face_03", "volcanic_rock_tiles", "rock_06"]
CHANNELS = ["diff", "nor_gl", "rough"]
DEST = Path("assets/pbr")
DEST.mkdir(exist_ok=True, parents=True)


def retrieve(item):
    name, channel = item
    target = DEST / f"{name}_{channel}_1k.jpg"
    if target.is_file() and target.stat().st_size > 10000:
        return name, channel, True
    url = f"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/{name}/{name}_{channel}_1k.jpg"
    for attempt in range(2):
        try:
            with urlopen(url, timeout=16) as req:
                content = req.read()
            if len(content) < 10000 or not content.startswith(b"\xff\xd8"):
                break
            target.write_bytes(content)
            return name, channel, True
        except (OSError, URLError):
            if attempt == 0:
                time.sleep(0.2)
    print(f"OPTIONAL PBR FALLBACK: {name}/{channel} not downloaded")
    return name, channel, False


if __name__ == "__main__":
    items = [(name, channel) for name in MATERIALS for channel in CHANNELS]
    with ThreadPoolExecutor(max_workers=8) as pool:
        output = list(pool.map(retrieve, items))
    print("PBR MAPS:", sum(valid for _, _, valid in output), "of", len(items))
