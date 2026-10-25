extends SceneTree
# Tests the REAL skinned hero models and costume bone attachments. These are
# Godot 3D screenshots, never concept art or composited reference images.
# All playable bodies use the single verified male chibi rig. The other
# downloaded asset-pack characters are female and MUST NOT be playable.
const HEROES: Array = [
    ["knight", "Knight"],
    ["knight", "Rogue"],
    ["knight", "Mage"],
    ["knight", "Barbarian"]
]
const COSTUME = preload("res://scripts/stylized_hero_art.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("MALE CHIBI HERO QA FAIL: " + reason)
    quit(72)

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var ambience := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("202a31")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("e4ddcc")
    env.ambient_light_energy = 0.92
    ambience.environment = env
    world.add_child(ambience)
    var sunlight := DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-42, -36, 0)
    sunlight.light_color = Color("ffdfac")
    sunlight.light_energy = 1.65
    world.add_child(sunlight)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-34, 145, 0)
    fill.light_color = Color("9abce7")
    fill.light_energy = 0.72
    world.add_child(fill)
    var camera := Camera3D.new()
    camera.fov = 39.0
    camera.position = Vector3(3.0, 2.75, 5.7)
    world.add_child(camera)
    camera.current = true
    camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
    var style = COSTUME.new()
    for pair in HEROES:
        var hero_name: String = str(pair[0])
        var hero_kind: String = str(pair[1])
        var packed: PackedScene = ResourceLoader.load("res://assets/models/chibi/%s.glb" % hero_name) as PackedScene
        if packed == null:
            _fail("Missing imported chibi model " + hero_name)
            return
        var model: Node3D = packed.instantiate() as Node3D
        if model == null:
            _fail("Cannot instantiate " + hero_name)
            return
        world.add_child(model)
        var skeletons: Array = model.find_children("*", "Skeleton3D", true, false)
        var animators: Array = model.find_children("*", "AnimationPlayer", true, false)
        if skeletons.is_empty() or animators.is_empty():
            _fail("Missing native skeletal animation " + hero_name)
            return
        if not style.decorate_chibi(model, hero_kind):
            _fail("Could not attach male chibi costume to skeleton " + hero_kind)
            return
        if str(model.get_meta("male_chibi_costume", "")) != hero_kind or str(model.get_meta("class_signature", "")) != hero_kind:
            _fail("Missing class-specific male chibi silhouette " + hero_kind)
            return
        var costume_nodes: Array = model.find_children("*", "BoneAttachment3D", true, false)
        var decorated_count: int = 0
        for node in costume_nodes:
            if str((node as Node).name).begins_with("HeroCostume"):
                decorated_count += 1
        if decorated_count < 2:
            _fail("Hero must have head and chest rig accessories " + hero_kind)
            return
        var costume_mesh_count: int = 0
        for costume_bone in costume_nodes:
            for art_part in (costume_bone as Node).find_children("*", "MeshInstance3D", true, false):
                if art_part is MeshInstance3D:
                    costume_mesh_count += 1
        if costume_mesh_count < 14:
            _fail("Class silhouette is too plain: " + hero_kind + " has " + str(costume_mesh_count) + " rigged props")
            return
        var moving: bool = false
        for player_node in animators:
            var player: AnimationPlayer = player_node as AnimationPlayer
            for clip in player.get_animation_list():
                var clip_name: String = str(clip).to_lower()
                if clip_name.contains("run") or clip_name.contains("walk"):
                    player.play(str(clip))
                    player.advance(0.2)
                    moving = true
                    break
            if moving:
                break
        if not moving:
            _fail("No native run/walk rig animation on " + hero_kind)
            return
        var bounds := AABB()
        var initialized := false
        for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
            var piece: MeshInstance3D = mesh_node as MeshInstance3D
            if piece.mesh == null:
                continue
            var local: AABB = model.global_transform.affine_inverse() * piece.global_transform * piece.get_aabb()
            bounds = bounds.merge(local) if initialized else local
            initialized = true
        if not initialized or bounds.size.y < 0.01:
            _fail("Hero lacks real visible mesh " + hero_kind)
            return
        var fit: float = 2.4 / bounds.size.y
        model.scale = Vector3.ONE * fit
        model.position.y = -bounds.position.y * fit
        await process_frame
        await RenderingServer.frame_post_draw
        var shot: Image = root.get_texture().get_image()
        if shot.is_empty() or shot.save_png("res://build/hero-style-%s.png" % hero_kind.to_lower()) != OK:
            _fail("Could not save actual hero 3D screenshot " + hero_kind)
            return
        print("MALE CHIBI HERO VERIFIED ", hero_kind, " native_movement=true, bone_costume=", decorated_count)
        world.remove_child(model)
        model.queue_free()
        await process_frame
    print("MALE CHIBI HERO QA PASS: four distinct male-styled skeleton-attached characters with native movement")
    quit(0)
