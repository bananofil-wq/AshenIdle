extends Control
# Crisp hand-drawn fantasy ability glyphs; no emoji or platform-dependent fonts.
@export var class_id := 0:
    set(v):
        class_id = v
        queue_redraw()
@export var ability_id := 0:
    set(v):
        ability_id = v
        queue_redraw()
@export var locked := false:
    set(v):
        locked = v
        queue_redraw()

func _draw() -> void:
    var accent: Color = [Color("ec9053"), Color("86ba69"), Color("80caff"), Color("c292ff")][clampi(class_id, 0, 3)]
    if locked:
        accent = Color("727982")
    var origin := Vector2(17, 17)
    draw_circle(origin, 16, Color("11151e", 0.94))
    draw_arc(origin, 14.7, -PI / 2.0, 3.0 * PI / 2.0, 24, accent.darkened(0.17), 1.7, true)
    if class_id == 0:
        # Steel blade, shield, explosive flame.
        if ability_id == 0:
            draw_line(Vector2(7, 27), Vector2(26, 7), accent.lightened(0.25), 4.0, true)
            draw_line(Vector2(8, 16), Vector2(18, 26), Color("f3d4a3"), 2.1, true)
        elif ability_id == 1:
            var shield := PackedVector2Array([Vector2(17, 5), Vector2(28, 11), Vector2(26, 23), Vector2(17, 30), Vector2(8, 23), Vector2(6, 11)])
            draw_colored_polygon(shield, accent.darkened(0.43))
            draw_polyline(shield, accent, 2.2, true)
            draw_line(Vector2(17, 9), Vector2(17, 24), accent.lightened(0.45), 2.0, true)
        else:
            for i in range(3):
                var ang: float = TAU * float(i) / 3.0
                var p: Vector2 = origin + Vector2(cos(ang), sin(ang)) * 7.0
                draw_line(origin, p + Vector2(cos(ang), sin(ang)) * 5.0, accent, 4, true)
            draw_circle(origin, 5, accent.lightened(0.4))
    elif class_id == 1:
        # Bow, trap / snare, falling arrows.
        if ability_id == 0:
            draw_arc(Vector2(7, 17), 16, -1.1, 1.1, 24, accent, 2.5, true)
            draw_line(Vector2(16, 5), Vector2(16, 29), Color("f3e6bf"), 1.5, true)
            draw_line(Vector2(9, 17), Vector2(29, 17), accent.lightened(0.35), 3, true)
        elif ability_id == 1:
            draw_arc(origin, 10, 0, TAU, 16, accent, 2.5, true)
            draw_line(Vector2(7, 7), Vector2(27, 27), accent.lightened(0.4), 2, true)
            draw_line(Vector2(27, 7), Vector2(7, 27), accent.lightened(0.4), 2, true)
        else:
            for i in range(3):
                var x: float = 9.0 + 8.0 * float(i)
                draw_line(Vector2(x, 6), Vector2(x, 26), accent.lightened(0.30), 2.6, true)
                draw_line(Vector2(x - 3, 21), Vector2(x, 27), accent, 2.6, true)
                draw_line(Vector2(x + 3, 21), Vector2(x, 27), accent, 2.6, true)
    elif class_id == 2:
        # Fire orb, jagged branching lightning, arcane star.
        if ability_id == 0:
            draw_circle(origin + Vector2(0, 2), 8.5, accent)
            draw_circle(origin + Vector2(-2, 0), 4.5, Color("fff5c9"))
            draw_line(Vector2(16, 7), Vector2(20, 12), accent.lightened(0.4), 3, true)
        elif ability_id == 1:
            var bolt := PackedVector2Array([Vector2(19, 3), Vector2(9, 19), Vector2(17, 19), Vector2(14, 30), Vector2(28, 13), Vector2(20, 13)])
            draw_colored_polygon(bolt, accent.lightened(0.40))
            draw_line(Vector2(23, 16), Vector2(29, 22), accent, 2.5, true)
            draw_line(Vector2(10, 18), Vector2(5, 25), accent, 2.5, true)
        else:
            for i in range(8):
                var angle: float = TAU * float(i) / 8.0
                var p: Vector2 = origin + Vector2(cos(angle), sin(angle)) * 5
                var q: Vector2 = origin + Vector2(cos(angle), sin(angle)) * 12
                draw_line(p, q, accent, 2.1, true)
            draw_circle(origin, 4, accent.lightened(0.6))
    else:
        # Reaper's scythe, void pupil, nightfall crescent.
        if ability_id == 0:
            draw_arc(Vector2(22, 14), 13, 2.9, 5.4, 20, accent, 3.4, true)
            draw_line(Vector2(12, 30), Vector2(23, 7), accent.lightened(0.3), 2.8, true)
        elif ability_id == 1:
            draw_circle(origin, 10.5, accent.darkened(0.45))
            draw_arc(origin, 10.5, 0, TAU, 24, accent, 2.0, true)
            draw_circle(origin, 3.7, accent.lightened(0.47))
        else:
            draw_circle(origin, 11, accent)
            draw_circle(origin + Vector2(5, -5), 11.5, Color("11151e"))
            draw_line(Vector2(6, 27), Vector2(13, 21), accent.lightened(0.3), 2.2, true)
    if locked:
        draw_rect(Rect2(0, 0, 34, 34), Color(0.08, 0.09, 0.11, 0.38), true)
