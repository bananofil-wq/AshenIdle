extends RefCounted
## Cinder Reckoning stylized enemies: original animated chibi silhouettes.
## A single lightweight geometry + movement pipeline for all dungeon biomes:
## large expressive faces, oversize helmets, bold outfit layers and moving limbs.
## No humanoid PBR/skeleton is loaded underneath these figures.
var _sphere_mesh: SphereMesh
var _materials: Dictionary = {}
var _shape_cache: Dictionary = {}

const BIOME_COLORS := [
    ["f7b578", "773b35", "ffcf69", "453b53"],
    ["bee6a2", "385c43", "ffe6ab", "26372b"],
    ["b9e1ed", "3e5985", "e9f1ff", "344567"],
    ["e7ad78", "66422c", "f5dd87", "402d30"],
    ["e9b1e9", "633766", "f7d3ff", "302d4e"],
    ["c1d3ec", "465c82", "ecf7ff", "2e3a62"],
    ["91d8c1", "38655f", "d3fff2", "334d48"],
    ["cfe3a1", "5e723d", "fff2ac", "354533"],
    ["f0baae", "793748", "ffe8b0", "392a45"],
    ["e59b70", "712c38", "ffca6a", "3b242d"]
]

func _material(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
    var key: String = "%s/%d/%d" % [color.to_html(false),int(metal*100.0),int(glow)]
    if _materials.has(key):
        return _materials[key] as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metal
    m.roughness = 0.52 if metal > 0.2 else 0.74
    m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    if glow:
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 0.56
    _materials[key] = m
    return m

func _sphere() -> SphereMesh:
    if _sphere_mesh == null:
        _sphere_mesh = SphereMesh.new()
        _sphere_mesh.radius = 0.5
        _sphere_mesh.height = 1.0
        _sphere_mesh.radial_segments = 18
        _sphere_mesh.rings = 9
    return _sphere_mesh

func _box_mesh(size: Vector3) -> BoxMesh:
    var key: String = "box-%.3f-%.3f-%.3f" % [size.x,size.y,size.z]
    if _shape_cache.has(key):
        return _shape_cache[key] as BoxMesh
    var m := BoxMesh.new()
    m.size = size
    _shape_cache[key] = m
    return m

func _cone_mesh(bottom: float, top: float, height: float) -> CylinderMesh:
    var key: String = "horn-%.3f-%.3f-%.3f" % [bottom,top,height]
    if _shape_cache.has(key):
        return _shape_cache[key] as CylinderMesh
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = bottom
    mesh.top_radius = top
    mesh.height = height
    mesh.radial_segments = 12
    _shape_cache[key] = mesh
    return mesh

func _part(parent: Node3D, name: String, mesh: Mesh, at: Vector3,
        size: Vector3, color: Color, metal: float = 0.0, glow: bool = false) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.name = name
    n.mesh = mesh
    n.material_override = _material(color, metal, glow)
    n.position = at
    n.scale = size
    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(n)
    return n

func _egg(parent: Node3D, name: String, at: Vector3, size: Vector3,
        color: Color, metal: float = 0.0, glow: bool = false) -> MeshInstance3D:
    return _part(parent,name,_sphere(),at,size,color,metal,glow)

func _block(parent: Node3D, name: String, at: Vector3, size: Vector3,
        color: Color, metal: float = 0.0) -> MeshInstance3D:
    return _part(parent,name,_box_mesh(size),at,Vector3.ONE,color,metal)

func _horn(parent: Node3D, name: String, at: Vector3, r: float, h: float,
        color: Color, tilt: float = 0.0) -> MeshInstance3D:
    var n := _part(parent,name,_cone_mesh(r,0.01,h),at,Vector3.ONE,color)
    n.rotation.z = tilt
    return n

func _cape(parent: Node3D, color: Color, long_scale: float = 1.0) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var pts := [
        Vector3(-.37,.16,-.19),Vector3(.37,.16,-.19),
        Vector3(-.50,-.74*long_scale,-.40),Vector3(.52,-.74*long_scale,-.40),
        Vector3(0,-.80*long_scale,-.51)
    ]
    for idx in [0,2,4,0,4,1,1,4,3]:
        st.set_uv(Vector2(float(idx%2),float(idx/2)))
        st.add_vertex(pts[idx])
    st.generate_normals()
    var n := MeshInstance3D.new()
    n.name = "FlowingMantle"
    n.mesh = st.commit()
    var material: StandardMaterial3D = _material(color).duplicate() as StandardMaterial3D
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    n.material_override = material
    n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(n)

func _blade(arm: Node3D, accent: Color, dagger: bool) -> void:
    var base: Vector3 = Vector3(.08,-.46,.20)
    var length: float = .52 if dagger else .78
    _block(arm,"SwordGrip",base + Vector3(0,.08,0),Vector3(.105,.27,.105),Color("55443c"))
    _block(arm,"GoldGuard",base+Vector3(0,.23,0),Vector3(.33,.09,.11),accent,.42)
    _egg(arm,"SteelBlade",base+Vector3(0,.29+length*.42,0),
        Vector3(.15,length,.078),Color("e7f0fa"),.65)
    _horn(arm,"SwordPoint",base+Vector3(0,.29+length*.91,0),.10,.22,Color("f5f8ff"))
    _egg(arm,"Pommel",base+Vector3(0,-.04,0),Vector3(.12,.12,.12),accent,.4)

func _face(parent: Node3D, eyes: Color, skin: Color, big: bool) -> void:
    var width: float = .19 if big else .17
    for side in [-1.0,1.0]:
        var x: float = float(side)
        _egg(parent,"EyeSocket",Vector3(x*width,.14,.378),Vector3(.14,.17,.055),Color("302836"))
        _egg(parent,"EmissiveIris",Vector3(x*width,.13,.410),Vector3(.075,.095,.026),eyes,0.0,true)
        var brow := _block(parent,"AngryBrow",Vector3(x*width,.31,.397),
            Vector3(.20,.055,.064),Color("372b31"))
        brow.rotation.z = x*.22
    _egg(parent,"SnubNose",Vector3(0,-.015,.385),Vector3(.10,.085,.08),skin.darkened(.07))

func _dress_humanoid(root: Node3D, species: String, biome: int,
        boss: bool, elite: bool, role: String, hero_kind: String = "") -> void:
    var colors: Array = BIOME_COLORS[clampi(biome,0,9)]
    if hero_kind != "":
        match hero_kind:
            "Knight": colors = ["f6bf98","315b9d","dcecf7","28364d"]
            "Rogue": colors = ["f4bc96","c55838","e9edf4","573570"]
            "Mage": colors = ["f9bf8f","d35e29","f4be46","7a3031"]
            "Barbarian": colors = ["ecd2cc","292d3f","e3cdd4","a72945"]
    var skin: Color = Color(colors[0])
    var cloth: Color = Color(colors[1])
    var accent: Color = Color(colors[2])
    var dark: Color = Color(colors[3])
    var is_undead: bool = species.contains("SKELETON") or species.contains("BONE") or species.contains("WRAITH") or species.contains("GHOST") or species.contains("REVENANT")
    if is_undead:
        skin = Color("e4ded2") if biome != 9 else Color("e5bc9c")
    var body := Node3D.new()
    body.name = "ToonVisual"
    root.add_child(body)
    body.scale = Vector3.ONE * (1.44 if boss else 1.17 if elite else 1.0)
    var hip := Node3D.new()
    hip.name = "Torso"
    hip.position = Vector3(0,.99,0)
    body.add_child(hip)
    _egg(hip,"FabricUndersuit",Vector3.ZERO,Vector3(.69,.64,.50),cloth)
    _egg(hip,"ChestPlate",Vector3(0,.05,.205),Vector3(.58,.48,.18),
        accent.darkened(.10),.20)
    _block(hip,"Belt",Vector3(0,-.26,.15),Vector3(.71,.14,.46),dark)
    _egg(hip,"GoldBuckle",Vector3(0,-.26,.38),Vector3(.15,.14,.06),accent,.65)
    if role == "caster" or boss or role == "guardian" or hero_kind == "Barbarian":
        _cape(hip,dark if not boss else cloth)
    for side in [-1.0,1.0]:
        var x: float = float(side)
        var leg := Node3D.new()
        leg.name = "LegLeft" if side < 0 else "LegRight"
        leg.position = Vector3(x*.19,.65,0)
        body.add_child(leg)
        _egg(leg,"PaddedLeg",Vector3(0,-.19,0),Vector3(.24,.47,.27),cloth)
        _egg(leg,"SteelBoot",Vector3(0,-.45,.14),Vector3(.30,.27,.44),dark,.16)
        _egg(leg,"KneeGuard",Vector3(0,-.28,.19),Vector3(.27,.22,.15),accent,.33)
        var arm := Node3D.new()
        arm.name = "ArmLeft" if side < 0 else "ArmRight"
        arm.position = Vector3(x*.47,1.25,.0)
        body.add_child(arm)
        _egg(arm,"ShoulderPauldrons",Vector3(0,-.02,0),
            Vector3(.36 if boss else .29,.32,.36),accent,.43)
        _egg(arm,"Sleeve",Vector3(x*.03,-.24,.02),Vector3(.24,.49,.26),cloth)
        _egg(arm,"Gauntlet",Vector3(x*.08,-.50,.08),Vector3(.24,.23,.29),skin)
        if side > 0:
            if role == "caster":
                _block(arm,"MagicStaff",Vector3(.08,-.18,.30),
                    Vector3(.085,1.04,.095),dark)
                _egg(arm,"ChargedCrystal",Vector3(.08,.42,.30),
                    Vector3(.23,.25,.23),accent,0.0,true)
            else:
                _blade(arm,accent,role=="flanker" or role=="raider")
    var head := Node3D.new()
    head.name = "Head"
    head.position = Vector3(0,1.53,.03)
    body.add_child(head)
    _egg(head,"OversizedHead",Vector3(0,.12,.05),
        Vector3(.87 if boss else .77,.81 if boss else .73,.74),
        skin)
    var eye_tint: Color = Color("72bbf9") if hero_kind == "Knight" else Color("84f0cf") if hero_kind == "Rogue" else Color("f7d33d") if hero_kind == "Mage" else Color("f05264") if hero_kind == "Barbarian" else Color("ffbb68") if biome in [0,3,9] else Color("94eeef")
    _face(head,eye_tint,skin,boss)
    if role == "caster":
        _egg(head,"Hood",Vector3(0,.33,-.10),Vector3(.89,.43,.72),cloth)
        _horn(head,"HoodPeak",Vector3(0,.61,-.07),.21,.43,dark)
    elif role == "guardian" or boss:
        _egg(head,"SilverHelm",Vector3(0,.39,.00),Vector3(.82,.37,.74),accent,.55)
        _block(head,"FaceGuard",Vector3(0,.20,.40),Vector3(.09,.24,.09),dark,.4)
    elif role == "flanker":
        for side in [-1.0,1.0]:
            _horn(head,"PointedEar",Vector3(float(side)*.45,.23,.01),.16,.34,skin,-float(side)*.83)
    else:
        for i in range(3):
            _horn(head,"WildHair",Vector3(-.27+float(i)*.26,.54,-.06),.16,.35,dark)
    if hero_kind == "Rogue":
        # Swept-back ivory hair and violet scarf, original design vocabulary.
        _egg(head,"SweptIvoryHair",Vector3(0,.48,-.11),Vector3(.83,.36,.71),Color("fff3d9"))
        for side in [-1.0,1.0]:
            _horn(head,"RoguePonytail",Vector3(float(side)*.38,.38,-.34),.18,.41,Color("fff3d9"),float(side)*.56)
        _egg(hip,"VioletTravelScarf",Vector3(0,.28,.18),Vector3(.66,.18,.56),Color("633990"))
    elif hero_kind == "Mage":
        # Fiery corona is sculpted, not a flat sprite overlay.
        for k in range(5):
            _horn(head,"EmberCrest",Vector3(-.34+.17*float(k),.70,-.05),
                .15,.31 + .09*float(k%2),Color("ffae2f") if k%2==0 else Color("ff6428"))
    elif hero_kind == "Knight":
        _horn(head,"RoyalRedPlume",Vector3(0,.74,-.10),.15,.43,Color("e64a50"))
    elif hero_kind == "Barbarian":
        for k in range(4):
            _horn(head,"MoonwhiteLock",Vector3(-.32+.20*float(k),.61,-.14),
                .13,.25,Color("f1e2e5"))
    if boss:
        # Every boss is crowned and larger, but the ten biome colorways stay
        # consistent with normal enemies of that realm.
        for side in [-1.0,1.0]:
            _horn(head,"BossAntler",Vector3(float(side)*.37,.70,-.10),
                .16,.62,dark,-float(side)*.26)
            _egg(hip,"CrownShoulder",Vector3(float(side)*.43,.30,-.07),
                Vector3(.33,.32,.40),skin)
        _egg(hip,"BossHeart",Vector3(0,.04,.315),
            Vector3(.22,.24,.08),accent,0.0,true)
    _animate(root,body,false,0)

func _dress_wolf(root: Node3D, species: String, biome: int, boss: bool, elite: bool) -> void:
    var colors: Array = BIOME_COLORS[clampi(biome,0,9)]
    var fur: Color = Color(colors[0]).darkened(.11)
    var coat: Color = Color(colors[1])
    var bright: Color = Color(colors[2])
    var body := Node3D.new()
    body.name = "ToonVisual"
    root.add_child(body)
    body.scale = Vector3.ONE * (1.65 if boss else 1.16 if elite else 1.0)
    _egg(body,"WolfBody",Vector3(0,.74,-.18),Vector3(.86,.60,1.30),fur)
    _egg(body,"ChestMane",Vector3(0,.88,.32),Vector3(.86,.77,.55),coat)
    var snout := Node3D.new()
    snout.name = "Head"
    snout.position = Vector3(0,1.03,.54)
    body.add_child(snout)
    _egg(snout,"LargeWolfHead",Vector3(0,.07,0),Vector3(.76,.73,.69),fur)
    _egg(snout,"Muzzle",Vector3(0,-.17,.40),Vector3(.52,.32,.55),bright)
    _egg(snout,"BlackNose",Vector3(0,-.13,.69),Vector3(.19,.15,.11),Color("302a30"))
    _face(snout,bright,fur,false)
    for side in [-1.0,1.0]:
        var x: float = float(side)
        _horn(snout,"FeralEar",Vector3(x*.27,.56,-.04),.16,.45,coat,-x*.20)
        for front in [false,true]:
            var z: float = .34 if front else -.56
            var leg := Node3D.new()
            var index: int = (0 if x < 0 else 1) + (0 if front else 2)
            leg.name = "Leg%d" % index
            leg.position = Vector3(x*.32,.63,z)
            body.add_child(leg)
            _egg(leg,"WolfLeg",Vector3(0,-.27,.01),Vector3(.21,.56,.25),fur)
            _egg(leg,"ClawedPaw",Vector3(0,-.53,.20),Vector3(.30,.20,.44),coat)
    var tail := Node3D.new()
    tail.name = "Tail"
    tail.position = Vector3(0,.87,-.79)
    body.add_child(tail)
    _egg(tail,"FluffyTail",Vector3(0,.10,-.30),Vector3(.28,.30,.80),coat)
    if boss:
        for side in [-1.0,1.0]:
            _horn(snout,"BossFang",Vector3(float(side)*.19,-.37,.48),.12,.35,bright)
    _animate(root,body,true,4)

func _dress_spider(root: Node3D, biome: int, boss: bool, elite: bool) -> void:
    var colors: Array = BIOME_COLORS[clampi(biome,0,9)]
    var chitin: Color = Color(colors[1])
    var glow: Color = Color(colors[2])
    var body := Node3D.new()
    body.name = "ToonVisual"
    root.add_child(body)
    body.scale = Vector3.ONE * (1.6 if boss else 1.1 if elite else 1.0)
    _egg(body,"BroodAbdomen",Vector3(0,.63,-.47),
        Vector3(.83,.76,1.0),chitin)
    _egg(body,"Thorax",Vector3(0,.67,.25),Vector3(.60,.60,.72),
        Color(colors[0]))
    var face := Node3D.new()
    face.name = "Head"
    face.position = Vector3(0,.80,.53)
    body.add_child(face)
    _egg(face,"ArachnidFace",Vector3.ZERO,Vector3(.70,.48,.49),chitin)
    _face(face,glow,chitin,false)
    for side in [-1.0,1.0]:
        for i in range(4):
            var idx: int = i if side < 0 else i+4
            var leg := Node3D.new()
            leg.name = "Leg%d" % idx
            leg.position = Vector3(float(side)*.29,.76,.40-float(i)*.30)
            body.add_child(leg)
            var x: float = float(side)
            var upper := _egg(leg,"BentSpiderLeg",
                Vector3(x*.45,.08,0),Vector3(.94,.16,.17),chitin)
            upper.rotation.z = x*.17
            var tip := _egg(leg,"SharpSpiderFoot",Vector3(x*.95,-.33,.0),
                Vector3(.14,.82,.13),glow)
            tip.rotation.z = x*.22
    _animate(root,body,true,8)

func _dress_tree(root: Node3D, biome: int, boss: bool, elite: bool) -> void:
    var colors: Array = BIOME_COLORS[clampi(biome,0,9)]
    var bark: Color = Color("876a51")
    var moss: Color = Color(colors[1])
    var eyes: Color = Color(colors[2])
    var body := Node3D.new()
    body.name = "ToonVisual"
    root.add_child(body)
    body.scale = Vector3.ONE*(1.72 if boss else 1.19 if elite else 1.0)
    _egg(body,"GnarledTrunk",Vector3(0,1.00,0),
        Vector3(.78,1.17,.72),bark)
    _egg(body,"BarkPlate",Vector3(0,1.18,.36),
        Vector3(.66,.63,.21),moss)
    var head := Node3D.new()
    head.name = "Head"
    head.position = Vector3(0,1.75,.05)
    body.add_child(head)
    _egg(head,"RootwoodHead",Vector3.ZERO,Vector3(.91,.68,.72),bark)
    _face(head,eyes,bark,true)
    for side in [-1.0,1.0]:
        var x: float = float(side)
        _horn(head,"LeafCrown",Vector3(x*.40,.43,-.12),.22,.52,moss,-x*.40)
        var arm := Node3D.new()
        arm.name = "ArmLeft" if x < 0 else "ArmRight"
        arm.position = Vector3(x*.47,1.42,0)
        body.add_child(arm)
        _egg(arm,"GnarledArm",Vector3(x*.08,-.32,0),Vector3(.34,.82,.36),bark)
        for claw in range(2):
            _horn(arm,"RootClaw",Vector3(x*(.08+float(claw)*.14),-.80,.17),
                .11,.37,moss)
        var leg := Node3D.new()
        leg.name = "LegLeft" if x < 0 else "LegRight"
        leg.position = Vector3(x*.28,.61,0)
        body.add_child(leg)
        _egg(leg,"TreeLeg",Vector3(0,-.30,0),Vector3(.40,.73,.39),bark)
    if boss:
        _egg(body,"CinderHeart",Vector3(0,1.16,.51),
            Vector3(.28,.30,.13),eyes,0.0,true)
    _animate(root,body,false,0)

func _rotation(animation: Animation, path: String, duration: float, values: Array) -> void:
    var track: int = animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(track,NodePath(path))
    animation.value_track_set_update_mode(track,Animation.UPDATE_CONTINUOUS)
    for i in range(values.size()):
        animation.track_insert_key(track,duration*float(i)/float(values.size()-1),values[i])

func _animate(root: Node3D, body: Node3D, beast: bool, legs: int) -> void:
    var player := AnimationPlayer.new()
    player.name = "CombatAnimationPlayer"
    root.add_child(player)
    var library := AnimationLibrary.new()
    for clip_name in ["Idle","Walk","Jog","Jog_Fwd","Attack","Sword_Regular_A","Spell_Simple_Shoot","Hit","Death"]:
        var walking: bool = clip_name in ["Walk","Jog","Jog_Fwd"]
        var striking: bool = clip_name in ["Attack","Sword_Regular_A","Spell_Simple_Shoot"]
        var dying: bool = clip_name == "Death"
        var duration: float = .49 if clip_name in ["Jog","Jog_Fwd"] else .82 if clip_name=="Walk" else .55 if striking else .48 if clip_name=="Hit" else .86 if dying else 1.4
        var animation := Animation.new()
        animation.length = duration
        animation.loop_mode = Animation.LOOP_LINEAR if walking or clip_name=="Idle" else Animation.LOOP_NONE
        _rotation(animation,"ToonVisual/Head:rotation",duration,
            [Vector3.ZERO,Vector3(.07 if not walking else -.04,0,0),Vector3.ZERO])
        var swing: float = .52 if clip_name in ["Jog","Jog_Fwd"] else .33 if walking else .025
        for child in body.get_children():
            if not child is Node3D:
                continue
            var pivot: Node3D = child as Node3D
            var phase: float = 1.0 if pivot.name in ["LegLeft","ArmRight","Leg0","Leg3","Leg4","Leg7"] else -1.0
            if pivot.name.begins_with("Leg"):
                var values: Array = [
                    Vector3(swing*phase,0,0),
                    Vector3(-swing*phase,0,0),
                    Vector3(swing*phase,0,0)
                ] if walking else [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
                if dying:
                    values = [Vector3.ZERO,Vector3(-.45,0,0),Vector3(-.6,0,0)]
                _rotation(animation,"ToonVisual/%s:rotation" % pivot.name,duration,values)
            elif pivot.name.begins_with("Arm"):
                var arc: Array = [Vector3(.09*phase,0,0),Vector3(-.09*phase,0,0),Vector3(.09*phase,0,0)] if walking else [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
                if striking:
                    arc = [Vector3(-.8,0,phase*.08),Vector3(.96,0,-phase*.2),Vector3.ZERO]
                _rotation(animation,"ToonVisual/%s:rotation" % pivot.name,duration,arc)
        if dying:
            _rotation(animation,"ToonVisual:rotation",duration,
                [Vector3.ZERO,Vector3(.15,0,.44),Vector3(.3,0,1.30)])
        library.add_animation(clip_name,animation)
    player.add_animation_library("",library)
    root.set_meta("stylized_enemy",true)
    root.set_meta("visual_rest_position",Vector3.ZERO)

func build_hero(root: Node3D, hero_kind: String) -> bool:
    var role: String
    match hero_kind:
        "Knight": role = "guardian"
        "Rogue": role = "flanker"
        "Mage": role = "caster"
        "Barbarian": role = "raider"
        _: return false
    _dress_humanoid(root,"HERO "+hero_kind.to_upper(),0,false,false,role,hero_kind)
    root.set_meta("toon_hero",hero_kind)
    return true

func build_enemy(root: Node3D, species: String, biome: int, boss: bool,
        elite: bool, role: String) -> bool:
    var upper: String = species.to_upper()
    var looks_like_wolf: bool = upper.contains("WOLF") or upper.contains("HOUND") or upper.contains("HYENA") or upper.contains("BEAST") or upper.contains("DRAKE") or upper.contains("DRAGON")
    var spider: bool = upper.contains("SPIDER") or upper.contains("SCORPION")
    var tree: bool = upper.contains("TREANT") or upper.contains("SAPLING") or upper.contains("ROOTMOTHER")
    if looks_like_wolf:
        _dress_wolf(root,upper,biome,boss,elite)
    elif spider:
        _dress_spider(root,biome,boss,elite)
    elif tree:
        _dress_tree(root,biome,boss,elite)
    else:
        _dress_humanoid(root,upper,biome,boss,elite,role)
    root.set_meta("toon_species",species)
    root.set_meta("toon_biome",biome)
    root.set_meta("toon_boss",boss)
    return true
