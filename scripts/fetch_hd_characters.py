#!/usr/bin/env python3
"""Fetch four pinned, properly textured GLB characters for the mobile visual pass.
Assets are from the freely downloadable Hollowreach pack; provenance and
terms: https://assetyard.dev/pack/ and https://assetyard.dev/licenses/.
Not for resale as standalone model packs. Source model records retained below.
"""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
import json
import struct

SOURCES = {
    "gloom_stalker": ("gloom-stalker", "969c84f4a81ad2b3a0eef0ed0bd14b59b2a75fb9d69549b3b9ae919bce0c1300", True),
    "hollow_warden": ("hollow-warden", "b53d3edfb8c41c462e457647f87f733adc2db775938e113b6297e007e6ba9395", True),
    "marsh_direwolf": ("marsh-direwolf", "9d5124a3fa6a61f9e87a6e80b8f802977dc9c5fcfbadf9d1d88ef82b9aeed55e", False),
    "ashfen_ranger": ("ashfen-ranger", "1d38fa13a99c2aa9f928735be363e7a3f74a927d9bf00d3e691dfe496073df0f", True),
}
destination = Path("assets/models/hd")
destination.mkdir(parents=True, exist_ok=True)

for name, (upstream, digest, require_clips) in SOURCES.items():
    path = destination / (name + ".glb")
    url = f"https://assetyard.dev/pack/files/{upstream}.glb"
    if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        with urlopen(Request(url, headers={"User-Agent": "AshenIdle/asset-fetch-1.0"}), timeout=65) as resp:
            data = resp.read()
        if hashlib.sha256(data).hexdigest() != digest:
            raise RuntimeError(f"Asset integrity mismatch: {name}")
        path.write_bytes(data)
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise ValueError(f"Corrupt GLB {name}")
    length = struct.unpack_from("<I", data, 12)[0]
    scene = json.loads(data[20:20 + length])
    tris = sum(scene["accessors"][p["indices"]]["count"] // 3 for m in scene.get("meshes", []) for p in m["primitives"] if "indices" in p)
    animation = [str(clip.get("name", "")) for clip in scene.get("animations", [])]
    assert tris >= 15000, (name, tris)
    assert scene.get("skins"), f"{name} must have a genuine animated/poseable skeleton"
    assert len(scene.get("images", [])) >= 2, f"{name} must have PBR textures, not solid colors"
    assert len(animation) > 1 or not require_clips, f"{name} has no combat animation clips"
    print(f"PBR ASSET VERIFIED {name}: {tris} triangles; {len(scene.get('images',[]))} maps; {len(animation)} animations; {len(data)} bytes", flush=True)
