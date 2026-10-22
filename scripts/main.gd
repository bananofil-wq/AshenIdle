extends Node3D
# Ashen Idle v0.2 — portrait mobile prototype, offline-safe save and auto combat.
const CLASSES = ["Cinder Knight", "Ash Ranger", "Ember Mage", "Dusk Reaper"]
const SETS = ["Cinderborn", "Gravewarden", "Ashen Crown"]
const SLOTS = ["Weapon", "Armor", "Helm", "Ring"]
const SAVE_FILE = "user://save_v2.json"

var hero_class = 0
var level = 1
var xp = 0
var gold = 0
var stage = 1
var highest = 1
var kills = 0
var hp = 112.0
var enemy_hp = 48.0
var enemy_max = 48.0
var gear: Array = []
var equipped: Dictionary = {}
var skill_points = 0
var skills: Array = [0, 0, 0]
var tick = 0.0
var save_timer = 0.0
var combat_note = "THE ASHEN ROAD AWAITS"
var offline_note = ""
var rng = RandomNumberGenerator.new()
var hero: Node3D
var foe: Node3D
var foe_body: MeshInstance3D
var status: Label
var details: Label
var combat: Label
var inventory: VBoxContainer
var info: Label
var offline: Label
var actions: HBoxContainer
var attack_flash = 0.0
var chaos_time := 0.0
var camera_ref: Camera3D
var arena_mobs: Array = []
var spell_fx: Array = []
var loot_beams: Array = []
var hit_texts: Array = []
var overlay: Control
var center_banner: Label
var stage_banner: Label
var power_label: Label
var map_dots: Control
var legendary_overlay: PanelContainer
var legendary_name: Label
var legendary_stats: Label
var last_legendary: Dictionary = {}
var hero_heart: ColorRect
var combat_bar: ColorRect
var skill_buttons: Array = []
var spawned_boss := false
var screen_note: Label
var popup_shade: ColorRect
var last_inventory_signature := ""
var minimap_refresh_timer := 10.0
var skill_overlay: PanelContainer
var skill_choice_buttons: Array = []
var skill_count_label: Label
var grind_mode := false
var grind_cycles := 0
var auto_skill_timer := 0.0
var skill_cooldowns: Array = [0.0, 0.0, 0.0]
var last_target_pos := Vector3.ZERO
var wave_kills := 0
var wave_size := 1
var inventory_overlay: PanelContainer
var inventory_list: VBoxContainer
var inventory_summary: Label
var boss_hp_label: Label
var boss_hp_bar: ColorRect
var legendary_item_display: Node3D
var legendary_item_viewport: SubViewport
var cached_model_scenes: Dictionary = {}
var ember_motes: Array = []


func _ready() -> void:
    rng.randomize()
    _load_game()
    _build_world()
    _build_ui()
    _spawn_enemy()
    _refresh()

func _mat(color: Color, metallic: float = 0.0, emission: bool = false) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = 0.6
    if emission:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 1.4
    return m

func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
    var n = MeshInstance3D.new()
    n.mesh = shape
    n.position = at
    n.material_override = material
    parent.add_child(n)
    return n

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, light: bool = false) -> MeshInstance3D:
    var b = BoxMesh.new()
    b.size = size
    return _mesh(parent, b, at, _mat(color, 0.15, light))

func _fighter(at: Vector3, color: Color, enemy: bool) -> Node3D:
    var root := Node3D.new()
    root.position = at
    add_child(root)
    var steel := Color("333643") if not enemy else Color("45303b")
    var trim := Color("c69a5e") if not enemy else Color("a84c38")
    var undersuit := Color("171822") if not enemy else Color("22151e")
    _capsule(root, 0.18, 0.85, Vector3(-0.23, 0.46, 0), undersuit)
    _capsule(root, 0.18, 0.85, Vector3(0.23, 0.46, 0), undersuit)
    _box(root, Vector3(0.38, 0.27, 0.55), Vector3(-0.23, 0.16, 0.08), steel)
    _box(root, Vector3(0.38, 0.27, 0.55), Vector3(0.23, 0.16, 0.08), steel)
    _cone(root, 0.55, 0.36, 1.32, Vector3(0, 1.24, 0), color)
    _box(root, Vector3(0.72, 0.20, 0.55), Vector3(0, 1.10, 0.0), trim)
    _capsule(root, 0.17, 0.90, Vector3(-0.60, 1.35, 0), steel, -0.24)
    _capsule(root, 0.17, 0.90, Vector3(0.60, 1.35, 0), steel, 0.24)
    _sphere_part(root, 0.31, Vector3(-0.53, 1.89, 0.02), trim)
    _sphere_part(root, 0.31, Vector3(0.53, 1.89, 0.02), trim)
    var chest_plate := _box(root, Vector3(0.78, 0.67, 0.13), Vector3(0, 1.59, 0.33), steel)
    chest_plate.rotation.z = 0.01
    _box(root, Vector3(0.16, 0.54, 0.15), Vector3(0, 1.59, 0.42), trim)
    _sphere_part(root, 0.32, Vector3(0, 2.26, 0), Color("b49b8d") if not enemy else Color("715460"))
    _cone(root, 0.39, 0.20, 0.48, Vector3(0, 2.53, -0.035), steel)
    _box(root, Vector3(0.63, 0.12, 0.14), Vector3(0, 2.32, 0.28), Color("13151e"))
    _box(root, Vector3(0.50, 0.055, 0.08), Vector3(0, 2.32, 0.375), Color("ffb95e") if enemy else Color("93dafa"), true)
    if enemy:
        _cone(root, 0.15, 0.01, 0.60, Vector3(-0.27, 2.80, 0), Color("2c1f2b"))
        _cone(root, 0.15, 0.01, 0.60, Vector3(0.27, 2.80, 0), Color("2c1f2b"))
        foe_body = chest_plate
        _box(root, Vector3(0.17, 1.03, 0.18), Vector3(0.88, 1.28, 0), trim)
    else:
        _cone(root, 0.62, 0.18, 1.56, Vector3(0, 1.23, -0.40), Color("492236"))
        _box(root, Vector3(0.17, 1.68, 0.14), Vector3(0.93, 1.60, 0), Color("b6c8d5"), true)
        _box(root, Vector3(0.46, 0.12, 0.19), Vector3(0.93, 1.02, 0), trim)
    return root

