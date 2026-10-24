#!/usr/bin/env python3
"""Mobile-friendly loss-tolerant geometry reduction for PBR skinned monsters.

Only modifies geometry. It keeps all original albedo/normal/ORM textures,
skin weights, and animation tracks. Automatically preserves the original GLB
if validation fails or simplified geometry is below the minimum quality floor.
No Draco/KTX extensions: Godot GLES3 can import the resulting standard GLBs.
"""
from pathlib import Path
import json
import struct
import subprocess

FOLDER = Path("assets/models/hd")

def signature(path):
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise ValueError("not a glTF binary: " + str(path))
    json_size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_size])
    triangles = sum(
        doc["accessors"][primitive["indices"]]["count"] // 3
        for mesh in doc.get("meshes", [])
        for primitive in mesh.get("primitives", [])
        if "indices" in primitive
    )
    return {"triangles": triangles,
            "skins": len(doc.get("skins", [])),
            "animations": sorted(str(anim.get("name", "")) for anim in doc.get("animations", [])),
            "images": len(doc.get("images", [])),
            "extensions_required": sorted(doc.get("extensionsRequired", []))}

def main():
    for original in sorted(FOLDER.glob("*.glb")):
        previous = signature(original)
        out = original.with_name(original.stem + ".mobile.glb")
        try:
            subprocess.run(
                ["gltf-transform", "simplify", str(original), str(out),
                 "--ratio", "0.52", "--error", "0.006"],
                timeout=100, check=True
            )
            current = signature(out)
            assert current["skins"] == previous["skins"]
            assert current["animations"] == previous["animations"]
            assert current["images"] == previous["images"]
            assert current["extensions_required"] == previous["extensions_required"], (
                "Don't require unsupported GLB extensions on Android"
            )
            assert current["triangles"] >= 14000
            if current["triangles"] < previous["triangles"] * 0.91:
                before_bytes = original.stat().st_size
                after_bytes = out.stat().st_size
                out.replace(original)
                print(f"MOBILE PBR LOD {original.stem}: triangles "
                      f"{previous['triangles']} -> {current['triangles']}; "
                      f"bytes {before_bytes} -> {after_bytes}; "
                      f"skins={current['skins']} clips={len(current['animations'])} "
                      f"textures={current['images']}", flush=True)
            else:
                print(f"MOBILE PBR LOD {original.stem}: "
                      "visual preservation took priority, original retained", flush=True)
        except Exception as err:
            print(f"::warning::Mobile LOD skipped for {original.name}: {err}", flush=True)
        finally:
            out.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
