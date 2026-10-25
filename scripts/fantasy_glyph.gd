extends Control
# High-detail artwork from the game's own atlas, not platform glyphs.
# This remains a real touch-through Godot Control and changes per class.
const ATLAS: Texture2D = preload("res://assets/ui/premium_hud_atlas.svg")
@export var class_id: int = 0:
    set(value):
        class_id = value
        queue_redraw()
@export var ability_id: int = 0:
    set(value):
        ability_id = value
        queue_redraw()
@export var locked: bool = false:
    set(value):
        locked = value
        queue_redraw()

func _draw() -> void:
    var icon_index: int = clampi(class_id, 0, 3) * 3 + clampi(ability_id, 0, 2)
    var ix: int = icon_index % 6
    var iy: int = int(icon_index / 6)
    var source := Rect2(965 + 167 * ix, 305 + 169 * iy, 160, 160)
    var tint := Color(0.57, 0.58, 0.65, 0.81) if locked else Color.WHITE
    draw_texture_rect_region(ATLAS, Rect2(Vector2.ZERO, size),
        source, tint, false)
