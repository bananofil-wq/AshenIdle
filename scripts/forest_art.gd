extends RefCounted
## Enchanted-forest art pass: instanced foliage and leaf litter, worn earth,
## sculpted roots, subtle wet patches and camera-friendly shafts of sunlight.
## Every detail remains actual scene geometry. The combat route stays clear.

var _fern_mesh: Mesh
var _leaf_mesh: Mesh
var _fern_material: StandardMaterial3D
var _leaf_material: StandardMaterial3D
var _root_material: StandardMaterial3D
var _wet_material: StandardMaterial3D
var _shade_material: StandardMaterial3D
var _sun_material: StandardMaterial3D
var _earth_texture: ImageTexture


func earth_texture() -> ImageTexture:
    if _earth_texture != null:
        return _earth_texture
    var broad := FastNoiseLite.new()
    broad.seed = 29873
    broad.frequency = 0.065
    broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    var grain := FastNoiseLite.new()
    grain.seed = 7382
    grain.frequency = 0.35
    grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    var image := Image.create(192, 192, false, Image.FORMAT_RGB8)
    var damp := Color("47372d")
    var dry := Color("a38b6c")
    for py in range(192):
        for px in range(192):
            var noise_value: float = broad.get_noise_2d(float(px), float(py))
            var fleck: float = grain.get_noise_2d(float(px), float(py))
            var t: float = clampf(0.49 + noise_value * 0.47 + fleck * 0.20, 0.05, 0.96)
            image.set_pixel(px, py, damp.lerp(dry, t))
    _earth_texture = ImageTexture.create_from_image(image)
    return _earth_texture


func _ensure_assets() -> void:
    if _fern_mesh != null:
        return
    _fern_material = StandardMaterial3D.new()
    _fern_material.vertex_color_use_as_albedo = true
    _fern_material.albedo_color = Color("9db18b")
    _fern_material.roughness = 0.96
    _fern_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _leaf_material = StandardMaterial3D.new()
    _leaf_material.vertex_color_use_as_albedo = true
    _leaf_material.albedo_color = Color("d8c8a8")
    _leaf_material.roughness = 1.0
    _leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _root_material = StandardMaterial3D.new()
    _root_material.vertex_color_use_as_albedo = true
    _root_material.albedo_color = Color("8c7963")
    _root_material.roughness = 1.0
    _wet_material = StandardMaterial3D.new()
    _wet_material.albedo_color = Color(0.22, 0.25, 0.20, 0.34)
    _wet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _wet_material.roughness = 0.24
    _wet_material.metallic = 0.12
    _wet_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _shade_material = StandardMaterial3D.new()
    _shade_material.albedo_color = Color(0.20, 0.24, 0.17, 0.105)
    _shade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _shade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _shade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _fern_mesh = _make_fronds()
    _leaf_mesh = _make_leaf_litter()
    _sun_material = _make_sun_material()


func _make_fronds() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Curled spear-shaped leaves, open rather than conical, all in one mesh.
    for blade in range(6):
        var angle: float = TAU * float(blade) / 6.0 + 0.18
        var forward := Vector3(cos(angle), 0, sin(angle))
        var across := Vector3(-sin(angle), 0, cos(angle))
        var root := Vector3(0, 0.035, 0)
        var shoulder_a: Vector3 = forward * 0.35 + across * 0.13 + Vector3(0, 0.25, 0)
        var shoulder_b: Vector3 = forward * 0.35 - across * 0.13 + Vector3(0, 0.25, 0)
        var tip: Vector3 = forward * 0.79 + Vector3(0, 0.12, 0)
        var green: Color = Color("78994d") if blade % 3 == 0 else Color("395d32") if blade % 3 == 1 else Color("557842")
        for vertex in [root, shoulder_a, tip, root, tip, shoulder_b]:
            surface.set_color(green)
            surface.add_vertex(vertex)
    surface.generate_normals()
    return surface.commit()