func _build_world() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("070a12")
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 0.83
    environment.adjustment_contrast = 1.22
    environment.adjustment_saturation = 0.85
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("677186")
    environment.ambient_light_energy = 0.42
    environment.glow_enabled = true
    environment.glow_intensity = 0.34
    world.environment = environment
    add_child(world)

    camera_ref = Camera3D.new()
    camera_ref.position = Vector3(0.0, 15.2, 17.6)
    add_child(camera_ref)
    camera_ref.look_at(Vector3(0.0, 0.2, 0.0), Vector3.UP)
    camera_ref.fov = 42.0
    camera_ref.current = true
    var sun := DirectionalLight3D.new()
    add_child(sun)
    sun.rotation_degrees = Vector3(-58, -31, 0)
    sun.light_color = Color("f5b990")
    sun.light_energy = 0.9
    sun.shadow_enabled = true
    var ember := OmniLight3D.new()
    add_child(ember)
    ember.position = Vector3(0.0, 2.8, 0.5)
    ember.light_color = Color("ff6332")
    ember.light_energy = 1.25
    ember.omni_range = 13.0
    var arcane := OmniLight3D.new()
    add_child(arcane)
    arcane.position = Vector3(-3.6, 4.0, -2.0)
    arcane.light_color = Color("965eff")
    arcane.light_energy = 0.82
    arcane.omni_range = 12

    _box(self, Vector3(17, 0.6, 18), Vector3(0, -0.35, 0), Color("171b27"))
    for x in range(-6, 7):
        for z in range(-6, 7):
            var v := float((x * 3 + z * 7 + 100) % 7) / 36.0
            var stone := Color(0.112 + v * 0.64, 0.126 + v * 0.62, 0.168 + v * 0.72)
            var t := BoxMesh.new()
            t.size = Vector3(1.27, 0.08 + v * 0.1, 1.27)
            _mesh(self, t, Vector3(float(x) * 1.3, -0.04, float(z) * 1.3), _mat(stone))
    _place_dungeon_detail()
    _scatter_embers()
    hero = _make_animated_character(["Knight", "Rogue", "Mage", "Barbarian"][hero_class], Vector3(-0.45, 0, 0.65), false)
    foe = _make_animated_character("Skeleton_Warrior", Vector3(1.55, 0, -0.8), true)
    _spawn_horde()

func _panel_color() -> StyleBoxFlat:
    var b = StyleBoxFlat.new()
    b.bg_color = Color("14141fea")
    b.border_color = Color("966642")
    b.set_border_width_all(2)
    b.set_corner_radius_all(10)
    b.content_margin_left = 14
    b.content_margin_right = 14
    b.content_margin_top = 12
    b.content_margin_bottom = 12
    return b

