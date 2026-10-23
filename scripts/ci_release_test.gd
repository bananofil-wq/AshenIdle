extends SceneTree
## CI release guard: icon and procedural progression must stay valid on Android.
const BIOMES = preload("res://scripts/biome_profiles.gd")
const EVO = preload("res://scripts/evolution_rules.gd")

func _initialize() -> void:
    call_deferred("_verify_release")

func _fail(reason: String) -> void:
    push_error("RELEASE CHECK FAILED: " + reason)
    quit(2)

func _verify_release() -> void:
    if not FileAccess.file_exists("res://icon.svg"):
        _fail("Launcher icon missing from exported project")
        return
    if BIOMES.THEMES.size() != 10:
        _fail("Exactly ten art biomes required")
        return
    var seen_names: Dictionary = {}
    for biome_index in range(10):
        var first_floor: int = biome_index * 10 + 1
        var last_floor: int = first_floor + 9
        var profile: Dictionary = BIOMES.profile_for_stage(first_floor)
        var name: String = str(profile.get("name", ""))
        if name.is_empty() or seen_names.has(name):
            _fail("Missing or repeated biome name at floor %d" % first_floor)
            return
        seen_names[name] = true
        if not profile.has("ground") or not profile.has("accent") or not profile.has("fog"):
            _fail("Biome %s is missing essential render colors" % name)
            return
        var props: Array = profile.get("props", [])
        if props.size() < 3:
            _fail("Biome %s needs at least three scenery signatures" % name)
            return
        for stage in range(first_floor, last_floor + 1):
            if str(BIOMES.profile_for_stage(stage)["name"]) != name:
                _fail("Biome changes before its floor-10 boss at %d" % stage)
                return
            if BIOMES.is_boss(stage) != (stage == last_floor):
                _fail("Boss floor sequencing incorrect at %d" % stage)
                return
            if BIOMES.prop_for(stage, stage + 1).is_empty():
                _fail("Missing deterministic scenery signature at floor %d" % stage)
                return
        if biome_index < 9 and str(BIOMES.profile_for_stage(last_floor + 1)["name"]) == name:
            _fail("Next act failed to change theme after floor %d" % last_floor)
            return
    if str(BIOMES.profile_for_stage(101)["name"]) != str(BIOMES.profile_for_stage(1)["name"]):
        _fail("Endless mode must rotate biomes after floor 100")
        return
    if BIOMES.is_boss(0) or not BIOMES.is_boss(500):
        _fail("Endless boss checkpoints incorrect")
        return
    if EVO.MILESTONES != [75, 170, 250, 500]:
        _fail("Evolution milestone levels changed unexpectedly")
        return
    print("RELEASE CONTENT PASS: custom icon, ten 10-floor biomes, boss gates, endless loop, evolution milestones")
    quit(0)
