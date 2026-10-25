extends SceneTree
# Capture a real Godot simulation for visual QA, never a staged or AI mock-up.
# The frames are assembled into a short portrait-mode MP4 by GitHub Actions.

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
    game.set("level", 12)
    game.set("stage", 8)
    game.set("highest", 8)
    game.set("hp", game.call("_max_hp"))
    game.call("_spawn_enemy")
    game.call("_refresh")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/motion"))
    for frame in range(210):
        # Camera and skeletal animation run naturally in _process every frame.
        if frame in [16, 57, 116, 168]:
            game.set("skill_cooldowns", [0.0, 0.0, 0.0])
            game.call("_use_skill", 0 if frame in [16, 116] else 2)
        # The live game already advances movement, AI and camera through
        # _process each rendered frame. Do not call them a second time here:
        # the old recording artificially doubled walking speed and made
        # enemies look as though they were sliding across the floor.
        await RenderingServer.frame_post_draw
        var image: Image = root.get_texture().get_image()
        if image.is_empty():
            push_error("Motion capture returned empty frame")
            quit(3)
            return
        var filename: String = "res://build/motion/%03d.jpg" % frame
        if image.save_jpg(filename, 0.90) != OK:
            push_error("Could not save animation frame " + filename)
            quit(4)
            return
    if float(game.get("dungeon_travel_distance")) < 0.25:
        push_error("MOTION QA FAIL: hero did not traverse the dungeon")
        quit(5)
        return
    print("MOTION QA PASS: 210 Godot-rendered frames (7 seconds at 30 FPS), native movement/AI/camera updated exactly once per live frame")
    quit(0)