func _label(t: String, font_size: int, color: Color = Color("e8d8c1")) -> Label:
    var l = Label.new()
    l.text = t
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _button(t: String, callback: Callable) -> Button:
    var b = Button.new()
    b.text = t
    b.custom_minimum_size = Vector2(0, 56)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size", 17)
    b.pressed.connect(callback)
    return b

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    overlay = Control.new()
    overlay.size = get_viewport().get_visible_rect().size
    overlay.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(overlay)

    var portrait := PanelContainer.new()
    portrait.position = Vector2(14, 20)
    portrait.size = Vector2(295, 128)
    portrait.add_theme_stylebox_override("panel", _skin(Color("12141fe8"), Color("b66b48")))
    overlay.add_child(portrait)
    var portrait_box := VBoxContainer.new()
    portrait.add_child(portrait_box)
    portrait_box.add_child(_label("CINDER RECKONING", 19, Color("f6be79")))
    status = _label("", 23, Color("ffe2be"))
    portrait_box.add_child(status)
    details = _label("", 15, Color("f1d7c1"))
    portrait_box.add_child(details)
    hero_heart = ColorRect.new()
    hero_heart.color = Color("d53c3c")
    hero_heart.custom_minimum_size = Vector2(270, 7)
    portrait_box.add_child(hero_heart)
    power_label = _label("", 16, Color("ffd375"))
    portrait_box.add_child(power_label)

    var map_panel := PanelContainer.new()
    map_panel.position = Vector2(496, 20)
    map_panel.size = Vector2(208, 175)
    map_panel.add_theme_stylebox_override("panel", _skin(Color("11121bed"), Color("785a43")))
    overlay.add_child(map_panel)
    var map_column := VBoxContainer.new()
    map_panel.add_child(map_column)
    map_column.add_child(_label("THE LOST LANDS", 16, Color("ead2b0")))
    map_dots = Control.new()
    map_dots.custom_minimum_size = Vector2(180, 80)
    map_column.add_child(map_dots)
    stage_banner = _label("", 24, Color("ffca77"))
    map_column.add_child(stage_banner)

    var controls := VBoxContainer.new()
    controls.position = Vector2(14, 205)
    controls.add_theme_constant_override("separation", 10)
    overlay.add_child(controls)
    controls.add_child(_ornate_button("LOOT", _show_inventory, Vector2(112, 51)))
    controls.add_child(_ornate_button("HERO", _switch_class, Vector2(112, 51)))
    controls.add_child(_ornate_button("TALENT", _open_talent_panel, Vector2(112, 51)))

    var banner := PanelContainer.new()
    banner.position = Vector2(159, 213)
    banner.size = Vector2(402, 83)
    banner.add_theme_stylebox_override("panel", _skin(Color("120f1bd2"), Color("ba823e")))
    overlay.add_child(banner)
    var banner_column := VBoxContainer.new()
    banner.add_child(banner_column)
    center_banner = _label("AUTO-BATTLING...", 29, Color("ffd08c"))
    center_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_column.add_child(center_banner)
    combat = _label("", 18, Color("dbceda"))
    combat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_column.add_child(combat)
    var boss_panel := PanelContainer.new()
    boss_panel.position = Vector2(182, 317)
    boss_panel.size = Vector2(356, 57)
    boss_panel.add_theme_stylebox_override("panel", _skin(Color("160d19ea"), Color("b14b3f")))
    overlay.add_child(boss_panel)
    var boss_col := VBoxContainer.new()
    boss_panel.add_child(boss_col)
    boss_hp_label = _label("ASHEN WARDEN", 17, Color("ffc5a0"))
    boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_col.add_child(boss_hp_label)
    boss_hp_bar = ColorRect.new()
    boss_hp_bar.color = Color("e13b46")
    boss_hp_bar.custom_minimum_size = Vector2(326, 8)
    boss_col.add_child(boss_hp_bar)
    boss_panel.name = "BossHPPanel"


    var bottom := PanelContainer.new()
    bottom.position = Vector2(16, overlay.size.y - 228)
    bottom.size = Vector2(688, 213)
    bottom.add_theme_stylebox_override("panel", _skin(Color("10111de9"), Color("695344")))
    overlay.add_child(bottom)
    var col := VBoxContainer.new()
    bottom.add_child(col)
    info = _label("", 17, Color("edddc7"))
    col.add_child(info)
    combat_bar = ColorRect.new()
    combat_bar.color = Color("ad653c")
    combat_bar.custom_minimum_size = Vector2(640, 5)
    col.add_child(combat_bar)
    var action_line := HBoxContainer.new()
    action_line.add_theme_constant_override("separation", 6)
    col.add_child(action_line)
    actions = action_line
    action_line.add_child(_ornate_button("BOSS", _try_boss, Vector2(106, 46)))
    action_line.add_child(_ornate_button("FARM", _grind, Vector2(106, 46)))
    action_line.add_child(_ornate_button("PUSH", _forward, Vector2(106, 46)))
    action_line.add_child(_ornate_button("HEAL", _heal, Vector2(106, 46)))
    action_line.add_child(_ornate_button("SKILL+", _open_talent_panel, Vector2(106, 46)))
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(630, 68)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    col.add_child(scroll)
    inventory = VBoxContainer.new()
    inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(inventory)
    offline = _label("", 14, Color("ffce6c"))
    col.add_child(offline)

    var skill_bar := HBoxContainer.new()
    skill_bar.position = Vector2(385, overlay.size.y - 337)
    skill_bar.add_theme_constant_override("separation", 10)
    overlay.add_child(skill_bar)
    for s in ["FIRE", "VOID", "ULT"]:
        var b := _ornate_button(s, _use_skill.bind(skill_buttons.size()), Vector2(97, 91))
        skill_buttons.append(b)
        skill_bar.add_child(b)


    popup_shade = ColorRect.new()
    popup_shade.color = Color(0.015, 0.015, 0.024, 0.78)
    popup_shade.size = overlay.size
    popup_shade.visible = false
    popup_shade.mouse_filter = Control.MOUSE_FILTER_STOP
    popup_shade.z_index = 40
    overlay.add_child(popup_shade)

    legendary_overlay = PanelContainer.new()
    legendary_overlay.position = Vector2(96, (overlay.size.y - 567.0) * 0.5)
    legendary_overlay.size = Vector2(528, 567)
    legendary_overlay.z_index = 41
    legendary_overlay.visible = false
    legendary_overlay.add_theme_stylebox_override("panel", _skin(Color("0f1119"), Color("e2ad58")))
    overlay.add_child(legendary_overlay)
    var leg_col := VBoxContainer.new()
    leg_col.add_theme_constant_override("separation", 12)
    legendary_overlay.add_child(leg_col)
    var rare_title := _label("✦  LEGENDARY EQUIPMENT  ✦", 21, Color("ffc76a"))
    rare_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    leg_col.add_child(rare_title)
    var split := HSeparator.new()
    leg_col.add_child(split)
    legendary_name = _label("", 26, Color("fff0bb"))
    legendary_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    legendary_name.custom_minimum_size = Vector2(480, 68)
    leg_col.add_child(legendary_name)
    var item_frame := SubViewportContainer.new()
    item_frame.custom_minimum_size = Vector2(480, 120)
    item_frame.stretch = true
    leg_col.add_child(item_frame)
    legendary_item_viewport = SubViewport.new()
    legendary_item_viewport.size = Vector2i(480, 120)
    legendary_item_viewport.transparent_bg = true
    legendary_item_viewport.own_world_3d = true
    legendary_item_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    item_frame.add_child(legendary_item_viewport)
    legendary_item_display = Node3D.new()
    legendary_item_viewport.add_child(legendary_item_display)
    var item_camera := Camera3D.new()
    item_camera.position = Vector3(2.8, 1.5, 3.2)
    item_camera.look_at(Vector3(0, 0.4, 0), Vector3.UP)
    item_camera.fov = 43
    item_camera.current = true
    legendary_item_viewport.add_child(item_camera)
    var item_light := DirectionalLight3D.new()
    item_light.rotation_degrees = Vector3(-48, -30, 0)
    item_light.light_color = Color("ffe0ae")
    item_light.light_energy = 2.0
    legendary_item_viewport.add_child(item_light)
    var item_env := WorldEnvironment.new()
    var item_env_resource := Environment.new()
    item_env_resource.background_mode = Environment.BG_COLOR
    item_env_resource.background_color = Color(0.0, 0.0, 0.0, 0.0)
    item_env_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    item_env_resource.ambient_light_color = Color("f4d5a0")
    item_env_resource.ambient_light_energy = 0.7
    item_env.environment = item_env_resource
    legendary_item_viewport.add_child(item_env)
    legendary_stats = _label("", 19, Color("eadcc9"))
    legendary_stats.custom_minimum_size = Vector2(480, 175)
    leg_col.add_child(legendary_stats)
    var flavor := _label("Forged in the ashes of fallen worlds.", 15, Color("bca88d"))
    flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    leg_col.add_child(flavor)
    var popup_buttons := HBoxContainer.new()
    popup_buttons.add_theme_constant_override("separation", 12)
    leg_col.add_child(popup_buttons)
    popup_buttons.add_child(_ornate_button("EQUIP", _equip_legendary, Vector2(230, 58)))
    popup_buttons.add_child(_ornate_button("KEEP", _hide_legendary, Vector2(230, 58)))

    skill_overlay = PanelContainer.new()
    skill_overlay.position = Vector2(92, (overlay.size.y - 540.0) * 0.5)
    skill_overlay.size = Vector2(536, 540)
    skill_overlay.visible = false
    skill_overlay.z_index = 41
    skill_overlay.add_theme_stylebox_override("panel", _skin(Color("0e1019"), Color("9c79bc")))
    overlay.add_child(skill_overlay)
    var talents := VBoxContainer.new()
    talents.add_theme_constant_override("separation", 10)
    skill_overlay.add_child(talents)
    var talent_title := _label("ASHEN TALENT TREE", 27, Color("edc99a"))
    talent_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    talents.add_child(talent_title)
    skill_count_label = _label("", 20, Color("edd6aa"))
    skill_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    talents.add_child(skill_count_label)
    var descriptions := [
        "FIREPOWER  +4 ATTACK PER RANK",
        "VITALITY  +24 MAX HP PER RANK",
        "WARDING  REDUCES INCOMING DAMAGE"
    ]
    for i in range(3):
        var button := _ornate_button(descriptions[i], _invest_talent.bind(i), Vector2(485, 75))
        button.add_theme_font_size_override("font_size", 17)
        skill_choice_buttons.append(button)
        talents.add_child(button)
    talents.add_child(_label("Choose a branch. Talents strengthen all four classes.", 16, Color("ac9ca8")))
    talents.add_child(_ornate_button("RETURN TO BATTLE", _close_talent_panel, Vector2(485, 60)))

    inventory_overlay = PanelContainer.new()
    inventory_overlay.position = Vector2(63, (overlay.size.y - 780.0) * 0.5)
    inventory_overlay.size = Vector2(594, 780)
    inventory_overlay.visible = false
    inventory_overlay.z_index = 41
    inventory_overlay.add_theme_stylebox_override("panel", _skin(Color("0e1019"), Color("bf955c")))
    overlay.add_child(inventory_overlay)
    var inv_outer := VBoxContainer.new()
    inv_outer.add_theme_constant_override("separation", 9)
    inventory_overlay.add_child(inv_outer)
    var inv_title := _label("ASHEN ARMORY", 28, Color("f7cb7d"))
    inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    inv_outer.add_child(inv_title)
    inventory_summary = _label("", 17, Color("d5c6b4"))
    inventory_summary.custom_minimum_size = Vector2(550, 118)
    inv_outer.add_child(inventory_summary)
    inv_outer.add_child(_label("FOUND EQUIPMENT — TAP TO EQUIP", 19, Color("f1cb94")))
    var inv_scroll := ScrollContainer.new()
    inv_scroll.custom_minimum_size = Vector2(550, 500)
    inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    inv_outer.add_child(inv_scroll)
    inventory_list = VBoxContainer.new()
    inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inventory_list.add_theme_constant_override("separation", 7)
    inv_scroll.add_child(inventory_list)
    inv_outer.add_child(_ornate_button("RETURN TO BATTLE", _close_inventory_panel, Vector2(550, 56)))




func _max_hp() -> float:
    var modifier = [1.2, 0.9, 0.85, 1.0][hero_class]
    return (100.0 + float(level) * 12.0 + float(skills[1]) * 24.0 + _bonus("hp")) * modifier

func _damage() -> float:
    var modifier = [1.0, 1.15, 1.32, 1.10][hero_class]
    return (8.0 + float(level) * 2.5 + float(skills[0]) * 4.0 + _bonus("damage") + _bonus("elemental") * 0.45) * modifier

