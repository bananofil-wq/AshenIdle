extends Control
# Hand-painted male hero medallion for the premium fantasy HUD.
# Uses native CanvasItem primitives and updates with the session-locked class.
@export var class_id: int = 0:
    set(value):
        class_id = value
        queue_redraw()

func _polygon(points: Array, color: Color) -> void:
    var verts := PackedVector2Array()
    for p in points:
        verts.append(p)
    draw_colored_polygon(verts,color)

func _draw() -> void:
    var scale_ratio: float = minf(size.x,size.y)/100.0
    draw_set_transform(Vector2((size.x-100*scale_ratio)*0.5,
        (size.y-100*scale_ratio)*0.5),0,Vector2.ONE*scale_ratio)
    draw_circle(Vector2(50,50),48,Color("60300f"))
    draw_circle(Vector2(50,50),44,Color("d99b4d"))
    draw_circle(Vector2(50,50),39,Color("10182b"))
    draw_circle(Vector2(50,50),37,Color("243d5e"))
    var capes := [Color("256eaf"),Color("3a7958"),
        Color("7a452e"),Color("4e2d69")]
    _polygon([Vector2(16,93),Vector2(24,70),Vector2(38,64),
        Vector2(63,64),Vector2(80,75),Vector2(88,93)],capes[clampi(class_id,0,3)])
    _polygon([Vector2(31,77),Vector2(38,68),Vector2(63,68),
        Vector2(72,78),Vector2(68,97),Vector2(34,97)],
        Color("e6dfcf") if class_id == 0 else Color("4c4352"))
    draw_circle(Vector2(50,50),25,Color("f4cda2"))
    # Angular jawline and thick dark brow keep all four portraits male.
    _polygon([Vector2(31,51),Vector2(34,66),Vector2(45,73),
        Vector2(59,71),Vector2(68,60),Vector2(65,49)],Color("f0c59a"))
    draw_line(Vector2(51,51),Vector2(62,50),Color("654a40"),3.0,true)
    draw_circle(Vector2(61,54),2.8,Color("151c2a"))
    draw_line(Vector2(62,67),Vector2(53,68),Color("af685a"),2.0,true)
    match class_id:
        0:
            # Heavy pale knight helmet: white overlapping sculpted plates.
            _polygon([Vector2(25,55),Vector2(23,38),Vector2(32,23),
                Vector2(49,18),Vector2(66,25),Vector2(75,42),
                Vector2(67,50),Vector2(55,40),Vector2(38,53)],
                Color("ece4d4"))
            _polygon([Vector2(26,45),Vector2(38,22),Vector2(55,20),
                Vector2(62,31),Vector2(47,39),Vector2(37,54)],
                Color("fff6df"))
            _polygon([Vector2(53,21),Vector2(70,25),Vector2(77,44),
                Vector2(69,57),Vector2(66,41)],Color("c2b9b4"))
            draw_line(Vector2(29,50),Vector2(49,37),Color("b6aeb3"),2.0,true)
            draw_circle(Vector2(28,74),7,Color("fff1d5"))
        1:
            # Ash Ranger: beige travel hood and leather shoulder clasp.
            _polygon([Vector2(25,61),Vector2(19,35),Vector2(32,19),
                Vector2(54,16),Vector2(75,30),Vector2(69,47),
                Vector2(47,37),Vector2(30,58)],Color("a48558"))
            _polygon([Vector2(31,52),Vector2(36,27),Vector2(53,22),
                Vector2(62,35),Vector2(44,38)],Color("dfc59c"))
            draw_circle(Vector2(27,75),7,Color("e2af51"))
        2:
            # Ember Mage: copper-plated horned crown.
            _polygon([Vector2(22,57),Vector2(21,28),Vector2(35,38),
                Vector2(47,15),Vector2(57,36),Vector2(76,23),
                Vector2(70,58),Vector2(63,47),Vector2(34,49)],
                Color("b76630"))
            _polygon([Vector2(27,42),Vector2(45,38),Vector2(49,24),
                Vector2(57,42),Vector2(71,37),Vector2(66,49)],
                Color("e3a24e"))
            draw_circle(Vector2(49,37),5,Color("9ed9ff"))
        3:
            # Dusk Reaper: obsidian face guard and high purple collar.
            _polygon([Vector2(25,57),Vector2(20,34),Vector2(31,22),
                Vector2(44,29),Vector2(56,15),Vector2(76,34),
                Vector2(72,63),Vector2(60,56),Vector2(35,61)],
                Color("4b305e"))
            _polygon([Vector2(26,42),Vector2(42,29),Vector2(55,30),
                Vector2(69,43),Vector2(57,49),Vector2(41,46)],
                Color("9571b1"))
            draw_line(Vector2(51,53),Vector2(65,50),Color("f1a0ee"),3.0,true)
    draw_arc(Vector2(50,50),45,0,TAU,54,Color("ffce80"),2.3,true)
    draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
