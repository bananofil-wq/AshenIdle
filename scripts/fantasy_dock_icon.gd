extends Control
# Decorative, touch-through illustrations for the two compact dock buttons.
@export var kind: String = "auto":
    set(value):
        kind = value
        queue_redraw()
@export var active: bool = true:
    set(value):
        active = value
        queue_redraw()

func _draw() -> void:
    var scale_ratio: float = minf(size.x,size.y)/72.0
    draw_set_transform(Vector2((size.x-72*scale_ratio)*0.5,(size.y-72*scale_ratio)*0.5),
        0,Vector2.ONE*scale_ratio)
    var c := Vector2(36,36)
    draw_circle(c,34,Color("071d25"))
    draw_arc(c,32,0,TAU,48,Color("d7a266"),3.4,true)
    draw_arc(c,27,PI*1.1,PI*1.9,30,Color("fff2a7"),1.2,true)
    if kind == "auto":
        draw_line(Vector2(19,51),Vector2(53,17),Color("e7e0cb"),7,true)
        draw_line(Vector2(19,17),Vector2(53,51),Color("e7e0cb"),7,true)
        draw_line(Vector2(20,52),Vector2(54,18),Color("bd894d"),3,true)
        draw_line(Vector2(20,18),Vector2(54,52),Color("bd894d"),3,true)
        draw_line(Vector2(14,42),Vector2(29,57),Color("ae6c35"),5,true)
        draw_line(Vector2(14,29),Vector2(29,14),Color("ae6c35"),5,true)
        draw_line(Vector2(44,14),Vector2(59,29),Color("ae6c35"),5,true)
        draw_line(Vector2(44,57),Vector2(59,42),Color("ae6c35"),5,true)
        draw_circle(Vector2(60,59),8.8,Color("2af06d") if active else Color("777880"))
        draw_arc(Vector2(60,59),9.5,0,TAU,24,Color("ddffe9") if active else Color("bcbec4"),2.1,true)
    else:
        draw_colored_polygon(PackedVector2Array([
            Vector2(18,25),Vector2(54,25),Vector2(58,56),
            Vector2(46,62),Vector2(26,62),Vector2(14,56)]),
            Color("96603a"))
        draw_polyline(PackedVector2Array([
            Vector2(18,25),Vector2(54,25),Vector2(58,56),
            Vector2(46,62),Vector2(26,62),Vector2(14,56),Vector2(18,25)]),
            Color("f0ba79"),3.4,true)
        draw_arc(Vector2(36,28),13,PI,TAU,26,Color("efc89b"),5,true)
        draw_colored_polygon(PackedVector2Array([
            Vector2(17,29),Vector2(55,29),Vector2(51,43),
            Vector2(38,49),Vector2(24,43)]),Color("c78c53"))
        draw_rect(Rect2(32,39,9,12),Color("ffdf94"),true)
        draw_rect(Rect2(34,41,5,8),Color("8e5834"),false,1.4)
        draw_circle(Vector2(61,10),7,Color("fb5138"))
        draw_circle(Vector2(61,10),3,Color("ffc1ad"))
    draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