func _bonus(key: String) -> float:
    var total = 0.0
    var counts: Dictionary = {}
    for item in equipped.values():
        if not item is Dictionary:
            continue
        total += float(item.get(key, 0))
        var set_name: String = str(item.get("set", ""))
        if set_name != "":
            counts[set_name] = int(counts.get(set_name, 0)) + 1
    if key == "damage" or key == "hp":
        for count in counts.values():
            if int(count) >= 2:
                total += 12.0 if key == "damage" else 25.0
            if int(count) >= 4:
                total += 28.0 if key == "damage" else 50.0
    return total

func _spawn_enemy() -> void:
    if hero == null:
        enemy_max = 50.0 + float(stage) * 20.0
        enemy_hp = enemy_max
        return
    _spawn_horde()
    _update_wave_health()

func _process(delta: float) -> void:
    chaos_time += delta
    if legendary_item_display != null and legendary_overlay.visible:
        legendary_item_display.rotation.y += delta * 0.64
    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = maxf(0.0, float(skill_cooldowns[i]) - delta)
    for i in range(skill_buttons.size()):
        var skill_button: Button = skill_buttons[i]
        skill_button.disabled = float(skill_cooldowns[i]) > 0.0
        skill_button.text = (["FIRE", "VOID", "ULT"][i] if float(skill_cooldowns[i]) <= 0.0 else ["FIRE", "VOID", "ULT"][i] + "\n%.0fs" % float(skill_cooldowns[i]))
    tick += delta
    save_timer += delta
    if hero != null:
        hero.rotation.y = 0.20 + sin(chaos_time * 2.6) * 0.12
        hero.position.y = sin(chaos_time * 2.8) * 0.05
    if foe != null:
        foe.rotation.y = sin(chaos_time * 2.0) * 0.10
    if foe_body != null:
        foe_body.scale = Vector3.ONE * (1.0 + attack_flash * 0.13)
    attack_flash = maxf(0.0, attack_flash - delta * 4.0)
    _update_chaos(delta)
    _update_ember_motes()
    minimap_refresh_timer += delta
    if tick > 0.36 and popup_shade.visible:
        tick = 0.36
    var attack_interval := 0.35 / (1.0 + minf(1.0, _bonus("speed") / 100.0))
    if tick >= attack_interval and not popup_shade.visible:
        tick -= attack_interval
        _fight()
    if save_timer >= 15.0:
        save_timer = 0.0
        _save_game()

func _fight() -> void:
    if arena_mobs.is_empty():
        _complete_wave()
        return
    var target: Node3D = arena_mobs[rng.randi_range(0, arena_mobs.size() - 1)] as Node3D
    if target == null or not is_instance_valid(target):
        return
    var crit: bool = rng.randf() < clampf(0.22 + _bonus("crit") / 100.0, 0.22, 0.68)
    var damage: float = _damage() * rng.randf_range(0.90, 1.40) * (2.1 if crit else 1.0)
    _hit_mob(target, damage, crit)
    attack_flash = 1.0
    if rng.randf() < 0.13 and not arena_mobs.is_empty():
        _use_skill(rng.randi_range(0, 1))
    if arena_mobs.is_empty():
        _complete_wave()
        return
    var remaining_mobs: float = float(arena_mobs.size())
    var incoming: float = maxf(0.25, float(stage) * 0.085 + remaining_mobs * 0.075 - float(skills[2]) * 0.25)
    if stage % 5 == 0:
        incoming *= 1.28
    hp -= incoming
    if hp <= 0.0:
        hp = _max_hp()
        grind_mode = true
        grind_cycles = 0
        stage = maxi(1, highest - 1)
        combat_note = "DEFEATED — AUTO-GRINDING PREVIOUS STAGE"
        _spawn_enemy()
    _refresh()

func _hit_mob(target: Node3D, damage: float, crit: bool) -> void:
    if not is_instance_valid(target) or not arena_mobs.has(target):
        return
    var health: float = float(target.get_meta("hp", 1.0)) - damage
    target.set_meta("hp", health)
    last_target_pos = target.global_position
    _impact(last_target_pos + Vector3(0.0, 0.75, 0.0), Color("ffc769") if crit else Color("b477ff"))
    _damage_popup(int(damage), last_target_pos + Vector3(0.0, 1.45, 0.0), crit)
    if health <= 0.0:
        _kill_mob(target)
    _update_wave_health()

func _kill_mob(target: Node3D) -> void:
    if not is_instance_valid(target):
        return
    var boss: bool = bool(target.get_meta("boss", false))
    var drop_pos: Vector3 = target.global_position
    arena_mobs.erase(target)
    target.queue_free()
    wave_kills += 1
    kills += 1
    gold += stage * 2 + (25 if boss else 3)
    xp += 5 + stage * 2 + (60 if boss else 0)
    if boss or rng.randf() < 0.22:
        _drop_loot_at(drop_pos, boss)
    if boss:
        combat_note = "BOSS DEFEATED — LEGENDARY REWARDS"
    while xp >= level * 30:
        xp -= level * 30
        level += 1
        skill_points += 1
        hp = _max_hp()
        combat_note = "LEVEL UP — TALENT POINT EARNED"

func _update_wave_health() -> void:
    enemy_hp = 0.0
    enemy_max = 0.0
    for mob in arena_mobs:
        if is_instance_valid(mob):
            enemy_hp += maxf(0.0, float(mob.get_meta("hp", 0.0)))
            enemy_max += float(mob.get_meta("max_hp", 0.0))
    enemy_max = maxf(enemy_max, 1.0)

func _complete_wave() -> void:
    var was_boss: bool = stage % 5 == 0
    if grind_mode:
        grind_cycles += 1
        if grind_cycles >= 3 and _damage() >= float(highest) * 3.0 + 10.0:
            grind_mode = false
            stage = highest
            combat_note = "STRONGER NOW — RETRYING THE BOSS"
        else:
            combat_note = "AUTO-GRIND — GAINING LEVELS AND EQUIPMENT"
    else:
        stage += 1
        highest = maxi(highest, stage)
        combat_note = "BOSS CLEARED — NEXT AREA" if was_boss else "AREA CLEARED"
    hp = _max_hp()
    _spawn_enemy()
    _save_game()

func _try_boss() -> void:
    grind_mode = false
    stage = maxi(5, int(ceil(float(highest) / 5.0)) * 5)
    hp = _max_hp()
    combat_note = "BOSS CHALLENGE"
    _spawn_enemy()
    _refresh()

func _grind() -> void:
    grind_mode = true
    grind_cycles = 0
    stage = maxi(1, highest - 1)
    hp = _max_hp()
    combat_note = "FARMING EXPERIENCE AND GEAR"
    _spawn_enemy()
    _refresh()

func _forward() -> void:
    grind_mode = false
    stage = highest
    hp = _max_hp()
    combat_note = "ADVANCING INTO THE ASHEN LANDS"
    _spawn_enemy()
    _refresh()

func _switch_class() -> void:
    hero_class = (hero_class + 1) % 4
    if hero != null:
        hero.queue_free()
    hero = _make_animated_character(["Knight", "Rogue", "Mage", "Barbarian"][hero_class], Vector3(-0.45, 0, 0.65), false)
    hp = _max_hp()
    combat_note = "NY KLASS: " + CLASSES[hero_class]
    _save_game()
    _refresh()

