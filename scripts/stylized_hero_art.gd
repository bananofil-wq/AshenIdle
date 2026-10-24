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
    # Expressive male chibi faces attached to the animated head bone.
    if head != null:
        var skin := Color("f6bd83") if kind in ["Knight", "Rogue"] else Color("f79a35") if kind == "Mage" else Color("eee6e1")
        _ball(head, Vector3(0, -0.035, 0.16), 0.17, skin, Vector3(1.08, 0.90, 0.45))
        var eye := Color("1b2634") if kind == "Rogue" else Color("168cdb") if kind == "Knight" else Color("ffe55b") if kind == "Mage" else Color("e3293b")
        for side in [-1.0, 1.0]:
            var x: float = float(side)
            _ball(head, Vector3(x * 0.075, -0.018, 0.239), 0.031, eye, Vector3(0.72, 1.35, 0.42))
            var brow := _block(head, Vector3(x * 0.075, 0.046, 0.239), Vector3(0.09, 0.021, 0.022), Color("332a30"))
            brow.rotation.z = x * 0.27
        if kind == "Mage":
            for side in [-1.0, 1.0]:
                _cone(head, Vector3(float(side) * 0.18, 0.25, 0), 0.07, 0.24, Color("8f2c1c"))
        elif kind == "Barbarian":
            _ball(head, Vector3(0, 0.21, -0.05), 0.19, c[0], Vector3(1.28, 0.43, 0.83))
    # The actual body, walk and attack are still skinned and animated by Godot.
    actor.set_meta("stylized_hero", kind)
    return true


func decorate_enemy(model: Node3D, species: String, biome: int, boss: bool, role: String) -> bool:
    # Reuse the same bold, toy-fantasy visual language as the player heroes.
    # Costume meshes are attached to animated bones so enemies still fight.
    var palettes: Array = [
        [Color("d97856"), Color("512837"), Color("ffcb59")],
        [Color("80bda0"), Color("304d42"), Color("e8e5ac")],
        [Color("b8c7f2"), Color("414c89"), Color("e9f4ff")],
        [Color("e5b471"), Color("725142"), Color("f3d992")],
        [Color("dca1dd"), Color("533660"), Color("f6d1ff")],
        [Color("b6c0cb"), Color("43434d"), Color("e5f3ff")],
        [Color("82c5c9"), Color("254a5c"), Color("c4f6ff")],
        [Color("b3cf8a"), Color("4a5e36"), Color("fff2a5")],
        [Color("d68b71"), Color("5c3539"), Color("ffdb94")],
        [Color("d48a62"), Color("612d2c"), Color("ffbd66")]
    ]
    var colors: Array = palettes[clampi(biome, 0, palettes.size()-1)]
    var skeleton: Skeleton3D
    for node in model.find_children("*", "Skeleton3D", true, false):
        skeleton = node as Skeleton3D
        break
    if skeleton == null:
        return false
    var head := _attachment(skeleton, ["Head", "head", "mixamorig:Head", "DEF-head"])
    if head != null:
        # Oversized expressive masks and recognizable class-specific headgear.
        _ball(head, Vector3(0, 0.11, 0.04), 0.24 if boss else 0.18, colors[0])
        for side in [-1.0, 1.0]:
            var x: float = float(side)
            _ball(head, Vector3(x * 0.085, 0.14, 0.21), 0.045 if boss else 0.036, colors[2])
            if boss or role == "guardian":
                _cone(head, Vector3(x * 0.17, 0.35, -0.02), 0.10, 0.36 if boss else 0.23, colors[1])
        if role == "caster":
            _cone(head, Vector3(0, 0.37, 0), 0.21, 0.40, colors[1])
        elif role == "flanker":
            _cone(head, Vector3(0, 0.31, -0.1), 0.12, 0.23, colors[2])
    var chest := _attachment(skeleton, ["Spine2", "Chest", "spine_02", "mixamorig:Spine2", "Spine1"])
    if chest != null:
        _block(chest, Vector3(0, 0, 0.14), Vector3(0.46, 0.39, 0.13), colors[1], 0.15)
        _ball(chest, Vector3(0, 0.04, 0.24), 0.095 if boss else 0.065, colors[2])
        if boss:
            for side in [-1.0, 1.0]:
                _ball(chest, Vector3(float(side)*0.37, 0.17, 0), 0.22, colors[0])
    model.set_meta("stylized_enemy", species)
    model.set_meta("stylized_boss", boss)
    return true

func decorate_creature(visual: Node3D, species: String, biome: int, boss: bool) -> void:
    # For non-humanoid animals, preserve the four-legged rig and layer readable
    # fantasy accents rather than putting a humanoid helmet on a wolf.
    var fur: Color = Color("f4ca82") if biome in [0,3,9] else Color("d4e9ff") if biome in [2,5,6] else Color("c7d8a0")
    var accent: Color = Color("f38d54") if biome in [0,9] else Color("74b7df")
    var scale_factor: float = 1.45 if boss else 1.0
    for side in [-1.0, 1.0]:
        _cone(visual, Vector3(float(side) * 0.19, 1.15 * scale_factor, 0.48), 0.11 * scale_factor, 0.28 * scale_factor, fur)
        _ball(visual, Vector3(float(side) * 0.20, 0.89 * scale_factor, 0.78), 0.08 * scale_factor, accent)
    if boss:
        _ball(visual, Vector3(0, 1.4 * scale_factor, 0), 0.24, accent)


