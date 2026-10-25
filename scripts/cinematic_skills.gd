extends Node3D
# Procedural dark-fantasy skill choreography inspired by the supplied video:
# telegraph -> surge/projectile -> impact -> lingering cracks and sigils.
# All geometry is generated locally (no internet, no borrowed game art).
# Short lifetimes, unshadowed meshes and a strict active-instance limit keep
# it suitable for Android's portrait rendering pipeline.

const MAX_EFFECTS := 125
const PALETTE := [
    [Color("ff7a36"), Color("ffb255"), Color("b51b19")],
    [Color("93dd69"), Color("9fefff"), Color("e7c77a")],
    [Color("ec8153"), Color("98ddff"), Color("dcb3ff")],
    [Color("ad4355"), Color("7950a2"), Color("b42c4d")]
]
var effects: Array = []
var elapsed := 0.0
var sparks_total := 0
var total_casts := 0
var randomizer := RandomNumberGenerator.new()
var haze_texture: ImageTexture
# Timed, class-specific attack beats. No 4-color version of one generic nova.
var signature_cues: Array = []
var signature_casts: Dictionary = {"inferno": 0, "arrowfall": 0, "chain_lightning": 0, "nightfall": 0}
var hammer_basic_casts := 0
var hammer_basic_impacts := 0

func _ready() -> void:
    randomizer.seed = 41773
    # Procedural feathered ash/fog, rather than a flat translucent plane.
    var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
    for y in range(96):
        for x in range(96):
            var rel := Vector2(float(x) - 47.5, float(y) - 47.5) / 47.5
            var distance: float = rel.length()
            var swirls: float = 0.56 + 0.25 * sin(rel.x * 14.0 + rel.y * 7.0) * sin(rel.y * 12.0 - rel.x * 4.0)
            var alpha: float = pow(maxf(0.0, 1.0 - distance), 1.5) * swirls
            image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
    haze_texture = ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
    elapsed += delta
    for cue_index in range(signature_cues.size() - 1, -1, -1):
        var cue: Dictionary = signature_cues[cue_index]
        if float(cue["at"]) <= elapsed:
            signature_cues.remove_at(cue_index)
            _play_signature_beat(cue)
    for i in range(effects.size() - 1, -1, -1):
        var effect: Dictionary = effects[i]
        var node: MeshInstance3D = effect["node"] as MeshInstance3D
        if not is_instance_valid(node):
            effects.remove_at(i)
            continue
        effect["age"] = float(effect["age"]) + delta
        var duration: float = float(effect["duration"])
        var t: float = clampf(float(effect["age"]) / maxf(0.01, duration), 0.0, 1.0)
        var kind: String = str(effect["kind"])
        if kind == "charge":
            node.scale = Vector3.ONE * (0.3 + 0.73 * sin(minf(1.0, t * 1.14) * PI * 0.5))
            node.rotation.y += delta * 0.33
        elif kind == "shock":
            node.scale = Vector3.ONE * (0.46 + 1.72 * t)
        elif kind == "firefront":
            node.scale = Vector3.ONE * (0.55 + 1.32 * t)
        elif kind == "flame_column":
            node.scale = Vector3(0.70 + 0.65 * t, 0.65 + 0.95 * sin(t * PI), 0.70 + 0.65 * t)
            node.position.y += delta * 0.32
        elif kind == "fissure":
            node.scale = Vector3.ONE * (0.73 + 0.32 * minf(1.0, t * 4.0))
        elif kind == "beam":
            node.scale = Vector3.ONE * (0.90 + 0.25 * sin(t * PI))
        elif kind == "rune":
            node.scale = Vector3.ONE * (0.86 + 0.16 * sin(t * PI))
            node.rotation.y += delta * 0.09
        elif kind == "orb":
            node.scale = Vector3.ONE * (0.42 + 0.90 * sin(minf(t * 1.35, 1.0) * PI * 0.5))
            node.position.y += delta * 0.30
        elif kind == "smoke":
            node.scale = Vector3.ONE * (0.74 + 0.58 * t)
            node.rotation.y += delta * 0.24
        if kind == "travel":
            var origin: Vector3 = effect["from"]
            var destination: Vector3 = effect["to"]
            var travel_t: float = 1.0 - pow(1.0 - t, 2.1)
            node.position = origin.lerp(destination, travel_t)
            node.scale = Vector3.ONE * (0.75 + 0.45 * sin(t * PI))
        var opacity: float = 1.0 - pow(t, 2.0)
        if kind == "charge":
            opacity = minf(1.0, (1.0 - t) * 2.6)
        var material: StandardMaterial3D = node.material_override as StandardMaterial3D
        if material != null:
            var tint: Color = effect["color"]
            tint.a = float(effect["alpha"]) * opacity
            material.albedo_color = tint
        if t >= 1.0:
            if kind == "travel":
                # A projectile finishes at the actual enemy location with a
                # small flash (not a persistent screen-filling laser).
                var at: Vector3 = effect["to"]
                _ring(at, 0.35, 0.075, effect["color"], 0.24, "shock", 0.63)
                _embers(at, effect["color"], 3)
            node.queue_free()
            effects.remove_at(i)

