extends SceneTree
## CI verifies 60 Hz target and sustained load switching, not physical device FPS.
const GOVERNOR = preload("res://scripts/mobile_quality.gd")

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var budget = GOVERNOR.new()
    if budget.TARGET_FPS != 60 or budget.tier != 2:
        push_error("MOBILE QUALITY FAIL: high 60 FPS baseline missing")
        quit(1)
        return
    for i in range(2):
        budget.observe(23.0, 1.0)
    if budget.tier != 2:
        push_error("MOBILE QUALITY FAIL: a short spike changed quality too soon")
        quit(2)
        return
    for i in range(19):
        budget.observe(23.0, 1.0)
    if budget.tier != 0:
        push_error("MOBILE QUALITY FAIL: sustained overload must fall back to low")
        quit(3)
        return
    for i in range(37):
        budget.observe(60.0, 1.0)
    if budget.tier != 2:
        push_error("MOBILE QUALITY FAIL: sustained fast frames must restore visuals")
        quit(4)
        return
    for i in range(6):
        budget.observe(52.0 if i % 2 == 0 else 58.0, 1.0)
    if budget.tier != 2:
        push_error("MOBILE QUALITY FAIL: ordinary FPS jitter causes quality oscillations")
        quit(5)
        return
    print("MOBILE QUALITY PASS: 60 FPS target, delayed fallback, automatic recovery and stable hysteresis")
    quit(0)
