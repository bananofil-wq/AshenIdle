extends RefCounted
## Sculpted, one-mesh bark anatomy plus a single leafy crown mesh.
## Deliberately low draw-call compared with assembling a monster from dozens
## of sphere and cone nodes. Designed for GLES3 portrait Android combat.

var bark_material: StandardMaterial3D
var foliage_material: StandardMaterial3D
var eyes_material: StandardMaterial3D
var eye_mesh: SphereMesh


func _ensure_materials() -> void:
    if bark_material != null:
        return
    bark_material = StandardMaterial3D.new()
    bark_material.vertex_color_use_as_albedo = true
    bark_material.albedo_color = Color("a69478")
    bark_material.roughness = 0.98
    foliage_material = StandardMaterial3D.new()
    foliage_material.vertex_color_use_as_albedo = true
    foliage_material.albedo_color = Color("93ad77")
    foliage_material.roughness = 0.93
    foliage_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    eyes_material = StandardMaterial3D.new()
    eyes_material.albedo_color = Color("ffc16f")
    eyes_material.emission_enabled = true
    eyes_material.emission = Color("ff9b30")
    eyes_material.emission_energy_multiplier = 2.15
    eyes_material.roughness = 0.12
    eye_mesh = SphereMesh.new()
    eye_mesh.radius = 0.078
    eye_mesh.height = 0.155
    eye_mesh.radial_segments = 8
    eye_mesh.rings = 4


func _vertex(surface: SurfaceTool, p: Vector3, color: Color, uv: Vector2) -> void:
    surface.set_color(color)
    surface.set_uv(uv)
    surface.add_vertex(p)


func _point(a: Vector3, b: Vector3, side: Vector3, bitangent: Vector3,
        t: float, angle: float, radius: float, phase: float) -> Vector3:
    var twist: float = sin(t * 5.0 + phase) * 0.058
    var ridge: float = 0.90 + 0.12 * sin(angle * 4.0 + phase + t * 4.0)
    return a.lerp(b, t) + Vector3(twist, 0, 0) +         (side * cos(angle) + bitangent * sin(angle)) * radius * ridge


func _branch(surface: SurfaceTool, a: Vector3, b: Vector3,
        thick: float, narrow: float, shade: Color, phase: float) -> void:
    var axis: Vector3 = (b - a).normalized()
    var side: Vector3 = axis.cross(Vector3.UP)
    if side.length_squared() < 0.001:
        side = axis.cross(Vector3.RIGHT)
    side = side.normalized()
    var bitangent: Vector3 = axis.cross(side).normalized()
    var facets: int = 8
    var sections: int = 4
    for n in range(sections):
        var t0: float = float(n) / float(sections)
        var t1: float = float(n + 1) / float(sections)
        var r0: float = lerpf(thick, narrow, t0)
        var r1: float = lerpf(thick, narrow, t1)
        for k in range(facets):
            var u0: float = float(k) / float(facets)
            var u1: float = float(k + 1) / float(facets)
            var angle0: float = TAU * u0
            var angle1: float = TAU * u1
            var v00 := _point(a, b, side, bitangent, t0, angle0, r0, phase)
            var v01 := _point(a, b, side, bitangent, t0, angle1, r0, phase)
            var v10 := _point(a, b, side, bitangent, t1, angle0, r1, phase)
            var v11 := _point(a, b, side, bitangent, t1, angle1, r1, phase)
            var bark_tone: Color = shade.lightened(0.13) if k % 4 == 0 else shade.darkened(0.19) if k % 3 == 0 else shade
            for vert in [v00, v10, v01, v01, v10, v11]:
                _vertex(surface, vert, bark_tone, Vector2(vert.x * 0.41 + u0, vert.y * 0.75))


func _foliage(surface: SurfaceTool, origin: Vector3, size: float, angle: float, tone: Color) -> void:
    var forward := Vector3(cos(angle), 0, sin(angle))
    var sideways := Vector3(-sin(angle), 0, cos(angle))
    var a: Vector3 = origin
    var b: Vector3 = origin + forward * size * 0.55 + sideways * size * 0.19 + Vector3(0, size * 0.23, 0)
    var c: Vector3 = origin + forward * size
    var d: Vector3 = origin + forward * size * 0.55 - sideways * size * 0.19 + Vector3(0, size * 0.23, 0)
    for p in [a, b, c, a, c, d]:
        _vertex(surface, p, tone, Vector2(p.x * 0.5, p.z * 0.5))


