extends RefCounted
## Organic fantasy monsters with real articulated limbs and GPU-conscious
## one-surface sculpted bodies. Each archetype has its own silhouette, not a
## recolored capsule. All meshes/materials are generated in the game (no CDN).
const DATA = preload("res://scripts/forest_monster_data.gd")
var registry = DATA.new()
var _materials: Dictionary = {}
var _noise_textures: Dictionary = {}
var _cached_eye: SphereMesh

func _noise_texture(seed_value: int, dark: Color, light: Color) -> Texture2D:
    if _noise_textures.has(seed_value):
        return _noise_textures[seed_value] as Texture2D
    var noise := FastNoiseLite.new()
    noise.seed = seed_value
    noise.frequency = 0.074
    noise.fractal_octaves = 3
    var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
    for y in range(128):
        for x in range(128):
            var grain: float = noise.get_noise_2d(float(x), float(y) * 0.38)
            var longitudinal: float = sin(float(x) * 0.23 + sin(float(y) * 0.052) * 1.7) * 0.18
            var v: float = clampf(0.48 + grain * 0.46 + longitudinal, 0.07, 0.96)
            img.set_pixel(x, y, dark.lerp(light, v))
    var tex := ImageTexture.create_from_image(img)
    _noise_textures[seed_value] = tex
    return tex

func _material(key: String) -> StandardMaterial3D:
    if _materials.has(key):
        return _materials[key] as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.roughness = 0.94
    m.metallic = 0.0
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    match key:
        "bark":
            m.albedo_texture = _noise_texture(12141, Color("45382d"), Color("c5a184"))
        "fur":
            m.albedo_texture = _noise_texture(27121, Color("332f2a"), Color("a09d8a"))
        "chitin":
            m.albedo_texture = _noise_texture(41073, Color("2a2830"), Color("807976"))
            m.roughness = 0.58
            m.metallic = 0.08
        "cloth":
            m.albedo_texture = _noise_texture(17711, Color("39463e"), Color("85978a"))
            m.cull_mode = BaseMaterial3D.CULL_DISABLED
        "bone":
            m.albedo_texture = _noise_texture(51017, Color("918d78"), Color("e8dcc0"))
        "moss":
            m.albedo_texture = _noise_texture(81071, Color("36482a"), Color("9aa976"))
            m.cull_mode = BaseMaterial3D.CULL_DISABLED
        "glow_orange", "glow_venom", "glow_ghost":
            m.vertex_color_use_as_albedo = false
            m.emission_enabled = true
            var c: Color = Color("fa9c4f") if key == "glow_orange" else Color("a6e772") if key == "glow_venom" else Color("81dfd3")
            m.albedo_color = c
            m.emission = c
            m.emission_energy_multiplier = 1.7
            m.roughness = 0.2
    _materials[key] = m
    return m

func _path(points: Array, radii: Array, color: Color, phase: float = 0.0) -> Dictionary:
    return {"points": points, "radii": radii, "color": color, "phase": phase}

func _tube(st: SurfaceTool, section: Dictionary) -> void:
    var pts: Array = section["points"] as Array
    var radii: Array = section["radii"] as Array
    var tint: Color = section["color"] as Color
    var phase: float = float(section["phase"])
    if pts.size() < 2 or pts.size() != radii.size():
        return
    const SIDES := 9
    for i in range(pts.size() - 1):
        var a: Vector3 = pts[i] as Vector3
        var b: Vector3 = pts[i + 1] as Vector3
        var direction: Vector3 = (b - a).normalized()
        var side: Vector3 = direction.cross(Vector3.UP)
        if side.length_squared() < 0.002:
            side = direction.cross(Vector3.FORWARD)
        side = side.normalized()
        var binormal: Vector3 = direction.cross(side).normalized()
        for face in range(SIDES):
            var angle0: float = TAU * float(face) / float(SIDES)
            var angle1: float = TAU * float(face + 1) / float(SIDES)
            var local_points: Array = []
            for ring in range(2):
                for angular in [angle0, angle1]:
                    var radius: float = float(radii[i + ring])
                    var ripple: float = 0.91 + 0.12 * sin(angular * 5.0 + phase + float(i) * 0.43)
                    var center: Vector3 = a if ring == 0 else b
                    local_points.append(center + (side * cos(angular) + binormal * sin(angular)) * radius * ripple)
            var c: Color = tint.darkened(0.16) if face % 4 == 0 else tint.lightened(0.07) if face % 3 == 1 else tint
            for idx in [0, 1, 2, 1, 3, 2]:
                var point: Vector3 = local_points[idx] as Vector3
                st.set_color(c)
                st.set_uv(Vector2((angle0 if idx % 2 == 0 else angle1) / TAU * 2.0, float(i + int(idx >= 2)) * 0.39))
                st.add_vertex(point)