func _material(color: Color, alpha: float = 0.85, additive: bool = true) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mat.albedo_color = Color(color.r, color.g, color.b, alpha)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 0.68 if additive else 0.06
    return mat

func _spawn(mesh: Mesh, at: Vector3, color: Color, alpha: float,
        lifetime: float, behavior: String = "fissure", additive: bool = true) -> MeshInstance3D:
    if effects.size() >= MAX_EFFECTS:
        return null
    var body := MeshInstance3D.new()
    body.mesh = mesh
    body.material_override = _material(color, alpha, additive)
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    body.position = at
    add_child(body)
    effects.append({"node": body, "duration": lifetime, "age": 0.0,
        "kind": behavior, "color": color, "alpha": alpha})
    return body

func _smoke(at: Vector3, extent: float, duration: float = 1.4) -> void:
    var shape := PlaneMesh.new()
    shape.size = Vector2(extent, extent)
    var plume := _spawn(shape, at + Vector3(0, 0.18, 0),
        Color("0c0715"), 0.91, duration, "smoke", false)
    if plume != null:
        var mat: StandardMaterial3D = plume.material_override as StandardMaterial3D
        mat.albedo_texture = haze_texture
        mat.emission_enabled = false
        plume.rotation.y = randomizer.randf_range(0.0, TAU)


