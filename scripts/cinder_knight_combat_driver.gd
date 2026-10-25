extends Node
# Standalone combat animation controller for Cinder Knight.
# Operates on the rigged model and hand-mounted warhammer, not the camera.
var body: Node3D
var hammer: Node3D
var body_rest := Transform3D.IDENTITY
var hammer_rest := Transform3D.IDENTITY
var elapsed := 0.0
var duration := 0.0
var impact_at := 0.0
var combo := 0
var active := false
var hit_sent := false
signal impact(combo_step: int)

func configure(character: Node3D) -> bool:
    if character == null or character.get_child_count() == 0:
        return false
    body = character.get_child(0) as Node3D
    var weapons := character.find_children("CinderWarhammer", "Node3D", true, false)
    if body == null or weapons.is_empty():
        return false
    hammer = weapons[0] as Node3D
    if not active:
        body_rest = body.transform
        hammer_rest = hammer.transform
    return true

func start_attack(step: int, ultimate: bool = false) -> bool:
    if not is_instance_valid(body) or not is_instance_valid(hammer):
        return false
    finish_attack()
    body_rest = body.transform
    hammer_rest = hammer.transform
    combo = 3 if ultimate else posmod(step, 3)
    duration = 0.78 if ultimate else (0.56 if combo == 2 else 0.49)
    impact_at = 0.42 if ultimate else (0.31 if combo == 2 else 0.25)
    elapsed = 0.0
    active = true
    hit_sent = false
    return true

func finish_attack() -> void:
    if active:
        if is_instance_valid(body):
            body.transform = body_rest
        if is_instance_valid(hammer):
            hammer.transform = hammer_rest
    active = false

func advance(delta: float) -> void:
    if not active:
        return
    if not is_instance_valid(body) or not is_instance_valid(hammer):
        active = false
        return
    elapsed += delta
    var t := clampf(elapsed / duration, 0.0, 1.0)
    var impact_phase := impact_at / duration
    var charge := smoothstep(0.0, impact_phase * 0.42, t)
    var swing := smoothstep(impact_phase * 0.42, impact_phase, t)
    var recover := smoothstep(impact_phase, 1.0, t)
    var sign_dir := 1.0 if combo == 0 else -1.0
    if combo >= 2:
        sign_dir = 0.0
    var wind_pitch := -0.95 if combo >= 2 else -0.40
    var strike_pitch := 1.45 if combo >= 2 else 0.52
    var current_pitch := lerpf(wind_pitch * charge, strike_pitch, swing) * (1.0 - recover)
    var roll := sign_dir * lerpf(-1.0 * charge, 0.95, swing) * (1.0 - recover)
    hammer.transform = hammer_rest
    hammer.rotation += Vector3(current_pitch, 0.12 * sign_dir * (1.0 - recover), roll)
    body.transform = body_rest
    body.rotation += Vector3(0.28 * swing * (1.0 - recover), sign_dir * 0.23 * sin(t * PI), sign_dir * 0.13 * sin(t * PI))
    body.position += Vector3(0, -0.16 * swing * (1.0 - recover), 0.28 * swing * (1.0 - recover))
    if not hit_sent and elapsed >= impact_at:
        hit_sent = true
        impact.emit(combo)
    if t >= 1.0:
        finish_attack()