func _skin(parent: Node3D, name: String, sections: Array, material: String) -> MeshInstance3D:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for section in sections:
        _tube(tool, section as Dictionary)
    tool.generate_normals()
    var part := MeshInstance3D.new()
    part.name = name
    part.mesh = tool.commit()
    part.material_override = _material(material)
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(part)
    return part

func _joint(visual: Node3D, name: String, pos: Vector3, sections: Array, mat: String) -> void:
    var pivot := Node3D.new()
    pivot.name = name
    pivot.position = pos
    visual.add_child(pivot)
    _skin(pivot, "Articulated_%s" % name, sections, mat)

func _eyes(visual: Node3D, points: Array, variant: String) -> void:
    if _cached_eye == null:
        _cached_eye = SphereMesh.new()
        _cached_eye.radius = 0.061
        _cached_eye.height = 0.122
        _cached_eye.radial_segments = 9
        _cached_eye.rings = 4
    var parent := Node3D.new()
    parent.name = "GlowingEyes"
    visual.add_child(parent)
    for p in points:
        var eye := MeshInstance3D.new()
        eye.mesh = _cached_eye
        eye.material_override = _material(variant)
        eye.position = p as Vector3
        eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(eye)

func _hound(visual: Node3D) -> void:
    var fur := Color("aaa393")
    var black := Color("4d554b")
    var bones := Color("c5be9b")
    _skin(visual, "HoundAnatomy", [
        _path([Vector3(0,1.06,-1.04),Vector3(0,1.04,-0.62),Vector3(0,1.10,0.02),
            Vector3(0,1.18,0.57),Vector3(0,1.38,0.86)], [.26,.45,.43,.51,.27], fur, 0.5),
        _path([Vector3(0,1.36,0.54),Vector3(0,1.48,0.93),
            Vector3(0,1.39,1.17)], [.33,.36,.19], fur.darkened(0.13), 2.0),
        _path([Vector3(0,1.33,1.05),Vector3(0,1.27,1.46),
            Vector3(0,1.22,1.66)], [.23,.17,.095], black, 1.3),
        _path([Vector3(0,1.18,-0.83),Vector3(0,1.29,-1.26),
            Vector3(0.09,1.20,-1.55)], [.19,.12,.025], black, 4.2),
        _path([Vector3(-0.33,1.19,0.45),Vector3(-0.48,1.30,0.54),
            Vector3(-0.44,1.49,0.67)], [.29,.23,.07], fur, 2.3),
        _path([Vector3(0.33,1.19,0.45),Vector3(0.48,1.30,0.54),
            Vector3(0.44,1.49,0.67)], [.29,.23,.07], fur, 3.2)
    ], "fur")
    var ridge: Array = []
    for n in range(9):
        var z: float = -0.85 + float(n) * 0.19
        ridge.append(_path([Vector3(0,1.32,z),Vector3(0,1.56 + 0.17*sin(float(n)*2.1),z-0.08),
            Vector3(0,1.72 + 0.19*sin(float(n)*2.1),z-0.14)], [.14,.075,.005], black, float(n)))
    for side in [-1.0,1.0]:
        ridge.append(_path([Vector3(side*0.20,1.60,0.93),Vector3(side*0.24,1.96,0.97),
            Vector3(side*0.13,2.06,0.78)], [.135,.085,.012], bones, side))
        ridge.append(_path([Vector3(side*.15,1.18,1.48),Vector3(side*.16,1.13,1.68)],
            [.075,.014],bones,side+1))
    _skin(visual,"ThornSpineAndEars",ridge,"bone")
    var moss: Array = []
    for n in range(14):
        var z: float = -1.02+float(n)*0.13
        var x: float = (-0.22 if n%2==0 else 0.20)
        moss.append(_path([Vector3(x,1.35,z),Vector3(x*1.2,1.52,z-0.10),
            Vector3(x*1.6,1.57,z-0.18)], [.12,.09,.005],Color("9bab78"),float(n)))
    _skin(visual,"MossFur",moss,"moss")
    for side in [-1.0,1.0]:
        for front in [false,true]:
            var z: float = 0.60 if front else -0.73
            var p: Vector3 = Vector3(side*0.32,1.05,z)
            var shape := [_path([Vector3.ZERO,Vector3(side*0.07,-0.31,0.02),
                Vector3(side*0.06,-0.76,-0.05),Vector3(side*0.09,-0.94,0.18)],
                [.23,.17,.115,.12],fur.darkened(0.16),side+z),
                _path([Vector3(side*0.09,-0.93,0.13),Vector3(side*.13,-1.00,0.34)],
                [.15,.065],black,side)]
            _joint(visual,"Gait_%d" % (0 if side < 0 and front else 1 if side < 0 else 2 if front else 3),p,shape,"fur")
    _eyes(visual,[Vector3(-.18,1.57,1.19),Vector3(.18,1.57,1.19)],"glow_orange")