func _upgrade_skill() -> void:
    if skill_points < 1:
        combat_note = "LEVLA UPP FÖR FLER SKILLPOÄNG"
        _refresh()
        return
    var idx = (int(skills[0]) + int(skills[1]) + int(skills[2])) % 3
    skills[idx] = int(skills[idx]) + 1
    skill_points -= 1
    hp = minf(_max_hp(), hp + 25.0)
    combat_note = "TALANG UPPGRADERAD"
    _save_game()
    _refresh()

func _heal() -> void:
    hp = _max_hp()
    combat_note = "VILAR VID GLÖDEN"
    _refresh()

func _drop_loot() -> void:
    _drop_loot_at(_random_spawn() * 0.75, false)

func _drop_loot_at(drop_pos: Vector3, boss_drop: bool) -> void:
    var slot: String = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
    var rarity_roll := rng.randf()
    var rarity := "COMMON"
    var loot_color := Color("b6d2d6")
    if boss_drop or rarity_roll > 0.985:
        rarity = "LEGENDARY"
        loot_color = Color("ffd060")
    elif rarity_roll > 0.87:
        rarity = "EPIC"
        loot_color = Color("ff642d")
    elif rarity_roll > 0.62:
        rarity = "RARE"
        loot_color = Color("a25cff")
    elif rarity_roll > 0.30:
        rarity = "MAGIC"
        loot_color = Color("54baff")
    var prefixes := ["Seven Star", "Flameveil", "Abyssblood", "Celestial", "Gravewarden", "Ghost"]
    var weapon_names := ["Demon Blade", "Soul Scythe", "Greatsword", "Cinder Staff", "Scepter"]
    var name: String = prefixes[rng.randi_range(0, prefixes.size()-1)] + " " + (weapon_names[rng.randi_range(0, weapon_names.size()-1)] if slot == "Weapon" else slot)
    var power := 1 if rarity == "COMMON" else 2 if rarity == "MAGIC" else 3 if rarity == "RARE" else 5 if rarity == "EPIC" else 9
    var item := {
        "slot": slot, "name": name,
        "damage": rng.randi_range(1, 5) * power + stage,
        "hp": rng.randi_range(4, 13) * power + stage * 2,
        "set": SETS[rng.randi_range(0, SETS.size()-1)] if rarity in ["EPIC", "LEGENDARY"] else "",
        "rarity": rarity,
        "crit": rng.randi_range(1, 3) * power,
        "speed": rng.randi_range(1, 2) * power,
        "element": ["FIRE", "FROST", "VOID", "LIGHTNING"][rng.randi_range(0, 3)],
        "elemental": rng.randi_range(1, 4) * power
    }
    gear.push_front(item)
    if gear.size() > 36:
        gear.pop_back()
    _loot_beam(drop_pos, loot_color, name)
    if rarity == "LEGENDARY":
        _show_legendary(item)

func _equip(index: int) -> void:
    if index < 0 or index >= gear.size():
        return
    var item: Dictionary = gear[index]
    equipped[str(item.get("slot", "Weapon"))] = item.duplicate(true)
    hp = minf(hp, _max_hp())
    combat_note = "UTRUSTAD: " + str(item.get("name", "Item"))
    _save_game()
    _refresh()

func _refresh() -> void:
    if status == null or inventory == null:
        return
    status.text = "%s   LVL %d" % [CLASSES[hero_class], level]
    details.text = "HP %.0f / %.0f    XP %d / %d" % [hp, _max_hp(), xp, level * 30]
    power_label.text = "POWER %d   GOLD %d" % [int(_damage() * 90 + _max_hp() * 2), gold]
    hero_heart.scale.x = clampf(hp / maxf(1.0, _max_hp()), 0.03, 1.0)
    stage_banner.text = "STAGE %d%s" % [stage, " BOSS" if stage % 5 == 0 else ""]
    var boss_panel: Control = overlay.get_node_or_null("BossHPPanel") as Control
    if boss_panel != null:
        boss_panel.visible = stage % 5 == 0
        boss_hp_label.text = "ASHEN WARDEN  •  %.0f / %.0f HP" % [maxf(0.0, enemy_hp), enemy_max]
        boss_hp_bar.scale.x = clampf(enemy_hp / maxf(1.0, enemy_max), 0.03, 1.0)
    center_banner.modulate.a = 0.87 + sin(chaos_time * 4.0) * 0.13
    combat.text = combat_note
    info.text = "%.0f DMG  •  %d/%d FOES  •  %d KILLS  •  %d SKILLS" % [_damage(), wave_size - arena_mobs.size(), wave_size, kills, skill_points]
    offline.text = offline_note
    combat_bar.scale.x = clampf(enemy_hp / maxf(1.0, enemy_max), 0.02, 1.0)
    if minimap_refresh_timer > 3.0:
        minimap_refresh_timer = 0.0
        _refresh_minimap()
    var signature := str(gear.size()) + ":" + str(gear[0].get("name", "")) if not gear.is_empty() else "empty"
    if signature == last_inventory_signature:
        return
    last_inventory_signature = signature
    for child in inventory.get_children():
        inventory.remove_child(child)
        child.queue_free()
    if gear.is_empty():
        inventory.add_child(_label("Fäll monster för bättre utrustning.", 16, Color("c5b7b6")))
    else:
        for i in range(mini(gear.size(), 3)):
            var item: Dictionary = gear[i]
            var text_value := "%s  +%d ATK  +%d HP" % [str(item.get("name", "")), int(item.get("damage", 0)), int(item.get("hp", 0))]
            inventory.add_child(_ornate_button(text_value, _equip.bind(i), Vector2(600, 40)))

func _save_game() -> void:
    var data = {
        "class": hero_class, "level": level, "xp": xp, "gold": gold,
        "stage": stage, "highest": highest, "kills": kills, "hp": hp,
        "gear": gear, "equipped": equipped, "skills": skills,
        "skill_points": skill_points, "saved_at": Time.get_unix_time_from_system()
    }
    var f = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_FILE):
        _spawn_enemy()
        hp = _max_hp()
        return
    var f = FileAccess.open(SAVE_FILE, FileAccess.READ)
    if f == null:
        _spawn_enemy()
        return
    var data = JSON.parse_string(f.get_as_text())
    if not data is Dictionary:
        _spawn_enemy()
        return
    hero_class = clampi(int(data.get("class", 0)), 0, CLASSES.size() - 1)
    level = maxi(1, int(data.get("level", 1)))
    xp = maxi(0, int(data.get("xp", 0)))
    gold = maxi(0, int(data.get("gold", 0)))
    stage = maxi(1, int(data.get("stage", 1)))
    highest = maxi(stage, int(data.get("highest", 1)))
    kills = maxi(0, int(data.get("kills", 0)))
    gear = data.get("gear", [])
    equipped = data.get("equipped", {})
    skills = data.get("skills", [0, 0, 0])
    if skills.size() != 3:
        skills = [0, 0, 0]
    skill_points = maxi(0, int(data.get("skill_points", 0)))
    hp = float(data.get("hp", _max_hp()))
    var now = Time.get_unix_time_from_system()
    var elapsed = clampi(int(now - float(data.get("saved_at", now))), 0, 28800)
    var offline_kills = int(float(elapsed) / 12.0)
    if offline_kills > 0:
        gold += offline_kills * (3 + stage * 2)
        xp += offline_kills * (8 + stage * 3)
        kills += offline_kills
        while xp >= level * 30:
            xp -= level * 30
            level += 1
            skill_points += 1
        offline_note = "OFFLINE: %d SEGRAR / +%d GULD" % [offline_kills, offline_kills * (3 + stage * 2)]
    hp = _max_hp()
    _spawn_enemy()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_game()