func _make_leaf_litter() -> Mesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for leaf in range(3):
        var angle: float = float(leaf) * 2.15
        var forward := Vector3(cos(angle), 0, sin(angle))
        var side := Vector3(-sin(angle), 0, cos(angle))
        var center: Vector3 = forward * (0.18 + float(leaf) * 0.06)
        var root: Vector3 = center - forward * 0.13
        var left: Vector3 = center + side * 0.10 + Vector3(0, 0.025, 0)
        var tip: Vector3 = center + forward * 0.19
        var right: Vector3 = center - side * 0.10 + Vector3(0, 0.025, 0)
        var shade: Color = Color("9f683e") if leaf == 0 else Color("bf994f") if leaf == 1 else Color("69563b")
        for vertex in [root, left, tip, root, tip, right]:
            surface.set_color(shade)
            surface.add_vertex(vertex)
    surface.generate_normals()
    return surface.commit()


func _make_sun_material() -> StandardMaterial3D:
    var image := Image.create(48, 128, false, Image.FORMAT_RGBA8)
    for y in range(128):
        var vertical: float = sin(PI * float(y) / 127.0)
        for x in range(48):
            var horizontal: float = 1.0 - absf(float(x) - 23.5) / 23.5
            var alpha: float = pow(maxf(0.0, horizontal), 2.4) * pow(maxf(0.0, vertical), 0.8) * 0.095
            image.set_pixel(x, y, Color(1.0, 0.91, 0.68, alpha))
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.albedo_texture = ImageTexture.create_from_image(image)
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    return material


func _scatter_instance_group(parent: Node3D, mesh: Mesh, material: Material,
        positions: Array, colors: Array, name: String) -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = mesh
    mm.instance_count = positions.size()
    for i in range(positions.size()):
        var sample: Dictionary = positions[i]
        var pivot: Vector3 = sample["position"]
        var angle: float = float(sample["angle"])
        var size: float = float(sample["scale"])
        var basis := Basis(Vector3.UP, angle).scaled(Vector3(size, size, size))
        mm.set_instance_transform(i, Transform3D(basis, pivot))
        mm.set_instance_color(i, colors[i] as Color)
    var foliage := MultiMeshInstance3D.new()
    foliage.name = name
    foliage.multimesh = mm
    foliage.material_override = material
    foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(foliage)


func _scatter_foliage(parent: Node3D, center: Vector3, seed_value: int, room_index: int) -> void:
    var random := RandomNumberGenerator.new()
    random.seed = seed_value
    var ferns: Array = []
    var fern_colors: Array = []
    var leaves: Array = []
    var leaf_colors: Array = []
    for n in range(104):
        # No obstacles in the hero's central auto-navigation lane.
        var side: float = -1.0 if n % 2 == 0 else 1.0
        var x: float = center.x + side * random.randf_range(2.05, 5.65)
        var z: float = center.z + random.randf_range(-5.45, 5.45)
        var size: float = random.randf_range(0.26, 0.76)
        ferns.append({"position": Vector3(x, -0.105, z),
            "angle": random.randf_range(-PI, PI), "scale": size})
        fern_colors.append([Color("a4ae8b"), Color("66865a"), Color("849d67")][n % 3])
    for n in range(82):
        var x: float = center.x + random.randf_range(-4.9, 4.9)
        var z: float = center.z + random.randf_range(-5.4, 5.4)
        leaves.append({"position": Vector3(x, -0.068, z),
            "angle": random.randf_range(-PI, PI),
            "scale": random.randf_range(0.25, 0.66)})
        leaf_colors.append([Color("a38b68"), Color("777b58"), Color("966d50"),
            Color("8b8758")][n % 4])
    _scatter_instance_group(parent, _fern_mesh, _fern_material, ferns, fern_colors,
        "ForestFernInstances_%d" % room_index)
    _scatter_instance_group(parent, _leaf_mesh, _leaf_material, leaves, leaf_colors,
        "ForestLeafLitter_%d" % room_index)