func _spider(visual: Node3D) -> void:
    var chitin := Color("77747b")
    var shadow := Color("4a3d51")
    _skin(visual,"SpiderArmoredCarapace",[
        _path([Vector3(0,.90,-.97),Vector3(0,.98,-.63),Vector3(0,1.12,-.29),
            Vector3(0,.97,.02)], [.17,.58,.68,.38],chitin,2.2),
        _path([Vector3(0,.94,-.06),Vector3(0,.90,.38),Vector3(0,.91,.73)],
            [.21,.38,.24],shadow,1.1),
        _path([Vector3(0,.87,.55),Vector3(0,.57,.91)], [.30,.12],chitin,1.5)
    ],"chitin")
    var plates: Array = []
    for n in range(5):
        var z: float = -.72 + float(n)*.24
        plates.append(_path([Vector3(-.30,1.30,z),Vector3(0,1.44,z-.10),
            Vector3(.30,1.30,z)], [.10,.14,.08],chitin.lightened(.17),float(n)))
    for side in [-1.0,1.0]:
        for n in range(2):
            plates.append(_path([Vector3(side*.16,.73,.64),Vector3(side*.14,.42,.88),
                Vector3(side*(.21+float(n)*.10),.31,1.07)],
                [.14,.09,.014],shadow,side+float(n)))
    _skin(visual,"CarapacePlatesAndFangs",plates,"chitin")
    for side in [-1.0,1.0]:
        for n in range(4):
            var origin := Vector3(side*.30,.96,.54-float(n)*.36)
            var extent: float = 1.16+float(n%2)*.20
            _joint(visual,"Gait_%d" % (n+(0 if side<0 else 4)),origin,[
                _path([Vector3.ZERO,Vector3(side*.49,.36,.16-float(n)*.12),
                    Vector3(side*.82,.67,.24-float(n)*.17),
                    Vector3(side*extent,.32,.32-float(n)*.24),
                    Vector3(side*(extent+.20),-.88,.38-float(n)*.34)],
                    [.17,.14,.095,.08,.015],shadow.lightened(.16),float(n)+side)
            ],"chitin")
    _eyes(visual,[Vector3(-.19,1.03,.86),Vector3(.19,1.03,.86),
        Vector3(-.08,1.10,.89),Vector3(.08,1.10,.89)],"glow_venom")
    var venom := _skin(visual,"VenomBladder",[_path([
        Vector3(0,1.17,-.60),Vector3(0,1.34,-.66),Vector3(0,1.41,-.81)
    ],[.12,.16,.06],Color("82ba64"),2.6)],"moss")
    venom.name = "VenomBladder"

