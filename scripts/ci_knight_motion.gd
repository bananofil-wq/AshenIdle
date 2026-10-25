extends SceneTree
# Real Godot portrait QA: Cinder Knight only. No fake demonstration frames.
# Required beats: idle/walk, three heavy melee basics and two Inferno slams.

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
    game.set("tick", -1000.0) # only the scripted, real attacks fire in this QA
    game.set("skill_cooldowns", [999.0, 999.0, 999.0])
    game.set("hp", game.call("_max_hp"))
    game.set("mp", game.call("_max_mp"))
    game.call("_spawn_enemy")
    var knight: Node3D = game.get("hero") as Node3D
    var vfx: Node3D = game.get("cinematic_skills") as Node3D
    if knight == null or vfx == null:
        push_error("KNIGHT QA FAIL: missing hero or cinematic effects")
        quit(3)
        return
    if knight.find_children("CinderWarhammer", "Node3D", true, false).is_empty():
        push_error("KNIGHT QA FAIL: no hand-mounted warhammer in playable rig")
        quit(4)
        return
    var points: PackedVector3Array = game.get("dungeon_points")
    if points.size() > 1:
        knight.position = points[1] + Vector3(0, 0, 3.5)
    game.call("_refresh")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/knight-motion"))
    for frame in range(270):
        # The first 50 frames allow genuine idle / walking animations.
        if frame in [50, 73, 96]:
            if (game.get("arena_mobs") as Array).is_empty():
                game.call("_spawn_enemy")
            var victim: Node3D = game.call("_choose_target") as Node3D
            if victim != null and is_instance_valid(victim):
                knight.position = victim.position + Vector3(0, 0, 1.78)
                game.call("_fight")
        if frame in [122, 215]:
            if (game.get("arena_mobs") as Array).is_empty():
                game.call("_spawn_enemy")
            var victim: Node3D = game.call("_choose_target") as Node3D
            if victim != null and is_instance_valid(victim):
                knight.position = victim.position + Vector3(0, 0, 1.82)
            game.set("mp", game.call("_max_mp"))
            game.set("skill_cooldowns", [999.0, 999.0, 0.0])
            game.call("_use_skill", 2)
        await RenderingServer.frame_post_draw
        var shot: Image = root.get_texture().get_image()
        if shot.is_empty() or shot.save_jpg("res://build/knight-motion/%03d.jpg" % frame, 0.90) != OK:
            push_error("KNIGHT QA FAIL: motion frame %d" % frame)
            quit(5)
            return
    var counts: Dictionary = vfx.get("signature_casts")
    var swings: int = int(vfx.get("hammer_basic_casts"))
    var impacts: int = int(vfx.get("hammer_basic_impacts"))
    if swings < 3 or impacts < 3 or int(counts.get("inferno", 0)) < 2:
        push_error("KNIGHT QA FAIL: basics=%d, contacts=%d, infernos=%d" %
            [swings, impacts, int(counts.get("inferno", 0))])
        quit(6)
        return
    print("KNIGHT QA PASS: 3 heavy hammer strikes + 2 Inferno casts, true Godot portrait footage")
    quit(0)
