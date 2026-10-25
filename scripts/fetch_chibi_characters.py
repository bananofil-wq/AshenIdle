#!/usr/bin/env python3
"""Fetch real CC0 rigged, textured chibi characters for a stylized RPG.
Source: https://store.godotengine.org/asset/styloo/chibi/
Creator: styloo, Godot Asset Store item 717, version download 1373.
License: CC0 1.0 Universal (verified on official item page).
The game imports a curated subset of the GLB models, not the original zip.
"""
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile
from io import BytesIO
import hashlib
import json
import struct

URL = "https://store.godotengine.org/asset/styloo/chibi/download/1373/"
# Verified male character only. The other pack avatars are female or
# not independently gender-verified, so do not download or ship them.
MODELS = {
    "knight": "glb/knightpr.glb",
}
OUT = Path("assets/models/chibi")
OUT.mkdir(parents=True, exist_ok=True)
if all((OUT / (name + ".glb")).is_file() for name in MODELS):
    print("CHIBI ASSETS: existing curated GLB set", flush=True)
else:
    req = Request(URL, headers={"User-Agent": "AshenIdle Godot Asset Import/1.0",
                                "Accept": "application/zip,*/*"})
    with urlopen(req, timeout=90) as response:
        archive = response.read()
    assert len(archive) >= 15000000, "Downloaded archive was unexpectedly small"
    with ZipFile(BytesIO(archive)) as zipped:
        for nickname, archive_name in MODELS.items():
            data = zipped.read(archive_name)
            if data[:4] != b"glTF":
                raise RuntimeError("Invalid glTF for " + nickname)
            header = struct.unpack_from("<I", data, 12)[0]
            structure = json.loads(data[20:20 + header])
            triangles = sum(
                structure["accessors"][primitive["indices"]]["count"] // 3
                for mesh in structure.get("meshes", [])
                for primitive in mesh["primitives"] if "indices" in primitive
            )
            animations = [str(a.get("name", "")) for a in structure.get("animations", [])]
            assert 5000 <= triangles <= 20000, (nickname, triangles)
            assert structure.get("skins") and len(structure.get("images", [])) >= 3
            assert len(animations) >= 9
            (OUT / (nickname + ".glb")).write_bytes(data)
            print("STYLIZED CHIBI MODEL",nickname,triangles,"tris",
                  len(structure["images"]),"textures",
                  len(animations),"clips, SHA256",hashlib.sha256(data).hexdigest(),flush=True)
(OUT/"LICENSE.txt").write_text(
    "Chibi Characters by styloo, Godot Asset Store: https://store.godotengine.org/asset/styloo/chibi/\n"
    "License: Creative Commons CC0 1.0 Universal. No attribution required.\n"
    "Source version: /asset/styloo/chibi/download/1373/\n",
    encoding="utf-8")
