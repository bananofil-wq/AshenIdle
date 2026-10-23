extends Control
# Small, deterministic vector emblems for Android class selection.
# These render without relying on off-screen 3D viewports or missing font glyphs.

var class_id: int = 0
var accent: Color = Color("c58c56")


func _ready() -> void:
    queue_redraw()


func _stroke(a: Vector2, b: Vector2, tint: Color, width: float = 3.0) -> void:
    draw_line(a, b, tint.darkened(0.71), width + 2.6, true)
    draw_line(a, b, tint, width, true)


func _draw() -> void:
    var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.49)
    var glow: Color = accent.darkened(0.52)
    draw_circle(c, 37.0, Color(0.09, 0.11, 0.15, 0.84))
    draw_arc(c, 43.0, 0.0, TAU, 64, glow, 1.7, true)
    draw_arc(c, 36.0, -PI * 0.68, PI * 0.41, 40, accent, 1.7, true)
    draw_arc(c, 36.0, PI * 0.45, PI * 1.12, 22, accent.darkened(0.25), 1.2, true)
    for mark in range(8):
        var a: float = TAU * float(mark) / 8.0 - PI * 0.5
        _stroke(c + Vector2(cos(a), sin(a)) * 44.0, c + Vector2(cos(a), sin(a)) * 48.0, glow, 1.0)
    match class_id:
        0:
            # Longsword and compact heater shield.
            _stroke(c + Vector2(-9, 26), c + Vector2(8, -28), accent.lightened(0.4), 4.0)
            _stroke(c + Vector2(-18, 12), c + Vector2(9, 20), accent, 4.5)
            _stroke(c + Vector2(-10, 29), c + Vector2(-5, 33), accent, 6.0)
            var shield := PackedVector2Array([
                c + Vector2(8, -5), c + Vector2(26, 1), c + Vector2(24, 19),
                c + Vector2(14, 31), c + Vector2(7, 16)
            ])
            draw_colored_polygon(shield, Color(0.17, 0.21, 0.28))
            draw_polyline(shield, accent, 2.3, true)
            _stroke(c + Vector2(16, 3), c + Vector2(15, 22), accent.lightened(0.33), 2.0)
        1:
            # Recurve bow, taut string and arrowhead.
            draw_arc(c + Vector2(-8, 0), 28.0, -1.28, 1.28, 26, accent.lightened(0.22), 4.6, true)
            _stroke(c + Vector2(0, -27), c + Vector2(0, 27), accent.darkened(0.12), 1.6)
            _stroke(c + Vector2(-22, 0), c + Vector2(30, 0), accent.lightened(0.38), 2.3)
            draw_colored_polygon(PackedVector2Array([
                c + Vector2(31, 0), c + Vector2(19, -6), c + Vector2(19, 6)
            ]), accent.lightened(0.36))
            _stroke(c + Vector2(-14, -6), c + Vector2(-14, 6), accent.darkened(0.15), 2.0)
        2:
            # Arcane orb with four-pointed rune, held by a staff.
            _stroke(c + Vector2(-19, 32), c + Vector2(2, -19), accent, 3.6)
            draw_circle(c + Vector2(6, -16), 16.0, Color(0.13, 0.17, 0.28))
            draw_arc(c + Vector2(6, -16), 16.0, 0.0, TAU, 40, accent.lightened(0.24), 2.2, true)
            draw_colored_polygon(PackedVector2Array([
                c + Vector2(6, -29), c + Vector2(10, -19), c + Vector2(21, -16),
                c + Vector2(10, -12), c + Vector2(6, 0), c + Vector2(2, -12),
                c + Vector2(-8, -16), c + Vector2(2, -19)
            ]), accent.lightened(0.40))
            draw_arc(c + Vector2(6, -16), 26.0, -2.2, 0.6, 26, accent.darkened(0.1), 1.2, true)
        3:
            # Long-handled scythe with a curved crescent blade.
            _stroke(c + Vector2(-17, 34), c + Vector2(12, -28), accent.lightened(0.22), 4.1)
            draw_arc(c + Vector2(7, -14), 27.0, -2.3, 0.15, 35, accent.lightened(0.33), 5.6, true)
            _stroke(c + Vector2(11, -26), c + Vector2(30, -12), accent, 2.2)
            draw_circle(c + Vector2(-12, 24), 2.9, accent)
    # Discrete footer bars indicate the four separate class archetypes.
    for i in range(4):
        var x: float = (size.x - 52.0) * 0.5 + float(i) * 15.0
        var tone: Color = accent if i == class_id else accent.darkened(0.64)
        draw_line(Vector2(x, size.y - 12), Vector2(x + 8, size.y - 12), tone, 2.2, true)
