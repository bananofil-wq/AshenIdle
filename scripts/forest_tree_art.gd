extends RefCounted
## Reusable forest canopy meshes for portrait GLES3.
## Four tree silhouettes share two materials and stay independent of the
## dungeon floor mesh. Avoids the old cube canopy / cone root appearance.

var variants: Array = []
var bark: StandardMaterial3D
var leaves: StandardMaterial3D

func _emit(st: SurfaceTool, p: Vector3, tint: Color, uv: Vector2) -> void:
    st.set_color(tint)
    st.set_uv(uv)
    st.add_vertex(p)


func _bark_texture() -> Texture2D:
    var image := Image.create(192, 192, false, Image.FORMAT_RGB8)
    var random := FastNoiseLite.new()
    random.seed = 921144
    random.frequency = 0.073
    for y in range(192):
        for x in range(192):
            var grain := sin(float(x) * 0.21 + sin(float(y) * 0.085) * 2.0) * 0.13
            var grain_fine := sin(float(x) * 0.57 + float(y) * 0.18) * 0.05
            var n: float = random.get_noise_2d(float(x) * 0.6, float(y) * 0.22)
            var t: float = clampf(0.52 + grain + grain_fine + n * 0.19, 0.08, 0.91)
            image.set_pixel(x, y, Color("43362b").lerp(Color("a58c69"), t))
    return ImageTexture.create_from_image(image)


func _foliage_texture() -> Texture2D:
    var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
    var noise := FastNoiseLite.new()
    noise.seed = 719872
    noise.frequency = 0.095
    for y in range(128):
        for x in range(128):
            var speck: float = noise.get_noise_2d(float(x), float(y))
            var vein: float = sin(float(x) * 0.53 + float(y) * 0.31) * 0.04
            var brightness: float = clampf(0.84 + speck * 0.24 + vein, 0.65, 1.0)
            image.set_pixel(x, y, Color(brightness, brightness, brightness))
    return ImageTexture.create_from_image(image)


func _make_materials() -> void:
    bark = StandardMaterial3D.new()
    bark.albedo_texture = _bark_texture()
    bark.albedo_color = Color("e1d4c3")
    bark.vertex_color_use_as_albedo = true
    bark.roughness = 0.97
    bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    leaves = StandardMaterial3D.new()
    leaves.albedo_texture = _foliage_texture()
    leaves.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    leaves.vertex_color_use_as_albedo = true
    leaves.albedo_color = Color("9cae8e")
    leaves.roughness = 0.95
    leaves.cull_mode = BaseMaterial3D.CULL_DISABLED


func _tube(st: SurfaceTool, a: Vector3, b: Vector3, bottom: float,
        top: float, rng: RandomNumberGenerator, shade: Color) -> void:
    var forward := (b - a).normalized()
    var side := forward.cross(Vector3.UP)
    if side.length_squared() < 0.001:
        side = forward.cross(Vector3.FORWARD)
    side = side.normalized()
    var up := forward.cross(side).normalized()
    var faces: int = 7
    var rings: int = 3
    var wobble: float = rng.randf_range(-0.19, 0.19)
    for ring in range(rings):
        var t0: float = float(ring) / float(rings)
        var t1: float = float(ring + 1) / float(rings)
        var h0: float = lerpf(bottom, top, t0)
        var h1: float = lerpf(bottom, top, t1)
        for face in range(faces):
            var a0 := TAU * float(face) / float(faces)
            var a1 := TAU * float(face + 1) / float(faces)
            var r0 := 0.89 + 0.08 * sin(a0 * 3.0 + wobble + t0 * 5.0)
            var r1 := 0.89 + 0.08 * sin(a1 * 3.0 + wobble + t1 * 5.0)
            var q0 := a.lerp(b, t0) + Vector3(wobble * t0, 0, 0)
            var q1 := a.lerp(b, t1) + Vector3(wobble * t1, 0, 0)
            var v00 := q0 + (side * cos(a0) + up * sin(a0)) * h0 * r0
            var v01 := q0 + (side * cos(a1) + up * sin(a1)) * h0 * r1
            var v10 := q1 + (side * cos(a0) + up * sin(a0)) * h1 * r0
            var v11 := q1 + (side * cos(a1) + up * sin(a1)) * h1 * r1
            var tone := shade.darkened(0.13) if face % 3 == 0 else shade
            for v in [v00, v10, v01, v01, v10, v11]:
                _emit(st, v, tone, Vector2(float(face) * 0.21, v.y * 0.26))


