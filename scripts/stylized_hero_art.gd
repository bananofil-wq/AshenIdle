extends RefCounted
## Original stylized hero treatment. Accessories follow the *animated skeleton*
## using BoneAttachment3D, rather than remaining static on a walking model.
## Built from a small shared set of low-poly meshes, suitable for GLES3.
func _material(color: Color, metallic: float = 0.0, glow: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = 0.44
    if glow:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 1.5
    return m

func _part(parent: Node3D, shape: Mesh, at: Vector3, color: Color, metallic: float = 0.0, glow: bool = false) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.mesh = shape
    mesh.position = at
    mesh.material_override = _material(color, metallic, glow)
    parent.add_child(mesh)
    return mesh

func _ball(parent: Node3D, at: Vector3, radius: float, color: Color, scale3: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    shape.radial_segments = 12
    shape.rings = 6
    var mesh := _part(parent, shape, at, color)
    mesh.scale = scale3
    return mesh

func _block(parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    return _part(parent, shape, at, color, metal)

func _cone(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.bottom_radius = radius
    shape.top_radius = 0.0
    shape.height = height
    shape.radial_segments = 9
    return _part(parent, shape, at, color)

func _attachment(skeleton: Skeleton3D, names: Array) -> BoneAttachment3D:
    for name in names:
        for i in range(skeleton.get_bone_count()):
            if str(name).to_lower() == skeleton.get_bone_name(i).to_lower():
                var node := BoneAttachment3D.new()
                node.name = "Chibi" + str(name).replace(" ", "")
                skeleton.add_child(node)
                node.bone_idx = i
                return node
    return null

func decorate(actor: Node3D, kind: String) -> bool:
    var skeleton: Skeleton3D
    for child in actor.find_children("*", "Skeleton3D", true, false):
        skeleton = child as Skeleton3D
        break
    if skeleton == null:
        return false
    # Proportions and palettes are inspired by the supplied cartoon references
    # but are original silhouettes and costumes.
    var palette: Dictionary = {
        "Knight": [Color("e6f3ff"), Color("245eaa"), Color("efb83c"), Color("d6414d")],
        "Rogue": [Color("f8f0d7"), Color("dd663b"), Color("7c4aab"), Color("c9f6ff")],
        "Mage": [Color("ff9d24"), Color("b73122"), Color("ffe17a"), Color("ffef86")],
        "Barbarian": [Color("f3e6e7"), Color("2a293a"), Color("c82942"), Color("fa4751")]
    }
    if not palette.has(kind):
        return false
    var c: Array = palette[kind]
    var head := _attachment(skeleton, ["Head", "head", "mixamorig:Head", "DEF-head"])
    if head != null:
        # Large helmet/hair, readable at an isometric distance.
        _ball(head, Vector3(0.0, 0.11, 0.02), 0.22, c[0], Vector3(1.13, 1.08, 1.0))
        if kind == "Knight":
            _block(head, Vector3(0, 0.12, 0.19), Vector3(0.33, 0.11, 0.07), Color("202d45"))
            _cone(head, Vector3(0, 0.39, 0), 0.09, 0.36, c[3])
        elif kind == "Rogue":
            for i in range(4):
                _cone(head, Vector3(-0.16 + 0.11 * i, 0.27, -0.07), 0.09, 0.22, c[0])
        elif kind == "Mage":
            for i in range(3):
                _cone(head, Vector3(-0.14 + 0.14 * i, 0.27, -0.03), 0.12, 0.32, c[2])
        else:
            _ball(head, Vector3(-0.18, 0.17, 0), 0.15, c[0])
            _ball(head, Vector3(0.18, 0.17, 0), 0.15, c[0])
    var chest := _attachment(skeleton, ["Spine2", "Chest", "spine_02", "mixamorig:Spine2", "Spine1"])
    if chest != null:
        _block(chest, Vector3(0, 0.0, 0.13), Vector3(0.52, 0.40, 0.14), c[1], 0.45 if kind == "Knight" else 0.05)
        _ball(chest, Vector3(0, 0.0, 0.23), 0.075, c[2])
        for side in [-1, 1]:
            _ball(chest, Vector3(float(side) * 0.33, 0.12, 0.0), 0.16, c[0])
    # The actual body, walk and attack are still skinned and animated by Godot.
    actor.set_meta("stylized_hero", kind)
    return true
