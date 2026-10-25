extends SceneTree
## Render one real Godot portrait for each new enemy role / distinctive boss,
## and fail on missing articulation, attack clips or empty models.
const TOON = preload("res://scripts/toon_enemy_art.gd")
const CASES := [
    ["BONE RAIDER",0,false,false,"raider","raider"],
    ["VOID HUNTER",1,false,false,"flanker","rogue"],
    ["CRYPT GUARDIAN",4,false,true,"guardian","guardian"],
    ["ASH SORCERER",9,false,false,"caster","caster"],
    ["HELL HOUND",9,false,false,"flanker","wolf"],
    ["FOREST SPIDER",1,false,false,"flanker","spider"],
    ["ANCIENT TREANT",1,true,false,"boss","treant-boss"],
    ["BONE EMPEROR",4,true,false,"boss","undead-boss"],
    ["EMBER TYRANT",9,true,false,"boss","infernal-boss"],
    ["STORM WRAITH",6,true,false,"boss","storm-boss"]
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("TOON ENEMY QA FAIL: " + message)
    quit(63)

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var atmosphere := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("252b31")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("d8d3ca")
    env.ambient_light_energy = 0.80
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    atmosphere.environment = env
    stage.add_child(atmosphere)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-45,-36,0)
    key.light_color = Color("fff0dc")
    key.light_energy = 1.50
    stage.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-26,135,0)
    fill.light_color = Color("92b4eb")
    fill.light_energy = 0.64
    stage.add_child(fill)
    var floor := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(12,12)
    floor.mesh = plane
    var earth := StandardMaterial3D.new()
    earth.albedo_color = Color("434b4c")
    floor.material_override = earth
    stage.add_child(floor)
    var camera := Camera3D.new()
    camera.current = true
    camera.fov = 39
    camera.position = Vector3(3.8,3.65,7.0)
    stage.add_child(camera)
    var maker = TOON.new()
    var signatures: Dictionary = {}
    for item in CASES:
        var actor := Node3D.new()
        actor.name = "Toon_%s" % str(item[5])
        stage.add_child(actor)
        if not maker.build_enemy(actor,str(item[0]),int(item[1]),bool(item[2]),bool(item[3]),str(item[4])):
            _fail("Could not create " + str(item[0]))
            return
        var body: Node3D = actor.get_node_or_null("ToonVisual") as Node3D
        var player: AnimationPlayer = actor.get_node_or_null("CombatAnimationPlayer") as AnimationPlayer
        if body == null or player == null:
            _fail("Missing 3D model or motion controller " + str(item[0]))
            return
        var meshes: Array = actor.find_children("*", "MeshInstance3D", true, false)
        if meshes.size() < 14:
            _fail("Character has insufficient 3D face/costume details: " + str(item[0]))
            return
        for clip in ["Idle","Walk","Jog_Fwd","Attack","Sword_Regular_A","Spell_Simple_Shoot","Hit","Death"]:
            if not player.has_animation(clip):
                _fail("Missing "+clip+" for "+str(item[0]))
                return
        var gait: Node3D = body.get_node_or_null("LegLeft") as Node3D
        if gait == null:
            gait = body.get_node_or_null("Leg0") as Node3D
        if gait == null:
            _fail("No independently moving legs for "+str(item[0]))
            return
        var opposite: Node3D = body.get_node_or_null("LegRight") as Node3D
        if opposite == null:
            opposite = body.get_node_or_null("Leg1") as Node3D
        if opposite == null:
            _fail("No opposite foot for articulated gait: "+str(item[0]))
            return
        var rest_foot: Vector3 = gait.position
        var opposite_rest: Vector3 = opposite.position
        player.play("Jog_Fwd")
        player.advance(.14)
        if gait.rotation.length_squared() <= 0.0005:
            _fail("Character glides without actual 3D limb rotation: " + str(item[0]))
            return
        var raised: float = gait.position.y - rest_foot.y
        var planted: float = opposite.position.y - opposite_rest.y
        if raised < .035 or planted > .025:
            _fail("Gait must lift one foot while planting the other: "
                + str(item[0]) + " raised=" + str(raised)
                + " planted=" + str(planted))
            return
        var attack: Animation = player.get_animation("Sword_Regular_A")
        if attack.get_track_count() < 2:
            _fail("No articulated attack for " + str(item[0]))
            return
        var signature: String = str(actor.get_meta("toon_species",""))
        signatures[signature] = true
        player.play("Idle")
        player.advance(.20)
        camera.position = Vector3(4.3,4.1,8.0) if bool(item[2]) else Vector3(3.3,3.0,6.3)
        camera.look_at(Vector3(0,1.44 if bool(item[2]) else 1.0,0),Vector3.UP)
        await process_frame
        await RenderingServer.frame_post_draw
        var image: Image = root.get_texture().get_image()
        var path: String = "res://build/toon-%s.png" % str(item[5])
        if image.save_png(path) != OK:
            _fail("Cannot render " + path)
            return
        print("TOON ENEMY VIEW ",item[5]," meshes=",meshes.size(),
            " drawcalls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        stage.remove_child(actor)
        actor.queue_free()
        await process_frame
    if signatures.size() != CASES.size():
        _fail("Bosses or ordinary creatures do not retain distinct identities")
        return
    print("TOON ENEMY QA PASS: 10 original cartoon-fantasy 3D characters and bosses, articulated locomotion and combat animation")
    quit(0)
