extends RefCounted
# Offline adaptive encounter director. This is tactical game AI, not a cloud
# language model: low CPU cost, no tracking, network requests or paid API.
# It remembers recent encounter types, adjusts risk after victories/defeats
# and generates a new mixed enemy formation for every chamber.
const MODES := ["HUNT", "AMBUSH", "GUARD", "RITUAL", "SWARM", "TREASURE", "SANCTUARY"]
const TITLES := [
    "HUNTERS ON THE TRAIL", "SHADOW AMBUSH", "IRON GUARD PATROL",
    "ARCANE RITUAL", "THE RAVENOUS SWARM", "LOST TREASURE CONVOY",
    "FORGOTTEN SANCTUARY"
]
var recent: Array = []
var momentum := 0.0
var wins := 0
var defeats := 0
var room_count := 0

func save_state() -> Dictionary:
    return {"recent": recent.duplicate(), "momentum": momentum,
        "wins": wins, "defeats": defeats, "rooms": room_count}

func load_state(raw: Variant) -> void:
    if not raw is Dictionary:
        return
    var data: Dictionary = raw
    recent.clear()
    var history: Variant = data.get("recent", [])
    if history is Array:
        for entry in history:
            if MODES.has(str(entry)):
                recent.append(str(entry))
    if recent.size() > 3:
        recent = recent.slice(recent.size() - 3)
    momentum = clampf(float(data.get("momentum", 0.0)), -2.0, 2.0)
    wins = clampi(int(data.get("wins", 0)), 0, 1000000)
    defeats = clampi(int(data.get("defeats", 0)), 0, 1000000)
    room_count = clampi(int(data.get("rooms", 0)), 0, 1000000)

func report_result(health_ratio: float, defeated: bool = false) -> void:
    if defeated:
        defeats += 1
        momentum = clampf(momentum - 0.85, -2.0, 2.0)
    else:
        wins += 1
        if health_ratio < 0.35:
            momentum = clampf(momentum - 0.42, -2.0, 2.0)
        elif health_ratio >= 0.85:
            momentum = clampf(momentum + 0.24, -2.0, 2.0)
        else:
            momentum = move_toward(momentum, 0.0, 0.14)

func choose(stage: int, room: int, hero_class: int, grinding: bool,
        health_ratio: float, randomizer: RandomNumberGenerator) -> Dictionary:
    var boss: bool = stage % 10 == 0 and room == 3
    var pressure: float = clampf(1.0 + momentum * 0.065, 0.87, 1.13)
    if health_ratio < 0.32 or grinding:
        pressure = minf(pressure, 0.95)
    if boss:
        return {"mode": "BOSS", "title": "BOSS SANCTUM", "primary_role": "guardian",
            "pressure": pressure, "hp_factor": 1.0, "damage_factor": pressure,
            "count_bonus": 0, "gold_bonus": 0.0, "heal_bonus": 0.0,
            "loot_bonus": false}

    var weights: Array = [1.35, 1.10, 1.05, 1.05, 0.95, 0.54, 0.46]
    if health_ratio < 0.38:
        weights[6] = 2.4
        weights[4] = 0.25
        weights[1] = 0.34
    if grinding:
        weights[5] = 0.9
        weights[6] = 1.3
    if hero_class == 2:
        weights[2] *= 1.18
    if hero_class == 0:
        weights[3] *= 1.15
    # No back-to-back identical encounters; recent alternatives get penalized.
    for i in range(MODES.size()):
        if not recent.is_empty() and str(recent.back()) == str(MODES[i]):
            weights[i] = 0.0
        elif recent.size() > 1 and str(recent[recent.size() - 2]) == str(MODES[i]):
            weights[i] *= 0.2
    var total := 0.0
    for weight in weights:
        total += float(weight)
    var roll: float = randomizer.randf() * total
    var selected: int = 0
    for i in range(weights.size()):
        roll -= float(weights[i])
        if roll <= 0.0 and float(weights[i]) > 0.0:
            selected = i
            break
    var mode: String = str(MODES[selected])
    recent.append(mode)
    if recent.size() > 3:
        recent.pop_front()
    room_count += 1

    var role: String = ["raider", "flanker", "guardian", "caster", "raider", "flanker", "guardian"][selected]
    var health_multiplier: float = [1.00, 0.91, 1.21, 0.93, 0.78, 0.97, 0.90][selected]
    var damage_multiplier: float = [1.00, 1.10, 0.92, 1.05, 0.80, 0.90, 0.80][selected]
    var extra_count: int = 2 if mode == "SWARM" else 1 if mode == "AMBUSH" else -1 if mode == "SANCTUARY" else 0
    return {
        "mode": mode, "title": TITLES[selected], "primary_role": role,
        "pressure": pressure,
        "hp_factor": clampf(health_multiplier * pressure, 0.66, 1.35),
        "damage_factor": clampf(damage_multiplier * pressure, 0.66, 1.33),
        "count_bonus": extra_count,
        "gold_bonus": 0.65 if mode == "TREASURE" else 0.0,
        "heal_bonus": 0.20 if mode == "SANCTUARY" else 0.0,
        "loot_bonus": mode == "TREASURE"
    }

func enemy_role(plan: Dictionary, index: int, boss: bool) -> String:
    if boss:
        return "guardian" if index == 0 else "flanker" if index % 2 == 0 else "raider"
    var primary: String = str(plan.get("primary_role", "raider"))
    var mode: String = str(plan.get("mode", "HUNT"))
    if mode == "GUARD" and index % 3 == 2:
        return "caster"
    if mode == "RITUAL" and index % 3 == 0:
        return "guardian"
    if mode == "AMBUSH" and index % 3 == 1:
        return "raider"
    if mode == "SWARM":
        return "raider" if index % 3 else "flanker"
    if index % 4 == 3:
        return "raider"
    return primary
