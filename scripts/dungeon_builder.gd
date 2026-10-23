extends Node3D
# Procedural, room-to-room dungeon generator. Ten floors share a biome; each
# floor has a deterministic but distinct winding layout, props and encounter rooms.
# The boss is always on the tenth floor of its biome.
const THEMES := ["THE CINDER CRYPT", "THE FROST HOLLOW", "THE THORNWILD", "THE VOID CITADEL", "THE MOLTEN DEPTHS"]
const FLOOR_COLORS := ["55505a", "879dad", "374c38", "343049", "3d3437"]
const ACCENTS := ["eb864e", "8bdcff", "8acb69", "b46fff", "ff6232"]
const ROCKS := ["35313c", "50647a", "354337", "302c4a", "34262b"]
const WIDTH := 9.0
const DISTANCE := 14.0

var walk_points := PackedVector3Array()
var current_theme := 0
var current_stage := 1
var randomizer := RandomNumberGenerator.new()
var floor_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var accent_material: StandardMaterial3D

func _solid(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.90
    if emissive:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 0.9
    return m

func _block(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = at
    parent.add_child(instance)
    return instance

func _column(parent: Node3D, at: Vector3, height: float, radius: float, mat: Material, sides: int = 8) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.top_radius = radius * 0.77
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = sides
    var part := MeshInstance3D.new()
    part.mesh = shape
    part.material_override = mat
    part.position = at + Vector3(0, height * 0.5, 0)
    parent.add_child(part)
    return part

func _spike(parent: Node3D, at: Vector3, height: float, radius: float, mat: Material) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.02
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 5
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = at + Vector3(0, height * 0.5, 0)
    instance.rotation.z = randomizer.randf_range(-0.14, 0.14)
    parent.add_child(instance)

func _connect(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
    var difference := b - a
    var slab := _block(parent, (a + b) * 0.5 + Vector3(0, -0.12, 0), Vector3(width, 0.22, difference.length() + 1.8), mat)
    slab.rotation.y = atan2(difference.x, difference.z)

func _arch(parent: Node3D, center: Vector3, stone: Material) -> void:
    for sign in [-1.0, 1.0]:
        _block(parent, center + Vector3(sign * 3.90, 1.10, 0), Vector3(0.65, 2.2, 0.75), stone)
    _block(parent, center + Vector3(0, 2.36, 0), Vector3(8.45, 0.60, 0.90), stone)

func _mountain(parent: Node3D, at: Vector3, height: float, width: float) -> void:
    # A real faceted mountain mesh with layered slopes and a broken summit.
    # Unlike placing boxes, its silhouette and cliff faces read at camera distance.
    var stone := _solid(Color("a5a9ad") if current_theme == 1 else Color("736277") if current_theme == 3 else Color("6c5b55"))
    stone.vertex_color_use_as_albedo = true
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sides: int = 9
    var ridge: Array = []
    for i in range(sides):
        ridge.append(randomizer.randf_range(0.72, 1.16))
    for tier in range(3):
        var bottom_h: float = float(tier) / 3.0 * height
        var top_h: float = float(tier + 1) / 3.0 * height
        var bottom_scale: float = [1.0, 0.64, 0.32][tier]
        var top_scale: float = [0.64, 0.32, 0.035][tier]
        for i in range(sides):
            var angle0: float = TAU * float(i) / float(sides)
            var angle1: float = TAU * float(i + 1) / float(sides)
            var direction0 := Vector3(cos(angle0), 0, sin(angle0))
            var direction1 := Vector3(cos(angle1), 0, sin(angle1))
            var p0: Vector3 = direction0 * width * bottom_scale * float(ridge[i]) + Vector3(0, bottom_h, 0)
            var p1: Vector3 = direction1 * width * bottom_scale * float(ridge[(i + 1) % sides]) + Vector3(0, bottom_h, 0)
            var p2: Vector3 = direction0 * width * top_scale * float(ridge[i]) + Vector3(0, top_h, 0)
            var p3: Vector3 = direction1 * width * top_scale * float(ridge[(i + 1) % sides]) + Vector3(0, top_h, 0)
            var shade: float = randomizer.randf_range(0.57, 0.95)
            var tone: Color = Color(shade, shade * 0.99, shade * 1.02)
            if current_theme == 1 and tier == 2:
                tone = Color("e0eef3") * randomizer.randf_range(0.85, 1.0)
            for vertex in [p0, p2, p1, p1, p2, p3]:
                builder.set_color(tone)
                builder.add_vertex(vertex)
    builder.generate_normals()
    var model := MeshInstance3D.new()
    model.mesh = builder.commit()
    model.material_override = stone
    model.position = at
    parent.add_child(model)

func _ground_details(parent: Node3D, center: Vector3) -> void:
    # Rocks, roots, fallen trunks and crystals hug path edges without blocking it.
    var earth := _solid(Color("463c39") if current_theme == 2 else Color("51505a"))
    for i in range(17):
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var p: Vector3 = center + Vector3(side * randomizer.randf_range(3.0, 4.7), 0, randomizer.randf_range(-4.2, 4.2))
        if current_theme == 2:
            var log := _block(parent, p + Vector3(0, 0.12, 0), Vector3(randomizer.randf_range(0.6, 1.5), 0.14, 0.21), earth)
            log.rotation.y = randomizer.randf_range(-0.9, 0.9)
            if i % 3 == 0:
                _tree(parent, p + Vector3(side * 1.2, 0, 0))
        elif current_theme == 1:
            _spike(parent, p, randomizer.randf_range(0.3, 1.1), 0.18, accent_material if i % 3 == 0 else rock_material)
        elif current_theme == 4:
            _mountain(parent, p, randomizer.randf_range(0.55, 1.5), randomizer.randf_range(0.35, 0.8))
        else:
            var rubble := _block(parent, p + Vector3(0, 0.10, 0), Vector3(0.48, 0.22, 0.58), rock_material)
            rubble.rotation.y = randomizer.randf_range(0.0, TAU)

func _tree(parent: Node3D, at: Vector3) -> void:
    # Multi-part trunk and irregular foliage clusters: these look like trees,
    # not cylinders with a single oversized green sphere.
    var bark := _solid(Color("392c25") if current_theme == 2 else Color("48515c"))
    var trunk_height: float = 2.4 + randomizer.randf_range(0.25, 1.5)
    _column(parent, at, trunk_height, 0.24, bark, 7)
    for limb in range(4):
        var angle: float = TAU * float(limb) / 4.0 + randomizer.randf_range(-0.32, 0.32)
        var length: float = randomizer.randf_range(0.7, 1.3)
        var branch := _block(parent, at + Vector3(cos(angle) * length * 0.35, trunk_height * 0.75, sin(angle) * length * 0.35), Vector3(0.16, 0.16, length), bark)
        branch.rotation.y = angle
        branch.rotation.x = randomizer.randf_range(-0.27, 0.27)
    var foliage_color := _solid(Color("284630") if current_theme == 2 else Color("547582"))
    for cluster in range(6):
        var angle: float = TAU * float(cluster) / 6.0
        var leaf := MeshInstance3D.new()
        var canopy := SphereMesh.new()
        canopy.radius = randomizer.randf_range(0.63, 0.93)
        canopy.height = randomizer.randf_range(1.15, 1.8)
        leaf.mesh = canopy
        leaf.material_override = foliage_color
        leaf.position = at + Vector3(cos(angle) * 0.73, trunk_height + randomizer.randf_range(0.2, 1.0), sin(angle) * 0.73)
        leaf.scale = Vector3(1.0, randomizer.randf_range(0.75, 1.2), 1.0)
        parent.add_child(leaf)

func _feature(parent: Node3D, at: Vector3, side: int, variant: int) -> void:
    var h: float = randomizer.randf_range(1.0, 2.7)
    match current_theme:
        0:
            # Crypt masonry and shattered gravestones.
            _column(parent, at, h, 0.34, rock_material)
            if variant % 3 == 0:
                _block(parent, at + Vector3(0.50, 0.42, 0), Vector3(0.56, 0.82, 0.19), floor_material)
        1:
            # Tall jagged walls behind sharp ice formations.
            if variant % 3 == 0:
                _mountain(parent, at, h * 1.75, 1.65)
            for i in range(3):
                _spike(parent, at + Vector3(float(i-1) * 0.4, 0, float(i % 2) * 0.24), h * (1.0 if i == 1 else 0.64), 0.32, accent_material if i == 1 else rock_material)
        2:
            # Forest floor, ancient roots, trees, boulders.
            if variant % 2 == 0:
                _tree(parent, at)
            else:
                _column(parent, at, 0.55, 0.65, rock_material)
        3:
            # Floating-looking void obelisks with luminous runes.
            _column(parent, at, h * 1.20, 0.41, rock_material, 4)
            _block(parent, at + Vector3(0, h * 0.8, 0.21), Vector3(0.17, 0.58, 0.07), accent_material)
        4:
            # Lava cliffs, black rock ridges and volcanic spires.
            if variant % 2 == 0:
                _mountain(parent, at, h * 2.2, 1.5)
            _spike(parent, at, h * 1.2, 0.48, rock_material)
            _block(parent, at + Vector3(float(side) * 0.36, 0.02, 0.44), Vector3(0.82, 0.035, 1.05), accent_material)

func _terrain_texture() -> ImageTexture:
    # Deterministic rock, snow, leaf-litter, void and lava texture variants.
    # Lightweight CPU noise replaces featureless solid-color floors on Android.
    var dark_colors := ["22232b", "5d7482", "233927", "242039", "3a1c1c"]
    var light_colors := ["68636a", "aecfdb", "536f45", "5d487a", "9b5536"]
    var dark: Color = Color(dark_colors[current_theme])
    var light: Color = Color(light_colors[current_theme])
    var noise := FastNoiseLite.new()
    noise.seed = 141 + current_stage * 7919
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.085
    var img := Image.create(96, 96, false, Image.FORMAT_RGB8)
    for y in range(96):
        for x in range(96):
            var broad: float = noise.get_noise_2d(float(x), float(y))
            var grit: float = sin(float(x) * 2.41 + float(y) * 1.73) * 0.09
            var weight: float = clampf(0.49 + broad * 0.40 + grit, 0.05, 0.96)
            img.set_pixel(x, y, dark.lerp(light, weight))
    return ImageTexture.create_from_image(img)

func _set_materials() -> void:
    floor_material = _solid(Color(FLOOR_COLORS[current_theme]))
    if current_theme == 0 and ResourceLoader.exists("res://assets/pbr/stone_floor_diff_1k.jpg"):
        floor_material.albedo_texture = load("res://assets/pbr/stone_floor_diff_1k.jpg")
        floor_material.uv1_scale = Vector3(2.5, 2.5, 1)
        floor_material.albedo_color = Color("94939b")
    else:
        floor_material.albedo_texture = _terrain_texture()
        floor_material.albedo_color = Color("d9e0df")
        floor_material.uv1_scale = Vector3(3.5, 3.5, 1)
    floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    rock_material = _solid(Color(ROCKS[current_theme]))
    accent_material = _solid(Color(ACCENTS[current_theme]), true)

func _decorate(parent: Node3D, at: Vector3, index: int) -> void:
    # Props never occupy the central corridor used by the automatic pathfinder.
    for side in [-1, 1]:
        var x: float = float(side) * randomizer.randf_range(4.1, 5.6)
        var n: int = 2 + int(index % 2)
        for i in range(n):
            var offset := Vector3(x + randomizer.randf_range(-0.55, 0.55), 0, randomizer.randf_range(-3.7, 3.7))
            _feature(parent, at + offset, side, i + index)
    if current_theme == 0 or current_theme == 3:
        if index > 0:
            _arch(parent, at + Vector3(0, 0, 4.3), rock_material)
    elif current_theme == 1:
        for side in [-1.0, 1.0]:
            _block(parent, at + Vector3(side * 4.45, -0.1, 0), Vector3(0.9, 0.23, 7.8), rock_material)
    elif current_theme == 2:
        for side in [-1.0, 1.0]:
            var stump := at + Vector3(side * 4.6, 0, -2.0)
            _tree(parent, stump)
    elif current_theme == 4:
        for side in [-1.0, 1.0]:
            _block(parent, at + Vector3(side * 5.0, -0.02, 0), Vector3(1.0, 0.10, 8.7), accent_material)

func generate(floor_number: int) -> PackedVector3Array:
    current_stage = maxi(1, floor_number)
    current_theme = posmod(int((current_stage - 1) / 10), THEMES.size())
    randomizer.seed = 7919 + current_stage * 15427
    for child in get_children():
        remove_child(child)
        child.queue_free()
    _set_materials()
    # Surround the playable route with biome-specific terrain, not an empty
    # black skybox. Landscapes need to occupy the whole portrait view.
    var terrain_colors := ["221e25", "273d4b", "152b1b", "1a142a", "2d1110"]
    var terrain := _solid(Color(terrain_colors[current_theme]))
    terrain.albedo_texture = floor_material.albedo_texture
    terrain.albedo_color = Color("84828c") if current_theme == 0 else Color("b4bdba")
    terrain.uv1_scale = Vector3(11, 11, 1)
    terrain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _block(self, Vector3(0, -0.58, -18.0), Vector3(48, 0.40, 88), terrain)
    walk_points = PackedVector3Array()
    var variation: float = float((current_stage - 1) % 10)
    walk_points.append(Vector3(0, 0, 5))
    for i in range(1, 4):
        var shifted: float = randomizer.randf_range(-2.15, 2.15)
        if i == 3:
            shifted *= 0.6
        walk_points.append(Vector3(shifted, 0, 5.0 - DISTANCE * float(i) - variation * 0.22 * float(i)))

    # Each stage is a long traversable chain of chambers linked by real corridors.
    for i in range(walk_points.size()):
        var room := Node3D.new()
        room.name = "Chamber_%d" % i
        add_child(room)
        var p: Vector3 = walk_points[i]
        _block(room, p + Vector3(0, -0.18, 0), Vector3(WIDTH + 1.1, 0.32, 10.3), floor_material)
        for side in [-1.0, 1.0]:
            if current_theme != 2:
                var wall: Vector3 = p + Vector3(side * 5.4, 0.7, 0)
                _block(room, wall, Vector3(0.55, 1.3 if current_theme != 1 else 0.72, 10.3), rock_material)
        _decorate(room, p, i + (current_stage % 10))
        _ground_details(room, p)
        if i > 0:
            _connect(room, walk_points[i-1] + Vector3(0, 0, -4.3), p + Vector3(0, 0, 4.3), 5.9, floor_material)
        if i == 3 and current_stage % 10 == 0:
            var altar := _column(room, p + Vector3(0, -0.03, -2.8), 0.35, 2.7, rock_material, 12)
            altar.name = "BossDais"
            for k in range(8):
                var angle := TAU * float(k) / 8.0
                _spike(room, p + Vector3(cos(angle) * 3.8, 0, sin(angle) * 3.8), 1.1, 0.21, accent_material)

    # The surrounding world continues beyond the route. Procedural rock,
    # snow and tree silhouettes create strong biome differences on every floor.
    var wilderness := Node3D.new()
    wilderness.name = "ExteriorLandscape"
    add_child(wilderness)
    for i in range(44):
        var z: float = randomizer.randf_range(-47.0, 12.0)
        var x: float = randomizer.randf_range(-18.0, 18.0)
        var close_to_route := false
        for point in walk_points:
            if absf(z - point.z) < 7.2 and absf(x - point.x) < 6.1:
                close_to_route = true
                break
        if close_to_route:
            continue
        _feature(wilderness, Vector3(x, -0.32, z), 1 if x > 0 else -1, i)
    # Silhouettes of large ridgelines occupy the distance: mountains are actual
    # 3D geometry, with height, slope and light catching the cliff faces.
    var far_ridges := Node3D.new()
    far_ridges.name = "MountainHorizon"
    add_child(far_ridges)
    for side in [-1.0, 1.0]:
        for r in range(8):
            var z: float = 8.0 - float(r) * 8.4
            var x: float = side * randomizer.randf_range(11.2, 19.5)
            if current_theme == 2:
                _tree(far_ridges, Vector3(x, -0.26, z))
                _tree(far_ridges, Vector3(x + side * 2.0, -0.26, z - 0.8))
            else:
                _mountain(far_ridges, Vector3(x, -0.35, z), randomizer.randf_range(4.5, 9.3), randomizer.randf_range(3.0, 5.5))
    # A directional entry gate makes forward traversal explicit.
    var entrance := Node3D.new()
    entrance.name = "EntranceGate"
    add_child(entrance)
    _arch(entrance, walk_points[0] + Vector3(0, 0, 4.5), rock_material)
    return walk_points