func _leaf_cluster(st: SurfaceTool, center: Vector3, size: float,
        rng: RandomNumberGenerator, color: Color) -> void:
    # Numerous curved, overlapping lanceolate leaves form a rounded and
    # naturally irregular crown instead of a handful of giant triangular cones.
    for n in range(9):
        var a: float = TAU * float(n) / 9.0 + rng.randf_range(-0.12, 0.12)
        var axis := Vector3(cos(a), rng.randf_range(-0.12, 0.24), sin(a)).normalized()
        var side := Vector3(-axis.z, 0, axis.x).normalized()
        var length: float = size * rng.randf_range(0.37, 0.72)
        var base: Vector3 = center + Vector3(
            rng.randf_range(-0.32, 0.32),
            rng.randf_range(-0.23, 0.23),
            rng.randf_range(-0.32, 0.32))
        var tip: Vector3 = base + axis * length
        var shoulder: Vector3 = base + axis * length * 0.42 + Vector3(0, length * 0.16, 0)
        var width: float = length * rng.randf_range(0.14, 0.22)
        var left: Vector3 = shoulder + side * width
        var right: Vector3 = shoulder - side * width
        var highlight: Color = color.lightened(0.12) if n % 4 == 0 else color.darkened(0.10) if n % 5 == 0 else color
        for p in [base, left, tip, base, tip, right]:
            _emit(st, p, highlight, Vector2(p.x * 0.5, p.z * 0.5))


func _build_variant(variant: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = 12781 + variant * 6383
    var trunk := SurfaceTool.new()
    trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
    var crown := SurfaceTool.new()
    crown.begin(Mesh.PRIMITIVE_TRIANGLES)
    var high: float = rng.randf_range(3.7, 4.65)
    var trunk_color := Color("8d806e") if variant % 2 == 0 else Color("aba18c")
    var shift: float = rng.randf_range(-0.30, 0.30)
    _tube(trunk, Vector3(0, 0.0, 0), Vector3(shift, high, 0.1),
        0.48, 0.21, rng, trunk_color)
    for root in range(5):
        var angle := TAU * float(root) / 5.0
        _tube(trunk, Vector3(cos(angle) * 0.84, 0.02, sin(angle) * 0.80),
            Vector3(cos(angle) * 0.18, 0.70, sin(angle) * 0.18),
            0.085, 0.21, rng, trunk_color.darkened(0.12))
    for arm in range(6):
        var theta: float = TAU * float(arm) / 6.0 + float(variant) * 0.25
        var level: float = high * rng.randf_range(0.68, 0.87)
        var origin := Vector3(shift * 0.7, level, 0.05)
        var direction := Vector3(cos(theta), 0, sin(theta))
        var length: float = rng.randf_range(1.25, 2.20)
        var tip: Vector3 = origin + direction * length + Vector3(0, rng.randf_range(0.65, 1.35), 0)
        _tube(trunk, origin, tip, 0.21, 0.045, rng, trunk_color)
        if arm % 2 == 0:
            _tube(trunk, origin.lerp(tip, 0.64),
                tip + direction * 0.34 + Vector3(0, 0.68, 0),
                0.075, 0.018, rng, trunk_color)
        var greens := [Color("435b38"), Color("617a46"), Color("354b32"), Color("738652")]
        for bunch in range(2):
            var leaf_origin: Vector3 = tip + Vector3(
                rng.randf_range(-0.68, 0.68),
                rng.randf_range(-0.12, 0.63),
                rng.randf_range(-0.68, 0.68))
            _leaf_cluster(crown, leaf_origin,
                rng.randf_range(0.63, 0.92), rng, greens[(arm + bunch + variant) % 4])
    for tuft in range(3):
        var center := Vector3(shift + rng.randf_range(-0.85, 0.85),
            high + rng.randf_range(0.28, 1.3),
            rng.randf_range(-0.90, 0.90))
        _leaf_cluster(crown, center, rng.randf_range(0.8, 1.1), rng,
            Color("455e3a") if tuft % 2 == 0 else Color("6d8150"))
    trunk.generate_normals()
    crown.generate_normals()
    return {"trunk": trunk.commit(), "leaves": crown.commit()}


func _ensure() -> void:
    if not variants.is_empty():
        return
    _make_materials()
    for n in range(4):
        variants.append(_build_variant(n))


func plant(parent: Node3D, position: Vector3, seed_value: int) -> void:
    _ensure()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var variety: int = int(seed_value % 4)
    var source: Dictionary = variants[variety]
    var tree := Node3D.new()
    tree.name = "ForestCanopyTree"
    tree.position = position
    tree.rotation.y = rng.randf_range(-PI, PI)
    var size: float = rng.randf_range(0.72, 0.94)
    tree.scale = Vector3(size, size * rng.randf_range(0.91, 1.15), size)
    parent.add_child(tree)
    var stem := MeshInstance3D.new()
    stem.mesh = source["trunk"] as Mesh
    stem.material_override = bark
    stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    tree.add_child(stem)
    var foliage := MeshInstance3D.new()
    foliage.mesh = source["leaves"] as Mesh
    foliage.material_override = leaves
    foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    tree.add_child(foliage)
