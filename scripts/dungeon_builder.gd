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

func _tree(parent: Node3D, at: Vector3) -> void:
    var bark := _solid(Color("30251e"))
    var leaves := _solid(Color("243b2b") if current_theme == 2 else Color("394753"))
    _column(parent, at, 2.5 + randomizer.randf(), 0.19, bark, 7)
    var foliage := SphereMesh.new()
    foliage.radius = 1.12
    foliage.height = 2.1
    var crown := MeshInstance3D.new()
    crown.mesh = foliage
    crown.material_override = leaves
    crown.position = at + Vector3(0, 3.0, 0)
    parent.add_child(crown)

func _feature(parent: Node3D, at: Vector3, side: int, variant: int) -> void:
    var h: float = randomizer.randf_range(1.0, 2.7)
    match current_theme:
        0:
            # Crypt masonry and shattered gravestones.
            _column(parent, at, h, 0.34, rock_material)
            if variant % 3 == 0:
                _block(parent, at + Vector3(0.50, 0.42, 0), Vector3(0.56, 0.82, 0.19), floor_material)
        1:
            # Frost-blue crystalline caves.
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
            # Basalt shards in rivers of magma.
            _spike(parent, at, h * 1.2, 0.48, rock_material)
            _block(parent, at + Vector3(float(side) * 0.36, 0.02, 0.44), Vector3(0.82, 0.035, 1.05), accent_material)

func _set_materials() -> void:
    floor_material = _solid(Color(FLOOR_COLORS[current_theme]))
    if current_theme == 0 and ResourceLoader.exists("res://assets/pbr/stone_floor_diff_1k.jpg"):
        floor_material.albedo_texture = load("res://assets/pbr/stone_floor_diff_1k.jpg")
        floor_material.uv1_scale = Vector3(2.5, 2.5, 1)
        floor_material.albedo_color = Color("84828c")
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
    for i in range(65):
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
    # A directional entry gate makes forward traversal explicit.
    var entrance := Node3D.new()
    entrance.name = "EntranceGate"
    add_child(entrance)
    _arch(entrance, walk_points[0] + Vector3(0, 0, 4.5), rock_material)
    return walk_points
