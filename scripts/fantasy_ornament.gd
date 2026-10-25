extends Control
# Decorative frame painted in native Godot so that gameplay controls remain
# interactive, scalable, and safe on both 720x1280 and tall phone displays.
const PREMIUM_ATLAS: Texture2D = preload("res://assets/ui/premium_hud_atlas.svg")
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
    var premium_region: Rect2 = Rect2()
    match mode:
        "hero": premium_region = Rect2(0, 0, 540, 288)
        "journey": premium_region = Rect2(560, 0, 440, 288)
        "banner": premium_region = Rect2(1010, 0, 650, 188)
        "dock": premium_region = Rect2(0, 305, 940, 320)
    if premium_region.size.x > 0.0:
        draw_texture_rect_region(PREMIUM_ATLAS,
            Rect2(Vector2.ZERO, size), premium_region, Color.WHITE, false)
        return
    var trim: Color = accent
    var old_gold := Color("75401e")
    var pale := Color("ffe1a0")
    var dark := Color("071023")
    if mode == "skill":
        # Each atlas ability includes its own full illuminated metal medallion.
        # The interactive button keeps only its understated description plate.
        draw_rect(Rect2(4,103,w-8,h-104), Color("081223",0.90), true)
        draw_line(Vector2(13,h-8),Vector2(w-13,h-8),Color("c37f3e"),1.7,true)
        return
    if mode == "mini":
        # The approved reference has a circular medallion, NOT a
        # square ornate button wrapped around each skill.
        var radius: float = minf(w * 0.38, h * 0.34) if mode == "skill" else minf(w * 0.32, h * 0.32)
        var center := Vector2(w * 0.5, radius + (7.0 if mode == "skill" else 8.0))
        draw_circle(center, radius + 7.0, Color("6a2d12", 0.5))
        draw_circle(center, radius + 4.0, old_gold)
        draw_circle(center, radius + 1.0, pale)
        draw_circle(center, radius - 3.0, trim)
        draw_circle(center, radius - 8.0, dark)
        draw_arc(center,radius-2.0,PI*1.10,PI*1.90,35,pale,2.2,true)
        if mode == "skill":
            # Leave the MP caption unobscured; lower gold rules previously
            # cut right through the second line of text.
            draw_rect(Rect2(11,106,w-22,h-112),Color("081323",0.90),true)
        return
    # More than one thin outline: inset bevel, raised metal and dark glass.
    draw_rect(Rect2(3,4,w-6,h-8), Color(0.18,0.075,0.020,0.69), true)
    draw_rect(Rect2(8,7,w-16,h-14), dark, true)
    draw_rect(Rect2(4,4,w-8,h-8), old_gold, false, 6)
    draw_rect(Rect2(7,7,w-14,h-14), trim, false, 2.8)
    draw_rect(Rect2(11,11,w-22,h-22), Color("533921"), false, 1.0)
    draw_line(Vector2(20,14),Vector2(w-20,14),pale * Color(1,1,1,0.6),1.1,true)
    draw_line(Vector2(19,h-15),Vector2(w-19,h-15),old_gold,1.8,true)
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
