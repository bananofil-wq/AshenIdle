extends Control
# Decorative frame painted in native Godot so that gameplay controls remain
# interactive, scalable, and safe on both 720x1280 and tall phone displays.
@export var mode: String = "panel"
@export var accent: Color = Color("e6a65b")
func _diamond(c: Vector2, radius: float, color: Color) -> void:
    draw_colored_polygon(PackedVector2Array([
        c + Vector2(0,-radius), c + Vector2(radius,0),
        c + Vector2(0,radius), c + Vector2(-radius,0)]), color)

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w < 10.0 or h < 10.0:
        return
    var trim: Color = accent
    var old_gold := Color("75401e")
    var pale := Color("ffe1a0")
    var dark := Color("071023")
    var r: float = 19.0 if mode != "skill" else 24.0
    # More than one thin outline: inset bevel, raised metal and dark glass.
    draw_rect(Rect2(3,4,w-6,h-8), Color(0.18,0.075,0.020,0.69), true)
    draw_rect(Rect2(8,7,w-16,h-14), dark, true)
    draw_rect(Rect2(4,4,w-8,h-8), old_gold, false, 6)
    draw_rect(Rect2(7,7,w-14,h-14), trim, false, 2.8)
    draw_rect(Rect2(11,11,w-22,h-22), Color("533921"), false, 1.0)
    draw_line(Vector2(20,14),Vector2(w-20,14),pale * Color(1,1,1,0.6),1.1,true)
    draw_line(Vector2(19,h-15),Vector2(w-19,h-15),old_gold,1.8,true)
    if mode == "skill":
        var radius: float = minf(w*0.43,h*0.41)
        var center := Vector2(w*.5, radius+9.0)
        draw_circle(center,radius+3,Color("51270f"))
        draw_circle(center,radius,trim)
        draw_circle(center,radius-5,Color("07142a"))
        draw_circle(center,radius-10,Color("10233b"))
        draw_arc(center,radius-2,PI*1.09,PI*1.91,32,pale,2.2,true)
    for sx in [0.0,1.0]:
        for sy in [0.0,1.0]:
            var origin := Vector2(7.0 if sx == 0.0 else w-7.0,
                7.0 if sy == 0.0 else h-7.0)
            var dx: float = 1.0 if sx == 0.0 else -1.0
            var dy: float = 1.0 if sy == 0.0 else -1.0
            draw_line(origin, origin+Vector2(dx*27,0),pale,2.2,true)
            draw_line(origin, origin+Vector2(0,dy*26),pale,2.2,true)
            draw_line(origin+Vector2(dx*4,dy*17),origin+Vector2(dx*17,dy*4),
                trim,2.1,true)
            draw_line(origin+Vector2(dx*10,dy*10),origin+Vector2(dx*26,dy*18),
                old_gold,1.7,true)
            _diamond(origin+Vector2(dx*17,dy*17),4.0,trim)
    if mode == "banner" or mode == "dock":
        _diamond(Vector2(w*.5,h-11),11.0,trim)
        _diamond(Vector2(w*.5,h-11),5.0,pale)
    if mode == "hero":
        _diamond(Vector2(w*.5,7),8.0,pale)
    if mode == "journey":
        draw_line(Vector2(21,45),Vector2(w-21,45),
            Color("966536"),1.0,true)
