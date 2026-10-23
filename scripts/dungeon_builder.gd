extends Node3D
# Procedural, room-to-room dungeon generator. Ten floors share a biome; each
# floor has a deterministic but distinct winding layout, props and encounter rooms.
# The boss is always on the tenth floor of its biome.
const THEMES := ["THE CINDER CRYPT", "THE FROST HOLLOW", "THE THORNWILD", "THE VOID CITADEL", "THE MOLTEN DEPTHS"]
const FLOOR_COLORS := ["55505a", "879dad", "374c38", "464544", "3d3437"]
const ACCENTS := ["eb864e", "8bdcff", "8acb69", "82669c", "ff6232"]
const ROCKS := ["35313c", "50647a", "354337", "45413f", "34262b"]
const WIDTH := 9.0
const DISTANCE := 14.0

var walk_points := PackedVector3Array()
var current_theme := 0
var current_stage := 1
var randomizer := RandomNumberGenerator.new()
var floor_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var landmark_count := 0
var route_style := 0
var box_batch_count := 0
var unbatched_box_count := 0
var _unit_box: BoxMesh = BoxMesh.new()
var _unit_spike: CylinderMesh = CylinderMesh.new()
var _unit_foliage: CylinderMesh = CylinderMesh.new()
var _unit_boulder: Mesh
var _unit_columns: Dictionary = {}
var _material_cache: Dictionary = {}

