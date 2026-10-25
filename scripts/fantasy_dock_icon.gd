extends Control
# Responsive textured medal for Auto and Inventory menu. The live indicator
# follows auto-equipment toggle; the bag notification is decorative for now.
const ATLAS: Texture2D = preload("res://assets/ui/premium_hud_atlas.svg")
@export var kind: String = "auto":
    set(value):
        kind = value
        queue_redraw()
@export var active: bool = true:
    set(value):
        active = value
        queue_redraw()

func _draw() -> void:
    var region := Rect2(170, 650, 160, 160) if kind == "bag" else Rect2(0, 650, 160, 160)
    draw_texture_rect_region(ATLAS, Rect2(Vector2.ZERO,size), region,
        Color.WHITE if kind == "bag" or active else Color(0.67,0.69,0.74), false)
    if kind == "auto" and not active:
        draw_circle(size * Vector2(0.78,0.8),size.x*0.085,Color("7a8592"))
