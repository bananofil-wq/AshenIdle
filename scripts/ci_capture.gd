extends SceneTree
# Offscreen visual smoke test. Runs with a virtual X11 display and OpenGL renderer.
# Captures what the portrait-mode Godot game actually draws, rather than a mockup.

func _initialize() -> void:
    call_deferred("_render_test")

func _render_test() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        push_error("Cannot load game scene")
        quit(2)
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    current_scene = game

    await create_timer(2.0).timeout
    await RenderingServer.frame_post_draw

    var frame: Image = root.get_texture().get_image()
    if frame.is_empty():
        push_error("Captured viewport is empty")
        quit(3)
        return
    var suffix: String = OS.get_environment("ASHEN_CAPTURE_SUFFIX")
    var output_path: String = "res://build/gameplay-preview" + ("-" + suffix if suffix != "" else "") + ".png"
    var err := frame.save_png(output_path)
    if err != OK:
        push_error("Cannot save gameplay preview: " + str(err))
        quit(4)
        return
    print("Saved ", output_path, " ", frame.get_width(), "x", frame.get_height())

    if suffix == "tall":
        game.call("_hide_legendary")
        var test_item := {
            "name": "Seven Star Greatsword",
            "slot": "Weapon",
            "damage": 68, "hp": 98, "crit": 12, "speed": 8,
            "element": "VOID", "elemental": 32, "set": "Gravewarden"
        }
        game.call("_show_legendary", test_item)
        await create_timer(0.18).timeout
        await RenderingServer.frame_post_draw
        var legendary_frame: Image = root.get_texture().get_image()
        legendary_frame.save_png("res://build/legendary-preview.png")

        game.call("_hide_legendary")
        game.call("_open_talent_panel")
        await create_timer(0.18).timeout
        await RenderingServer.frame_post_draw
        var talent_frame: Image = root.get_texture().get_image()
        talent_frame.save_png("res://build/talent-preview.png")
        print("Captured legendary and talent modal QA screenshots")

    quit()
