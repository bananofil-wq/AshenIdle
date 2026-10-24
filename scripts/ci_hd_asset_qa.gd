extends SceneTree
# Genuine imported high-poly skinned GLBs. This QA fails on toy fallback meshes.
const ITEMS: Array = [
    ["gloom_stalker","GLOOM STALKER",false],
    ["hollow_warden","HOLLOW WARDEN",false],
    ["marsh_direwolf","MARSH DIREWOLF",true],
    ["ashfen_ranger","ASHFEN RANGER",false]
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("HD CHARACTER QA FAIL: " + message)
    quit(66)

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var ambient := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("171c1b")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("d6d7d2")
    env.ambient_light_energy = 0.67
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    ambient.environment = env
    world.add_child(ambient)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-50,-35,0)
    key.light_energy = 1.65
    key.light_color = Color("ffe5c0")
    world.add_child(key)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-28,145,0)
    rim.light_energy = 0.78
    rim.light_color = Color("9baeca")
    world.add_child(rim)
    var ground := MeshInstance3D.new()
    var floor := PlaneMesh.new()
    floor.size = Vector2(12,12)
    ground.mesh = floor
    ground.position.y = -0.04
    var soil := StandardMaterial3D.new()
    soil.albedo_color = Color("51544a")
    soil.roughness = 0.97
    ground.material_override = soil
    world.add_child(ground)
    var camera := Camera3D.new()
    world.add_child(camera)
    camera.current = true
    camera.fov = 43.0
    var found_total: int = 0
    for item in ITEMS:
        var name: String = str(item[0])
        var scene_path: String = "res://assets/models/hd/%s.glb" % name
        var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
        if packed == null:
            _fail("Missing imported 3D model: " + scene_path)
            return
        var model: Node3D = packed.instantiate() as Node3D
        if model == null:
            _fail("Could not instantiate " + name)
            return
        world.add_child(model)
        var skeletons: Array = model.find_children("*","Skeleton3D",true,false)
        var meshes: Array = model.find_children("*","MeshInstance3D",true,false)
        var players: Array = model.find_children("*","AnimationPlayer",true,false)
        if skeletons.is_empty() or meshes.is_empty():
            _fail("No proper rigged textured mesh: " + name)
            return
        var texture_count: int = 0
        var approximate_triangles: int = 0
        var bounds := AABB()
        var initialized: bool = false
        for found in meshes:
            var mesh: MeshInstance3D = found as MeshInstance3D
            if mesh.mesh == null:
                continue
            var bbox: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
            if not initialized:
                bounds = bbox
                initialized = true
            else:
                bounds = bounds.merge(bbox)
            for surface in range(mesh.mesh.get_surface_count()):
                var array_surface: Array = mesh.mesh.surface_get_arrays(surface)
                if array_surface.size() > Mesh.ARRAY_INDEX:
                    var indices: PackedInt32Array = array_surface[Mesh.ARRAY_INDEX] as PackedInt32Array
                    approximate_triangles += indices.size()/3
                var material: BaseMaterial3D = mesh.get_active_material(surface) as BaseMaterial3D
                if material != null and material.albedo_texture != null:
                    texture_count += 1
        if approximate_triangles < 14000 or texture_count < 1:
            _fail("Expected high-detail PBR mesh with textured surfaces: " + name + " triangles " + str(approximate_triangles) + " textured " + str(texture_count))
            return
        if not bool(item[2]) and players.is_empty():
            _fail("Missing clip animation player for " + name)
            return
        var clips: Array = []
        for found in players:
            var player: AnimationPlayer = found as AnimationPlayer
            for clip in player.get_animation_list():
                clips.append(str(clip).to_lower())
            if player.has_animation("idle"):
                player.play("idle")
                player.advance(0.16)
        if not bool(item[2]) and not clips.has("idle"):
            _fail("HD model without imported idle animation: " + name + str(clips))
            return
        var height: float = maxf(0.01,bounds.size.y)
        var factor: float = 2.7 / height
        model.scale = Vector3.ONE * factor
        model.position.y = -bounds.position.y * factor
        camera.position = Vector3(3.0,3.15,7.0)
        camera.look_at(Vector3(0,1.4,0),Vector3.UP)
        await process_frame
        await RenderingServer.frame_post_draw
        var image: Image = root.get_texture().get_image()
        var output: String = "res://build/hd-%s.png" % name
        if image.save_png(output) != OK:
            _fail("Failed actual Godot screenshot: " + output)
            return
        print("HD CHARACTER VERIFIED ",name," tris=",approximate_triangles," pbrSurfaces=",texture_count," skins=",skeletons.size()," clips=",clips," screenshot=",output)
        if name == "marsh_direwolf":
            var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
            for index in range(skeleton.get_bone_count()):
                print("HD WOLF BONE ",index," ",skeleton.get_bone_name(index)," rest=",skeleton.get_bone_global_rest(index).origin)
        found_total += 1
        world.remove_child(model)
        model.queue_free()
        await process_frame
    if found_total != 4:
        _fail("Insufficient unique 3D models")
        return
    print("HD CHARACTER QA PASS: 4 genuine 3D PBR GLBs, imported animations and portrait Godot renders")
    quit(0)