func _skin(bg: Color, edge: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = edge
    style.set_border_width_all(2)
    style.set_corner_radius_all(13)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    return style

func _ornate_button(title: String, callback: Callable, dims: Vector2) -> Button:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size = dims
    b.add_theme_font_size_override("font_size", 17)
    b.add_theme_stylebox_override("normal", _skin(Color("231c28ef"), Color("8b633c")))
    b.add_theme_stylebox_override("hover", _skin(Color("50323bed"), Color("ffc268")))
    b.pressed.connect(callback)
    return b

func _show_inventory() -> void:
    if legendary_overlay.visible or skill_overlay.visible:
        return
    _refresh_inventory_panel()
    popup_shade.visible = true
    inventory_overlay.visible = true

func _close_inventory_panel() -> void:
    inventory_overlay.visible = false
    popup_shade.visible = false

func _refresh_inventory_panel() -> void:
    if inventory_list == null:
        return
    var current: PackedStringArray = PackedStringArray()
    var set_counts: Dictionary = {}
    for slot in SLOTS:
        if equipped.has(slot):
            var item: Dictionary = equipped[slot]
            current.append(slot + ": " + str(item.get("name", "?")))
            var set_name: String = str(item.get("set", ""))
            if set_name != "":
                set_counts[set_name] = int(set_counts.get(set_name, 0)) + 1
        else:
            current.append(slot + ": EMPTY")
    var set_parts: PackedStringArray = PackedStringArray()
    for set_name in set_counts:
        set_parts.append(str(set_name) + " " + str(set_counts[set_name]) + "/4")
    inventory_summary.text = "EQUIPPED\n" + "    |    ".join(current.slice(0, 2)) + "\n" + "    |    ".join(current.slice(2, 4)) + "\nSETS: " + (", ".join(set_parts) if not set_parts.is_empty() else "None")
    for child in inventory_list.get_children():
        child.queue_free()
    if gear.is_empty():
        inventory_list.add_child(_label("No equipment found yet. Defeat monsters to loot.", 18, Color("c8b9b2")))
        return
    for i in range(gear.size()):
        var item: Dictionary = gear[i]
        var rarity: String = str(item.get("rarity", "COMMON"))
        var color: Color = Color("d4d9de")
        if rarity == "MAGIC":
            color = Color("62b9f8")
        elif rarity == "RARE":
            color = Color("b882ff")
        elif rarity == "EPIC":
            color = Color("ff9364")
        elif rarity == "LEGENDARY":
            color = Color("ffcc69")
        var item_title: String = "%s  %s  |  +%d ATK +%d HP" % [rarity, str(item.get("name", "Item")), int(item.get("damage", 0)), int(item.get("hp", 0))]
        var btn: Button = _ornate_button(item_title, _equip_from_armory.bind(i), Vector2(545, 60))
        btn.add_theme_color_override("font_color", color)
        inventory_list.add_child(btn)

func _equip_from_armory(index: int) -> void:
    _equip(index)
    _refresh_inventory_panel()

func _refresh_minimap() -> void:
    if map_dots == null:
        return
    for n in map_dots.get_children():
        n.queue_free()
    for i in range(18):
        var dot := ColorRect.new()
        dot.color = Color("c25139") if i % 5 != 0 else Color("f8b855")
        dot.position = Vector2(8 + float((i * 31) % 152), 8 + float((i * 17) % 65))
        dot.size = Vector2(4, 4)
        map_dots.add_child(dot)
    var hero_dot := ColorRect.new()
    hero_dot.color = Color("99e7f9")
    hero_dot.size = Vector2(7, 7)
    hero_dot.position = Vector2(91, 40)
    map_dots.add_child(hero_dot)

func _hide_legendary() -> void:
    popup_shade.visible = false
    legendary_overlay.visible = false

func _equip_legendary() -> void:
    if last_legendary.is_empty():
        return
    equipped[str(last_legendary.get("slot", "Weapon"))] = last_legendary.duplicate(true)
    combat_note = "LEGENDARY EQUIPPED!"
    hp = _max_hp()
    _hide_legendary()
    _save_game()
    _refresh()

func _show_legendary(item: Dictionary) -> void:
    if legendary_overlay.visible:
        return
    last_legendary = item.duplicate(true)
    _update_item_preview(item)
    legendary_name.text = str(item.get("name", "Ashen Relic")).to_upper()
    legendary_stats.text = "POWER   %d\nATTACK   +%d\nVITALITY   +%d\nCRITICAL CHANCE   +%d%%\nATTACK SPEED   +%d%%\n%s DAMAGE   +%d\nSET   %s" % [int(item.get("damage", 0)) * 78, int(item.get("damage", 0)), int(item.get("hp", 0)), int(item.get("crit", 0)), int(item.get("speed", 0)), str(item.get("element", "FIRE")), int(item.get("elemental", 0)), str(item.get("set", "Cinderborn"))]
    popup_shade.visible = true
    legendary_overlay.visible = true

func _use_skill(index: int) -> void:
    if index < 0 or index >= 3 or popup_shade.visible:
        return
    if float(skill_cooldowns[index]) > 0.0:
        return
    skill_cooldowns[index] = [3.2, 5.2, 12.0][index]
    var palette: Array = [Color("ff6b20"), Color("9653ff"), Color("fff1a8")]
    _spell_burst(palette[index], 2.2 + float(index) * 0.7, 3 + index * 2)
    var multiplier: float = [1.25, 1.60, 2.80][index]
    var targets: Array = arena_mobs.duplicate()
    targets.shuffle()
    var target_count: int = mini(targets.size(), [3, 5, 10][index])
    for i in range(target_count):
        var mob: Node3D = targets[i] as Node3D
        if is_instance_valid(mob) and arena_mobs.has(mob):
            _hit_mob(mob, _damage() * multiplier, index == 2)
    combat_note = ["FIRE NOVA!", "VOID STORM!", "ASHEN APOCALYPSE!"][index]
    if arena_mobs.is_empty():
        _complete_wave()
    _refresh()

func _random_spawn() -> Vector3:
    var a := rng.randf_range(0.0, TAU)
    var d := rng.randf_range(1.7, 4.8)
    return Vector3(cos(a) * d, 0, sin(a) * d)


func _spawn_horde() -> void:
    for mob in arena_mobs:
        if is_instance_valid(mob):
            mob.queue_free()
    arena_mobs.clear()
    wave_kills = 0
    var is_boss: bool = stage % 5 == 0
    var mob_count: int = (6 + mini(int(stage / 10), 4)) if is_boss else (11 + mini(int(stage / 5), 11))
    wave_size = mob_count
    for i in range(mob_count):
        var elite: bool = is_boss and i == 0
        var model_name: String = "Skeleton_Warrior" if elite else ["Skeleton_Minion", "Skeleton_Rogue", "Skeleton_Warrior", "Skeleton_Mage"][i % 4]
        var root := Node3D.new()
        add_child(root)
        var packed := _get_asset_scene(model_name)
        if packed != null:
            var instance: Node3D = packed.instantiate() as Node3D
            if instance != null:
                root.add_child(instance)
                instance.scale = Vector3.ONE * (1.45 if elite else 0.57 if i % 4 != 2 else 0.68)
                _play_animation(instance, ["Idle", "idle", "Walking_A", "Walking", "walk"])
        if root.get_child_count() == 0:
            var body := CapsuleMesh.new()
            body.radius = 0.38 if not elite else 0.67
            body.height = 1.18 if not elite else 2.1
            _mesh(root, body, Vector3(0, 0.8, 0), _mat(Color("80404f")))
        root.position = _random_spawn()
        var mob_health := (14.0 + float(stage) * 5.0 + float(level) * 0.20) * (13.0 if elite else 1.0)
        root.set_meta("hp", mob_health)
        root.set_meta("max_hp", mob_health)
        root.set_meta("boss", elite)
        root.set_meta("speed", 0.22 + rng.randf_range(0.01, 0.10))
        root.set_meta("phase", rng.randf_range(0.0, TAU))
        arena_mobs.append(root)
    combat_note = "BOSS ENCOUNTER — THE ASHEN WARDEN" if is_boss else "HORDE APPROACHING — AUTO COMBAT"

func _impact(pos: Vector3, color: Color) -> void:
    var ball := SphereMesh.new()
    ball.radius = 0.12
    ball.height = 0.24
    var node := _mesh(self, ball, pos, _bright(color))
    spell_fx.append({"node": node, "time": 0.40, "total": 0.40, "type": "hit"})
    if spell_fx.size() > 45:
        var old = spell_fx.pop_front()
        if is_instance_valid(old["node"]):
            old["node"].queue_free()

func _spell_burst(color: Color, size: float, shards: int) -> void:
    var ring := TorusMesh.new()
    ring.inner_radius = size * 0.38
    ring.outer_radius = size * 0.43
    var pulse_mesh := _mesh(self, ring, Vector3(0, 0.12, 0), _bright(color))
    pulse_mesh.scale = Vector3.ONE * 0.65
    spell_fx.append({"node": pulse_mesh, "time": 0.55, "total": 0.55, "type": "spell"})
    for i in range(shards):
        var a := TAU * float(i) / float(shards)
        var p := Vector3(cos(a) * size * 0.42, rng.randf_range(0.3,1.3), sin(a) * size * 0.42)
        _impact(p, color)

func _bright(color: Color) -> Material:
    var m := _mat(color.darkened(0.20))
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = 0.8
    return m

func _loot_beam(pos: Vector3, color: Color, title: String) -> void:
    var column := CylinderMesh.new()
    column.top_radius = 0.018
    column.bottom_radius = 0.065
    column.height = 1.65
    var mesh := _mesh(self, column, pos + Vector3(0, 0.94, 0), _bright(color.darkened(0.35)))
    var base := CylinderMesh.new()
    base.top_radius = 0.25
    base.bottom_radius = 0.25
    base.height = 0.025
    var disc := _mesh(self, base, pos + Vector3(0, 0.08, 0), _bright(color))
    var label := _label(title, 18, color)
    label.size = Vector2(260, 36)
    overlay.add_child(label)
    loot_beams.append({"mesh": mesh, "disc": disc, "label": label, "pos": pos, "time": 5.2})
    if loot_beams.size() > 12:
        _clear_beam(loot_beams.pop_front())

func _clear_beam(beam: Dictionary) -> void:
    for key in ["mesh", "disc", "label"]:
        if is_instance_valid(beam[key]):
            beam[key].queue_free()

func _damage_popup(value: int, pos: Vector3, crit: bool) -> void:
    if overlay == null:
        return
    var label := _label(str(value), 25 if crit else 18, Color("ffdf83") if crit else Color("f3e2dc"))
    label.size = Vector2(135, 34)
    overlay.add_child(label)
    hit_texts.append({"label": label, "pos": pos, "time": 0.84})
    if hit_texts.size() > 30:
        var old = hit_texts.pop_front()
        if is_instance_valid(old["label"]):
            old["label"].queue_free()

func _update_chaos(delta: float) -> void:
    for i in range(arena_mobs.size()):
        var mob = arena_mobs[i]
        if not is_instance_valid(mob):
            continue
        var a := float(i) * 2.39996 + chaos_time * (0.2 if i % 2 == 0 else -0.17)
        var r := 2.0 + float(i % 8) * 0.39
        mob.position = Vector3(cos(a) * r, sin(chaos_time * 4.0 + float(i)) * 0.07, sin(a) * r)
        mob.rotation.y = a + PI
    for i in range(spell_fx.size() - 1, -1, -1):
        var fx: Dictionary = spell_fx[i]
        fx["time"] = float(fx["time"]) - delta
        var m: MeshInstance3D = fx["node"]
        if is_instance_valid(m):
            var p := 1.0 - float(fx["time"]) / float(fx["total"])
            m.scale = Vector3.ONE * (0.65 + p * (0.58 if fx["type"] == "spell" else 1.1))
        if float(fx["time"]) <= 0.0:
            if is_instance_valid(m):
                m.queue_free()
            spell_fx.remove_at(i)
    for i in range(loot_beams.size() - 1, -1, -1):
        var beam: Dictionary = loot_beams[i]
        beam["time"] = float(beam["time"]) - delta
        var label: Label = beam["label"]
        if camera_ref != null and is_instance_valid(label):
            var p := camera_ref.unproject_position(Vector3(beam["pos"]) + Vector3(0, 3.3, 0))
            label.position = p - Vector2(100, 14)
            label.modulate.a = clampf(float(beam["time"]), 0.0, 1.0)
        if float(beam["time"]) <= 0.0:
            _clear_beam(beam)
            loot_beams.remove_at(i)
    for i in range(hit_texts.size() - 1, -1, -1):
        var hit: Dictionary = hit_texts[i]
        hit["time"] = float(hit["time"]) - delta
        hit["pos"] = Vector3(hit["pos"]) + Vector3(0, delta * 2.1, 0)
        var label: Label = hit["label"]
        if is_instance_valid(label):
            var text_screen_pos := camera_ref.unproject_position(Vector3(hit["pos"]))
            label.visible = text_screen_pos.x > 28.0 and text_screen_pos.x < overlay.size.x - 28.0 and text_screen_pos.y > 385.0 and text_screen_pos.y < overlay.size.y - 260.0
            label.position = text_screen_pos - Vector2(50, 15)
            label.modulate.a = clampf(float(hit["time"]) / 0.84, 0.0, 1.0)
        if float(hit["time"]) <= 0.0:
            if is_instance_valid(label):
                label.queue_free()
            hit_texts.remove_at(i)

func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, tilt: float = 0.0) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = maxf(height, radius * 2.05)
    var part := _mesh(parent, mesh, pos, _mat(color, 0.25))
    part.rotation.z = tilt
    return part