# Reference-driven costume silhouettes for the four male playable heroes.
# The source GLB's skinned body, facial materials and native animations remain
# intact. Lightweight accessories attach to real animated bones, not the floor
# or an independently bobbing mannequin.
func _chibi_bone(skeleton: Skeleton3D, region: String) -> BoneAttachment3D:
    var first: int = -1
    for i in range(skeleton.get_bone_count()):
        var name: String = skeleton.get_bone_name(i).to_lower()
        if region == "head" and (name.ends_with("head") or name == "head"):
            first = i
            break
        if region == "chest" and (name.contains("chest") or name.ends_with("spine2") or name.ends_with("spine_02")):
            first = i
            break
    if first < 0 and region == "chest":
        for i in range(skeleton.get_bone_count()):
            if skeleton.get_bone_name(i).to_lower().contains("spine"):
                first = i
                break
    if first < 0:
        return null
    var attachment := BoneAttachment3D.new()
    attachment.name = "HeroCostume" + region.capitalize()
    skeleton.add_child(attachment)
    attachment.bone_idx = first
    return attachment

func decorate_chibi(model: Node3D, kind: String) -> bool:
    if model == null:
        return false
    if model.has_meta("male_chibi_costume"):
        return str(model.get_meta("male_chibi_costume")) == kind
    if not kind in ["Knight", "Rogue", "Mage", "Barbarian"]:
        return false
    var skeleton: Skeleton3D
    for node in model.find_children("*", "Skeleton3D", true, false):
        skeleton = node as Skeleton3D
        break
    if skeleton == null:
        return false
    var head: BoneAttachment3D = _chibi_bone(skeleton, "head")
    var chest: BoneAttachment3D = _chibi_bone(skeleton, "chest")
    if head == null or chest == null:
        return false
    var silver := Color("d8e8f1")
    var gold := Color("f6bf52")
    var blue := Color("285bad")
    var red := Color("d53b3a")
    if kind == "Knight":
        # Silver armored guardian, blue mantle and upright crimson crest.
        _block(chest, Vector3(0, 0.0, 0.16), Vector3(0.32, 0.27, 0.075), silver, 0.65)
        _ball(chest, Vector3(0, 0.04, 0.22), 0.061, gold)
        _ball(head, Vector3(0, 0.24, -0.02), 0.085, red, Vector3(0.78, 1.85, 0.85))
        _cone(head, Vector3(0, 0.36, -0.05), 0.055, 0.23, red)
        for side in [-1.0, 1.0]:
            _ball(chest, Vector3(float(side) * 0.24, 0.12, 0), 0.105, silver)
        _block(chest, Vector3(0, -0.15, -0.15), Vector3(0.34, 0.31, 0.055), blue)
    elif kind == "Rogue":
        # White ponytail, orange leather and purple scarf: clear at phone scale.
        _ball(head, Vector3(0, 0.19, -0.025), 0.21, Color("f7e6ca"), Vector3(1.15, 0.43, 0.97))
        _ball(head, Vector3(-0.17, 0.24, -0.13), 0.115, Color("f7e6ca"), Vector3(1.12, 1.26, 0.91))
        _block(chest, Vector3(0, -0.05, 0.15), Vector3(0.32, 0.27, 0.075), Color("dc653a"))
        _ball(chest, Vector3(0, 0.15, 0.12), 0.16, Color("5b397e"), Vector3(1.54, 0.27, 1.13))
        _ball(chest, Vector3(0, -0.20, 0.19), 0.052, silver)
    elif kind == "Mage":
        # Male infernal pyromancer: paired horns, ember crown and fiery wings.
        for side in [-1.0, 1.0]:
            var x: float = float(side)
            _cone(head, Vector3(x * 0.17, 0.25, -0.04), 0.075, 0.24, Color("8c281a"))
            var wing := _ball(chest, Vector3(x * 0.39, 0.13, -0.20), 0.18,
                Color("f77a16"), Vector3(0.58, 1.9, 0.34))
            wing.rotation.z = x * -0.45
            _ball(chest, Vector3(x * 0.31, 0.10, -0.17), 0.10, gold)
        _cone(head, Vector3(0, 0.34, -0.01), 0.105, 0.36, Color("f15a17"))
        _cone(head, Vector3(0, 0.42, 0.02), 0.052, 0.24, Color("fff078"))
        _block(chest, Vector3(0, 0.0, 0.14), Vector3(0.34, 0.33, 0.09), red)
        _ball(chest, Vector3(0, 0.01, 0.22), 0.09, gold)
    else:
        # White-haired reaper with angular dark armor, red-black cape, ruby.
        _ball(head, Vector3(0, 0.20, -0.05), 0.22, silver, Vector3(1.12, 0.42, 1.05))
        for side in [-1.0, 1.0]:
            _ball(head, Vector3(float(side) * 0.18, 0.0, -0.075), 0.11, silver,
                Vector3(0.61, 1.63, 0.68))
            _ball(chest, Vector3(float(side) * 0.26, 0.11, 0.01), 0.105, Color("292b36"))
        _block(chest, Vector3(0, 0.0, 0.14), Vector3(0.35, 0.32, 0.085), Color("272633"), 0.43)
        _ball(chest, Vector3(0, 0.09, 0.23), 0.068, red)
        _block(chest, Vector3(0, -0.08, -0.16), Vector3(0.48, 0.40, 0.054), red)
        _block(chest, Vector3(0, -0.02, -0.20), Vector3(0.25, 0.32, 0.04), Color("2a2029"))
    model.set_meta("male_chibi_costume", kind)
    return true