func _stroke(tool: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
    var along := b - a
    along.y = 0
    if along.length_squared() < 0.00001:
        return
    var lateral := Vector3(-along.z, 0, along.x).normalized() * width * 0.5
    for point in [a - lateral, a + lateral, b - lateral,
        b - lateral, a + lateral, b + lateral]:
        tool.set_uv(Vector2(point.x * 0.23, point.z * 0.23))
        tool.add_vertex(point)

func _mesh_from_strokes(paths: Array, width: float) -> Mesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for segment in paths:
        _stroke(tool, segment[0], segment[1], float(segment[2]) if segment.size() > 2 else width)
    tool.generate_normals()
    return tool.commit()

func _ring(at: Vector3, radius: float, width: float, tint: Color,
        duration: float, style: String = "shock", alpha: float = 0.76) -> void:
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius - width
    mesh.outer_radius = radius
    # Major-ring subdivisions, not tube subdivisions. Four rings created a
    # giant bright DIAMOND instead of a circular shockwave on Godot.
    mesh.rings = 64
    mesh.ring_segments = 8
    var node := _spawn(mesh, at + Vector3(0, 0.105, 0), tint, alpha, duration, style)
    if node != null and style == "shock":
        node.scale = Vector3.ONE * 0.46

func _fire_wave(at: Vector3, radius: float, lifetime: float = 0.54) -> void:
    # Radial, multi-height tongues: unlike a flat luminous torus this has
    # visible silhouette and height from a portrait isometric camera.
    # All 32 flames share one low-poly ArrayMesh (one draw call per layer).
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(32):
        var angle: float = TAU * float(i) / 32.0
        var outward := Vector3(cos(angle), 0, sin(angle))
        var tangent := Vector3(-sin(angle), 0, cos(angle))
        var width: float = 0.16 + 0.025 * float(i % 4)
        var base: Vector3 = outward * radius
        var a: Vector3 = base - tangent * width
        var b: Vector3 = base + tangent * width
        var c: Vector3 = base + outward * (0.15 + 0.03 * float(i % 5))
        c.y = 0.60 + 0.11 * float(i % 4)
        for vertex in [a, b, c]:
            tool.add_vertex(vertex)
    tool.generate_normals()
    var mesh: Mesh = tool.commit()
    if mesh == null:
        return
    var flame := _spawn(mesh, at + Vector3(0, 0.20, 0),
        Color("ff8324"), 0.94, lifetime, "shock")
    if flame != null:
        flame.scale = Vector3.ONE * 0.46



func _inferno_fan(at: Vector3, radius: float, duration: float) -> void:
    # One contiguous double-sided triangle mesh for a full fire-front,
    # replacing individual tooth-like orange shards.
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(48):
        var angle: float = TAU * float(i) / 48.0
        var next_angle: float = TAU * float(i + 1) / 48.0
        var wave: float = 0.22 * sin(float(i) * 2.45)
        var tip_height: float = 0.75 + 0.35 * sin(float(i) * 1.91)
        var inner_a := Vector3(cos(angle) * radius * 0.72, 0.10, sin(angle) * radius * 0.72)
        var inner_b := Vector3(cos(next_angle) * radius * 0.72, 0.10, sin(next_angle) * radius * 0.72)
        var peak := Vector3(cos(angle + 0.045) * (radius + wave),
            tip_height, sin(angle + 0.045) * (radius + wave))
        for point in [inner_a, inner_b, peak]:
            tool.add_vertex(point)
    var mesh: Mesh = tool.commit()
    if mesh == null:
        return
    var tongue: MeshInstance3D = _spawn(mesh, at + Vector3(0, 0.10, 0),
        Color("ffad39"), 0.90, duration, "firefront")
    if tongue != null:
        tongue.scale = Vector3.ONE * 0.34


func _inferno_columns(at: Vector3, count: int, spread: float) -> void:
    # Fire tongues are tapered volumes, not flat floor decals.
    # Reuse a small number of unshadowed meshes to protect mobile fill rate.
    for i in range(count):
        if effects.size() >= MAX_EFFECTS - 3:
            break
        var theta: float = TAU * float(i) / float(count)
        var distance: float = spread * (0.55 + 0.34 * float(i % 3) / 2.0)
        var point := at + Vector3(cos(theta) * distance, 0.33, sin(theta) * distance)
        var flame := CylinderMesh.new()
        flame.top_radius = 0.035
        flame.bottom_radius = 0.17 + 0.055 * float(i % 3)
        flame.height = 1.2 + 0.36 * float(i % 4)
        flame.radial_segments = 7
        var tint: Color = Color("ffde76") if i % 3 == 0 else Color("ff6a1d")
        var node := _spawn(flame, point + Vector3(0, flame.height * 0.5, 0),
            tint, 0.88, 0.65 + 0.07 * float(i % 3), "flame_column")
        if node != null:
            node.rotation.z = 0.12 * cos(theta)
            node.rotation.x = 0.12 * sin(theta)


func _inferno_impact(at: Vector3) -> void:
    # Silhouette, incandescent core and darker smoke have distinct roles.
    # Three separated heights and a hot center make Inferno readable
    # through the zoomed-out Android camera, not only in an FX close-up.
    _inferno_fan(at, 2.65, 0.82)
    _inferno_fan(at + Vector3(0, 0.22, 0), 3.2, 0.70)
    _inferno_columns(at, 10, 2.1)
    _ring(at, 1.10, 0.26, Color("fff3c8"), 0.20, "shock", 0.95)
    _ring(at, 1.75, 0.30, Color("ff6a16"), 0.60, "shock", 0.84)
    _smoke(at, 3.2, 1.2)
    _embers(at + Vector3(0, 0.35, 0), Color("ffbd50"), 15)

func _beam(a: Vector3, b: Vector3, width: float, tint: Color,
        duration: float = 0.30, alpha: float = 0.94) -> void:
    if a.distance_squared_to(b) < 0.004:
        return
    var body := CylinderMesh.new()
    body.top_radius = width * 0.54
    body.bottom_radius = width
    body.height = a.distance_to(b)
    body.radial_segments = 5
    var node := _spawn(body, (a + b) * 0.5, tint, alpha, duration, "beam")
    if node != null:
        node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _bolts(origin: Vector3, destination: Vector3, tint: Color, forks: int = 3) -> void:
    var start := origin
    var axis: Vector3 = destination - origin
    var sideways: Vector3 = axis.cross(Vector3.UP).normalized()
    if sideways.length_squared() < 0.01:
        sideways = Vector3.RIGHT
    for j in range(6):
        var fraction: float = float(j + 1) / 6.0
        var finish: Vector3 = origin.lerp(destination, fraction)
        if j < 5:
            finish += sideways * randomizer.randf_range(-0.21, 0.21)
        _beam(start, finish, 0.060 if j % 2 == 0 else 0.035, tint, 0.23)
        start = finish
    for branch in range(mini(forks, 4)):
        var fork_origin: Vector3 = origin.lerp(destination, 0.22 + 0.17 * float(branch))
        var fork_end := fork_origin + Vector3(
            randomizer.randf_range(-0.65, 0.65),
            randomizer.randf_range(-0.55, 0.6),
            randomizer.randf_range(-0.65, 0.65))
        _beam(fork_origin, fork_end, 0.024, tint.lightened(0.44), 0.16)

func _sigil(center: Vector3, radius: float, tint: Color,
        lifetime: float = 1.25, markings: int = 24) -> void:
    var paths: Array = []
    var circles := [radius, radius * 0.78, radius * 0.47]
    for r in circles:
        for i in range(48):
            var a: float = TAU * float(i) / 48.0
            var b: float = TAU * float(i + 1) / 48.0
            var start := Vector3(cos(a) * float(r), 0, sin(a) * float(r))
            var finish := Vector3(cos(b) * float(r), 0, sin(b) * float(r))
            paths.append([start, finish, 0.020])
    for i in range(markings):
        var a: float = TAU * float(i) / float(markings)
        var q := Vector3(cos(a), 0, sin(a))
        paths.append([q * radius * 0.82, q * (radius + 0.16), 0.034])
        if i % 3 == 0:
            paths.append([q * radius * 0.58, q.rotated(Vector3.UP, 0.24) * radius * 0.77, 0.023])
    var mesh: Mesh = _mesh_from_strokes(paths, 0.024)
    _spawn(mesh, center + Vector3(0, 0.15, 0), tint, 0.40, lifetime, "rune")

func _fractures(center: Vector3, radius: float, tint: Color,
        duration: float = 1.5, thorns: int = 7) -> void:
    var paths: Array = []
    var branch_paths: Array = []
    for branch in range(thorns):
        var theta: float = TAU * float(branch) / float(thorns)
        var previous := Vector3.ZERO
        for j in range(1, 7):
            var progress: float = float(j) / 6.0
            var angular_wiggle: float = sin(float(j + branch * 3) * 2.8) * 0.115
            var endpoint := Vector3(
                cos(theta + angular_wiggle) * radius * progress,
                0.0,
                sin(theta + angular_wiggle) * radius * progress)
            paths.append([previous, endpoint, 0.058 * (1.1 - progress * 0.58)])
            if j == 3 or j == 5:
                var off := theta + (0.38 if j == 3 else -0.43)
                var fork := endpoint + Vector3(cos(off) * radius * 0.27, 0,
                    sin(off) * radius * 0.27)
                branch_paths.append([endpoint, fork, 0.040])
            previous = endpoint
    var background: Array = paths + branch_paths
    _spawn(_mesh_from_strokes(background, 0.08),
        center + Vector3(0, 0.115, 0), Color("100b17"), 0.91, duration * 1.22, "fissure", false)
    _spawn(_mesh_from_strokes(paths, 0.046),
        center + Vector3(0, 0.142, 0), tint, 0.46, duration, "fissure")
    _ring(center, radius * 0.74, 0.045, tint, 0.45, "shock", 0.44)

func _whip(origin: Vector3, destination: Vector3, tint: Color,
        width: float = 0.20, duration: float = 0.42, dark: bool = false) -> void:
    # One continuous sinuous mesh, not a single rigid neon tube.
    var axis: Vector3 = destination - origin
    var across := Vector3(-axis.z, 0, axis.x).normalized()
    var paths: Array = []
    var previous := Vector3.ZERO
    for j in range(1, 14):
        var f: float = float(j) / 13.0
        var now := axis * f
        now += across * sin(f * PI * 2.7) * (0.18 + 0.14 * sin(f * PI))
        now.y = (axis * f).y + sin(f * PI) * 0.2
        paths.append([previous, now, width * (1.05 - 0.55 * f)])
        previous = now
    _spawn(_mesh_from_strokes(paths, width), origin,
        tint if not dark else tint.darkened(0.38),
        0.58 if not dark else 0.53, duration, "beam", not dark)

func _embers(at: Vector3, tint: Color, power: int = 10) -> void:
    # Tiny procedural rising tongues have depth and motion without a giant
    # textureless orange disc covering the battlefield.
    for i in range(mini(power, 9)):
        var angle: float = TAU * float(i) / float(maxi(power, 1))
        var offset := Vector3(cos(angle), 0, sin(angle)) * randomizer.randf_range(0.15, 0.75)
        _beam(at + offset + Vector3(0, 0.12, 0),
            at + offset * 1.25 + Vector3(0, randomizer.randf_range(0.75, 1.8), 0),
            randomizer.randf_range(0.025, 0.095),
            tint.lightened(randomizer.randf_range(0.08, 0.45)), 0.45)
        sparks_total += 1

func swing_cinder_hammer(start: Vector3, target: Vector3,
        critical: bool = false, combo: int = 0) -> void:
    # A short, directional blade-of-light follows the heavy hand-rigged mace.
    # The impact arrives after the swing, never as a projectile from the hero.
    hammer_basic_casts += 1
    var toward: Vector3 = target - start
    toward.y = 0.0
    if toward.length_squared() < 0.02:
        toward = Vector3.FORWARD
    toward = toward.normalized()
    var side := Vector3(-toward.z, 0.0, toward.x)
    var handed: float = -1.0 if posmod(combo, 3) == 1 else 1.0
    var path: Array = []
    var previous: Vector3 = start + toward * 0.24 + side * handed * 0.72 + Vector3(0, 1.8, 0)
    for j in range(1, 11):
        var t: float = float(j) / 10.0
        var next: Vector3 = start + toward * (0.24 + 1.30 * t)
        next += side * handed * (0.72 - 1.44 * t)
        next.y += 1.78 - 0.97 * t + 0.26 * sin(t * PI)
        path.append([previous, next, 0.055 if critical else 0.038])
        previous = next
    if effects.size() < MAX_EFFECTS - 6:
        _spawn(_mesh_from_strokes(path, 0.045), Vector3.ZERO,
            Color("ffcf73") if critical else Color("f18138"),
            0.65 if critical else 0.38, 0.21, "beam")
    _queue_signature("cinder_basic", 0.19, start, target, [], 1)


func shoot_basic(hero_class: int, origin: Vector3, target: Vector3, critical: bool = false) -> void:
    # A real moving mesh visibly travels FROM the actor TO the foe. Previous
    # combat used invisible instant damage and only drew a beam at the victim.
    var span: Vector3 = target - origin
    if span.length_squared() < 0.20 or effects.size() > MAX_EFFECTS - 9:
        return
    var cls: int = clampi(hero_class, 0, 3)
    var colors := [Color("ffac63"), Color("bddb7b"), Color("86caff"), Color("d473a5")]
    var tint: Color = colors[cls].lightened(0.20 if critical else 0.0)
    var bolt_mesh: Mesh
    if cls == 1:
        var arrow := CylinderMesh.new()
        arrow.top_radius = 0.014
        arrow.bottom_radius = 0.033
        arrow.height = 0.68
        arrow.radial_segments = 6
        bolt_mesh = arrow
    elif cls == 3:
        var void_sphere := SphereMesh.new()
        void_sphere.radius = 0.16
        void_sphere.height = 0.32
        void_sphere.radial_segments = 10
        void_sphere.rings = 5
        bolt_mesh = void_sphere
    else:
        var orb := SphereMesh.new()
        orb.radius = 0.18 if critical else 0.13
        orb.height = 0.36 if critical else 0.26
        orb.radial_segments = 10
        orb.rings = 5
        bolt_mesh = orb
    var distance: float = origin.distance_to(target)
    var time_to_hit: float = clampf(distance / (13.5 if cls == 1 else 11.2), 0.12, 0.50)
    var projectile := _spawn(bolt_mesh, origin, tint, 0.98,
        time_to_hit, "travel")
    if projectile == null:
        return
    if cls == 1:
        projectile.quaternion = Quaternion(Vector3.UP, span.normalized())
    var data: Dictionary = effects.back()
    data["from"] = origin
    data["to"] = target
    # Brief tapering energy afterimage, avoids exposing effects as white rods.
    if cls == 2 or cls == 3:
        _beam(origin, origin.lerp(target, 0.33), 0.035, tint, 0.16, 0.38)


func clear_all() -> void:
    for entry in effects:
        var node: MeshInstance3D = entry["node"] as MeshInstance3D
        if is_instance_valid(node):
            node.queue_free()
    effects.clear()
    signature_cues.clear()


func _queue_signature(kind: String, delay: float, start: Vector3,
        destination: Vector3, targets: Array, rank: int) -> void:
    signature_cues.append({
        "kind": kind, "at": elapsed + delay, "start": start,
        "destination": destination, "targets": targets.duplicate(), "rank": rank
    })


func _scythe_sweep(at: Vector3, radius: float) -> void:
    # A curved, wide violet arc, not a stack of straight neon rays.
    var path: Array = []
    var old: Vector3 = Vector3(cos(-1.25), 0.95, sin(-1.25)) * radius
    for n in range(1, 19):
        var angle: float = -1.25 + 2.65 * float(n) / 18.0
        var next: Vector3 = Vector3(cos(angle) * radius, 0.96, sin(angle) * radius)
        path.append([old, next, 0.42 * (1.0 - float(n) / 27.0)])
        old = next
    _spawn(_mesh_from_strokes(path, 0.30), at,
        Color("b86aff"), 0.88, 0.54, "beam")
    _ring(at, radius * 0.76, 0.095, Color("672f9c"), 0.36)


func _play_signature_beat(cue: Dictionary) -> void:
    var kind: String = str(cue["kind"])
    var start: Vector3 = cue["start"]
    var target: Vector3 = cue["destination"]
    var targets: Array = cue["targets"]
    var rank: int = int(cue["rank"])
    match kind:
        "cinder_basic":
            hammer_basic_impacts += 1
            _ring(target, 0.30, 0.07, Color("ffb45d"), 0.23, "shock", 0.65)
            _embers(target + Vector3(0, 0.20, 0), Color("f89141"), 3)
        "inferno":
            # Ground-shattering mace slam: incandescent deep fissures, a
            # three-layer expanding fire blast, then free embers rising.
            var toward: Vector3 = target - start
            toward.y = 0.0
            toward = toward.normalized() if toward.length_squared() > 0.01 else Vector3.FORWARD
            # Crack beneath the hammer's forward landing point, not under
            # the knight's feet behind the visible lunge.
            var center: Vector3 = start + toward * 0.55 + Vector3(0, 0.03, 0)
            _fractures(center, 2.85 + float(rank) * 0.06,
                Color("ff511b"), 1.38, 12)
            # The previous impact displayed only thin glowing ground lines.
            # A raised fiery crown creates an actual, directional blast.
            _inferno_impact(center)
            _fire_wave(center, 1.05 + float(rank) * 0.015, 0.54)
            _fire_wave(center + Vector3(0, 0.08, 0), 1.35, 0.67)
            _ring(center, 1.25, 0.23, Color("ffedaf"), 0.33, "shock", 0.92)
            _ring(center, 1.80, 0.32, Color("ff9c29"), 0.59, "shock", 0.87)
            _ring(center, 2.40, 0.19, Color("d63714"), 0.78, "shock", 0.76)
            _embers(center, Color("ffb94a"), 9)
            for i in range(7):
                var angle: float = TAU * float(i) / 7.0
                var offset := Vector3(cos(angle), 0, sin(angle)) * 1.3
                _beam(center + offset + Vector3(0, 0.20, 0),
                    center + offset * 1.17 + Vector3(0, 1.05 + float(i % 3) * 0.22, 0),
                    0.10, Color("ff9a32"), 0.42)
        "arrowfall":
            # A rapid airborne shot resolves into real downward TRAVELING
            # arrows, with slanting paths and staggered impact timing.
            var number: int = mini(18, 12 + rank)
            for i in range(number):
                if effects.size() >= MAX_EFFECTS - 4:
                    break
                var x: float = float((i * 7) % number) / float(number - 1) - 0.5
                var z: float = float((i * 11) % number) / float(number - 1) - 0.5
                var landing: Vector3 = target + Vector3(x * 5.6, 0.12, z * 5.3)
                var launch: Vector3 = landing + Vector3(-2.2, 5.2 + float(i % 4) * 0.26, -1.1)
                var bolt := CylinderMesh.new()
                bolt.top_radius = 0.018
                bolt.bottom_radius = 0.065
                bolt.height = 0.94
                bolt.radial_segments = 5
                var arrow: MeshInstance3D = _spawn(bolt, launch,
                    Color("ffe8aa"), 0.94, 0.27 + float(i % 4) * 0.065, "travel")
                if arrow != null:
                    arrow.quaternion = Quaternion(Vector3.UP, (landing - launch).normalized())
                    var effect: Dictionary = effects.back()
                    effect["from"] = launch
                    effect["to"] = landing
                    # Short tracer stabs clarify descending arrows at camera distance.
                    if i % 3 == 0:
                        _beam(launch, launch.lerp(landing, 0.42), 0.028,
                            Color("a8eaff"), 0.29, 0.58)
            _sigil(target, 2.35, Color("d9d7a3"), 0.65, 16)
        "chain_lightning":
            var current: Vector3 = start + Vector3(0, 1.42, 0)
            if not targets.is_empty():
                current = targets[0] as Vector3 + Vector3(0, 1.0, 0)
            var finish: Vector3 = target + Vector3(0, 1.0, 0)
            # Wide icy bolt / hot white core and independent forks.
            _bolts(current, finish, Color("60baff"), 4)
            _bolts(current + Vector3(0.05, 0.09, 0),
                finish, Color("f1fcff"), 2)
            _ring(target, 0.42, 0.11, Color("b6dcff"), 0.23)
            _embers(target, Color("8ee8ff"), 4)
        "nightfall":
            # Black smoke dash leaves a curving violet reaper blade and a
            # reverse-flow blood-red tether returning to the caster.
            _smoke(start, 2.3, 0.66)
            _smoke(target, 3.1, 0.92)
            _scythe_sweep(target, 2.20)
            _fractures(target, 1.92, Color("71339c"), 1.18, 6)
            for n in range(mini(4, maxi(1, targets.size()))):
                var victim: Vector3 = targets[n] as Vector3 if not targets.is_empty() else target
                _whip(victim + Vector3(0, 0.95, 0),
                    start + Vector3(0, 1.15, 0), Color("e94168"),
                    0.075, 0.72)
            _ring(start, 0.7, 0.10, Color("e8406e"), 0.48)
            _embers(start, Color("ec4167"), 6)


func _cast_signature(hero_class: int, skill: int, rank: int, start: Vector3,
        destination: Vector3, targets: Array) -> bool:
    if hero_class == 0 and skill == 2:
        signature_casts["inferno"] = int(signature_casts["inferno"]) + 1
        _sigil(start, 1.1, Color("ffb35a"), 0.32, 16)
        _embers(start, Color("ffac59"), 4)
        _queue_signature("inferno", 0.42, start, destination, targets, rank)
        return true
    if hero_class == 1 and skill == 2:
        signature_casts["arrowfall"] = int(signature_casts["arrowfall"]) + 1
        _smoke(start, 1.65, 0.42)
        _whip(start + Vector3(0, 1.2, 0), start + Vector3(0, 5.8, 0),
            Color("ffe9a0"), 0.12, 0.56)
        _queue_signature("arrowfall", 0.30, start, destination, targets, rank)
        return true
    if hero_class == 2 and skill == 1:
        signature_casts["chain_lightning"] = int(signature_casts["chain_lightning"]) + 1
        _sigil(start, 0.83, Color("87d5ff"), 0.63, 14)
        _embers(start + Vector3(0, 0.7, 0), Color("aaddff"), 7)
        var bounce_start: Vector3 = start
        for hop in range(mini(targets.size(), mini(6, 2 + rank))):
            var bounce_destination: Vector3 = targets[hop] as Vector3
            _queue_signature("chain_lightning", 0.10 + 0.11 * float(hop),
                bounce_start, bounce_destination, [bounce_start], rank)
            bounce_start = bounce_destination
        if targets.is_empty():
            _queue_signature("chain_lightning", 0.12, start, destination,
                [start], rank)
        return true
    if hero_class == 3 and skill == 2:
        signature_casts["nightfall"] = int(signature_casts["nightfall"]) + 1
        _smoke(start, 2.5, 0.64)
        _sigil(start, 1.14, Color("7834b4"), 0.56, 18)
        _queue_signature("nightfall", 0.19, start, destination, targets, rank)
        return true
    return false


func cast(hero_class: int, slot: int, rank: int, start: Vector3,
        destination: Vector3, targets: Array) -> void:
    total_casts += 1
    var cls: int = clampi(hero_class, 0, 3)
    var skill: int = clampi(slot, 0, 2)
    var palette: Array = PALETTE[cls]
    var primary: Color = palette[skill]
    var scale_bonus: float = minf(0.55, float(maxi(0, rank - 1)) * 0.045)
    var origin: Vector3 = start + Vector3(0, 1.0, 0)
    var impact: Vector3 = destination + Vector3(0, 0.14, 0)
    if _cast_signature(cls, skill, rank, start, destination, targets):
        return
    match skill:
        0:
            # Basic: fast directional slash/arc and short-lived impact.
            _whip(origin, impact + Vector3(0, 0.7, 0), primary, 0.12, 0.24)
            if cls == 2:
                _bolts(origin, impact + Vector3(0, 0.75, 0), primary, 2)
            elif cls == 3:
                _whip(origin + Vector3(0, 0.25, 0), impact + Vector3(0, 0.3, 0),
                    Color("391527"), 0.26, 0.35)
            _ring(destination, 0.48 + scale_bonus, 0.10, primary, 0.21)
            _embers(destination, primary, 5)
        1:
            # Core/defensive: distinct space control and real lingering
            # circles/cracks rather than bright static metal cylinders.
            if cls == 0:
                _sigil(start, 1.12 + scale_bonus, Color("ffd6a0"), 1.5, 20)
                _ring(start, 1.42 + scale_bonus, 0.12, primary, 0.8)
                _embers(start, Color("ffbd6c"), 5)
            elif cls == 1:
                _sigil(destination, 2.12 + scale_bonus, primary, 2.1, 32)
                _smoke(destination, 4.4 + scale_bonus, 1.35)
                _fractures(destination, 1.65 + scale_bonus, Color("78c4c0"), 1.4, 8)
            elif cls == 2:
                var current: Vector3 = origin
                for i in range(mini(targets.size(), 3 + rank)):
                    var point: Vector3 = targets[i] as Vector3
                    var endpoint: Vector3 = point + Vector3(0, 1.0, 0)
                    _bolts(current, endpoint, primary, 2)
                    _ring(point, 0.47, 0.08, primary, 0.28)
                    current = endpoint
            else:
                _whip(origin, impact + Vector3(0, 0.15, 0), Color("4d1945"), 0.18, 0.7, true)
                _smoke(destination, 4.8 + scale_bonus, 1.7)
                _fractures(destination, 2.35 + scale_bonus, primary, 1.8, 9)
                _sigil(destination, 1.7 + scale_bonus, Color("b36ae0"), 1.6, 24)
        2:
            # Ultimate: telegraph / expanding ring / deep dark scars /
            # branching tendrils / incandescent fragments. Burst scale grows
            # with investment but never floods the entire portrait viewport.
            var radius: float = 2.35 + scale_bonus * 1.5
            _smoke(destination, radius * 3.0, 2.3)
            _sigil(destination, radius, primary, 1.85, 32)
            _ring(destination, radius * 0.86, 0.10, primary, 0.7, "charge", 0.45)
            _fractures(destination, radius * 1.30, primary, 2.15, 10)
            _ring(destination, radius, 0.105,
                primary.lightened(0.33), 0.53, "shock", 0.47)
            # A handful of heavy smoky tendrils, not five glowing white
            # ribbons crossing at the same spot (the old neon spiderweb).
            for i in range(3):
                var theta: float = TAU * float(i) / 3.0
                var edge := destination + Vector3(cos(theta) * radius * 0.9,
                    randomizer.randf_range(0.32, 0.8), sin(theta) * radius * 0.9)
                _whip(origin, edge, primary, 0.085, 0.58, cls == 3)
            if cls == 2:
                for i in range(mini(targets.size(), 6)):
                    var point: Vector3 = targets[i] as Vector3
                    _bolts(origin, point + Vector3(0, 0.8, 0), primary, 2)
            elif cls == 3:
                _sigil(destination, radius * 1.2, Color("30172c"), 2.7, 20)
                _fractures(destination, radius * 1.44, Color("8e244a"), 2.5, 7)
            _embers(destination, Color("ffb983") if cls == 0 else primary, 9)
