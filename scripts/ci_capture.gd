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

func _check_modal_fits(panel: Control, label: String) -> bool:
    # Never accept a screenshot as good when Godot silently expands a Button
    # beyond the phone width (long descriptions used to escape on the right).
    var screen: Vector2 = root.get_visible_rect().size
    var frame: Rect2 = panel.get_global_rect()
    print("MOBILE MODAL QA ", label, " screen=", screen, " frame=", frame)
    if frame.position.x < -1.0 or frame.end.x > screen.x + 1.0 or frame.position.y < -1.0 or frame.end.y > screen.y + 1.0:
        push_error(label + ": modal frame exceeds phone viewport")
        return false
    for candidate in panel.find_children("*", "Button", true, false):
        var button: Button = candidate as Button
        var bounds: Rect2 = button.get_global_rect()
        if bounds.position.x < -2.0 or bounds.end.x > screen.x + 2.0 or bounds.position.y < -2.0 or bounds.end.y > screen.y + 2.0:
            push_error(label + ": button clipped offscreen: " + button.text.substr(0, 30))
            return false
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
    if not _check_modal_fits(game.get("hero_overlay") as Control, "Startup class selection"):
        quit(22)
        return
    if not await _save_capture("startup-hero-selection.png"):
        quit(12)
        return
    game.call("_select_class", 0)
    game.call("_hide_legendary")
    game.set("stage", 8)
    game.set("highest", 8)
    game.set("level", 12)
    game.set("gold", 840)
    game.set("hp", game.call("_max_hp"))
    game.set("mp", game.call("_max_mp"))
    game.call("_spawn_enemy")
    game.call("_refresh")
    await create_timer(0.45).timeout
    game.call("_hide_legendary")
    var suffix: String = OS.get_environment("ASHEN_CAPTURE_SUFFIX")
    var gameplay_name: String = "gameplay-preview" + ("-" + suffix if suffix != "" else "") + ".png"
    if not await _save_capture(gameplay_name):
        quit(3)
        return
    # The approved HUD has exactly three big abilities and a compact
    # collapsible menu. Capture the OPEN drawer so a hidden or overflowing
    # navigation panel cannot masquerade as a finished mobile interface.
    var new_skills: Array = game.get("skill_buttons") as Array
    if new_skills.size() != 3:
        push_error("Compact fantasy HUD must have exactly three visible abilities")
        quit(40)
        return
    var dock: Control = (game.get("overlay") as Control).get_node_or_null("BottomHUD")
    if dock == null or not _check_modal_fits(dock, "Compact ability dock"):
        quit(41)
        return
    game.call("_toggle_quick_menu")
    await create_timer(0.10).timeout
    var drawer: Control = game.get("quick_menu") as Control
    if drawer == null or not drawer.visible or not _check_modal_fits(drawer, "Fantasy quick menu"):
        quit(42)
        return
    if not await _save_capture("gameplay-preview-menu.png"):
        quit(43)
        return
    game.call("_dismiss_quick_menu")

    if suffix == "tall":
        # Reference-video VFX QA: snapshot the actual 3D rune/crack/ultimate
        # system, with the combat camera centred on the effects.
        var arena_positions: PackedVector3Array = game.get("dungeon_points")
        var fx_center: Vector3 = arena_positions[1] if arena_positions.size() > 1 else Vector3.ZERO
        var fx_hero: Node3D = game.get("hero") as Node3D
        fx_hero.position = fx_center + Vector3(0, 0, 2.4)
        var fx_camera: Camera3D = game.get("camera_ref") as Camera3D
        fx_camera.position = fx_center + Vector3(0, 19.0, 19.0)
        fx_camera.look_at(fx_center, Vector3.UP)
        game.set("camera_focus", fx_center)
        var vfx: Node3D = game.get("cinematic_skills") as Node3D
        vfx.call("cast", 3, 2, 6, fx_hero.global_position, fx_center,
            [fx_center + Vector3(1.5, 0, 0), fx_center + Vector3(-1, 0, -1)])
        await create_timer(0.12).timeout
        if not await _save_capture("skills-ultimate-shadow.png"):
            quit(27)
            return
        # Isolate the lightning art so the previous lasting shadow ultimate
        # does not turn the second screenshot into a layered spiderweb.
        vfx.call("clear_all")
        vfx.call("cast", 2, 1, 6, fx_hero.global_position, fx_center,
            [fx_center + Vector3(1.5, 0, 0), fx_center + Vector3(-1.0, 0, -1)])
        await create_timer(0.09).timeout
        if not await _save_capture("skills-chain-lightning.png"):
            quit(28)
            return
        # Capture each of the ten fantasy biomes from the actual Godot renderer.
        # Each floor creates a new traversable path, not a recolored static arena.
        for biome_floor in [11, 21, 31, 41, 51, 61, 71, 81, 91]:
            game.set("stage", biome_floor)
            game.call("_spawn_enemy")
            game.call("_refresh")
            await create_timer(0.12).timeout
            if not await _save_capture("biome-%d.png" % biome_floor):
                quit(14)
                return
            if biome_floor == 11:
                # Render the identical viewpoint in low-power mode to verify
                # real GPU batching/culling, rather than claim 60 FPS from CI.
                var full_draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
                var scene_builder: Node3D = game.get("dungeon_map") as Node3D
                var viewpoint: Node3D = game.get("hero") as Node3D
                scene_builder.call("set_graphics_preset", 0)
                scene_builder.call("set_lod_focus", viewpoint.position, true)
                await create_timer(0.13).timeout
                if not await _save_capture("biome-11-performance.png"):
                    quit(32)
                    return
                var limited_draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
                print("MOBILE RENDER QA: forest-high=", full_draws, " draw_calls, forest-low=", limited_draws, " draw_calls")
                if limited_draws > full_draws + 12:
                    push_error("Mobile performance tier increased forest draw calls")
                    quit(33)
                    return
                scene_builder.call("set_graphics_preset", 2)
                scene_builder.call("set_lod_focus", viewpoint.position, true)

        # Dedicated visual QA of the boss arena for all ten visual themes.
        # Each tenth floor includes the unique biome-specific boss sanctuary.
        for milestone in [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
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
        # The ultimate is level-gated. QA must actually unlock and cast it,
        # otherwise a screenshot of "LOCKED" silently passes as spell art.
        game.set("level", 10)
        game.set("mp", game.call("_max_mp"))
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
        if not _check_modal_fits(game.get("skill_overlay") as Control, "Talent panel"):
            quit(44)
            return
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
        # Inventory captures need collected items now that drop beams are
        # actual physical pickup entities rather than instant inventory grants.
        var preview_loot: Array = (game.get("ground_drops") as Array).duplicate()
        game.call("_clear_ground_drops")
        for pickup in preview_loot:
            game.call("_collect_ground_drop", pickup, true)
        game.call("_hide_legendary")
        game.call("_show_inventory")
        await create_timer(0.16).timeout
        if not _check_modal_fits(game.get("inventory_overlay") as Control, "Inventory panel"):
            quit(45)
            return
        if not await _save_capture("inventory-preview.png"):
            quit(7)
            return
        game.call("_close_inventory_panel")
        game.set("level", 75)
        game.call("_open_evolution_panel")
        await create_timer(0.12).timeout
        if not _check_modal_fits(game.get("evolution_overlay") as Control, "Evolution level 75"):
            quit(23)
            return
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
        # Capture the actual new looting decision at portrait resolution.
        game.set("auto_equip", false)
        var comparison_item: Dictionary = {
            "slot": "Weapon", "name": "Ashen Runeblade",
            "damage": 9000, "hp": 6000, "crit": 35, "speed": 30,
            "element": "VOID", "elemental": 600, "set": "Gravewarden",
            "rarity": "LEGENDARY"
        }
        for mob in (game.get("arena_mobs") as Array).duplicate():
            if is_instance_valid(mob):
                mob.queue_free()
        (game.get("arena_mobs") as Array).clear()
        var hero_pos: Vector3 = (game.get("hero") as Node3D).position
        game.call("_place_ground_drop", hero_pos, Color("ffbf75"), comparison_item)
        game.call("_update_ground_pickup")
        await create_timer(0.12).timeout
        if not _check_modal_fits(game.get("drop_prompt") as Control, "Manual loot comparison"):
            quit(29)
            return
        var compare_bounds: Rect2 = (game.get("drop_prompt") as Control).get_global_rect()
        if compare_bounds.size.y > root.get_visible_rect().size.x * 1.15:
            push_error("Loot comparison became an oversized, mostly-empty vertical panel")
            quit(31)
            return
        if not await _save_capture("loot-comparison-preview.png"):
            quit(30)
            return
        game.call("_answer_drop_comparison", false)
        game.set("auto_equip", true)
        print("Visual QA PASS: hero selection, portrait combat, physical loot/comparison, floor-10 boss, talents and evolutions")
    quit(0)