func _cone(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = bottom
    mesh.top_radius = top
    mesh.height = height
    return _mesh(parent, mesh, pos, _mat(color, 0.12))

func _sphere_part(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    return _mesh(parent, mesh, pos, _mat(color, 0.12))

func _get_asset_scene(short_name: String) -> PackedScene:
    if cached_model_scenes.has(short_name):
        return cached_model_scenes[short_name] as PackedScene
    var path: String = "res://assets/models/" + short_name + ".glb"
    if not ResourceLoader.exists(path):
        return null
    var scene: PackedScene = ResourceLoader.load(path) as PackedScene
    if scene != null:
        cached_model_scenes[short_name] = scene
    return scene

func _play_animation(model: Node, candidates: Array) -> void:
    var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
    for found in players:
        var player: AnimationPlayer = found as AnimationPlayer
        if player == null:
            continue
        var names := player.get_animation_list()
        for candidate in candidates:
            for name in names:
                if str(name).to_lower().contains(str(candidate).to_lower()):
                    player.play(name)
                    return
        if names.size() > 0:
            player.play(names[0])
            return

func _make_animated_character(model_name: String, at: Vector3, enemy: bool) -> Node3D:
    var packed := _get_asset_scene(model_name)
    if packed == null:
        return _fighter(at, Color("a43f52") if enemy else Color("507b81"), enemy)
    var root := Node3D.new()
    root.position = at
    add_child(root)
    var model: Node3D = packed.instantiate() as Node3D
    if model == null:
        root.queue_free()
        return _fighter(at, Color("a43f52") if enemy else Color("507b81"), enemy)
    root.add_child(model)
    model.scale = Vector3.ONE * (0.72 if enemy else 0.86)
    model.rotation.y = PI
    _play_animation(model, ["Idle_A", "Idle", "idle"])
    return root

func _place_dungeon_model(asset_name: String, at: Vector3, yaw: float = 0.0, factor: float = 1.0) -> void:
    var packed := _get_asset_scene(asset_name)
    if packed == null:
        return
    var model := packed.instantiate() as Node3D
    if model == null:
        return
    add_child(model)
    model.position = at
    model.rotation.y = yaw
    model.scale = Vector3.ONE * factor
    if asset_name.begins_with("floor_tile") or asset_name == "wall_broken":
        # Tint each instance without discarding the imported CC0 material textures.
        var tint := Color(0.46, 0.56, 0.75) if asset_name.begins_with("floor_tile") else Color(0.70, 0.73, 0.80)
        for child in model.find_children("*", "MeshInstance3D", true, false):
            var part := child as MeshInstance3D
            if part == null:
                continue
            for surface_i in range(part.get_surface_override_material_count()):
                var source_mat := part.get_active_material(surface_i) as BaseMaterial3D
                if source_mat != null:
                    var colored_mat := source_mat.duplicate() as BaseMaterial3D
                    colored_mat.albedo_color = colored_mat.albedo_color * tint
                    part.set_surface_override_material(surface_i, colored_mat)

func _scatter_embers() -> void:
    # Tiny drifting emissive ash sparks provide depth without a heavy particle shader.
    for i in range(44):
        var mesh := SphereMesh.new()
        mesh.radius = rng.randf_range(0.025, 0.054)
        mesh.height = mesh.radius * 2.0
        mesh.radial_segments = 8
        mesh.rings = 4
        var spark := _mesh(self, mesh, Vector3(rng.randf_range(-5.8, 5.8), 0.2, rng.randf_range(-5.8, 5.8)), _bright(Color("f47c3d") if i % 3 else Color("ffca78")))
        var phase := rng.randf_range(0.0, TAU)
        ember_motes.append({"node": spark, "x": spark.position.x, "z": spark.position.z, "phase": phase, "rate": rng.randf_range(0.22, 0.53)})

func _update_ember_motes() -> void:
    for mote in ember_motes:
        var spark: MeshInstance3D = mote["node"]
        if not is_instance_valid(spark):
            continue
        var t: float = chaos_time * float(mote["rate"]) + float(mote["phase"])
        spark.position = Vector3(float(mote["x"]) + sin(t * 1.4) * 0.28, 0.15 + fposmod(t, 3.2), float(mote["z"]) + cos(t * 1.1) * 0.24)

func _place_dungeon_detail() -> void:
    # Geometry and materials supplied by the CC0 KayKit Dungeon Remastered pack.
    # Existing stone slabs remain beneath these imported floor meshes as a safe fallback.
    for x in range(-4, 5):
        for z in range(-4, 5):
            var n: int = absi(x * 7 + z * 13)
            var asset_name := "floor_tile_large"
            if n % 7 == 0:
                asset_name = "floor_tile_large_rocks"
            elif n % 11 == 0:
                asset_name = "floor_tile_small_broken_A"
            _place_dungeon_model(asset_name, Vector3(float(x) * 1.72, -0.01, float(z) * 1.72), float(n % 4) * PI / 2.0, 0.84)
    for i in range(9):
        var a := TAU * float(i) / 12.0 + PI * 0.08
        var dist := 6.5
        var pos := Vector3(cos(a) * dist, 0.0, -absf(sin(a) * dist) - 1.1)
        _place_dungeon_model("pillar_decorated" if i % 3 == 0 else "wall_broken", pos, a + PI / 2.0, 0.86)
        if i % 3 == 0:
            _place_dungeon_model("torch_lit", pos + Vector3(0, 1.35, 0), a + PI, 0.8)

func _open_talent_panel() -> void:
    if legendary_overlay.visible:
        return
    _update_talent_labels()
    popup_shade.visible = true
    skill_overlay.visible = true

func _close_talent_panel() -> void:
    skill_overlay.visible = false
    popup_shade.visible = false

func _update_talent_labels() -> void:
    if skill_count_label == null:
        return
    skill_count_label.text = "AVAILABLE POINTS: " + str(skill_points)
    for i in range(3):
        var button: Button = skill_choice_buttons[i]
        button.text = ["FIREPOWER", "VITALITY", "WARDING"][i] + "  •  RANK " + str(int(skills[i])) + "\n" + ["+4 ATTACK / RANK", "+24 MAX HP / RANK", "LESS DAMAGE TAKEN"][i]
        button.disabled = skill_points < 1

func _invest_talent(index: int) -> void:
    if skill_points < 1 or index < 0 or index >= 3:
        return
    skills[index] = int(skills[index]) + 1
    skill_points -= 1
    hp = minf(_max_hp(), hp + 24.0)
    combat_note = ["FIREPOWER INCREASED", "MAXIMUM HP INCREASED", "WARDING INCREASED"][index]
    _update_talent_labels()
    _save_game()
    _refresh()

func _update_item_preview(item: Dictionary) -> void:
    if legendary_item_display == null:
        return
    for child in legendary_item_display.get_children():
        child.queue_free()
    legendary_item_display.rotation = Vector3.ZERO
    var name: String = str(item.get("name", "")).to_lower()
    var model_name := "sword_2handed"
    if name.contains("staff") or name.contains("scepter"):
        model_name = "staff"
    elif name.contains("dagger") or name.contains("ring"):
        model_name = "dagger"
    var asset_path := "res://assets/weapons/" + model_name + ".gltf"
    if ResourceLoader.exists(asset_path):
        var packed: PackedScene = load(asset_path) as PackedScene
        if packed != null:
            var weapon: Node3D = packed.instantiate() as Node3D
            if weapon != null:
                legendary_item_display.add_child(weapon)
                weapon.scale = Vector3.ONE * 2.2
                weapon.position = Vector3(0, -0.75, 0)
                return
    # Mesh fallback if asset import fails: no blank loot card.
    var blade := _box(legendary_item_display, Vector3(0.18, 1.80, 0.11), Vector3(0, 0.55, 0), Color("d5e3ec"), true)
    blade.rotation.z = 0.2
    _box(legendary_item_display, Vector3(0.67, 0.12, 0.16), Vector3(0, -0.12, 0), Color("f2be61"), true)