func _sapling(visual: Node3D) -> void:
    var bark := Color("ad997c")
    var wood := [
        _path([Vector3(0,.40,0),Vector3(.09,.87,0),Vector3(-.12,1.33,.02),
            Vector3(.07,1.91,.03)], [.24,.32,.25,.15],bark,.8),
        _path([Vector3(.03,1.75,0),Vector3(-.16,2.06,-.06),
            Vector3(-.28,2.39,-.16)], [.18,.12,.013],bark.darkened(.2),1.4),
        _path([Vector3(-.16,1.99,-.04),Vector3(-.50,2.13,-.09),
            Vector3(-.72,2.41,-.16)], [.14,.07,.009],bark,1.2),
        _path([Vector3(.16,1.87,0),Vector3(.49,2.17,-.14),
            Vector3(.71,2.38,-.27)], [.13,.08,.006],bark.darkened(.16),3.0)
    ]
    _skin(visual,"SaplingTorsionAndThorns",wood,"bark")
    for side in [-1.0,1.0]:
        _joint(visual,"Gait_%d" % (0 if side<0 else 1),
            Vector3(side*.17,.55,0),[
            _path([Vector3.ZERO,Vector3(side*.10,-.20,.09),
                Vector3(side*.22,-.49,.26),Vector3(side*.38,-.55,.36)],
                [.16,.12,.09,.015],bark,side+1.8)],"bark")
        _joint(visual,"Arm_%s" % ("Left" if side<0 else "Right"),
            Vector3(side*.23,1.48,.03),[
            _path([Vector3.ZERO,Vector3(side*.37,-.28,.02),
                Vector3(side*.62,-.51,.19),Vector3(side*.83,-.69,.30)],
                [.15,.12,.07,.012],bark.darkened(.20),side+2.0),
            _path([Vector3(side*.62,-.51,.19),Vector3(side*.86,-.52,.16)],
                [.085,.006],bark.darkened(.20),side)],"bark")
    _eyes(visual,[Vector3(-.13,1.68,.24),Vector3(.13,1.68,.24)],"glow_orange")
    var foliage: Array = []
    for n in range(10):
        var angle: float = TAU*float(n)/10.0
        foliage.append(_path([Vector3(cos(angle)*.12,2.06,sin(angle)*.12),
            Vector3(cos(angle)*.35,2.25,sin(angle)*.35),
            Vector3(cos(angle)*.46,2.48,sin(angle)*.47)],
            [.13,.11,.01],Color("70895b"),float(n)))
    _skin(visual,"WitheredCrown",foliage,"moss")

func _revenant(visual: Node3D) -> void:
    var pale := Color("c0c3b5")
    var dusk := Color("b1c1ae")
    _skin(visual,"RevenantBones",[
        _path([Vector3(0,.38,0),Vector3(0,.82,.01),Vector3(0,1.51,.02),
            Vector3(0,1.92,.02)], [.13,.20,.29,.13],pale,1.0),
        _path([Vector3(0,1.92,.02),Vector3(0,2.16,.11),Vector3(0,2.39,.12)],
            [.15,.29,.21],pale.darkened(.1),2.3)
    ],"bone")
    var ribs: Array = []
    for n in range(5):
        var y: float = 1.10+float(n)*.14
        ribs.append(_path([Vector3(-.22,y,0),Vector3(0,y-.02,.30),
            Vector3(.22,y,0)], [.08,.07,.05],pale,float(n)))
    _skin(visual,"SpectralRibCage",ribs,"bone")
    var cloth: Array = []
    for side in [-1.0,1.0]:
        cloth.append(_path([Vector3(side*.23,1.87,-.1),Vector3(side*.45,1.24,-.22),
            Vector3(side*.54,.49,-.30),Vector3(side*.71,.16,-.13)],
            [.24,.29,.20,.009],dusk,side))
        cloth.append(_path([Vector3(side*.18,2.13,.01),Vector3(side*.31,2.23,.01),
            Vector3(side*.34,1.98,.13)], [.22,.24,.20],dusk.darkened(.17),side))
    _skin(visual,"RottenShroud",cloth,"cloth")
    for side in [-1.0,1.0]:
        _joint(visual,"Arm_%s" % ("Left" if side<0 else "Right"),
            Vector3(side*.31,1.75,.01),[
            _path([Vector3.ZERO,Vector3(side*.17,-.40,.14),
                Vector3(side*.29,-.74,.23),Vector3(side*.38,-.98,.35)],
                [.16,.11,.08,.012],pale,side+2.2)],"bone")
    _eyes(visual,[Vector3(-.13,2.23,.32),Vector3(.13,2.23,.32)],"glow_ghost")