func build(visual: Node3D, color_hint: Color) -> void:
    _ensure_materials()
    var trunk := SurfaceTool.new()
    trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
    var core := Color("55402d")
    var dark := Color("342b27")
    var branch_tone := Color("655035")
    # Tapered torso and haunches, rather than a smiling brown cone.
    _branch(trunk, Vector3(0, 0.48, 0), Vector3(0.06, 1.94, -0.06),
        0.40, 0.29, core, 0.17)
    for side in [-1.0, 1.0]:
        _branch(trunk, Vector3(side * 0.20, 0.75, 0),
            Vector3(side * 0.43, 0.10, 0.25), 0.21, 0.13, dark, side)
        _branch(trunk, Vector3(side * 0.38, 1.62, 0),
            Vector3(side * 0.77, 1.35, 0.08), 0.25, 0.17, core, side + 0.5)
        _branch(trunk, Vector3(side * 0.77, 1.35, 0.08),
            Vector3(side * 1.06, 0.91, 0.29), 0.16, 0.10, branch_tone, side + 0.4)
        for digit in range(3):
            _branch(trunk, Vector3(side * 1.06, 0.91, 0.29),
                Vector3(side * (1.21 + float(digit) * 0.045),
                    0.62 - float(digit) * 0.045,
                    0.16 + float(digit) * 0.22), 0.07, 0.018, dark, digit + side)
        _branch(trunk, Vector3(side * 0.22, 1.75, -0.04),
            Vector3(side * 0.63, 2.40, -0.09), 0.15, 0.028, branch_tone, side + 2.0)
        _branch(trunk, Vector3(side * 0.53, 2.20, -0.07),
            Vector3(side * 0.91, 2.66, -0.27), 0.09, 0.012, dark, side + 4.0)
    for sign in [-1.0, 1.0]:
        _branch(trunk, Vector3(sign * 0.15, 0.5, -0.08),
            Vector3(sign * 0.81, 0.04, -0.18), 0.18, 0.018, dark, sign + 2.4)
    trunk.generate_normals()
    var torso := MeshInstance3D.new()
    torso.name = "SculptedBarkAndBranchAnatomy"
    torso.mesh = trunk.commit()
    torso.material_override = bark_material
    torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    visual.add_child(torso)

    # Leaf bunches crest the crown and upper shoulders without hiding its face.
    var crown := SurfaceTool.new()
    crown.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tones := [Color("496f37"), Color("6b8a47"), Color("365b38"), Color("8c9d4e")]
    for layer in range(3):
        for leaf_index in range(8):
            var angle: float = TAU * float(leaf_index) / 8.0 + float(layer) * 0.36
            var radius: float = 0.22 + float(layer) * 0.16
            var center := Vector3(cos(angle) * radius,
                2.11 + float((leaf_index + layer) % 3) * 0.15,
                -0.18 + sin(angle) * radius)
            _foliage(crown, center, 0.55 + float(layer % 2) * 0.17, angle,
                tones[(leaf_index + layer) % tones.size()])
    for side in [-1.0, 1.0]:
        for n in range(5):
            _foliage(crown, Vector3(side * 0.55, 1.63 + float(n) * 0.11, 0.0),
                0.43, float(n) * 0.70, tones[n % tones.size()])
    crown.generate_normals()
    var leaves := MeshInstance3D.new()
    leaves.name = "TreantLeavesAndMoss"
    leaves.mesh = crown.commit()
    leaves.material_override = foliage_material
    leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    visual.add_child(leaves)

    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        eye.name = "EmberEyeLeft" if side < 0 else "EmberEyeRight"
        eye.mesh = eye_mesh
        eye.material_override = eyes_material
        eye.position = Vector3(side * 0.17, 1.84, 0.34)
        visual.add_child(eye)
