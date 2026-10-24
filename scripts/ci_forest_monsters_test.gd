extends SceneTree
# Fail the release if forest enemies silently regress to capsules or unanimated props.
const FACTORY = preload("res://scripts/forest_monster_factory.gd")
const DATA = preload("res://scripts/forest_monster_data.gd")

func _initialize() -> void:
    call_deferred("_test")

func _fail(message: String) -> void:
    push_error("FOREST MONSTERS FAIL: " + message)
    quit(31)

func _test() -> void:
    var model_factory = FACTORY.new()
    var register = DATA.new()
    if register.SPECS.size() != 6:
        _fail("Missing six distinct forest monster definitions")
        return
    var seen: Dictionary = {}
    var total_meshes: int = 0
    var monster_names: Array = ["CORRUPTED SAPLING", "MOSS HOUND", "BROOD SPIDER",
        "REVENANT WANDERER", "THORN BRUTE", "THE ROOTMOTHER"]
    for species in monster_names:
        var is_boss: bool = species == "THE ROOTMOTHER"
        var enemy := Node3D.new()
        enemy.name = "QA_%s" % species.replace(" ","_")
        root.add_child(enemy)
        if not model_factory.build(enemy, species, species == "THORN BRUTE", is_boss):
            _fail("Failed to build " + species)
            return
        var kind: String = str(enemy.get_meta("forest_monster_id", ""))
        if kind == "" or seen.has(kind):
            _fail("Duplicate / unrecognized silhouette for " + species)
            return
        seen[kind] = true
        var visual: Node3D = enemy.get_node_or_null("CreatureVisual") as Node3D
        var animator: AnimationPlayer = enemy.get_node_or_null("CreatureAnimationPlayer") as AnimationPlayer
        if visual == null or animator == null:
            _fail("Missing dedicated visual or skeletal motion controller: " + species)
            return
        var meshes: Array = visual.find_children("*", "MeshInstance3D", true, false)
        total_meshes += meshes.size()
        if meshes.size() < 3:
            _fail("Too few sculpted components: " + species)
            return
        for state in ["Idle", "Walk", "Jog", "Attack", "Hit", "Death"]:
            if not animator.has_animation(state):
                _fail("Missing animation " + state + ": " + species)
                return
        var walk: Animation = animator.get_animation("Jog")
        if walk.get_track_count() < 2:
            _fail("Only whole-body bouncing instead of independently animated limbs: " + species)
            return
        var movable: Node3D = visual.get_node_or_null("Gait_0") as Node3D
        if movable == null and kind != "revenant":
            _fail("No leg joints to animate: " + species)
            return
        animator.play("Jog")
        animator.advance(0.2)
        if movable != null and movable.rotation.length_squared() < 0.0005:
            _fail("Jog clip is not rotating individual legs: " + species)
            return
        animator.play("Attack")
        animator.advance(0.22)
        enemy.queue_free()
    if seen.size() != 6:
        _fail("Expected exactly six independent forest silhouettes")
        return
    print("FOREST MONSTERS PASS: 6 sculpted enemy types, ", total_meshes,
        " mesh sections, 6 clips per type, articulated walking and attacks")
    quit(0)
