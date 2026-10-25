extends SceneTree
# Real portrait renders of authentic rigged 3D chibi characters imported from
# a verified CC0 Godot pack. Do not substitute AI concept art for gameplay.
const MODEL_NAMES := ["knight"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("CHIBI IMPORT QA FAIL: "+message)
    quit(47)

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var lightbox := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("243039")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("e7d8ca")
    env.ambient_light_energy = 0.92
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    lightbox.environment = env
    stage.add_child(lightbox)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-44,-30,0)
    key.light_color = Color("fff0d3")
    key.light_energy = 1.62
    stage.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-30,143,0)
    fill.light_color = Color("9abce6")
    fill.light_energy = .66
    stage.add_child(fill)
    var floor := MeshInstance3D.new()
    floor.mesh = PlaneMesh.new()
    floor.scale = Vector3(8,1,8)
    var m := StandardMaterial3D.new()
    m.albedo_color = Color("4b584a")
    floor.material_override = m
    stage.add_child(floor)
    var camera := Camera3D.new()
    camera.current = true
    camera.fov = 44.0
    camera.position = Vector3(3.1,3.1,6.5)
    stage.add_child(camera)
    for name in MODEL_NAMES:
        var packed: PackedScene = ResourceLoader.load("res://assets/models/chibi/%s.glb" % name) as PackedScene
        if packed == null:
            _fail("No imported CC0 chibi GLB " + name)
            return
        var actor: Node3D = packed.instantiate() as Node3D
        if actor == null:
            _fail("Could not instantiate "+name)
            return
        stage.add_child(actor)
        var skeletons: Array = actor.find_children("*","Skeleton3D",true,false)
        var animators: Array = actor.find_children("*","AnimationPlayer",true,false)
        var meshes: Array = actor.find_children("*","MeshInstance3D",true,false)
        if skeletons.is_empty() or animators.is_empty() or meshes.is_empty():
            _fail("Missing rig, native 3D body or animation for "+name)
            return
        var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
        var played: bool = false
        var all_clips: Array = []
        for node in animators:
            var player: AnimationPlayer = node as AnimationPlayer
            for clip in player.get_animation_list():
                all_clips.append(str(clip))
                if str(clip).to_lower().contains("run") and not played:
                    player.play(str(clip))
                    player.advance(.18)
                    played = true
        if not played or all_clips.size() < 8 or skeleton.get_bone_count() < 8:
            _fail("Missing imported walk/run rig or sufficient anatomy for "+name)
            return
        var textures: int = 0
        var bounds: AABB
        var found_bounds: bool = false
        for found in meshes:
            var part: MeshInstance3D = found as MeshInstance3D
            if part.mesh == null:
                continue
            var box: AABB = actor.global_transform.affine_inverse()*part.global_transform*part.get_aabb()
            bounds = bounds.merge(box) if found_bounds else box
            found_bounds = true
            for surface in range(part.mesh.get_surface_count()):
                var material: BaseMaterial3D = part.get_active_material(surface) as BaseMaterial3D
                if material != null and material.albedo_texture != null:
                    textures += 1
        if textures < 1 or not found_bounds:
            _fail("Chibi model needs original painted materials, not a gray fallback "+name)
            return
        actor.scale = Vector3.ONE * 2.45 / maxf(.01,bounds.size.y)
        actor.position.y = -bounds.position.y * actor.scale.y
        camera.look_at(Vector3(0,1.29,0),Vector3.UP)
        await process_frame
        await RenderingServer.frame_post_draw
        var image: Image = root.get_texture().get_image()
        if image.save_png("res://build/chibi-%s.png" % name) != OK:
            _fail("Cannot render original 3D avatar "+name)
            return
        print("CHIBI ASSET VERIFIED ",name," bones=",skeleton.get_bone_count()," clips=",all_clips.size()," textured_surfaces=",textures)
        stage.remove_child(actor)
        actor.queue_free()
        await process_frame
    print("CHIBI IMPORT QA PASS: one verified male skinned and textured 3D fantasy model, with genuine locomotion and portrait captures")
    quit(0)
