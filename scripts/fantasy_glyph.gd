extends Control
# Icon paintings run inside the real Godot buttons; each class and each
# ability has its own warm/cold signature and no placeholder system glyph.
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

func _line(points: PackedVector2Array, color: Color, width: float) -> void:
    draw_polyline(points,color,width,true)

func _draw() -> void:
    var mid := Vector2(39,38)
    var palette := [Color("ff9b3c"),Color("baffbb"),Color("7bd9ff"),Color("be83ff")]
    var tint: Color = palette[clampi(class_id,0,3)]
    if locked:
        tint = Color("6b7080")
    # Three overlapping light rings give a soft emissive halo even on GLES3.
    draw_circle(mid,38,Color(tint.r,tint.g,tint.b,0.08))
    draw_circle(mid,32,Color(tint.r,tint.g,tint.b,0.16))
    draw_circle(mid,25,Color(tint.r,tint.g,tint.b,0.14))
    var hot := tint.lightened(0.52)
    match class_id:
        0:
            match ability_id:
                0:
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(39,5),Vector2(51,23),Vector2(46,37),
                        Vector2(59,27),Vector2(57,56),Vector2(43,68),
                        Vector2(23,59),Vector2(19,39),Vector2(31,24),
                        Vector2(32,45)]),tint)
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(39,28),Vector2(44,44),Vector2(48,40),
                        Vector2(47,56),Vector2(37,62),Vector2(30,55),
                        Vector2(33,42)]),Color("fff1a5"))
                1:
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(39,8),Vector2(64,20),Vector2(59,47),
                        Vector2(39,67),Vector2(19,47),Vector2(14,20)]),
                        Color("b06d22"))
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(39,14),Vector2(57,23),Vector2(53,45),
                        Vector2(39,60),Vector2(25,45),Vector2(21,23)]),hot)
                    _line(PackedVector2Array([
                        Vector2(39,14),Vector2(39,60)]),Color("fff2c4"),2.3)
                _:
                    for i in range(3):
                        _line(PackedVector2Array([
                            Vector2(9,16+i*18),Vector2(54,9+i*15),
                            Vector2(67,19+i*14),Vector2(37,29+i*12),
                            Vector2(16,26+i*14)]),
                            hot if i == 1 else tint,5.6-i*0.9)
                    _line(PackedVector2Array([
                        Vector2(27,60),Vector2(39,73),Vector2(46,62)]),
                        Color("fff3bf"),4.4)
        1:
            match ability_id:
                0:
                    _line(PackedVector2Array([
                        Vector2(18,12),Vector2(9,38),Vector2(18,65)]),
                        hot,5)
                    _line(PackedVector2Array([
                        Vector2(20,12),Vector2(49,39),Vector2(20,65)]),tint,3)
                    _line(PackedVector2Array([
                        Vector2(17,38),Vector2(67,38)]),Color("fff5ca"),4)
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(67,38),Vector2(56,30),Vector2(56,46)]),hot)
                1:
                    draw_arc(mid,25,0,TAU,42,hot,5,true)
                    draw_arc(mid,16,0,TAU,42,tint,3,true)
                    _line(PackedVector2Array([Vector2(12,39),Vector2(66,39)]),hot,3)
                    _line(PackedVector2Array([Vector2(39,12),Vector2(39,66)]),hot,3)
                _:
                    for i in range(5):
                        var x: float = 14+i*12.0
                        _line(PackedVector2Array([
                            Vector2(x,10+i*3),Vector2(x+7,61+i*2)]),hot,3.4)
                        _line(PackedVector2Array([
                            Vector2(x+1,50+i*2),Vector2(x+7,61+i*2),
                            Vector2(x+14,50+i*2)]),tint,2)
        2:
            match ability_id:
                0:
                    draw_circle(mid,23,tint)
                    draw_circle(mid+Vector2(4,-3),17,hot)
                    draw_circle(mid+Vector2(6,-4),8,Color("fff8d5"))
                    draw_arc(mid,30,0,TAU,28,hot,2,true)
                1:
                    draw_colored_polygon(PackedVector2Array([
                        Vector2(44,4),Vector2(19,40),Vector2(36,39),
                        Vector2(29,72),Vector2(64,29),Vector2(45,30)]),hot)
                    _line(PackedVector2Array([
                        Vector2(10,16),Vector2(25,30),Vector2(11,44)]),tint,3)
                    _line(PackedVector2Array([
                        Vector2(56,45),Vector2(70,55),Vector2(59,69)]),tint,3)
                _:
                    for i in range(4):
                        var a: float = TAU*float(i)/4.0
                        _line(PackedVector2Array([
                            mid+Vector2(cos(a),sin(a))*10,
                            mid+Vector2(cos(a),sin(a))*29]),hot,5)
                    draw_circle(mid,15,tint)
                    draw_circle(mid,9,Color("fff4df"))
        3:
            match ability_id:
                0:
                    _line(PackedVector2Array([
                        Vector2(24,69),Vector2(48,13)]),hot,5)
                    draw_arc(Vector2(49,34),23,-PI*0.85,PI*0.36,28,tint,8,true)
                    draw_arc(Vector2(49,34),23,-PI*0.85,PI*0.36,28,hot,2,true)
                1:
                    draw_circle(mid,27,Color("6d359e"))
                    draw_circle(mid,19,Color("090f24"))
                    draw_circle(mid,7,hot)
                    draw_arc(mid,30,0,TAU,30,tint,3,true)
                _:
                    _line(PackedVector2Array([
                        Vector2(20,68),Vector2(52,12)]),Color("f4d8ff"),6)
                    draw_arc(Vector2(48,31),24,-PI*.94,PI*.23,28,hot,9,true)
                    _line(PackedVector2Array([
                        Vector2(9,57),Vector2(24,49),Vector2(37,65),
                        Vector2(60,58),Vector2(70,68)]),Color("fe536e"),3.4)
