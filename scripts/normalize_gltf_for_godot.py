"""Convert CC0 Quaternius character WebP GLBs to Godot 4.3-compatible glTF.

The upstream Avelune GLBs reference textures only via EXT_texture_webp, which
Godot 4.3's glTF importer cannot decode. Preserve mesh, skeleton and animation
bytes; transcode embedded WebP to PNG/JPEG and replace extension-only textures
with valid core glTF 'source' entries. No model geometry is modified.
"""
from __future__ import annotations

import io
import json
from pathlib import Path
import struct
import sys

from PIL import Image

GLB_JSON = 0x4E4F534A
GLB_BIN = 0x004E4942


def aligned(data: bytes, fill: bytes = b"\0") -> bytes:
    return data + fill * ((-len(data)) % 4)


def normalize(path: Path) -> None:
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise ValueError(f"Not a GLB: {path}")
    position = 12
    chunks: dict[int, bytes] = {}
    while position + 8 <= len(raw):
        chunk_length, chunk_type = struct.unpack_from("<II", raw, position)
        position += 8
        chunks[chunk_type] = raw[position : position + chunk_length]
        position += chunk_length
    document = json.loads(chunks[GLB_JSON].decode("utf-8"))
    if "EXT_texture_webp" not in document.get("extensionsUsed", []):
        print(f"GLB unchanged: {path.name}")
        return

    image_records = document.setdefault("images", [])
    texture_records = document.setdefault("textures", [])
    buffer_views = document.setdefault("bufferViews", [])
    bin_data = bytearray(chunks.get(GLB_BIN, b""))
    modified = 0

    def embed_image(image_bytes: bytes, mime_type: str) -> int:
        offset = len(bin_data)
        bin_data.extend(aligned(image_bytes))
        buffer_views.append(
            {"buffer": 0, "byteOffset": offset, "byteLength": len(image_bytes)}
        )
        image_records.append(
            {"bufferView": len(buffer_views) - 1, "mimeType": mime_type}
        )
        return len(image_records) - 1

    source_replacements: dict[int, int] = {}
    for old_index, image_record in enumerate(list(image_records)):
        if image_record.get("mimeType") != "image/webp":
            continue
        view = buffer_views[image_record["bufferView"]]
        offset = view.get("byteOffset", 0)
        length = view["byteLength"]
        webp = bytes(bin_data[offset : offset + length])
        with Image.open(io.BytesIO(webp)) as source_image:
            source_image.load()
            if source_image.mode in ("RGBA", "LA") and source_image.getchannel("A").getextrema()[0] < 255:
                save_buffer = io.BytesIO()
                source_image.convert("RGBA").save(save_buffer, "PNG", optimize=True)
                mime = "image/png"
            else:
                save_buffer = io.BytesIO()
                source_image.convert("RGB").save(save_buffer, "JPEG", quality=91, optimize=True)
                mime = "image/jpeg"
        source_replacements[old_index] = embed_image(save_buffer.getvalue(), mime)
        modified += 1

    white_index: int | None = None
    for tex in texture_records:
        ext = tex.get("extensions", {})
        if "source" not in tex:
            webp_ext = ext.get("EXT_texture_webp", {})
            if "source" in webp_ext:
                original = webp_ext["source"]
                tex["source"] = source_replacements.get(original, original)
            else:
                if white_index is None:
                    pixel_buffer = io.BytesIO()
                    Image.new("RGB", (2, 2), (255, 255, 255)).save(pixel_buffer, "PNG")
                    white_index = embed_image(pixel_buffer.getvalue(), "image/png")
                tex["source"] = white_index
        ext.pop("EXT_texture_webp", None)
        if not ext:
            tex.pop("extensions", None)

    document["extensionsUsed"] = [
        name for name in document.get("extensionsUsed", [])
        if name != "EXT_texture_webp"
    ]
    if "extensionsRequired" in document:
        document["extensionsRequired"] = [
            name for name in document["extensionsRequired"]
            if name != "EXT_texture_webp"
        ]
    document["buffers"][0]["byteLength"] = len(bin_data)
    json_bytes = aligned(
        json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8"),
        b" ",
    )
    binary_bytes = aligned(bin_data)
    total_length = 12 + 8 + len(json_bytes) + 8 + len(binary_bytes)
    out = (
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<II", len(json_bytes), GLB_JSON)
        + json_bytes
        + struct.pack("<II", len(binary_bytes), GLB_BIN)
        + binary_bytes
    )
    path.write_bytes(out)
    print(
        f"GLB normalized: {path.name} ({modified} images transcoded; "
        f"{len(texture_records)} textures now use core source; {len(out)} bytes)"
    )


if __name__ == "__main__":
    for filename in sys.argv[1:]:
        normalize(Path(filename))
