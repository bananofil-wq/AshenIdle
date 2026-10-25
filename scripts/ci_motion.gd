extends SceneTree
# Capture a real Godot simulation for visual QA, never a staged or AI mock-up.
# The frames are assembled into a short portrait-mode MP4 by GitHub Actions.

func _initialize() -> void:
    call_deferred("_capture")

# QA-only class montage: four genuine game scenes, one signature attack
# per hero. There is still NO player-facing class switching during a run.
func _prepare_class_reel(game: Node3D, class_id: int) -> void:
    game.call("_end_signature_pose")
    var old_hero: Node3D = game.get("hero") as Node3D
    if old_hero != null and is_instance_valid(old_hero):
        old_hero.queue_free()
    game.set("hero_class", class_id)
    game.set("level", 12)
    game.set("stage", 8)
    game.set("highest", 8)
    game.set("skill_cooldowns", [0.0, 0.0, 0.0])
    var identity: String = ["Knight", "Rogue", "Mage", "Barbarian"][class_id]
    var actor: Node3D = game.call("_make_animated_character",
        identity, Vector3(0, 0, 5), false) as Node3D
    game.set("hero", actor)
    game.set("hp", game.call("_max_hp"))
    game.set("mp", game.call("_max_mp"))
    var visuals: Node3D = game.get("cinematic_skills") as Node3D
    if visuals != null:
        visuals.call("clear_all")
    game.call("_spawn_enemy")
    var points: PackedVector3Array = game.get("dungeon_points")
    if points.size() > 1 and actor != null:
        actor.position = points[1] + Vector3(0, 0, 3.2)
        game.set("camera_focus", actor.position + Vector3(0, 0.8, -2.0))
        var camera: Camera3D = game.get("camera_ref") as Camera3D
        if camera != null:
            camera.global_position = actor.position + Vector3(0, 15.9, 17.4)
            camera.look_at(actor.position + Vector3(0, 0.8, -2.0), Vector3.UP)
    game.call("_refresh")


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
    _prepare_class_reel(game, 0)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/motion"))
    for frame in range(210):
        # Each segment captures real combat and imported skin animation.
        # This is a four-class showcase, not a claim of live class swapping.
        if frame == 53:
            _prepare_class_reel(game, 2) # Ember Mage, Chain Lightning
        elif frame == 106:
            _prepare_class_reel(game, 3) # Dusk Reaper, Nightfall
        elif frame == 159:
            _prepare_class_reel(game, 1) # Ash Ranger, Arrowfall
        if frame in [7, 60, 113, 166]:
            game.set("mp", game.call("_max_mp"))
            game.set("skill_cooldowns", [0.0, 0.0, 0.0])
            game.call("_use_skill", 1 if frame == 60 else 2)
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
    var vfx: Node3D = game.get("cinematic_skills") as Node3D
    var signature_counts: Dictionary = vfx.get("signature_casts") if vfx != null else {}
    for signature in ["inferno", "chain_lightning", "nightfall", "arrowfall"]:
        if int(signature_counts.get(signature, 0)) < 1:
            push_error("ATTACK REEL QA FAIL: missing " + signature)
            quit(5)
            return
    print("ATTACK REEL QA PASS: all four genuine Godot signature attacks in 210 frames / 7 seconds")
    quit(0)
