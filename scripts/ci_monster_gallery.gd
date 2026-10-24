extends SceneTree
# Contact-sheet source captures: six ACTUAL Godot monster models, never AI concepts.
const FACTORY = preload("res://scripts/forest_monster_factory.gd")

func _initialize() -> void:
    call_deferred("_capture_monsters")

func _capture_monsters() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var ambience := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("1b231d")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("d4dbcb")
    env.ambient_light_energy = 0.75
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    ambience.environment = env
    world.add_child(ambience)
    var sunlight := DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-55, -37, 0)
    sunlight.light_color = Color("ffdda7")
    sunlight.light_energy = 1.65
    sunlight.shadow_enabled = false
    world.add_child(sunlight)
    var bounce := OmniLight3D.new()
    bounce.position = Vector3(-2.5, 3.4, 4.0)
    bounce.light_color = Color("9ab9a7")
    bounce.light_energy = 0.9
    bounce.omni_range = 11.0
    world.add_child(bounce)
    var ground := MeshInstance3D.new()
    var floor := PlaneMesh.new()
    floor.size = Vector2(12,12)
    ground.mesh = floor
    ground.position.y = -0.06
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("3f4934")
    floor_material.roughness = 0.98
    ground.material_override = floor_material
    world.add_child(ground)
    var camera := Camera3D.new()
    world.add_child(camera)
    camera.current = true
    camera.fov = 39.0
    var creator = FACTORY.new()
    var species: Array = ["CORRUPTED SAPLING", "MOSS HOUND", "BROOD SPIDER",
        "REVENANT WANDERER", "THORN BRUTE", "THE ROOTMOTHER"]
    for index in range(species.size()):
        var boss: bool = index == 5
        var enemy := Node3D.new()
        enemy.name = "MonsterGallery_%d" % index
        world.add_child(enemy)
        if not creator.build(enemy, str(species[index]), index == 4, boss):
            push_error("MONSTER GALLERY FAIL: " + str(species[index]))
            quit(31)
            return
        if boss:
            camera.position = Vector3(4.8, 6.2, 12.5)
            camera.look_at(Vector3(0,3.0,0),Vector3.UP)
        else:
            camera.position = Vector3(3.2, 3.6, 7.5)
            camera.look_at(Vector3(0,1.15,0),Vector3.UP)
        var animator := enemy.get_node("CreatureAnimationPlayer") as AnimationPlayer
        animator.play("Idle")
        animator.advance(0.24)
        await process_frame
        await RenderingServer.frame_post_draw
        var image_data: Image = root.get_texture().get_image()
        if image_data.is_empty():
            push_error("MONSTER GALLERY FAIL: empty rendered image")
            quit(32)
            return
        var id: String = str(enemy.get_meta("forest_monster_id", ""))
        var dest: String = "res://build/forest-monster-%s.png" % id
        if image_data.save_png(dest) != OK:
            push_error("MONSTER GALLERY FAIL: could not save " + dest)
            quit(33)
            return
        print("MONSTER GALLERY rendered ", id, " at ", image_data.get_width(),
            "x",image_data.get_height(), " draw_calls=",
            Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        world.remove_child(enemy)
        enemy.queue_free()
        await process_frame
    print("MONSTER GALLERY PASS: six actual Godot monster views captured")
    quit(0)
