extends SceneTree
# Combat close-up QA recorded by Godot. This is a SCRIPTED preview of the
# real hero model, weapons, animations and VFX (not normal autoplay footage).
# Three heavy basic strikes and two Inferno impacts must remain visible.

func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var save_path: String = ProjectSettings.globalize_path("user://save_v2.json")
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
    var game: Node3D = load("res://scenes/main.tscn").instantiate() as Node3D
    if game == null:
        quit(2)
        return
    root.add_child(game)
    current_scene = game
    game.call("_select_class", 0)
    game.set("level", 14)
    game.set("stage", 8)
    game.set("highest", 8)
    game.set("skill_cooldowns", [999.0, 999.0, 999.0])
    game.set("hp", game.call("_max_hp"))
    game.set("mp", game.call("_max_mp"))
    game.call("_spawn_enemy")
    var knight: Node3D = game.get("hero") as Node3D
    var vfx: Node3D = game.get("cinematic_skills") as Node3D
    var camera: Camera3D = game.get("camera_ref") as Camera3D
    if knight == null or vfx == null or camera == null:
        push_error("KNIGHT QA FAIL: missing hero, camera or VFX")
        quit(3)
        return
    if knight.find_children("CinderWarhammer", "Node3D", true, false).is_empty():
        push_error("KNIGHT QA FAIL: no hand-mounted warhammer in playable rig")
        quit(4)
        return

    # The old recording let AI clear the chamber mid-film and then framed
    # two Inferno casts against empty terrain. Stop game autopilot only in
    # this QA reel; native AnimationPlayers + VFX remain fully active.
    game.set_process(false)
    var points: PackedVector3Array = game.get("dungeon_points")
    if points.size() > 1:
        knight.position = points[1] + Vector3(0, 0, 1.4)
    knight.rotation.y = 0.0
    var mobs: Array = game.get("arena_mobs")
    if mobs.size() < 4:
        push_error("KNIGHT QA FAIL: not enough real enemy models")
        quit(7)
        return
    var survivors: Array = []
    var offsets := [
        Vector3(-1.45, 0, 3.20),
        Vector3(1.30, 0, 3.60),
        Vector3(-0.65, 0, 4.30),
        Vector3(0.55, 0, 4.65)
    ]
    for i in range(mobs.size()):
        var enemy: Node3D = mobs[i] as Node3D
        if enemy == null or not is_instance_valid(enemy):
            continue
        if i < 4:
            enemy.position = knight.position + offsets[i]
            enemy.rotation.y = PI
            enemy.set_meta("hp", 999999.0)
            survivors.append(enemy)
        else:
            enemy.queue_free()
    game.set("arena_mobs", survivors)
    # Keep the camera close enough to examine head, hands and hammer
    # while retaining a three-dimensional view of the actual cave.
    camera.global_position = knight.global_position + Vector3(1.55, 8.3, 11.4)
    camera.fov = 41.0
    camera.look_at(knight.global_position + Vector3(0, 0.95, 2.1), Vector3.UP)
    game.call("_refresh")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/knight-motion"))
    for frame in range(270):
        if frame in [45, 65, 85]:
            game.call("_fight")
        if frame in [112, 202]:
            game.set("mp", game.call("_max_mp"))
            game.set("skill_cooldowns", [999.0, 999.0, 0.0])
            game.call("_use_skill", 2)
        # Without game._process, update only the actual signature body pose.
        game.call("_update_signature_pose", 1.0 / 30.0)
        await RenderingServer.frame_post_draw
        var shot: Image = root.get_texture().get_image()
        if shot.is_empty() or shot.save_jpg("res://build/knight-motion/%03d.jpg" % frame, 0.90) != OK:
            push_error("KNIGHT QA FAIL: motion frame %d" % frame)
            quit(5)
            return
    var counts: Dictionary = vfx.get("signature_casts")
    var swings: int = int(vfx.get("hammer_basic_casts"))
    var impacts: int = int(vfx.get("hammer_basic_impacts"))
    if survivors.size() < 4 or swings < 3 or impacts < 3 or int(counts.get("inferno", 0)) < 2:
        push_error("KNIGHT QA FAIL: survivors=%d basics=%d contacts=%d infernos=%d" %
            [survivors.size(), swings, impacts, int(counts.get("inferno", 0))])
        quit(6)
        return
    print("KNIGHT QA PASS: 4 visible targets, 3 hammer hits and 2 Infernos")
    quit(0)
