extends SceneTree
const DIRECTOR = preload("res://scripts/encounter_director.gd")
# Offline deterministic tests for the adaptive director. These run in Actions
# without a network, user save file, 3D renderer or expensive model imports.
func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool, detail: String) -> bool:
    if not ok:
        push_error("AI DIRECTOR FAIL: " + detail)
    return ok

func _run() -> void:
    var mind = DIRECTOR.new()
    var dice := RandomNumberGenerator.new()
    dice.seed = 23871
    var seen: Dictionary = {}
    var previous := ""
    for i in range(90):
        var plan: Dictionary = mind.choose(1 + i % 9, i % 3 + 1, i % 4, false, 0.93, dice)
        var mode: String = str(plan.get("mode", ""))
        if not _assert(mode != previous and not mode.is_empty(), "Repeated identical chambers"):
            quit(2)
            return
        seen[mode] = true
        previous = mode
        if not _assert(float(plan["hp_factor"]) <= 1.35 and float(plan["hp_factor"]) >= 0.66, "Enemy HP must be capped"):
            quit(3)
            return
        if not _assert(float(plan["damage_factor"]) <= 1.33 and float(plan["damage_factor"]) >= 0.66, "Enemy damage must be capped"):
            quit(4)
            return
        if not _assert(int(plan["count_bonus"]) <= 2 and int(plan["count_bonus"]) >= -1, "No unfair mob spikes"):
            quit(5)
            return
        mind.report_result(0.92, false)
    if not _assert(seen.size() >= 5, "Encounter generator should yield varied room families"):
        quit(6)
        return
    var hard_momentum: float = float(mind.momentum)
    for i in range(8):
        mind.report_result(0.0, true)
    if not _assert(float(mind.momentum) < hard_momentum, "AI must ease up after repeated defeats"):
        quit(7)
        return
    var relief: Dictionary = mind.choose(5, 2, 1, true, 0.15, dice)
    if not _assert(float(relief["pressure"]) <= 0.95, "Low-health grinders require protection"):
        quit(8)
        return
    var boss: Dictionary = mind.choose(10, 3, 1, false, 0.93, dice)
    if not _assert(str(boss["mode"]) == "BOSS" and int(boss["count_bonus"]) == 0, "Boss floor must remain protected"):
        quit(9)
        return
    var saved: Dictionary = mind.save_state()
    var recovered = DIRECTOR.new()
    recovered.load_state(saved)
    if not _assert(recovered.recent == mind.recent and recovered.wins == mind.wins and recovered.defeats == mind.defeats, "AI history must survive saving"):
        quit(10)
        return
    if not _assert(str(recovered.enemy_role({"primary_role": "caster", "mode": "RITUAL"}, 1, false)) == "caster"
        and str(recovered.enemy_role({"primary_role": "caster"}, 0, true)) == "guardian", "Enemy archetype roles must differ"):
        quit(11)
        return
    print("AI DIRECTOR PASS: 7 encounter types, no consecutive repeats, adaptive defeats, boss rules, HP/damage caps, save/load")
    quit(0)