func _brute(visual: Node3D, boss: bool) -> void:
    var bark := Color("a89880")
    var torso_height: float = 2.45 if boss else 2.20
    var torso: Array = [
        _path([Vector3(0,.37,0),Vector3(0,.95,0),Vector3(.10,1.74,-.05),
            Vector3(0,torso_height,.01)], [.38,.65,.81,.42],bark,1.7),
        _path([Vector3(0,torso_height,.02),Vector3(0,torso_height+.26,.20),
            Vector3(0,torso_height+.43,.23)], [.41,.41,.28],bark.darkened(.1),2.1)
    ]
    for side in [-1.0,1.0]:
        torso.append(_path([Vector3(side*.43,.56,0),Vector3(side*.57,.08,.19),
            Vector3(side*.80,.04,.44)], [.30,.27,.20],bark,side))
        torso.append(_path([Vector3(side*.45,torso_height-.08,-.13),
            Vector3(side*.77,torso_height+.44,-.23),
            Vector3(side*1.05,torso_height+.93,-.40)], [.20,.13,.015],bark.darkened(.3),side+1.2))
    _skin(visual,"MonolithicRotwoodBody",torso,"bark")
    var horns: Array = []
    for side in [-1.0,1.0]:
        horns.append(_path([Vector3(side*.45,torso_height+.18,.06),
            Vector3(side*.55,torso_height+.66,-.18),
            Vector3(side*.83,torso_height+1.08,-.33)], [.21,.14,.005],bark.darkened(.32),side))
        for n in range(3):
            horns.append(_path([Vector3(side*(.59+float(n)*.12),torso_height+.30-float(n)*.18,.08),
                Vector3(side*(.99+float(n)*.14),torso_height+.60-float(n)*.05,-.22)],
                [.13,.008],bark.darkened(.25),float(n)+side))
    _skin(visual,"AsymmetricThornAntlers",horns,"bone")
    for side in [-1.0,1.0]:
        var arm_width: float = .82 if side<0 else 1.10
        _joint(visual,"Arm_%s" % ("Left" if side<0 else "Right"),
            Vector3(side*.66,torso_height-.48,0),[
            _path([Vector3.ZERO,Vector3(side*.35,-.38,.06),
                Vector3(side*.38,-.91,.17),Vector3(side*.48,-1.20,.40)],
                [.35,.31*arm_width,.38*arm_width,.18],bark.darkened(.15),side+3),
            _path([Vector3(side*.48,-1.12,.40),Vector3(side*.62,-1.56,.52)],
                [.25,.012],bark.darkened(.35),side+2)],"bark")
    for side in [-1.0,1.0]:
        _joint(visual,"Gait_%d" % (0 if side<0 else 1),
            Vector3(side*.38,.72,0),[
            _path([Vector3.ZERO,Vector3(side*.14,-.36,.07),
                Vector3(side*.35,-.65,.34),Vector3(side*.48,-.70,.51)],
                [.30,.26,.28,.025],bark.darkened(.19),side+2)],"bark")
    _eyes(visual,[Vector3(-.22,torso_height+.22,.41),Vector3(.22,torso_height+.22,.41)],"glow_orange")
    var core := _skin(visual,"Heart",[_path([
        Vector3(0,torso_height-.50,.59),Vector3(0,torso_height-.38,.80),
        Vector3(0,torso_height-.18,.71)], [.18,.24,.08],Color("ffffff"),2.1)],"glow_orange")
    core.name = "Heart"
    if boss:
        var foliage: Array = []
        for n in range(18):
            var angle: float = TAU*float(n)/18.0
            var distance: float = .30+float(n%3)*.18
            foliage.append(_path([Vector3(cos(angle)*distance,torso_height+.45,sin(angle)*distance),
                Vector3(cos(angle)*(distance+.30),torso_height+.88,sin(angle)*(distance+.28)),
                Vector3(cos(angle)*(distance+.46),torso_height+1.25,sin(angle)*(distance+.40))],
                [.17,.12,.004],Color("87925b"),float(n)))
        _skin(visual,"WitheredBossCrown",foliage,"moss")

func _key(anim: Animation, target: String, values: Array, duration: float) -> void:
    var track: int = anim.add_track(Animation.TYPE_VALUE)
    anim.track_set_path(track, NodePath(target))
    anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
    if values.size() == 3:
        anim.track_insert_key(track, 0.0, values[0])
        anim.track_insert_key(track, duration*0.5, values[1])
        anim.track_insert_key(track, duration, values[2])
    elif values.size() == 4:
        anim.track_insert_key(track, 0.0, values[0])
        anim.track_insert_key(track, duration*0.28, values[1])
        anim.track_insert_key(track, duration*0.68, values[2])
        anim.track_insert_key(track, duration, values[3])

