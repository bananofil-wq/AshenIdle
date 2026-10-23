extends SceneTree
# Deterministic screenshot QA: real Godot renders without stale CI test save data.

func _initialize() -> void:
    call_deferred("_render_test")

func _save_capture(filename: String) -> bool:
    await RenderingServer.frame_post_draw
    var frame: Image = root.get_texture().get_image()
    if frame.is_empty():
        push_error("Cannot capture render: " + filename)
        return false
    var err: Error = frame.save_png("res://build/" + filename)
    if err != OK:
        push_error("Failed to save " + filename + ": " + str(err))
        return false
    print("Saved build/", filename, " (", frame.get_width(), "x", frame.get_height(), ")")
    return true

func _render_test() -> void:
    # Game CI integration tests intentionally save unusual stats and gear;
    # never let those leftovers make previews look like actual starting gameplay.
    var save_path: String = ProjectSettings.globalize_path("user://save_v2.json")
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)

    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        push_error("Cannot load game scene")
        quit(2)
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    current_scene = game

    await create_timer(0.20).timeout
    if not (game.get("hero_overlay") as Control).visible:
        push_error("Initial hero chooser is missing")
        quit(11)
        return
    if not await _save_capture("startup-hero-selection.png"):
        quit(12)
        return
    game.call("_select_class", 0)
    game.call("_hide_legendary")
    game.set("stage", 8)
    game.set("highest", 8)
    game.set("level", 9)
    game.set("gold", 840)
    game.set("hp", game.call("_max_hp"))
    game.call("_spawn_enemy")
    game.call("_refresh")
    await create_timer(0.45).timeout
    game.call("_hide_legendary")
    var suffix: String = OS.get_environment("ASHEN_CAPTURE_SUFFIX")
    var gameplay_name: String = "gameplay-preview" + ("-" + suffix if suffix != "" else "") + ".png"
    if not await _save_capture(gameplay_name):
        quit(3)
        return

    if suffix == "tall":
        # Inspect actual hero asset at game size with mobs hidden (not concept art).
        for mob in (game.get("arena_mobs") as Array).duplicate():
            if is_instance_valid(mob):
                mob.queue_free()
        (game.get("arena_mobs") as Array).clear()
        game.call("_refresh")
        await create_timer(0.10).timeout
        if not await _save_capture("hero-detail-preview.png"):
            quit(9)
            return
        game.call("_spawn_enemy")
        game.set("skill_cooldowns", [0.0, 0.0, 0.0])
        game.call("_use_skill", 2)
        await create_timer(0.11).timeout
        if not await _save_capture("spell-effects-preview.png"):
            quit(10)
            return
        # Second screenshot exposes the real boss health bar and boss model.
        game.set("stage", 10)
        game.set("highest", 10)
        game.set("hp", game.call("_max_hp"))
        game.call("_spawn_enemy")
        game.call("_refresh")
        await create_timer(0.20).timeout
        game.call("_hide_legendary")
        if not await _save_capture("boss-preview.png"):
            quit(4)
            return

        var test_item := {
            "name": "Seven Star Greatsword",
            "slot": "Weapon",
            "damage": 68, "hp": 98, "crit": 12, "speed": 8,
            "element": "VOID", "elemental": 32, "set": "Gravewarden"
        }
        game.call("_show_legendary", test_item)
        await create_timer(0.16).timeout
        if not await _save_capture("legendary-preview.png"):
            quit(5)
            return

        game.call("_hide_legendary")
        game.call("_open_talent_panel")
        await create_timer(0.16).timeout
        if not await _save_capture("talent-preview.png"):
            quit(6)
            return

        game.call("_close_talent_panel")
        game.call("_show_hero_panel")
        await create_timer(0.16).timeout
        if not await _save_capture("hero-selection-preview.png"):
            quit(8)
            return
        game.call("_close_hero_panel")
        for i in range(6):
            game.call("_drop_loot")
        game.call("_hide_legendary")
        game.call("_show_inventory")
        await create_timer(0.16).timeout
        if not await _save_capture("inventory-preview.png"):
            quit(7)
            return
        print("Visual QA PASS: first-launch character selection, portrait combat, hero asset, spell VFX, floor-10 boss, loot, talent tree and inventory")
    quit(0)