func _sculpt_roots(parent: Node3D, center: Vector3, seed_value: int, room_index: int) -> void:
    var random := RandomNumberGenerator.new()
    random.seed = seed_value + 1843
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for root_index in range(9):
        var sign: float = -1.0 if root_index % 2 == 0 else 1.0
        var x0: float = center.x + sign * random.randf_range(3.45, 5.0)
        var z0: float = center.z + random.randf_range(-4.5, 4.5)
        var angle: float = random.randf_range(-0.5, 0.5)
        var across := Vector3(cos(angle), 0, sin(angle))
        var start := Vector3(x0, -0.105, z0)
        for segment in range(6):
            var t: float = float(segment) / 6.0
            var u: float = float(segment + 1) / 6.0
            var a: Vector3 = start - across * float(segment) * 0.23 * sign
            var b: Vector3 = start - across * float(segment + 1) * 0.23 * sign
            a.z += sin(float(segment) * 1.5 + float(root_index)) * 0.13
            b.z += sin(float(segment + 1) * 1.5 + float(root_index)) * 0.13
            var thickness_a: float = lerpf(0.12, 0.025, t)
            var thickness_b: float = lerpf(0.12, 0.025, u)
            var normal := Vector3(-across.z, 0, across.x)
            var left_a := a + normal * thickness_a
            var right_a := a - normal * thickness_a
            var left_b := b + normal * thickness_b
            var right_b := b - normal * thickness_b
            for vertex in [left_a, right_a, left_b, right_a, right_b, left_b]:
                surface.set_color(Color("79664e") if root_index % 3 == 0 else Color("514a3a"))
                surface.add_vertex(vertex)
    surface.generate_normals()
    var roots := MeshInstance3D.new()
    roots.name = "ForestSculptedRoots_%d" % room_index
    roots.mesh = surface.commit()
    roots.material_override = _root_material
    roots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(roots)


func _wet_ground(parent: Node3D, center: Vector3, seed_value: int, room_index: int) -> void:
    var random := RandomNumberGenerator.new()
    random.seed = seed_value + 5472
    for is_shade in [false, true]:
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        var patches: int = 9 if is_shade else 5
        for n in range(patches):
            var x: float = center.x + random.randf_range(-4.2, 4.2) if is_shade else center.x + random.randf_range(-0.85, 0.85)
            var z: float = center.z + random.randf_range(-5.1, 5.1)
            var wide: float = random.randf_range(0.20, 0.65) if is_shade else random.randf_range(0.12, 0.34)
            var long: float = random.randf_range(0.21, 0.72)
            var y: float = -0.068 if is_shade else -0.060
            var pivot := Vector3(x, y, z)
            var edge: Array = []
            for i in range(9):
                var theta: float = TAU * float(i) / 9.0
                edge.append(pivot + Vector3(cos(theta) * wide *
                    random.randf_range(0.83, 1.13), 0,
                    sin(theta) * long * random.randf_range(0.85, 1.12)))
            for i in range(9):
                for vertex in [pivot, edge[(i + 1) % 9], edge[i]]:
                    surface.add_vertex(vertex)
        surface.generate_normals()
        var decal := MeshInstance3D.new()
        decal.name = ("CanopyDapple_" if is_shade else "WetFootprints_") + str(room_index)
        decal.mesh = surface.commit()
        decal.material_override = _shade_material if is_shade else _wet_material
        decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(decal)


func _sun_shafts(parent: Node3D, center: Vector3, seed_value: int, room_index: int) -> void:
    var random := RandomNumberGenerator.new()
    random.seed = seed_value + 819
    for i in range(2):
        var quad := QuadMesh.new()
        quad.size = Vector2(random.randf_range(1.4, 2.8), random.randf_range(5.8, 8.4))
        var shaft := MeshInstance3D.new()
        shaft.name = "ForestLightShaft_%d_%d" % [room_index, i]
        shaft.mesh = quad
        shaft.material_override = _sun_material
        var side: float = -1.0 if i == 0 else 1.0
        shaft.position = center + Vector3(side * random.randf_range(2.6, 4.9),
            random.randf_range(2.2, 3.2), random.randf_range(-3.5, 2.1))
        shaft.rotation.z = 0.26 if i == 0 else -0.26
        shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(shaft)


func decorate(parent: Node3D, center: Vector3, stage: int, room_index: int) -> void:
    _ensure_assets()
    var seed_value: int = stage * 10007 + room_index * 15013
    _scatter_foliage(parent, center, seed_value, room_index)
    _sculpt_roots(parent, center, seed_value, room_index)
    _wet_ground(parent, center, seed_value, room_index)
    _sun_shafts(parent, center, seed_value, room_index)