func _rig(root: Node3D, visual: Node3D, kind: String) -> void:
    var animator := AnimationPlayer.new()
    animator.name = "CreatureAnimationPlayer"
    root.add_child(animator)
    var library := AnimationLibrary.new()
    for state in ["Idle","Walk","Jog","Attack","Hit","Death"]:
        var a := Animation.new()
        a.length = 0.8 if state == "Walk" else 0.58 if state == "Jog" else 0.68 if state == "Attack" else 0.40 if state == "Hit" else 0.92 if state == "Death" else 1.6
        a.loop_mode = Animation.LOOP_LINEAR if state == "Idle" or state == "Walk" or state == "Jog" else Animation.LOOP_NONE
        var moving: bool = state == "Walk" or state == "Jog"
        var lift: float = .03 if kind == "spider" else .055 if kind == "hound" else .02 if kind == "revenant" else .07
        _key(a,"CreatureVisual:position",[
            Vector3.ZERO,Vector3(0,lift if moving else lift*.36,0),Vector3.ZERO],a.length)
        for child in visual.get_children():
            if not child is Node3D:
                continue
            var pivot: Node3D = child as Node3D
            if pivot.name.begins_with("Gait_"):
                var num: int = int(pivot.name.trim_prefix("Gait_"))
                var phase: float = (1.0 if num==0 or num==3 else -1.0) if kind=="hound" else 1.0 if num%2==0 else -1.0
                var arc: float = .33 if kind=="spider" else .50 if kind=="hound" else .24 if kind=="revenant" else .37
                var swinging: float = arc*phase if moving else .018*phase
                var angle_axis := Vector3(0,0,swinging) if kind=="spider" else Vector3(swinging,0,0)
                _key(a,"CreatureVisual/%s:rotation" % pivot.name,
                    [angle_axis,-angle_axis,angle_axis] if moving else [Vector3.ZERO,Vector3(.01*phase,0,0),Vector3.ZERO],a.length)
            elif pivot.name.begins_with("Arm_"):
                var sign: float = -1.0 if pivot.name == "Arm_Left" else 1.0
                var twist: float = .10 if moving else .026
                var swing := Vector3(twist*sign,0,0)
                var arc_attack := Vector3(-.62,0,sign*.16)
                var impact := Vector3(.80,0,-sign*.11)
                var movement: Array = [swing,-swing,swing]
                if state=="Attack":
                    movement = [Vector3.ZERO,arc_attack,impact,Vector3.ZERO]
                elif state=="Hit":
                    movement = [Vector3.ZERO,Vector3(-.15,0,sign*.22),Vector3.ZERO]
                elif state=="Death":
                    movement = [Vector3.ZERO,Vector3(0,0,sign*.18),Vector3.ZERO]
                _key(a,"CreatureVisual/%s:rotation" % pivot.name,movement,a.length)
        if state=="Attack" and kind=="hound":
            _key(a,"CreatureVisual:rotation",
                [Vector3.ZERO,Vector3(-.12,0,0),Vector3(.19,0,0),Vector3.ZERO],a.length)
        elif state=="Attack" and kind=="spider":
            _key(a,"CreatureVisual:rotation",
                [Vector3.ZERO,Vector3(.10,0,0),Vector3(-.15,0,0),Vector3.ZERO],a.length)
        elif state=="Hit":
            _key(a,"CreatureVisual:rotation",
                [Vector3.ZERO,Vector3(-.12,0,.10),Vector3.ZERO],a.length)
        elif state=="Death":
            _key(a,"CreatureVisual:rotation",
                [Vector3.ZERO,Vector3(-.17,0,.36),Vector3(-.23,0,.75)],a.length)
        library.add_animation(state,a)
    animator.add_animation_library("",library)

func build(root: Node3D, species: String, elite: bool = false, boss: bool = false) -> bool:
    var id: String = registry.identify(species,elite,boss)
    if not registry.SPECS.has(id):
        return false
    var visual := Node3D.new()
    visual.name = "CreatureVisual"
    root.add_child(visual)
    match id:
        "hound":
            _hound(visual)
        "spider":
            _spider(visual)
        "sapling":
            _sapling(visual)
        "revenant":
            _revenant(visual)
        "brute":
            _brute(visual,false)
        "rot_treant":
            _brute(visual,true)
    visual.scale = Vector3.ONE*float(registry.spec(id).get("scale",1.0))
    _rig(root,visual,id)
    root.set_meta("forest_monster_id",id)
    root.set_meta("forest_monster_signature","SCULPTED_%s" % id.to_upper())
    root.set_meta("visual_rest_position",Vector3.ZERO)
    return true