func _solid(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var key: String = color.to_html(true) + (":glow" if emissive else ":mat")
    if _material_cache.has(key):
        return _material_cache[key] as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.90
    if emissive:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 0.9
    _material_cache[key] = m
    return m

func _build_boulder_mesh() -> Mesh:
    # Single shared sculpted rock, then scaled/rotated thousands of ways with
    # MultiMesh. This replaces the little rectangular boxes littering the map.
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sides: int = 11
    var top := Vector3(0.08, 0.68, -0.10)
    for i in range(sides):
        var a: float = TAU * float(i) / float(sides)
        var b: float = TAU * float(i + 1) / float(sides)
        var radius_a: float = 0.89 + 0.14 * sin(float(i) * 4.7)
        var radius_b: float = 0.89 + 0.14 * sin(float(i + 1) * 4.7)
        var p0 := Vector3(cos(a) * radius_a, -0.43, sin(a) * radius_a)
        var p1 := Vector3(cos(b) * radius_b, -0.43, sin(b) * radius_b)
        var p2 := Vector3(cos(a) * radius_a * 0.70, 0.29 + 0.12 * sin(a * 3.0), sin(a) * radius_a * 0.70)
        var p3 := Vector3(cos(b) * radius_b * 0.70, 0.29 + 0.12 * sin(b * 3.0), sin(b) * radius_b * 0.70)
        for point in [p0, p2, p1, p1, p2, p3, p2, top, p3]:
            builder.set_uv(Vector2(point.x * 0.45 + 0.5, point.z * 0.45 + 0.5))
            builder.add_vertex(point)
    builder.generate_normals()
    return builder.commit()


func _stone(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
    var piece := MeshInstance3D.new()
    piece.mesh = _unit_boulder
    piece.material_override = mat
    piece.position = at
    piece.scale = dimensions
    piece.rotation.y = randomizer.randf_range(-PI, PI)
    parent.add_child(piece)
    return piece


func _block(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    # One shared unit cube. Scale carries individual dimensions; all small
    # stone/wood/rubble pieces can be merged into a few GPU instanced batches.
    var instance := MeshInstance3D.new()
    instance.mesh = _unit_box
    instance.scale = size
    instance.material_override = mat
    instance.position = at
    parent.add_child(instance)
    return instance

func _batch_static_boxes() -> void:
    # Batch static cubes, crystals, pillars and foliage into a handful of
    # GPU-instanced MultiMeshes, not hundreds of individual GLES3 draw calls.
    var batches: Dictionary = {}
    var rendered: Array = find_children("*", "MeshInstance3D", true, false)
    for child in rendered:
        var part: MeshInstance3D = child as MeshInstance3D
        if part == null or part.mesh == null or part.material_override == null:
            continue
        var eligible: bool = part.mesh == _unit_box or part.mesh == _unit_spike or part.mesh == _unit_foliage or part.mesh == _unit_boulder
        if not eligible:
            for unit in _unit_columns.values():
                if part.mesh == unit:
                    eligible = true
                    break
        if not eligible or part.name == "BossDais" or part.name == "RiftGate":
            continue
        var material: Material = part.material_override
        # Each batch belongs to a short section of the route. A stage-wide
        # MultiMesh has an enormous AABB and defeats Godot frustum culling:
        # walking in room 1 still draws ruins from room 4 and the distant forest.
        var chunk: int = floori(part.global_position.z / 26.0)
        var key: String = "%d-%d-%d" % [part.mesh.get_instance_id(), material.get_instance_id(), chunk]
        if not batches.has(key):
            batches[key] = {"material": material, "mesh": part.mesh, "chunk": chunk, "transforms": []}
        (batches[key]["transforms"] as Array).append(global_transform.affine_inverse() * part.global_transform)
        unbatched_box_count += 1
        part.queue_free()
    box_batch_count = batches.size()
    for key in batches:
        var batch: Dictionary = batches[key]
        var placements: Array = batch["transforms"]
        if placements.is_empty():
            continue
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = batch["mesh"] as Mesh
        multi.instance_count = placements.size()
        for i in range(placements.size()):
            multi.set_instance_transform(i, placements[i] as Transform3D)
        var instance := MultiMeshInstance3D.new()
        instance.name = "BatchedEnvironment_%s" % str(key).replace("-", "_")
        instance.set_meta("spatial_chunk", int(batch["chunk"]))
        instance.multimesh = multi
        instance.material_override = batch["material"] as Material
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(instance)


func _column(parent: Node3D, at: Vector3, height: float, radius: float, mat: Material, sides: int = 8) -> MeshInstance3D:
    if not _unit_columns.has(sides):
        var shape := CylinderMesh.new()
        shape.top_radius = 0.77
        shape.bottom_radius = 1.0
        shape.height = 1.0
        shape.radial_segments = sides
        _unit_columns[sides] = shape
    var part := MeshInstance3D.new()
    part.mesh = _unit_columns[sides] as Mesh
    part.scale = Vector3(radius, height, radius)
    part.material_override = mat
    part.position = at + Vector3(0, height * 0.5, 0)
    parent.add_child(part)
    return part

func _spike(parent: Node3D, at: Vector3, height: float, radius: float, mat: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.mesh = _unit_spike
    instance.scale = Vector3(radius, height, radius)
    instance.material_override = mat
    instance.position = at + Vector3(0, height * 0.5, 0)
    instance.rotation.z = randomizer.randf_range(-0.14, 0.14)
    parent.add_child(instance)

func _connect(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
    # A rough-hewn passage built from a real curved polygon strip. The previous
    # full-width rectangular box read as a pale floating tabletop on the game.
    var direction: Vector3 = b - a
    direction.y = 0.0
    if direction.length_squared() < 0.01:
        return
    var forward: Vector3 = direction.normalized()
    var lateral := Vector3(direction.z, 0, -direction.x).normalized()
    var length: float = direction.length()
    var n: int = 10
    var points_left := PackedVector3Array()
    var points_right := PackedVector3Array()
    for i in range(n + 1):
        var t: float = float(i) / float(n)
        var taper: float = lerpf(0.85, 1.0, sin(PI * t))
        var jagged: float = 0.94 + 0.05 * sin(float(i) * 1.8 + float(current_stage))
        var half_width: float = width * 0.5 * taper * jagged
        var p: Vector3 = a + forward * length * t + Vector3(0, -0.17, 0)
        points_left.append(p + lateral * half_width)
        points_right.append(p - lateral * half_width)
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(n):
        for v in [points_left[i], points_right[i], points_left[i + 1], points_right[i], points_right[i + 1], points_left[i + 1]]:
            surface.set_uv(Vector2(v.x * 0.28, v.z * 0.28))
            surface.add_vertex(v)
    surface.generate_normals()
    var walkway := MeshInstance3D.new()
    walkway.name = "CarvedStonePassage"
    walkway.mesh = surface.commit()
    walkway.material_override = mat
    parent.add_child(walkway)
    # Edges are irregular, not continuous raised beams in the camera view.
    for i in range(1, n, 3):
        var p: Vector3 = a.lerp(b, float(i) / float(n))
        for side in [-1.0, 1.0]:
            if (i + int(side) + current_stage) % 3 == 0:
                _stone(parent, p + lateral * side * (width * 0.56), Vector3(0.34, 0.22, 0.54), rock_material)

func _arch(parent: Node3D, center: Vector3, stone: Material) -> void:
    # Two broken pillars and interrupted lintels frame the gate, without a
    # horizontal beam across the hero at portrait camera height.
    for sign in [-1.0, 1.0]:
        var footing := center + Vector3(sign * 3.95, 0, 0)
        _column(parent, footing, 2.70, 0.46, stone)
        var broken_lintel := _block(parent, footing + Vector3(-sign * 0.38, 2.6, 0), Vector3(1.15, 0.33, 0.72), stone)
        broken_lintel.rotation.z = sign * randomizer.randf_range(0.05, 0.18)

func _mountain(parent: Node3D, at: Vector3, height: float, width: float) -> void:
    # A real faceted mountain mesh with layered slopes and a broken summit.
    # Unlike placing boxes, its silhouette and cliff faces read at camera distance.
    var stone := _solid(Color("a5b5cd") if current_theme == 1 else Color("6d6084") if current_theme == 3 else Color("657183") if current_theme == 0 else Color("655857"))
    stone.vertex_color_use_as_albedo = true
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sides: int = 13
    var ridge: Array = []
    for i in range(sides):
        ridge.append(randomizer.randf_range(0.72, 1.16))
    var profile: Array = [1.0, 0.86, 0.66, 0.46, 0.21, 0.035]
    for tier in range(5):
        var bottom_h: float = float(tier) / 5.0 * height
        var top_h: float = float(tier + 1) / 5.0 * height
        var bottom_scale: float = float(profile[tier])
        var top_scale: float = float(profile[tier + 1])
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
            if current_theme == 1 and tier >= 3:
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
    var earth := _solid(Color("463c39") if current_theme == 2 else Color("343438") if current_theme == 3 else Color("51505a"))
    for i in range(25):
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
            _stone(parent, p + Vector3(0, 0.06, 0), Vector3(randomizer.randf_range(0.34, 0.90), randomizer.randf_range(0.22, 0.60), randomizer.randf_range(0.44, 1.2)), rock_material)

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
    var foliage_color := _solid(Color("23402a") if current_theme == 2 else Color("41586a"))
    # Staggered conifer-like crowns replace the former oversized green spheres,
    # which gave the forest a toy-model appearance even with PBR soil.
    for cluster in range(6):
        var tier: int = int(cluster / 3)
        var angle: float = TAU * float(cluster % 3) / 3.0 + float(tier) * 0.60
        var leaf := MeshInstance3D.new()
        var foliage_radius: float = randomizer.randf_range(0.60, 0.90) * (1.0 - 0.18 * float(tier))
        leaf.mesh = _unit_foliage
        leaf.material_override = foliage_color
        leaf.position = at + Vector3(cos(angle) * 0.46, trunk_height - 0.46 + float(tier) * 0.66, sin(angle) * 0.46)
        leaf.scale = Vector3(foliage_radius, randomizer.randf_range(1.55, 2.18), foliage_radius)
        leaf.rotation.y = angle
        parent.add_child(leaf)

func _feature(parent: Node3D, at: Vector3, side: int, variant: int) -> void:
    var h: float = randomizer.randf_range(1.0, 2.7)
    match current_theme:
        0:
            # Broken tombstones half-buried among irregular rock rubble.
            _column(parent, at, h, 0.34, rock_material)
            _stone(parent, at + Vector3(0.45, 0.04, 0.35), Vector3(0.85, 0.48, 0.80), rock_material)
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
                _stone(parent, at, Vector3(1.5, 0.8, 1.1), rock_material)
        3:
            # Fallen masonry and fractured steles instead of glowing cuboids.
            var obelisk := _column(parent, at, h * 1.15, 0.46, rock_material, 7)
            obelisk.rotation.z = randomizer.randf_range(-0.22, 0.22)
            _stone(parent, at + Vector3(0.45, 0.09, -0.2),
                Vector3(1.32, 0.70, 1.15), rock_material)
            if variant % 4 == 0:
                var tablet := _block(parent, at + Vector3(0.18, h * 0.68, 0.32),
                    Vector3(0.41, 0.32, 0.10), accent_material)
                tablet.rotation.z = -0.15
        4:
            # Lava cliffs, black rock ridges and volcanic spires.
            if variant % 2 == 0:
                _mountain(parent, at, h * 2.2, 1.5)
            _spike(parent, at, h * 1.2, 0.48, rock_material)
            _block(parent, at + Vector3(float(side) * 0.36, 0.02, 0.44), Vector3(0.82, 0.035, 1.05), accent_material)

func _room_floor(parent: Node3D, center: Vector3, room_id: int) -> void:
    # Uneven 22-segment silhouette eliminates identical square arena footprints.
    # Low-cost mesh, no colliders: autonomous walking remains on the central aisle.
    var mesh_builder := SurfaceTool.new()
    mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rim := PackedVector3Array()
    var count: int = 22
    var room_shape: int = posmod(current_stage + room_id, 5)
    var room_width: float = 5.6 + float((current_stage + room_id) % 3) * 0.45
    var room_depth: float = 5.8 + float((room_id + current_stage) % 4) * 0.31
    for j in range(count):
        var angle: float = TAU * float(j) / float(count)
        var jagged: float = randomizer.randf_range(0.94, 1.06)
        var width_scale: float = 1.0
        var depth_scale: float = 1.0
        match room_shape:
            0: # circular subterranean chapel
                width_scale = 1.06
            1: # narrow longitudinal shrine
                width_scale = 0.84
                depth_scale = 1.18
            2: # asymmetric cavern with a wider southern bay
                width_scale = 0.95 + 0.16 * sin(angle)
            3: # broken star chamber
                width_scale = 0.95 + 0.10 * sin(angle * 5.0)
                depth_scale = 0.97 + 0.08 * sin(angle * 5.0)
            4: # wide combat courtyard
                width_scale = 1.24
                depth_scale = 0.90
        rim.append(Vector3(cos(angle) * room_width * jagged * width_scale, -0.16, sin(angle) * room_depth * jagged * depth_scale))
    var middle := Vector3(0.0, -0.16, 0.0)
    for j in range(count):
        var a: Vector3 = rim[j]
        var b: Vector3 = rim[(j + 1) % count]
        for vertex in [middle, b, a]:
            mesh_builder.set_uv(Vector2(vertex.x * 0.31, vertex.z * 0.31))
            mesh_builder.add_vertex(vertex)
    mesh_builder.generate_normals()
    var platform := MeshInstance3D.new()
    platform.name = "IrregularFloor_%d" % room_id
    platform.set_meta("room_shape", room_shape)
    platform.mesh = mesh_builder.commit()
    platform.material_override = floor_material
    platform.position = center
    parent.add_child(platform)
    # A stone lip creates physical edges and visible differences in elevation.
    for j in range(0, count, 2):
        var a: Vector3 = rim[j]
        var b: Vector3 = rim[(j + 1) % count]
        var difference: Vector3 = b - a
        var ledge := _block(parent, center + (a + b) * 0.5 + Vector3(0, -0.22, 0), Vector3(0.21, 0.36, difference.length()), rock_material)
        ledge.rotation.y = atan2(difference.x, difference.z) + PI * 0.5


func _weather_particles(parent: Node3D, center: Vector3, area_index: int) -> void:
    # Two light emitters per scene: leaves/snow/ashes/void motes. The particle
    # budget remains bounded on GLES3 mobile and avoids expensive GPU fog.
    if area_index % 2 != 0:
        return
    var weather := CPUParticles3D.new()
    weather.name = "Atmosphere_%d" % area_index
    weather.position = center + Vector3(0, 5.2, 0)
    weather.amount = 22
    weather.lifetime = 5.0
    weather.preprocess = 2.0
    weather.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    weather.emission_box_extents = Vector3(7.0, 1.9, 6.8)
    weather.direction = Vector3(0, -1, 0) if current_theme == 1 or current_theme == 2 else Vector3(0, 1, 0)
    weather.spread = 35
    weather.gravity = Vector3(0, -0.35, 0) if current_theme == 1 else Vector3(0, 0.15, 0)
    weather.initial_velocity_min = 0.12
    weather.initial_velocity_max = 0.58
    weather.scale_amount_min = 0.02
    weather.scale_amount_max = 0.05
    weather.color = [Color("ba8c76", 0.6), Color("d6f1ff", 0.83), Color("9cb272", 0.75), Color("c28cf6", 0.7), Color("ffa15e", 0.7)][current_theme]
    var sparkle := SphereMesh.new()
    sparkle.radius = 0.06
    sparkle.height = 0.13
    weather.mesh = sparkle
    weather.emitting = true
    parent.add_child(weather)


func _surface_story(parent: Node3D, center: Vector3, room_id: int) -> void:
    # Worn paving stones and fractures. Previously every room was covered
    # in identical fluorescent rings and matchstick-like luminous shards.
    var grout := _solid(Color("27282a") if current_theme == 3 else Color("33343a"))
    var chipped := _solid(Color("58534d") if current_theme == 3 else Color("4c4947"))
    for i in range(12):
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var p: Vector3 = center + Vector3(side * randomizer.randf_range(3.2, 5.1),
            0.028, randomizer.randf_range(-4.7, 4.7))
        if i % 4 == 0:
            _stone(parent, p, Vector3(randomizer.randf_range(0.35, 0.7),
                randomizer.randf_range(0.16, 0.29),
                randomizer.randf_range(0.45, 0.90)), rock_material)
        else:
            var crack := _block(parent, p, Vector3(randomizer.randf_range(0.27, 0.95),
                0.014, randomizer.randf_range(0.035, 0.075)),
                chipped if i % 3 == 0 else grout)
            crack.rotation.y = randomizer.randf_range(-PI, PI)
    if room_id == 3 and current_stage % 10 == 0:
        var rim := TorusMesh.new()
        rim.inner_radius = 2.65
        rim.outer_radius = 2.74
        rim.rings = 48
        rim.ring_segments = 7
        var glyph := MeshInstance3D.new()
        glyph.name = "BossRitualInlay"
        glyph.mesh = rim
        glyph.position = center + Vector3(0, 0.015, -0.95)
        glyph.material_override = chipped
        parent.add_child(glyph)


func _biome_beacon(parent: Node3D, center: Vector3, room_id: int) -> void:
    # Two small pool lights per level produce alternating warm/cool contrast
    # on actual stone and cliffs. Lights are unshadowed, short-range and only
    # affect nearby props; unlike full-scene fog/shadows this is mobile-friendly.
    if room_id % 2 != 0:
        return
    var side: float = -1.0 if room_id == 0 else 1.0
    var at: Vector3 = center + Vector3(side * 4.75, 0.0, -2.45)
    _column(parent, at, 1.12, 0.28, rock_material, 6)
    _stone(parent, at + Vector3(0, 1.07, 0), Vector3(0.57, 0.25, 0.57), rock_material)
    _spike(parent, at + Vector3(0, 1.18, 0), 0.64, 0.19, accent_material)
    var glow := OmniLight3D.new()
    glow.name = "WorldLight_%d" % room_id
    glow.position = at + Vector3(0, 1.65, 0)
    glow.light_color = Color("ffca8b") if current_theme == 3 else Color(ACCENTS[current_theme]).lerp(Color("f1dcc3"), 0.36)
    glow.light_energy = 1.05 if current_theme == 3 else 0.72
    glow.omni_range = 8.0
    glow.shadow_enabled = false
    parent.add_child(glow)


func _boss_sanctum(parent: Node3D, center: Vector3) -> void:
    # A distinct final arena for each biome, not three ordinary mob rooms.
    var boss_stage := Node3D.new()
    boss_stage.name = "BossSanctum_%d" % current_theme
    parent.add_child(boss_stage)
    _column(boss_stage, center + Vector3(0, -0.26, -0.8), 0.45, 3.75, rock_material, 14)
    var ritual := TorusMesh.new()
    ritual.inner_radius = 3.20
    ritual.outer_radius = 3.29
    var halo := MeshInstance3D.new()
    halo.mesh = ritual
    halo.material_override = accent_material
    halo.position = center + Vector3(0, 0.06, -0.8)
    boss_stage.add_child(halo)
    for pylon in range(6):
        var angle: float = TAU * float(pylon) / 6.0
        var anchor: Vector3 = center + Vector3(cos(angle) * 4.5, 0.0, -0.8 + sin(angle) * 4.5)
        match current_theme:
            0:
                _column(boss_stage, anchor, 3.4, 0.56, rock_material)
                _spike(boss_stage, anchor + Vector3(0, 3.2, 0), 0.85, 0.33, accent_material)
            1:
                _spike(boss_stage, anchor, 4.3, 0.92, rock_material)
                _spike(boss_stage, anchor + Vector3(0.35, 0, 0.15), 2.35, 0.48, accent_material)
            2:
                _tree(boss_stage, anchor)
                _block(boss_stage, anchor + Vector3(0, 0.16, 0), Vector3(1.6, 0.26, 0.43), rock_material)
            3:
                _column(boss_stage, anchor, 4.4, 0.58, rock_material, 4)
                _spike(boss_stage, anchor + Vector3(0, 4.1, 0), 1.05, 0.25, accent_material)
            4:
                _mountain(boss_stage, anchor, 3.7, 1.1)
                _spike(boss_stage, anchor + Vector3(0, 2.3, 0), 2.2, 0.25, accent_material)
    var beacon := OmniLight3D.new()
    beacon.name = "BossArenaGlow"
    beacon.position = center + Vector3(0, 3.7, -0.8)
    beacon.light_color = Color(ACCENTS[current_theme])
    beacon.light_energy = 1.35
    beacon.omni_range = 10.2
    beacon.shadow_enabled = false
    boss_stage.add_child(beacon)


func _terrain_height(noise: FastNoiseLite, x: float, z: float) -> float:
    # Keep the walkable aisle clear and lift the surrounding countryside into
    # ridges and ravines. Nothing on the auto-path ever changes elevation.
    var separation: float = smoothstep(6.0, 15.0, absf(x))
    var rolling: float = absf(noise.get_noise_2d(x, z))
    var cliff: float = maxf(0.0, noise.get_noise_2d(x + 83.0, z - 29.0))
    var stratification: float = sin(z * 0.19 + x * 0.43) * 0.22
    var height_scale: float = [0.80, 1.40, 0.93, 1.35, 1.80][current_theme]
    return -0.49 + separation * (0.28 + (rolling * 1.45 + cliff * 1.5 + stratification) * height_scale)


func _build_exterior_terrain(parent: Node3D) -> void:
    # ~1,700 triangles per side: true height variation with smooth normals,
    # biome PBR, and no per-cell draw calls. Ground is above the distant flat
    # undersurface but remains below all playable chambers and corridors.
    var noise := FastNoiseLite.new()
    noise.seed = current_stage * 4703 + 321
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.085
    var earth := floor_material.duplicate() as StandardMaterial3D
    earth.vertex_color_use_as_albedo = true
    earth.albedo_color = [
        Color("6e676a"), Color("c0d8e3"), Color("526b51"),
        Color("99958c"), Color("75676a")
    ][current_theme]
    earth.uv1_scale = Vector3(2.0, 2.0, 1.0)
    var x_steps: int = 11
    var z_steps: int = 37
    var dx: float = 2.0
    var dz: float = 2.5
    for side in range(2):
        var x_begin: float = -28.0 if side == 0 else 6.0
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        for zi in range(z_steps):
            var z0: float = -74.0 + float(zi) * dz
            var z1: float = z0 + dz
            for xi in range(x_steps):
                var x0: float = x_begin + float(xi) * dx
                var x1: float = x0 + dx
                var a := Vector3(x0, _terrain_height(noise, x0, z0), z0)
                var b := Vector3(x1, _terrain_height(noise, x1, z0), z0)
                var c := Vector3(x0, _terrain_height(noise, x0, z1), z1)
                var d := Vector3(x1, _terrain_height(noise, x1, z1), z1)
                # Winding faces upward for both the left and right terrain.
                for vertex in [a, c, b, b, c, d]:
                    var shade: float = clampf(
                        0.89 + 0.16 * noise.get_noise_2d(vertex.x * 5.0, vertex.z * 5.0),
                        0.75, 1.05
                    )
                    surface.set_color(Color(shade, shade, shade))
                    surface.set_uv(Vector2(vertex.x * 0.18, vertex.z * 0.18))
                    surface.add_vertex(vertex)
        surface.generate_normals()
        var bank := MeshInstance3D.new()
        bank.name = "TerrainBank_Left" if side == 0 else "TerrainBank_Right"
        bank.mesh = surface.commit()
        bank.material_override = earth
        bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(bank)


func _terrain_texture() -> ImageTexture:
    # Deterministic rock, snow, leaf-litter, void and lava texture variants.
    # Lightweight CPU noise replaces featureless solid-color floors on Android.
    var dark_colors := ["22232b", "5d7482", "233927", "2e2d30", "3a1c1c"]
    var light_colors := ["68636a", "aecfdb", "536f45", "726b66", "9b5536"]
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
    # Physically-based 1k photographic textures from Poly Haven, CC0.
    # Fallback terrain generation is retained for offline development.
    var keys: Array = ["stone_floor", "snow_02", "forrest_ground_01", "rock_face_03", "volcanic_rock_tiles"]
    var key: String = str(keys[current_theme])
    floor_material = _solid(Color(FLOOR_COLORS[current_theme]))
    floor_material.uv1_scale = Vector3(2.1, 2.1, 1.0)
    var diffuse_path: String = "res://assets/pbr/%s_diff_1k.jpg" % key
    if ResourceLoader.exists(diffuse_path):
        floor_material.albedo_texture = load(diffuse_path)
        floor_material.albedo_color = [Color("919eaf"), Color("8da5b8"), Color("84997b"), Color("b9b5a9"), Color("857981")][current_theme]
    else:
        floor_material.albedo_texture = _terrain_texture()
        floor_material.albedo_color = Color("c0c5c5")
    var normal_path: String = "res://assets/pbr/%s_nor_gl_1k.jpg" % key
    if ResourceLoader.exists(normal_path):
        floor_material.normal_enabled = true
        floor_material.normal_scale = 1.35
        floor_material.normal_texture = load(normal_path)
    var rough_path: String = "res://assets/pbr/%s_rough_1k.jpg" % key
    if ResourceLoader.exists(rough_path):
        floor_material.roughness_texture = load(rough_path)
    floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    floor_material.roughness = 0.82 if current_theme == 1 else 0.88
    rock_material = _solid(Color(ROCKS[current_theme]))
    rock_material.uv1_scale = Vector3(2.7, 2.7, 1.0)
    var cliff_key: String = "rock_face_03" if current_theme != 4 else "volcanic_rock_tiles"
    var cliff_path: String = "res://assets/pbr/%s_diff_1k.jpg" % cliff_key
    if ResourceLoader.exists(cliff_path):
        rock_material.albedo_texture = load(cliff_path)
        rock_material.albedo_color = [Color("596477"), Color("748ea3"), Color("536d55"), Color("ada8a0"), Color("544b52")][current_theme]
        var cliff_normal: String = "res://assets/pbr/%s_nor_gl_1k.jpg" % cliff_key
        if ResourceLoader.exists(cliff_normal):
            rock_material.normal_enabled = true
            rock_material.normal_texture = load(cliff_normal)
    # Nonemissive stone and muted inlaid metal replace neon purple rubble.
    accent_material = _solid(Color(ACCENTS[current_theme]), current_theme != 3)
    if current_theme == 3:
        accent_material.roughness = 0.69
        accent_material.metallic = 0.24

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
            # Do not put a full roof beam in front of the mobile camera:
            # two ruined pillars frame the lane without hiding hero/enemies.
            for side in [-1.0, 1.0]:
                var support: Vector3 = at + Vector3(side * 4.15, 0, 3.8)
                _column(parent, support, randomizer.randf_range(2.3, 3.3), 0.33, rock_material)
                _stone(parent, support + Vector3(side * 0.39, 0.22, 0),
                    Vector3(1.1, 0.60, 1.52), rock_material)
                if current_theme == 3:
                    _stone(parent, support + Vector3(side * 0.71, -0.05, 0.8),
                        Vector3(1.0, 0.36, 1.0), rock_material)
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

func _landmark(parent: Node3D, room: Vector3, index: int) -> void:
    # Different focal structures on each floor create silhouettes that remain
    # distinguishable at phone scale, without placing walls in the walk lane.
    var side: float = -1.0 if index % 2 == 0 else 1.0
    var at: Vector3 = room + Vector3(side * 5.95, 0.0, -1.55)
    var structure := Node3D.new()
    structure.name = "BiomeLandmark_%d" % index
    parent.add_child(structure)
    landmark_count += 1
    match current_theme:
        0: # Collapsed crypt chapel, arch and burnt pedestal.
            for column in range(3):
                var p := at + Vector3(0, 0, float(column - 1) * 1.45)
                _column(structure, p, randomizer.randf_range(2.0, 3.8), 0.32, rock_material)
                _block(structure, p + Vector3(0.0, 2.5, 0.0), Vector3(0.88, 0.30, 0.87), floor_material)
            _block(structure, at + Vector3(0.42 * side, 0.35, 2.05), Vector3(2.15, 0.7, 0.90), rock_material)
            _spike(structure, at + Vector3(0, 0, 2.05), 1.20, 0.20, accent_material)
        1: # Uneven glacial outcrop with cut faces and tall crystal spires.
            _mountain(structure, at + Vector3(side * 1.2, -0.05, 0), 7.0 + float(index), 3.15)
            for shard in range(6):
                var offset := at + Vector3(randomizer.randf_range(-2.1, 2.2), 0.0, randomizer.randf_range(-1.4, 1.5))
                _spike(structure, offset, randomizer.randf_range(1.8, 4.8), randomizer.randf_range(0.24, 0.49), accent_material if shard % 3 == 0 else rock_material)
        2: # Interwoven grove and fallen trunk at the woodland edge.
            for tree_index in range(3):
                _tree(structure, at + Vector3(side * float(tree_index) * 1.4, 0.0, float(tree_index - 1) * 2.0))
            var fallen := _block(structure, at + Vector3(0.0, 0.21, 1.5), Vector3(3.5, 0.36, 0.38), rock_material)
            fallen.rotation.y = 0.44
            for root_index in range(4):
                var root := _block(structure, at + Vector3(float(root_index - 2) * 0.63, 0.04, 2.50), Vector3(0.14, 0.14, 1.1), rock_material)
                root.rotation.y = float(root_index) * 0.4
        3: # Ruined fortified shrine with toppled capitals and rocky bases.
            _column(structure, at, 1.35, 1.47, rock_material, 10)
            _stone(structure, at + Vector3(0, 1.2, 0), Vector3(2.5, 0.65, 2.1), rock_material)
            for obelisk in range(5):
                var angle: float = float(obelisk) * TAU / 5.0
                var point := at + Vector3(cos(angle) * 2.1, 0, sin(angle) * 1.8)
                var tower := _column(structure, point, 2.2 + float(obelisk % 3) * 0.95, 0.42, rock_material, 7)
                tower.rotation.z = 0.14 * sin(angle)
                _stone(structure, point + Vector3(0.42, 0.05, 0),
                    Vector3(1.25, 0.50, 1.08), rock_material)
                if obelisk % 2 == 0:
                    _block(structure, point + Vector3(0, 1.96, 0.25),
                        Vector3(0.43, 0.18, 0.16), accent_material)
            _spike(structure, at + Vector3(0, 1.47, 0), 2.4, 0.55, rock_material)
        4: # Volcanic cliff shelf, magma seams, stacked dark basalt columns.
            _mountain(structure, at + Vector3(side, -0.10, 0), 6.5, 3.6)
            for spike_i in range(5):
                var p := at + Vector3(float(spike_i - 2) * 0.78, 0, randomizer.randf_range(-1.3, 1.3))
                _column(structure, p, randomizer.randf_range(1.6, 4.5), 0.45, rock_material, 6)
                if spike_i % 2 == 0:
                    _block(structure, p + Vector3(0.3, 0.12, 0.0), Vector3(0.16, 0.08, 1.8), accent_material)


func generate(floor_number: int) -> PackedVector3Array:
    current_stage = maxi(1, floor_number)
    box_batch_count = 0
    unbatched_box_count = 0
    _material_cache.clear()
    if _unit_boulder == null:
        _unit_boulder = _build_boulder_mesh()
    _unit_spike.bottom_radius = 1.0
    _unit_spike.top_radius = 0.04
    _unit_spike.height = 1.0
    _unit_spike.radial_segments = 5
    _unit_foliage.bottom_radius = 0.95
    _unit_foliage.top_radius = 0.08
    _unit_foliage.height = 1.0
    _unit_foliage.radial_segments = 11
    _unit_foliage.rings = 2
    landmark_count = 0
    route_style = (current_stage - 1) % 5
    current_theme = posmod(int((current_stage - 1) / 10), THEMES.size())
    randomizer.seed = 7919 + current_stage * 15427
    for child in get_children():
        remove_child(child)
        child.queue_free()
    _set_materials()
    # Surround the playable route with biome-specific terrain, not an empty
    # black skybox. Landscapes need to occupy the whole portrait view.
    var terrain_colors := ["26303c", "273d4b", "152b1b", "1a142a", "2d1110"]
    var terrain := _solid(Color(terrain_colors[current_theme]))
    terrain.albedo_texture = floor_material.albedo_texture
    terrain.albedo_color = [Color("454f5a"), Color("7d91a9"), Color("485c49"), Color("a19d95"), Color("534348")][current_theme]
    terrain.uv1_scale = Vector3(11, 11, 1)
    terrain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _block(self, Vector3(0, -0.58, -18.0), Vector3(48, 0.40, 88), terrain)
    var exterior := Node3D.new()
    exterior.name = "ExteriorTerrain"
    add_child(exterior)
    _build_exterior_terrain(exterior)
    walk_points = PackedVector3Array()
    var variation: float = float((current_stage - 1) % 10)
    walk_points.append(Vector3(0, 0, 5))
    var drift: float = 0.0
    for i in range(1, 4):
        # A room may veer or snake; the same dungeon theme does not mean the
        # same hallway shape for 10 consecutive floors.
        var bend: float = sin(float(current_stage) * 1.719 + float(i) * 1.43) * (1.85 + float(route_style) * 0.33)
        drift = clampf(drift * 0.62 + bend, -4.4, 4.4)
        var shift: float = drift + randomizer.randf_range(-0.65, 0.65)
        walk_points.append(Vector3(shift, 0, 5.0 - DISTANCE * float(i) - variation * 0.22 * float(i)))

    # Each stage is a long traversable chain of chambers linked by real corridors.
    for i in range(walk_points.size()):
        var room := Node3D.new()
        room.name = "Chamber_%d" % i
        add_child(room)
        var p: Vector3 = walk_points[i]
        _room_floor(room, p, i)
        _surface_story(room, p, i)
        _biome_beacon(room, p, i)
        _weather_particles(room, p, i)
        for side in [-1.0, 1.0]:
            if current_theme != 2:
                var wall: Vector3 = p + Vector3(side * 5.4, 0.7, 0)
                # Irregular broken wall sections with visible gaps instead of
                # continuous rectangular slabs on every floor.
                for panel in range(4):
                    var span: float = 2.1 + randomizer.randf_range(-0.15, 0.22)
                    var p_wall: Vector3 = wall + Vector3(randomizer.randf_range(-0.25, 0.25), 0, -3.65 + float(panel) * 2.45)
                    var fragment := _block(room, p_wall, Vector3(0.62, randomizer.randf_range(0.8, 2.25), span), rock_material)
                    fragment.rotation.y = randomizer.randf_range(-0.12, 0.12)
                    # Rough fractured caps and fallen masonry break the straight
                    # cartoon-box silhouette without expensive individual meshes.
                    _stone(room, p_wall + Vector3(0.1, fragment.scale.y * 0.48, 0), Vector3(0.83, 0.42, span * 0.52), rock_material)
                    _stone(room, p_wall + Vector3(side * 0.64, -0.09, 0.35), Vector3(0.77, 0.31, 0.89), rock_material)
        _decorate(room, p, i + (current_stage % 10))
        _ground_details(room, p)
        if i > 0:
            _landmark(room, p, i)
        if i > 0:
            _connect(room, walk_points[i-1] + Vector3(0, 0, -4.3), p + Vector3(0, 0, 4.3), 4.75, floor_material)
        if i == 3 and current_stage % 10 == 0:
            _boss_sanctum(room, p)
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
    for i in range(36):
        var z: float = randomizer.randf_range(-47.0, 12.0)
        var x: float = randomizer.randf_range(-18.0, 18.0)
        var close_to_route := false
        for point in walk_points:
            if absf(z - point.z) < 7.2 and absf(x - point.x) < 6.1:
                close_to_route = true
                break
        if close_to_route:
            continue
        var place := Vector3(x, -0.32, z)
        _feature(wilderness, place, 1 if x > 0 else -1, i)
        if i % 2 == 0:
            _stone(wilderness, place + Vector3(randomizer.randf_range(-1.4, 1.4), 0.15, randomizer.randf_range(-0.9, 0.9)), Vector3(randomizer.randf_range(0.55, 1.45), randomizer.randf_range(0.45, 1.10), randomizer.randf_range(0.5, 1.35)), rock_material)
    # Silhouettes of large ridgelines occupy the distance: mountains are actual
    # 3D geometry, with height, slope and light catching the cliff faces.
    var far_ridges := Node3D.new()
    far_ridges.name = "MountainHorizon"
    add_child(far_ridges)
    for side in [-1.0, 1.0]:
        for r in range(7):
            var z: float = 8.0 - float(r) * 9.2
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
    var exit_gate := Node3D.new()
    exit_gate.name = "ExitGate"
    add_child(exit_gate)
    var end_position: Vector3 = walk_points[3] + Vector3(0, 0, -4.05)
    _arch(exit_gate, end_position, rock_material)
    var exit_core := _column(exit_gate, end_position + Vector3(0, 0.0, -0.2), 0.05, 1.45, accent_material, 16)
    exit_core.name = "RiftGate"
    # Thousands of static stage blocks are now rendered through a few
    # MultiMesh batches rather than separate draw calls per cube.
    _batch_static_boxes()
    # This exit marks the destination; gameplay advances only after combat.
    return walk_points
