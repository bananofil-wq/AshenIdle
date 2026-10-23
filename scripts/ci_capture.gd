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
    # Software-rendered CI is not a proxy for phone FPS, but draw-call and
    # node counters expose regressions and confirm actual MultiMesh use.
    var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    print("RENDER QA ", filename, ": draw_calls=", draws, " scene_nodes=", nodes)
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
        # Capture the five different biome families from the actual Godot renderer.
        # Each floor creates a new traversable path, not a recolored static arena.
        for biome_floor in [11, 21, 31, 41]:
            game.set("stage", biome_floor)
            game.call("_spawn_enemy")
            game.call("_refresh")
            await create_timer(0.12).timeout
            if not await _save_capture("biome-%d.png" % biome_floor):
                quit(14)
                return
        # Dedicated visual QA of the boss arena for all five visual themes.
        # Each tenth floor includes the unique biome-specific boss sanctuary.
        for milestone in [10, 20, 30, 40, 50]:
            game.set("stage", milestone)
            game.set("highest", milestone)
            game.call("_spawn_enemy")
            game.call("_complete_wave")
            game.call("_complete_wave")
            # Render the real boss sanctum, not the distant starting portal:
            # moving the hero here is screenshot QA only, not shipped gameplay.
            var boss_points: PackedVector3Array = game.get("dungeon_points")
            (game.get("hero") as Node3D).position = boss_points[3] + Vector3(0, 0, 2.3)
            game.set("camera_focus", boss_points[3])
            (game.get("camera_ref") as Camera3D).position = boss_points[3] + Vector3(0, 21.3, 22.6)
            game.call("_refresh")
            await create_timer(0.18).timeout
            if not await _save_capture("boss-biome-%d.png" % milestone):
                quit(15)
                return
        game.set("stage", 8)
        game.call("_spawn_enemy")
        game.call("_refresh")
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
        # The boss guards the last room, not the entrance.
        game.call("_complete_wave")
        game.call("_complete_wave")
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
        game.call("_close_inventory_panel")
        game.set("level", 75)
        game.call("_open_evolution_panel")
        if not await _save_capture("evolution-75-preview.png"):
            quit(20)
            return
        game.call("_choose_evolution", 0)
        game.set("level", 170)
        game.call("_open_evolution_panel")
        game.call("_choose_evolution", 1)
        game.set("level", 250)
        game.call("_open_evolution_panel")
        game.call("_choose_evolution", 2)
        game.set("level", 500)
        game.call("_open_evolution_panel")
        if not await _save_capture("evolution-500-preview.png"):
            quit(21)
            return
        game.call("_close_evolution_panel")
        print("Visual QA PASS: hero selection, portrait combat, floor-10 boss, loot, talents and level-75/500 three-way evolutions")
    quit(0)
