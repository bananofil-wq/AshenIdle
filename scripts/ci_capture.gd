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
    var err := frame.save_png("res://build/gameplay-preview.png")
    if err != OK:
        push_error("Cannot save gameplay preview: " + str(err))
        quit(4)
        return
    print("Saved gameplay-preview.png ", frame.get_width(), "x", frame.get_height())
    quit()
