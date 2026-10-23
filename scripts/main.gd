extends Node3D
# Ashen Idle v0.2 — portrait mobile prototype, offline-safe save and auto combat.
const CLASSES = ["Cinder Knight", "Ash Ranger", "Ember Mage", "Dusk Reaper"]
const SETS = ["Cinderborn", "Gravewarden", "Ashen Crown"]
const BOSS_NAMES = ["ASHEN WARDEN", "VOID HARBINGER", "BONE TYRANT"]
const BOSS_INTERVAL := 10
const CLASS_MP_BASE = [70.0, 95.0, 165.0, 82.0]
const CLASS_MP_PER_LEVEL = [2.0, 3.0, 6.0, 3.0]
const CLASS_MP_REGEN = [6.0, 10.0, 16.0, 9.0]
const CLASS_DEFENSE = [0.23, 0.07, 0.06, 0.13]
const CLASS_SKILL_COSTS = [[10.0, 20.0, 45.0], [14.0, 22.0, 48.0], [25.0, 36.0, 85.0], [15.0, 27.0, 56.0]]

const CLASS_SPELLS = [
    ["FLAME", "SHIELD", "INFERNO"],
    ["VOLLEY", "TRAP", "ARROWFALL"],
    ["FIRE", "CHAIN LIGHTNING", "ARCANE"],
    ["REAP", "VOID", "NIGHTFALL"]
]
const SLOTS = ["Weapon", "Armor", "Helm", "Ring"]
const CLASS_TALENT_NAMES = [
    ["BLADE MASTERY", "IRON FORTITUDE", "BULWARK"],
    ["DEADLY PRECISION", "WILD SURVIVAL", "QUICK REFLEXES"],
    ["ARCANE POWER", "MYSTIC BARRIER", "ICE WARD"],
    ["SOUL HARVEST", "BLOOD RITUAL", "SHADOW VEIL"]
]
const CLASS_DESCRIPTIONS = [
    "Heavy armor and high DEF. Protects against bosses.",
    "Fast precision hunter. High critical chance.",
    "Arcane sorcerer. Highest MP and spell damage.",
    "Shadow fighter. Steals life with each strike."
]
const CLASS_SKILL_DESCRIPTIONS = [
    ["Fire-infused melee", "Restores your health", "Massive fire damage"],
    ["Hits several foes", "Controls groups of enemies", "Storm of arrows"],
    ["Explosive fire magic", "Lightning jumps between more enemies as it levels", "Devastating arcane burst"],
    ["Steals life on hit", "Dark energy blast", "Powerful shadow attack"]
]
const SKILL_UNLOCK_LEVELS = [1, 5, 10]
const SKILL_MAX_RANK := 12
const SAVE_FILE = "user://save_v2.json"
const EVO = preload("res://scripts/evolution_rules.gd")
const DIRECTOR = preload("res://scripts/encounter_director.gd")

var hero_class = 0
var level = 1
var xp = 0
var gold = 0
var stage = 1
var highest = 1
var kills = 0
var hp = 112.0
var mp := 0.0
var enemy_hp = 48.0
var enemy_max = 48.0
var boss_health := 1.0
var boss_max := 1.0
var gear: Array = []
var equipped: Dictionary = {}
var skill_points = 0
var skills: Array = [0, 0, 0]
var class_talents: Dictionary = {}
var class_skill_ranks: Dictionary = {}
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
var camera_focus := Vector3.ZERO
var camera_kick := 0.0
var camera_shake := 0.0
var camera_time := 0.0
var cinematic_camera := true
var arena_mobs: Array = []
var spell_fx: Array = []
var loot_beams: Array = []
var hit_texts: Array = []
var overlay: Control
var center_banner: Label
var stage_banner: Label
var power_label: Label
var map_dots: Control
var journey_track: ColorRect
var journey_caption: Label
var fps_label: Label
var fps_sample_timer := 0.0
var encounter_banner_time := 0.0
var legendary_overlay: PanelContainer
var legendary_name: Label
var legendary_stats: Label
var last_legendary: Dictionary = {}
var hero_heart: ColorRect
var hero_mana_bar: ColorRect
var hero_mana_label: Label
var combat_bar: ColorRect
var skill_buttons: Array = []
var spawned_boss := false
var screen_note: Label
var popup_shade: ColorRect
var last_inventory_signature := ""
var minimap_refresh_timer := 10.0
var action_ui_timer := 0.0
var last_map_stage := -1
var skill_overlay: PanelContainer
var hero_overlay: PanelContainer
var hero_return_button: Button
var startup_selection := true
var class_selection_locked := false # Reset only by restarting the game.
var hero_choice_buttons: Array = []
var evolution_choices: Dictionary = {} # Per-class tiers: four irreversible branch choices.
var evolution_overlay: PanelContainer
var evolution_title: Label
var evolution_summary: Label
var evolution_buttons: Array = []
var evolution_close_button: Button
var evolution_action_button: Button
var skill_choice_buttons: Array = []
var skill_upgrade_buttons: Array = []
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
var ritual_marks: Array = []
var attack_animation_index := 0
var biome_index := -1
var dungeon_map: Node3D
var dungeon_points := PackedVector3Array()
var dungeon_room_index := 1
var dungeon_travel_distance := 0.0
var boss_telegraph: MeshInstance3D
var boss_cast_timer := 4.5
var boss_cast_windup := 0.0
var boss_warning_center := Vector3.ZERO
var boss_dodges := 0
var hero_hit_flash := 0.0
var earned_bosses: Dictionary = {}
var battle_statistics: Dictionary = {"bosses": 0, "loot": 0, "forged": 0}
var bg_environment: WorldEnvironment
var key_sun: DirectionalLight3D
var fire_light: OmniLight3D
var mystic_light: OmniLight3D
var spark_texture: ImageTexture
var pbr_floor: MeshInstance3D
var art_brazier_lights: Array[OmniLight3D] = []
var vfx_last_msec := 0
var shared_animation_cache: Dictionary = {}
var screen_flash: ColorRect
var screen_flash_fade := 0.0
var fx_sounds: Array = []
var sound_bank: Node
var footstep_clock := 0.0
var audio_enabled := true
var sfx_toggle_button: Button
var last_hit_sound_msec := 0
var auto_equip := true
var auto_gear_button: Button
var equipped_vfx: Node3D
var encounter_director = DIRECTOR.new()
var current_encounter: Dictionary = {}
var encounter_started_ms := 0


func _ready() -> void:
    rng.randomize()
    _load_game()
    _create_fx_textures()
    _build_world()
    _build_ui()
    _fit_hud()
    get_viewport().size_changed.connect(_fit_hud)
    _create_flash_layer()
    _prepare_audio()
    _spawn_enemy()
    _sync_equipment_visuals()
    _apply_biome()
    if mp <= 0.0:
        mp = _max_mp()
    _refresh()
    _show_hero_panel(true)

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
    bg_environment = world
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("070a12")
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 1.02
    environment.adjustment_contrast = 1.08
    environment.adjustment_saturation = 0.88
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("677186")
    environment.ambient_light_energy = 0.73
    environment.glow_enabled = false
    # Keep saturated spell silhouettes; aggressive glow had clipped the entire combat area white.
    environment.glow_intensity = 0.38
    environment.glow_strength = 0.76
    world.environment = environment
    add_child(world)

    camera_ref = Camera3D.new()
    camera_ref.position = Vector3(0.0, 17.2, 19.2)
    add_child(camera_ref)
    camera_ref.look_at(Vector3(0.0, 0.2, 0.0), Vector3.UP)
    camera_ref.fov = 47.0
    camera_ref.current = true
    camera_focus = Vector3.ZERO
    var sun := DirectionalLight3D.new()
    key_sun = sun
    add_child(sun)
    sun.rotation_degrees = Vector3(-58, -31, 0)
    sun.light_color = Color("f5b990")
    sun.light_energy = 1.05
    # Fake contact shadows remain beneath characters; full-scene shadows
    # over thousands of dungeon props were too expensive for mobile GLES3.
    sun.shadow_enabled = false
    var ember := OmniLight3D.new()
    fire_light = ember
    add_child(ember)
    ember.position = Vector3(0.0, 2.8, 0.5)
    ember.light_color = Color("ff6332")
    ember.light_energy = 0.94
    ember.omni_range = 10.5
    var arcane := OmniLight3D.new()
    mystic_light = arcane
    add_child(arcane)
    arcane.position = Vector3(-3.6, 4.0, -2.0)
    arcane.light_color = Color("965eff")
    arcane.light_energy = 0.56
    arcane.omni_range = 10

    # The old static arena is replaced by interconnected dungeon chambers.
    var dungeon_script: Script = preload("res://scripts/dungeon_builder.gd")
    dungeon_map = dungeon_script.new() as Node3D
    dungeon_map.name = "TraversableDungeon"
    add_child(dungeon_map)
    hero = _make_animated_character(["Knight", "Rogue", "Mage", "Barbarian"][hero_class], Vector3(0, 0, 5), false)

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
    if font_size >= 24 or t == "CINDER RECKONING" or t == "THE LOST LANDS" or t.contains("LEGENDARY EQUIPMENT"):
        if ResourceLoader.exists("res://assets/fonts/Cinzel.ttf"):
            var display_font := load("res://assets/fonts/Cinzel.ttf") as Font
            if display_font != null:
                l.add_theme_font_override("font", display_font)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
    l.add_theme_constant_override("shadow_offset_x", 1)
    l.add_theme_constant_override("shadow_offset_y", 2)
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

func _fit_hud() -> void:
    # The game is authored in a 720px-wide portrait design space. Scale the
    # entire HUD to the *actual* window width, but preserve all extra height:
    # 720x1280 and tall Pixel displays keep the bottom controls accessible.
    if overlay == null:
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var ui_scale: float = clampf(viewport_size.x / 720.0, 0.45, 2.5)
    overlay.scale = Vector2.ONE * ui_scale
    overlay.position = Vector2.ZERO
    overlay.size = Vector2(720, maxf(1280.0, viewport_size.y / ui_scale))
    var height: float = overlay.size.y
    var bottom: Control = overlay.get_node_or_null("BottomHUD") as Control
    if bottom != null:
        bottom.position.y = height - 156.0
    var abilities: Control = overlay.get_node_or_null("SkillHUD") as Control
    if abilities != null:
        abilities.position.y = height - 248.0
    if popup_shade != null:
        popup_shade.size = overlay.size
    for panel in [legendary_overlay, skill_overlay, hero_overlay, evolution_overlay, inventory_overlay]:
        if panel != null:
            var popup: Control = panel as Control
            popup.position = Vector2((720.0 - popup.size.x) * 0.5, (height - popup.size.y) * 0.5)


func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    overlay = Control.new()
    overlay.size = Vector2(720, 1280)
    overlay.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(overlay)

    var portrait := PanelContainer.new()
    portrait.position = Vector2(14, 18)
    portrait.size = Vector2(280, 171)
    portrait.add_theme_stylebox_override("panel", _skin(Color("0a0c12ed"), Color("65594d")))
    overlay.add_child(portrait)
    var portrait_box := VBoxContainer.new()
    portrait.add_child(portrait_box)
    portrait_box.add_child(_label("ASHEN IDLE  •  RECKONING", 17, Color("d9b78d")))
    status = _label("", 21, Color("e7e2d6"))
    portrait_box.add_child(status)
    details = _label("", 15, Color("f1d7c1"))
    portrait_box.add_child(details)
    hero_heart = ColorRect.new()
    hero_heart.color = Color("ab342a")
    hero_heart.custom_minimum_size = Vector2(250, 5)
    portrait_box.add_child(hero_heart)
    hero_mana_label = _label("", 13, Color("9ac9f1"))
    portrait_box.add_child(hero_mana_label)
    hero_mana_bar = ColorRect.new()
    hero_mana_bar.color = Color("427fd8")
    hero_mana_bar.custom_minimum_size = Vector2(250, 5)
    portrait_box.add_child(hero_mana_bar)
    power_label = _label("", 16, Color("ffd375"))
    portrait_box.add_child(power_label)

    var map_panel := PanelContainer.new()
    map_panel.position = Vector2(512, 18)
    map_panel.size = Vector2(192, 177)
    map_panel.add_theme_stylebox_override("panel", _skin(Color("0a0c12ed"), Color("65594d")))
    overlay.add_child(map_panel)
    var map_column := VBoxContainer.new()
    map_panel.add_child(map_column)
    map_column.add_child(_label("THE LOST LANDS", 15, Color("cabbad")))
    map_dots = Control.new()
    map_dots.custom_minimum_size = Vector2(167, 103)
    map_column.add_child(map_dots)
    stage_banner = _label("", 13, Color("f0c997"))
    map_column.add_child(stage_banner)
    journey_caption = _label("PATH  0%", 12, Color("b7c9c5"))
    map_column.add_child(journey_caption)
    journey_track = ColorRect.new()
    journey_track.color = Color("c88a5e")
    journey_track.custom_minimum_size = Vector2(160, 3)
    map_column.add_child(journey_track)
    # Actual on-device frame counter, refreshed once per second rather than
    # changing a label 60 times per second. Useful for confirming mobile lag.
    fps_label = _label("FPS --", 14, Color("a4cbb7"))
    fps_label.position = Vector2(617, 204)
    fps_label.size = Vector2(88, 26)
    fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    overlay.add_child(fps_label)

    # Horizontal action strip: the previous left-side menu covered nearly
    # 200px of the actual dungeon, leaving little combat space in portrait.
    var controls := HBoxContainer.new()
    controls.position = Vector2(14, 205)
    controls.add_theme_constant_override("separation", 7)
    overlay.add_child(controls)
    controls.add_child(_ornate_button("LOOT", _show_inventory, Vector2(105, 43)))
    evolution_action_button = _ornate_button("EVOLVE", _open_evolution_panel, Vector2(105, 43))
    controls.add_child(evolution_action_button)
    controls.add_child(_ornate_button("TALENT", _open_talent_panel, Vector2(105, 43)))
    auto_gear_button = _ornate_button("AUTO GEAR", _toggle_auto_gear, Vector2(105, 43))
    controls.add_child(auto_gear_button)

    var banner := PanelContainer.new()
    banner.position = Vector2(168, 260)
    banner.size = Vector2(384, 52)
    banner.add_theme_stylebox_override("panel", _skin(Color("090a10ba"), Color("5e4e4b")))
    overlay.add_child(banner)
    var banner_column := VBoxContainer.new()
    banner.add_child(banner_column)
    center_banner = _label("THE ASHEN HUNT", 19, Color("ffd08c"))
    center_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_column.add_child(center_banner)
    combat = _label("", 15, Color("ded4ce"))
    combat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_column.add_child(combat)
    var boss_panel := PanelContainer.new()
    boss_panel.position = Vector2(189, 322)
    boss_panel.size = Vector2(342, 52)
    boss_panel.add_theme_stylebox_override("panel", _skin(Color("100a12c9"), Color("aa5143")))
    overlay.add_child(boss_panel)
    var boss_col := VBoxContainer.new()
    boss_panel.add_child(boss_col)
    boss_hp_label = _label("ASHEN WARDEN", 17, Color("ffc5a0"))
    boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_col.add_child(boss_hp_label)
    boss_hp_bar = ColorRect.new()
    boss_hp_bar.color = Color("e13b46")
    boss_hp_bar.custom_minimum_size = Vector2(310, 6)
    boss_col.add_child(boss_hp_bar)
    boss_panel.name = "BossHPPanel"


    var bottom := PanelContainer.new()
    bottom.name = "BottomHUD"
    bottom.position = Vector2(16, overlay.size.y - 156)
    bottom.size = Vector2(688, 142)
    bottom.add_theme_stylebox_override("panel", _skin(Color("090b11ea"), Color("68615c")))
    overlay.add_child(bottom)
    var col := VBoxContainer.new()
    bottom.add_child(col)
    info = _label("", 15, Color("c8bdad"))
    col.add_child(info)
    combat_bar = ColorRect.new()
    combat_bar.color = Color("ba4d32")
    combat_bar.custom_minimum_size = Vector2(640, 4)
    col.add_child(combat_bar)
    var action_line := HBoxContainer.new()
    action_line.add_theme_constant_override("separation", 6)
    col.add_child(action_line)
    actions = action_line
    action_line.add_child(_ornate_button("BOSS", _try_boss, Vector2(106, 46)))
    action_line.add_child(_ornate_button("FARM", _grind, Vector2(106, 46)))
    action_line.add_child(_ornate_button("PUSH", _forward, Vector2(106, 46)))
    action_line.add_child(_ornate_button("FORGE", _forge_weakest, Vector2(106, 46)))
    action_line.add_child(_ornate_button("SKILL+", _open_talent_panel, Vector2(106, 46)))
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(630, 27)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    col.add_child(scroll)
    inventory = VBoxContainer.new()
    inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(inventory)
    offline = _label("", 14, Color("ffce6c"))
    col.add_child(offline)

    var skill_bar := HBoxContainer.new()
    skill_bar.name = "SkillHUD"
    skill_bar.position = Vector2(380, overlay.size.y - 248)
    skill_bar.add_theme_constant_override("separation", 7)
    overlay.add_child(skill_bar)
    for spell_name in CLASS_SPELLS[hero_class]:
        var slot_index: int = skill_buttons.size()
        var b := _ornate_button(str(spell_name), _use_skill.bind(slot_index), Vector2(100, 76))
        b.add_theme_font_size_override("font_size", 12)
        b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
        b.add_theme_stylebox_override("normal", _skin(Color("121724ed"), Color("a7775c")))
        b.add_theme_stylebox_override("hover", _skin(Color("273044f7"), Color("deb879")))
        skill_buttons.append(b)
        skill_bar.add_child(b)
        var glyph_script: Script = preload("res://scripts/ability_icon.gd")
        var glyph: Control = glyph_script.new() as Control
        glyph.name = "AbilityGlyph"
        glyph.set("class_id", hero_class)
        glyph.set("ability_id", slot_index)
        glyph.position = Vector2(6, 5)
        glyph.size = Vector2(34, 34)
        glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(glyph)


    popup_shade = ColorRect.new()
    popup_shade.color = Color(0.015, 0.015, 0.024, 0.78)
    popup_shade.size = overlay.size
    popup_shade.visible = false
    popup_shade.mouse_filter = Control.MOUSE_FILTER_STOP
    popup_shade.z_index = 40
    overlay.add_child(popup_shade)

    legendary_overlay = PanelContainer.new()
    legendary_overlay.position = Vector2(84, (overlay.size.y - 640.0) * 0.5)
    legendary_overlay.size = Vector2(552, 640)
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
    legendary_name.custom_minimum_size = Vector2(492, 56)
    leg_col.add_child(legendary_name)
    var item_frame := SubViewportContainer.new()
    item_frame.custom_minimum_size = Vector2(490, 208)
    item_frame.stretch = true
    leg_col.add_child(item_frame)
    legendary_item_viewport = SubViewport.new()
    legendary_item_viewport.size = Vector2i(490, 208)
    legendary_item_viewport.transparent_bg = true
    legendary_item_viewport.own_world_3d = true
    legendary_item_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    item_frame.add_child(legendary_item_viewport)
    legendary_item_display = Node3D.new()
    legendary_item_viewport.add_child(legendary_item_display)
    var item_camera := Camera3D.new()
    legendary_item_viewport.add_child(item_camera)
    item_camera.position = Vector3(0, 0.35, 4.3)
    item_camera.look_at(Vector3(0, 0.18, 0), Vector3.UP)
    item_camera.fov = 36
    item_camera.current = true
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
    legendary_stats = _label("", 17, Color("eadcc9"))
    legendary_stats.custom_minimum_size = Vector2(490, 142)
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
    skill_overlay.position = Vector2(92, (overlay.size.y - 815.0) * 0.5)
    skill_overlay.size = Vector2(536, 815)
    skill_overlay.visible = false
    skill_overlay.z_index = 41
    skill_overlay.add_theme_stylebox_override("panel", _skin(Color("0e1019"), Color("9c79bc")))
    overlay.add_child(skill_overlay)
    var talents := VBoxContainer.new()
    talents.add_theme_constant_override("separation", 7)
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
        var button := _ornate_button(descriptions[i], _invest_talent.bind(i), Vector2(485, 57))
        button.add_theme_font_size_override("font_size", 17)
        skill_choice_buttons.append(button)
        talents.add_child(button)
    talents.add_child(_label("ACTIVE SKILLS — UNLOCK & UPGRADE", 18, Color("edc99a")))
    for ability_index in range(3):
        var upgrade_button := _ornate_button("UPGRADE SKILL", _upgrade_class_skill.bind(ability_index), Vector2(485, 65))
        upgrade_button.add_theme_font_size_override("font_size", 15)
        skill_upgrade_buttons.append(upgrade_button)
        talents.add_child(upgrade_button)
    talents.add_child(_label("Ranks improve damage, cooldown and chain targets.", 15, Color("ac9ca8")))
    talents.add_child(_ornate_button("RETURN TO BATTLE", _close_talent_panel, Vector2(485, 52)))

    hero_overlay = PanelContainer.new()
    hero_overlay.position = Vector2(80, (overlay.size.y - 820.0) * 0.5)
    hero_overlay.size = Vector2(560, 820)
    hero_overlay.z_index = 41
    hero_overlay.visible = false
    hero_overlay.add_theme_stylebox_override("panel", _skin(Color("0b0d15f7"), Color("a78053")))
    overlay.add_child(hero_overlay)
    # Hero choices may be taller than the usable screen on compact phones.
    # Give the card list a true vertical viewport instead of letting a VBox
    # resize its parent beyond the top/bottom screen edges.
    var hero_scroll := ScrollContainer.new()
    hero_scroll.name = "HeroChoiceScroll"
    hero_scroll.custom_minimum_size = Vector2(522, 770)
    hero_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    hero_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    hero_overlay.add_child(hero_scroll)
    var hero_column := VBoxContainer.new()
    hero_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hero_column.add_theme_constant_override("separation", 9)
    hero_scroll.add_child(hero_column)
    var hero_title := _label("CHOOSE YOUR HERO", 29, Color("f2cf99"))
    hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_column.add_child(hero_title)
    var hero_explainer := _label("4 classes  •  Different MP, DEF and skills\nYour choice is locked until the game restarts.", 16, Color("c1b9b3"))
    hero_explainer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_column.add_child(hero_explainer)
    for class_id in range(CLASSES.size()):
        var costs: Array = CLASS_SKILL_COSTS[class_id]
        var titles: Array = CLASS_SPELLS[class_id]
        var spell_help: Array = CLASS_SKILL_DESCRIPTIONS[class_id]
        var class_text := "%s  %s\nDEF %d%%  •  MP %d  •  REGEN %d/s\n%s\n%s — %d MP\n%s — %d MP\n%s — %d MP" % [
            "▶" if class_id == hero_class else "◆", CLASSES[class_id].to_upper(),
            int(float(CLASS_DEFENSE[class_id]) * 100.0),
            int(float(CLASS_MP_BASE[class_id])),
            int(float(CLASS_MP_REGEN[class_id])),
            CLASS_DESCRIPTIONS[class_id],
            titles[0], int(costs[0]),
            titles[1], int(costs[1]),
            titles[2], int(costs[2])
        ]
        var hero_row := HBoxContainer.new()
        hero_row.add_theme_constant_override("separation", 8)
        hero_column.add_child(hero_row)
        hero_row.add_child(_create_hero_preview(class_id))
        var class_button := _ornate_button(class_text, _select_class.bind(class_id), Vector2(394, 149))
        hero_choice_buttons.append(class_button)
        class_button.add_theme_font_size_override("font_size", 14)
        # The hero chooser has fixed-height cards. Wrap-enabled buttons can
        # report an enormous minimum height before their width is assigned.
        class_button.autowrap_mode = TextServer.AUTOWRAP_OFF
        class_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
        class_button.add_theme_stylebox_override("normal", _skin(Color("1a1e2bf5"), [Color("b8794d"), Color("81a36d"), Color("608ac9"), Color("8e62a8")][class_id]))
        hero_row.add_child(class_button)
    sfx_toggle_button = _ornate_button("SOUND: ON" if audio_enabled else "SOUND: OFF", _toggle_sound, Vector2(510, 42))
    hero_column.add_child(sfx_toggle_button)
    hero_return_button = _ornate_button("RETURN TO BATTLE", _close_hero_panel, Vector2(510, 43))
    hero_column.add_child(hero_return_button)

    # Evolution is a separate, portrait-friendly upgrade choice, NOT a character switch.
    evolution_overlay = PanelContainer.new()
    evolution_overlay.position = Vector2(82, (overlay.size.y - 775.0) * 0.5)
    evolution_overlay.size = Vector2(556, 775)
    evolution_overlay.visible = false
    evolution_overlay.z_index = 42
    evolution_overlay.add_theme_stylebox_override("panel", _skin(Color("0c1019f7"), Color("c99a62")))
    overlay.add_child(evolution_overlay)
    # Keep the ascension panel compact even when button text reflows;
    # long translated tooltips stay inside a scrollable 735px viewport.
    var evolution_scroll := ScrollContainer.new()
    evolution_scroll.name = "EvolutionChoiceScroll"
    evolution_scroll.custom_minimum_size = Vector2(520, 735)
    evolution_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    evolution_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    evolution_overlay.add_child(evolution_scroll)
    var evolution_column := VBoxContainer.new()
    evolution_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    evolution_column.add_theme_constant_override("separation", 12)
    evolution_scroll.add_child(evolution_column)
    evolution_title = _label("THE ASCENSION PATH", 27, Color("ffd69a"))
    evolution_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    evolution_column.add_child(evolution_title)
    evolution_summary = _label("", 16, Color("d1c2b1"))
    evolution_summary.custom_minimum_size = Vector2(515, 115)
    evolution_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    evolution_summary.clip_text = true
    evolution_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    evolution_column.add_child(evolution_summary)
    var evolution_divider := HSeparator.new()
    evolution_column.add_child(evolution_divider)
    for branch in range(3):
        var choose_button := _ornate_button("EVOLUTION", _choose_evolution.bind(branch), Vector2(510, 148))
        choose_button.add_theme_font_size_override("font_size", 15)
        choose_button.add_theme_stylebox_override("normal", _skin(Color("1b202c"), [Color("be6f44"), Color("6d9ab0"), Color("9677cf")][branch]))
        evolution_buttons.append(choose_button)
        evolution_column.add_child(choose_button)
    evolution_close_button = _ornate_button("RETURN TO BATTLE", _close_evolution_panel, Vector2(510, 54))
    evolution_column.add_child(evolution_close_button)

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




func _create_hero_preview(class_id: int) -> PanelContainer:
    # Actual armored 3D hero preview. The emblem remains a fully rendered
    # fallback when third-party GLBs are not yet downloaded into the editor.
    var accent: Color = [Color("b8794d"), Color("81a36d"), Color("608ac9"), Color("8e62a8")][class_id]
    var frame := PanelContainer.new()
    frame.custom_minimum_size = Vector2(108, 149)
    frame.add_theme_stylebox_override("panel", _skin(Color("11141d"), accent))
    var holder := Control.new()
    holder.custom_minimum_size = Vector2(108, 149)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(holder)
    var portraits: Array = ["ashen_armored_knight", "ashen_ranger", "ashen_mage", "ashen_shadow_knight"]
    var packed: PackedScene = _get_asset_scene(str(portraits[class_id]))
    if packed != null:
        var viewport_holder := SubViewportContainer.new()
        viewport_holder.position = Vector2(0, 0)
        viewport_holder.size = Vector2(108, 149)
        viewport_holder.stretch = true
        viewport_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
        holder.add_child(viewport_holder)
        var preview_viewport := SubViewport.new()
        preview_viewport.size = Vector2i(216, 298)
        preview_viewport.own_world_3d = true
        preview_viewport.transparent_bg = true
        # Hidden hero chooser no longer renders four additional 3D worlds on
        # every gameplay frame; it redraws only while actually visible.
        preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
        viewport_holder.add_child(preview_viewport)
        var portrait_environment := WorldEnvironment.new()
        var portrait_scene := Environment.new()
        portrait_scene.background_mode = Environment.BG_COLOR
        portrait_scene.background_color = Color("24222c")
        portrait_scene.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        portrait_scene.ambient_light_color = Color("dfd2b9")
        portrait_scene.ambient_light_energy = 0.8
        portrait_scene.tonemap_mode = Environment.TONE_MAPPER_FILMIC
        portrait_environment.environment = portrait_scene
        preview_viewport.add_child(portrait_environment)
        var preview_model: Node3D = packed.instantiate() as Node3D
        if preview_model != null:
            preview_viewport.add_child(preview_model)
            # The selection card is not in the scene tree until _build_ui()
            # finishes. Transform3D and look_at before that point return
            # default transforms and silently produce blank 3D previews.
            preview_model.rotation.y = -0.38
            var camera := Camera3D.new()
            camera.position = Vector3(2.65, 2.18, 4.65)
            camera.fov = 37.0
            preview_viewport.add_child(camera)
            camera.current = true
            call_deferred("_finish_hero_preview", preview_model, camera)
            var key := DirectionalLight3D.new()
            key.rotation_degrees = Vector3(-45, -31, 0)
            key.light_color = accent.lightened(0.58)
            key.light_energy = 2.0
            preview_viewport.add_child(key)
            var fill := DirectionalLight3D.new()
            fill.rotation_degrees = Vector3(-29, 125, 0)
            fill.light_color = Color("a3b8dd")
            fill.light_energy = 0.8
            preview_viewport.add_child(fill)
    var emblem_script: Script = preload("res://scripts/class_emblem.gd")
    var emblem: Control = emblem_script.new() as Control
    emblem.set("class_id", class_id)
    emblem.set("accent", accent)
    if packed != null:
        # Full-size fallback prevents an empty black hero card in renderers
        # which cannot show secondary 3D viewports (some mobile GL drivers).
        emblem.position = Vector2.ZERO
        emblem.size = Vector2(108, 149)
        emblem.modulate.a = 0.60
    else:
        emblem.size = Vector2(108, 149)
    emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(emblem)
    return frame


func _finish_hero_preview(model: Node3D, camera: Camera3D) -> void:
    if not is_instance_valid(model) or not model.is_inside_tree() or not is_instance_valid(camera) or not camera.is_inside_tree():
        return
    _fit_visual_model(model, 2.6)
    _attach_hero_clips(model)
    _pose_fantasy_skeleton(model, 0.0)
    for clip_node in model.find_children("*", "AnimationPlayer", true, false):
        var player: AnimationPlayer = clip_node as AnimationPlayer
        if player != null:
            for clip_name in player.get_animation_list():
                if str(clip_name).to_lower().contains("idle"):
                    player.play(str(clip_name))
                    break
    camera.look_at(Vector3(0, 1.35, 0), Vector3.UP)


func _max_mp() -> float:
    var baseline: float = float(CLASS_MP_BASE[hero_class]) + float(level - 1) * float(CLASS_MP_PER_LEVEL[hero_class]) + _bonus("mana")
    return baseline + 22.0 * _evolution_weight(2)

func _mana_regeneration() -> float:
    var baseline: float = float(CLASS_MP_REGEN[hero_class]) + float(level - 1) * 0.10 + _bonus("mana_regen")
    return baseline * (1.0 + 0.14 * _evolution_weight(2))

func _defense_reduction() -> float:
    var baseline: float = float(CLASS_DEFENSE[hero_class]) + float(skills[2]) * 0.014 + _bonus("defense") / 100.0
    var class_ward: float = 0.0
    if hero_class == 0 and stage % BOSS_INTERVAL == 0:
        class_ward = 0.012 * _evolution_weight(1)
    return clampf(baseline + 0.022 * _evolution_weight(1) + class_ward, 0.0, 0.84)

func _max_hp() -> float:
    var modifier: float = float([1.2, 0.9, 0.85, 1.0][hero_class])
    return (100.0 + float(level) * 12.0 + float(skills[1]) * 24.0 + _bonus("hp")) * modifier * (1.0 + 0.12 * _evolution_weight(1))

func _damage() -> float:
    var modifier: float = float([1.0, 1.15, 1.32, 1.10][hero_class])
    return (8.0 + float(level) * 2.5 + float(skills[0]) * 4.0 + _bonus("damage") + _bonus("elemental") * 0.45) * modifier * (1.0 + 0.07 * _evolution_weight(0))

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
    for set_name in counts.keys():
        var count: int = int(counts[set_name])
        if count >= 2:
            match str(set_name):
                "Cinderborn":
                    if key == "damage": total += 16.0
                    if key == "elemental": total += 8.0
                "Gravewarden":
                    if key == "hp": total += 55.0
                    if key == "defense": total += 8.0
                "Ashen Crown":
                    if key == "crit": total += 10.0
                    if key == "speed": total += 12.0
        if count >= 4:
            match str(set_name):
                "Cinderborn":
                    if key == "damage": total += 30.0
                    if key == "elemental": total += 18.0
                "Gravewarden":
                    if key == "hp": total += 85.0
                    if key == "defense": total += 18.0
                "Ashen Crown":
                    if key == "crit": total += 14.0
                    if key == "speed": total += 20.0
    return total

func _boss_variant() -> int:
    return posmod(floori(float(stage) / float(BOSS_INTERVAL)) - 1, BOSS_NAMES.size())

func _encounter_victory() -> void:
    if current_encounter.is_empty() or encounter_director == null:
        return
    encounter_director.report_result(hp / maxf(1.0, _max_hp()), false)
    var bonus: float = float(current_encounter.get("gold_bonus", 0.0))
    if bonus > 0.0:
        var extra_gold: int = maxi(8, int(float(stage) * 8.0 * bonus))
        gold += extra_gold
        combat_note = "TREASURE CONVOY - +%d BONUS GOLD" % extra_gold
    var restoration: float = float(current_encounter.get("heal_bonus", 0.0))
    if restoration > 0.0:
        hp = minf(_max_hp(), hp + _max_hp() * restoration)
        mp = minf(_max_mp(), mp + _max_mp() * 0.14)
    if bool(current_encounter.get("loot_bonus", false)) and hero != null:
        _drop_loot_at(hero.global_position, false)
    current_encounter.clear()


func _adaptive_defeat() -> void:
    if encounter_director != null:
        encounter_director.report_result(0.0, true)


func _select_auto_skill() -> int:
    # Tactical auto-casting: heal when threatened, interrupt groups with
    # crowd control, spend high-cost ultimate only on worthwhile targets.
    var options: Array = []
    for spell in range(3):
        if level < int(SKILL_UNLOCK_LEVELS[spell]) or float(skill_cooldowns[spell]) > 0.0:
            continue
        if mp < float(CLASS_SKILL_COSTS[hero_class][spell]) + float(_skill_rank(spell) - 1):
            continue
        options.append(spell)
    if options.is_empty():
        return -1
    var danger: bool = hp / maxf(1.0, _max_hp()) < 0.55
    if hero_class == 0 and danger and options.has(1):
        return 1
    if hero_class == 2 and arena_mobs.size() >= 3 and options.has(1):
        return 1
    if arena_mobs.size() >= 4 and options.has(2):
        return 2
    if arena_mobs.size() >= 3 and options.has(1):
        return 1
    if options.has(0):
        return 0
    return int(options[0])


func _spawn_enemy() -> void:
    if hero == null:
        enemy_max = 50.0 + float(stage) * 20.0
        enemy_hp = enemy_max
        return
    _clear_boss_telegraph()
    if dungeon_map != null:
        dungeon_points = dungeon_map.call("generate", stage) as PackedVector3Array
    dungeon_room_index = 1
    if hero != null and dungeon_points.size() > 0:
        hero.position = dungeon_points[0]
    if camera_ref != null and hero != null:
        camera_focus = hero.position
        camera_ref.position = hero.position + Vector3(0.0, 18.0, 20.0)
        camera_ref.look_at(hero.position + Vector3(0, 0.8, -2.3), Vector3.UP)
    _spawn_horde()
    _update_wave_health()
    _apply_biome()

func _process(delta: float) -> void:
    chaos_time += delta
    fps_sample_timer += delta
    if fps_label != null and fps_sample_timer >= 1.0:
        fps_sample_timer = 0.0
        var live_fps: int = int(Engine.get_frames_per_second())
        fps_label.text = "%d FPS" % live_fps
        fps_label.add_theme_color_override("font_color", Color("93e4ad") if live_fps >= 50 else Color("f4bd73") if live_fps >= 30 else Color("ff7e74"))
    if not popup_shade.visible:
        mp = minf(_max_mp(), mp + _mana_regeneration() * delta)
    if legendary_item_display != null and legendary_overlay.visible:
        legendary_item_display.rotation.y += delta * 0.64
    for i in range(skill_cooldowns.size()):
        skill_cooldowns[i] = maxf(0.0, float(skill_cooldowns[i]) - delta)
    # UI labels do not need 60 updates a second; 8 Hz saves mobile CPU and layout passes.
    action_ui_timer += delta
    if action_ui_timer >= 0.12:
        action_ui_timer = 0.0
        for i in range(skill_buttons.size()):
            var skill_button: Button = skill_buttons[i]
            var cost: float = float(CLASS_SKILL_COSTS[hero_class][i])
            var unlock_level: int = int(SKILL_UNLOCK_LEVELS[i])
            var unlocked: bool = level >= unlock_level
            var should_disable: bool = not unlocked or float(skill_cooldowns[i]) > 0.0 or mp < cost or popup_shade.visible
            if skill_button.disabled != should_disable:
                skill_button.disabled = should_disable
            var icon: Control = skill_button.get_node_or_null("AbilityGlyph") as Control
            if icon != null:
                if int(icon.get("class_id")) != hero_class:
                    icon.set("class_id", hero_class)
                if bool(icon.get("locked")) == unlocked:
                    icon.set("locked", not unlocked)
            var skill_caption: String = "CHAIN" if hero_class == 2 and i == 1 else str(CLASS_SPELLS[hero_class][i])
            if not unlocked:
                var locked_label: String = "LOCKED\nLVL %d" % unlock_level
                if skill_button.text != locked_label:
                    skill_button.text = locked_label
            else:
                var ready_label: String = (skill_caption + " R%d\n%.0f MP" % [_skill_rank(i), cost + float(_skill_rank(i) - 1)] if float(skill_cooldowns[i]) <= 0.0 else skill_caption + "\n%.0fs" % float(skill_cooldowns[i]))
                if skill_button.text != ready_label:
                    skill_button.text = ready_label
    tick += delta
    save_timer += delta
    if hero != null:
        pass # hero movement is handled by _move_hero
    if foe != null:
        foe.rotation.y = sin(chaos_time * 2.0) * 0.10
    if foe_body != null:
        foe_body.scale = Vector3.ONE * (1.0 + attack_flash * 0.13)
    attack_flash = maxf(0.0, attack_flash - delta * 4.0)
    _update_chaos(delta)
    if screen_flash != null and screen_flash_fade > 0.0:
        screen_flash_fade = maxf(0.0, screen_flash_fade - delta * 2.8)
        screen_flash.modulate.a = screen_flash_fade
    _move_hero(delta)
    _update_camera(delta)
    _update_journey_hud()
    _update_boss_cast(delta)
    _update_ember_motes()
    minimap_refresh_timer += delta
    if tick > 0.36 and popup_shade.visible:
        tick = 0.36
    var attack_interval := 0.35 / (1.0 + minf(1.0, _bonus("speed") / 100.0) + 0.035 * _evolution_weight(0))
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
    var target: Node3D = _choose_target()
    if target == null or not is_instance_valid(target):
        return
    # Stop attacking through walls / from a different room. Travel comes first.
    var attack_reach: float = 5.9 if hero_class == 1 or hero_class == 2 else 2.45
    if hero.position.distance_to(target.position) > attack_reach:
        return
    var ranger_precision: float = 0.015 * _evolution_weight(0) if hero_class == 1 else 0.0
    var crit: bool = rng.randf() < clampf(0.20 + _bonus("crit") / 100.0 + (0.08 if hero_class == 1 else 0.0) + 0.03 * _evolution_weight(0) + ranger_precision, 0.20, 0.85)
    var damage: float = _damage() * rng.randf_range(0.90, 1.40) * (2.1 if crit else 1.0)
    if hero_class == 3:
        hp = minf(_max_hp(), hp + damage * 0.035)
    if hero_class == 2 or hero_class == 3:
        # Directional caster bolts: a visible link from the moving hero to the target.
        _energy_arc(hero.global_position + Vector3(0.0, 1.45, 0.0), target.global_position + Vector3(0.0, 0.95, 0.0), Color("a86aff") if hero_class == 2 else Color("ed4058"), 0.075 if crit else 0.046)
    var impact_point: Vector3 = target.global_position
    _hit_mob(target, damage, crit)
    if hero_class == 3 and _evolution_weight(0) > 0.0:
        hp = minf(_max_hp(), hp + damage * 0.011 * _evolution_weight(0))
    _slash_trail(impact_point, crit)
    _play_audio(0)
    attack_animation_index += 1
    _actor_attack(hero, hero_class == 2)
    # Evolved assault branches learn a real cleave: each fifth basic hit
    # damages nearby enemies, and each ascension strengthens the impact.
    var assault_power: float = _evolution_weight(0)
    if assault_power > 0.0 and attack_animation_index % 5 == 0:
        var victims := 0
        for candidate in arena_mobs.duplicate():
            var secondary: Node3D = candidate as Node3D
            if secondary == null or not is_instance_valid(secondary) or secondary == target:
                continue
            if secondary.global_position.distance_squared_to(impact_point) <= 12.25:
                var cleave_power: float = damage * (0.26 + assault_power * 0.045)
                if hero_class == 0:
                    cleave_power *= 1.18
                _hit_mob(secondary, cleave_power, false)
                victims += 1
            if victims >= mini(4, 1 + EVO.count_branch(_evolution_picks(), 0)):
                break
        if victims > 0:
            _burst_particles(impact_point + Vector3(0, 1.0, 0), [Color("fd7d45"), Color("9ccc6e"), Color("aa8bfd"), Color("db5080")][hero_class], 12, 1.4, 0.35)
    camera_kick = minf(1.0, camera_kick + (0.36 if crit else 0.11))
    if crit:
        camera_shake = maxf(camera_shake, 0.11)
    attack_flash = 1.0
    if rng.randf() < 0.25 and not arena_mobs.is_empty():
        var tactical_choice: int = _select_auto_skill()
        if tactical_choice >= 0:
            _use_skill(tactical_choice)
    if arena_mobs.is_empty():
        _complete_wave()
        return
    var remaining_mobs: float = float(arena_mobs.size())
    var incoming: float = maxf(0.20, float(stage) * 0.085 + remaining_mobs * 0.075) * (1.0 - _defense_reduction())
    if stage % BOSS_INTERVAL == 0:
        incoming *= [1.28, 1.10, 1.48][_boss_variant()]
    var attacker: Node3D = _choose_target()
    if attacker != null and is_instance_valid(attacker):
        var distance_to_attacker: float = hero.global_position.distance_to(attacker.global_position)
        var ai_role: String = str(attacker.get_meta("ai_role", "raider"))
        incoming *= float(current_encounter.get("damage_factor", 1.0))
        if ai_role == "flanker":
            incoming *= 1.11
        elif ai_role == "guardian":
            incoming *= 0.85
        elif ai_role == "caster":
            incoming *= 1.04
        if distance_to_attacker <= (5.15 if ai_role == "caster" else 3.4 if bool(attacker.get_meta("boss", false)) else 2.55):
            _actor_attack(attacker, ai_role == "caster")
            # Caster foes can hurt from medium range, others need to close.
            hp -= incoming
        else:
            hp -= incoming * 0.12
    if hp <= 0.0:
        _adaptive_defeat()
        hp = _max_hp()
        mp = _max_mp()
        grind_mode = true
        grind_cycles = 0
        stage = maxi(1, highest - 1)
        combat_note = "DEFEATED — AUTO-GRINDING PREVIOUS STAGE"
        _spawn_enemy()
    _refresh()

func _toggle_sound() -> void:
    audio_enabled = not audio_enabled
    if sfx_toggle_button != null:
        sfx_toggle_button.text = "SOUND: ON" if audio_enabled else "SOUND: OFF"
    _save_game()

func _prepare_audio() -> void:
    # Dedicated original SFX bank: attacks, pickups, class spells and boss cues.
    var bank_script: Script = preload("res://scripts/audio_bank.gd")
    sound_bank = bank_script.new() as Node
    add_child(sound_bank)

func _play_audio(effect_kind: int) -> void:
    if audio_enabled and sound_bank != null:
        sound_bank.call("play_effect", effect_kind, hero_class)


func _choose_target() -> Node3D:
    if arena_mobs.is_empty():
        return null
    var origin: Vector3 = hero.global_position if is_instance_valid(hero) else Vector3.ZERO
    var best: Node3D
    var best_distance: float = INF
    for candidate in arena_mobs:
        var mob: Node3D = candidate as Node3D
        if mob == null or not is_instance_valid(mob):
            continue
        var distance: float = mob.global_position.distance_squared_to(origin)
        if bool(mob.get_meta("boss", false)):
            distance *= 0.4
        if distance < best_distance:
            best_distance = distance
            best = mob
    return best

func _move_hero(delta: float) -> void:
    if hero == null or not is_instance_valid(hero) or popup_shade.visible:
        return
    var before: Vector3 = hero.position
    var destination: Vector3 = dungeon_points[dungeon_room_index] if dungeon_points.size() > dungeon_room_index else hero.position
    var target: Node3D = _choose_target()
    var in_encounter: bool = hero.position.distance_to(destination) < 5.5
    # Along the corridor: always move towards the next room. Only stop for
    # actual enemies when close enough to the chamber.
    if in_encounter and target != null and is_instance_valid(target):
        var from_target: Vector3 = hero.position - target.position
        from_target.y = 0.0
        if from_target.length_squared() < 0.03:
            from_target = Vector3.RIGHT
        destination = target.position + from_target.normalized() * (3.45 if hero_class == 1 or hero_class == 2 else 1.45)
    if boss_cast_windup > 0.0 and boss_telegraph != null and is_instance_valid(boss_telegraph):
        var away: Vector3 = hero.position - boss_warning_center
        away.y = 0.0
        if away.length_squared() < 0.03:
            away = Vector3.RIGHT
        destination = boss_warning_center + away.normalized() * 2.90
    # Never leave the current chamber or the walkable spine of the corridor.
    var route_x: float = dungeon_points[dungeon_room_index].x if dungeon_points.size() > dungeon_room_index else 0.0
    destination.x = clampf(destination.x, route_x - 3.35, route_x + 3.35)
    var motion: Vector3 = destination - hero.position
    motion.y = 0.0
    var speed: float = 3.75 if not in_encounter else 3.20
    # Acceleration, braking and directional blending keep traversal from
    # looking like rigid chess-piece movement on mobile.
    var desired_velocity := motion.normalized() * speed if motion.length_squared() > 0.01 else Vector3.ZERO
    var travel_velocity: Vector3 = hero.get_meta("travel_velocity", Vector3.ZERO)
    travel_velocity = travel_velocity.move_toward(desired_velocity, 15.0 * delta)
    var travel_step: Vector3 = travel_velocity * delta
    if travel_step.length_squared() > motion.length_squared():
        travel_step = motion
        travel_velocity = Vector3.ZERO
    hero.position += travel_step
    hero.set_meta("travel_velocity", travel_velocity)
    var velocity: float = hero.position.distance_to(before) / maxf(0.001, delta)
    dungeon_travel_distance += hero.position.distance_to(before)
    if velocity > 0.65 and sound_bank != null and audio_enabled:
        footstep_clock -= delta
        if footstep_clock <= 0.0:
            sound_bank.call("play_step", int((stage - 1) / 10) % 5)
            footstep_clock = 0.47
    else:
        footstep_clock = 0.0
    _animate_actor(hero, velocity)
    if motion.length_squared() > 0.08:
        # Model imports already carry a PI yaw to align their forward axis.
        # Applying the raw motion yaw on top pointed the hero's back into its
        # travel direction: it looked like it was running backwards.
        hero.rotation.y = lerp_angle(hero.rotation.y, atan2(motion.x, motion.z) + PI, clampf(delta * 8.0, 0.0, 1.0))
    elif target != null and is_instance_valid(target):
        var face: Vector3 = target.position - hero.position
        hero.rotation.y = lerp_angle(hero.rotation.y, atan2(face.x, face.z) + PI, clampf(delta * 8.0, 0.0, 1.0))
    hero.position.y = 0.0
    if hero_hit_flash > 0.0:
        hero_hit_flash = maxf(0.0, hero_hit_flash - delta)
        hero.scale = Vector3.ONE * (1.02 if int(hero_hit_flash * 14.0) % 2 == 0 else 0.96)
    else:
        hero.scale = Vector3.ONE

func _update_journey_hud() -> void:
    if journey_track == null or journey_caption == null or hero == null or dungeon_points.size() < 4:
        return
    var next_index: int = clampi(dungeon_room_index, 1, 3)
    var previous: Vector3 = dungeon_points[next_index - 1]
    var ahead: Vector3 = dungeon_points[next_index]
    var segment: Vector3 = ahead - previous
    var travelled: float = 0.0
    if segment.length_squared() > 0.05:
        travelled = clampf((hero.position - previous).dot(segment) / segment.length_squared(), 0.0, 1.0)
    var full_progress: float = (float(next_index - 1) + travelled) / 3.0
    var caption_text := "EXPLORING  %d%%" % int(full_progress * 100.0)
    if journey_caption.text != caption_text:
        journey_caption.text = caption_text
    journey_track.scale.x = maxf(0.025, full_progress)

func _jagged_lightning(start: Vector3, finish: Vector3, rank: int) -> void:
    # Segmented forks resemble an electrical discharge rather than a straight rod.
    # Segments taper and run between actual enemy positions.
    var direction: Vector3 = finish - start
    var length: float = direction.length()
    if length < 0.08:
        return
    var side: Vector3 = direction.normalized().cross(Vector3.UP).normalized()
    if side.length_squared() < 0.01:
        side = Vector3.RIGHT
    var previous: Vector3 = start
    var segments: int = 6
    for part in range(1, segments + 1):
        var p: float = float(part) / float(segments)
        var point: Vector3 = start.lerp(finish, p)
        if part < segments:
            var jitter: float = length * (0.032 if rank < 5 else 0.045)
            point += side * rng.randf_range(-jitter, jitter) + Vector3(0, rng.randf_range(-jitter, jitter), 0)
        _energy_arc(previous, point, Color("8ad5ff") if part % 2 == 0 else Color("effcff"), 0.065 if part % 2 == 0 else 0.038)
        previous = point
    _burst_particles(finish, Color("addcff"), 9, 0.9, 0.24)

func _slash_trail(pos: Vector3, crit: bool) -> void:
    var arc := TorusMesh.new()
    arc.inner_radius = 0.38 if crit else 0.25
    arc.outer_radius = 0.395 if crit else 0.265
    var tint := Color("ffcc7c") if crit else Color("ef8b47") if hero_class == 0 else Color("73cef8") if hero_class == 2 else Color("a56de8")
    var slash := _mesh(self, arc, pos + Vector3(0, 0.95, 0), _bright(tint))
    slash.rotation.x = PI * 0.34
    slash.scale = Vector3.ONE * 0.52
    spell_fx.append({"node": slash, "time": 0.18, "total": 0.18, "type": "hit"})

func _clear_boss_telegraph() -> void:
    if boss_telegraph != null and is_instance_valid(boss_telegraph):
        boss_telegraph.queue_free()
    boss_telegraph = null
    boss_cast_windup = 0.0
    boss_cast_timer = 4.5

func _update_boss_cast(delta: float) -> void:
    if stage % BOSS_INTERVAL != 0 or popup_shade.visible:
        return
    var has_boss := false
    for candidate in arena_mobs:
        if is_instance_valid(candidate) and bool(candidate.get_meta("boss", false)):
            has_boss = true
            break
    if not has_boss:
        return
    if boss_cast_windup > 0.0:
        boss_cast_windup -= delta
        if boss_telegraph != null and is_instance_valid(boss_telegraph):
            var urgency: float = clampf(1.0 - boss_cast_windup / 1.35, 0.0, 1.0)
            boss_telegraph.scale = Vector3.ONE * (0.8 + urgency * 0.4)
        if boss_cast_windup <= 0.0:
            var impact_damage: float = (10.0 + float(stage) * 0.9) * [1.1, 0.9, 1.4][_boss_variant()]
            var mage_ward: float = 1.0 - minf(0.30, 0.035 * _evolution_weight(1)) if hero_class == 2 else 1.0
            var reduced: float = impact_damage * (1.0 - _defense_reduction()) * mage_ward
            var warning_color: Color = [Color("ed5038"), Color("9e60d9"), Color("e8ab53")][_boss_variant()]
            _burst_particles(boss_warning_center + Vector3(0, 0.22, 0), warning_color, 43, 2.0, 0.42)
            camera_shake = maxf(camera_shake, 0.18)
            camera_kick = maxf(camera_kick, 0.46)
            if hero.position.distance_to(boss_warning_center) <= 1.65:
                hp -= reduced
                _damage_popup(int(reduced), hero.position + Vector3(0, 0.15, 0), true)
                hero_hit_flash = 0.3
                combat_note = "BOSS POWER ATTACK!"
            else:
                boss_dodges += 1
                combat_note = "PERFECT DODGE — BOSS ATTACK EVADED"
            if hp <= 0.0:
                _adaptive_defeat()
                hp = _max_hp()
                mp = _max_mp()
                grind_mode = true
                stage = maxi(1, highest - 1)
                combat_note = "DEFEATED — FARMING FOR BETTER GEAR"
                _spawn_enemy()
                _apply_biome()
            _clear_boss_telegraph()
            _refresh()
        return
    boss_cast_timer -= delta
    if boss_cast_timer <= 0.0:
        boss_cast_windup = 1.35
        boss_cast_timer = 6.0
        boss_warning_center = hero.position
        var ring := TorusMesh.new()
        ring.inner_radius = 1.4
        ring.outer_radius = 1.5
        boss_telegraph = _mesh(self, ring, boss_warning_center + Vector3(0, 0.15, 0), _bright([Color("b92c23"), Color("7140d3"), Color("db8537")][_boss_variant()]))
        combat_note = "DANGER — BOSS CHARGING!"
        _play_audio(4)
        _refresh()

func _apply_biome() -> void:
    var next_biome: int = posmod(floori(float(stage - 1) / float(BOSS_INTERVAL)), 5)
    if biome_index == next_biome or bg_environment == null:
        return
    biome_index = next_biome
    var scene: Environment = bg_environment.environment
    scene.background_color = [Color("070a12"), Color("091925"), Color("0b1e12"), Color("130e24"), Color("250b09")][next_biome]
    scene.fog_enabled = true
    scene.fog_light_color = [Color("35445c"), Color("64879b"), Color("526851"), Color("48305e"), Color("704238")][next_biome]
    scene.fog_density = [0.004, 0.005, 0.004, 0.007, 0.006][next_biome]
    scene.adjustment_brightness = [1.02, 0.97, 0.99, 0.93, 0.99][next_biome]
    scene.adjustment_saturation = [0.92, 0.78, 0.96, 0.90, 0.94][next_biome]
    if key_sun != null:
        key_sun.light_color = [Color("bfd2f2"), Color("c2e7ff"), Color("c3dda1"), Color("bc9aff"), Color("ffd0a6")][next_biome]
        key_sun.light_energy = [1.05, 1.05, 0.99, 0.92, 1.08][next_biome]
    scene.ambient_light_color = [Color("8da5c7"), Color("88b5c8"), Color("8eae88"), Color("805aa6"), Color("a17b77")][next_biome]
    if fire_light != null:
        fire_light.light_color = [Color("ff9a61"), Color("8ee3ff"), Color("a4dc72"), Color("c376ff"), Color("ff6e30")][next_biome]
    if mystic_light != null:
        mystic_light.light_color = [Color("965eff"), Color("63b4d3"), Color("5b9f66"), Color("743ee0"), Color("ff9b45")][next_biome]
    if center_banner != null:
        center_banner.text = ["THE CINDER CRYPT", "THE FROST HOLLOW", "THE THORNWILD", "THE VOID CITADEL", "THE MOLTEN DEPTHS"][next_biome]
        center_banner.add_theme_color_override("font_color", [Color("ffd08c"), Color("b3ebff"), Color("b0e3a4"), Color("d4b4ff"), Color("ffbb81")][next_biome])

func _bind_motion_driver(actor: Node3D) -> void:
    if actor == null:
        return
    var preferred: AnimationPlayer
    for candidate in actor.find_children("*", "AnimationPlayer", true, false):
        var player: AnimationPlayer = candidate as AnimationPlayer
        if player == null:
            continue
        if player.name == "CombatAnimationPlayer":
            preferred = player
            break
        if preferred == null and player.get_animation_list().size() > 1:
            preferred = player
    if preferred != null:
        actor.set_meta("animation_driver", preferred)
        actor.set_meta("clip_state", "")
        actor.set_meta("action_until", 0)

func _play_actor_clip(actor: Node3D, clip: String, blend: float = 0.16, rate: float = 1.0) -> bool:
    if actor == null or not is_instance_valid(actor):
        return false
    var player: AnimationPlayer = actor.get_meta("animation_driver", null) as AnimationPlayer
    if player == null or not is_instance_valid(player):
        return false
    var best := ""
    for name in player.get_animation_list():
        if str(name).to_lower() == clip.to_lower():
            best = str(name)
            break
    if best == "":
        for name in player.get_animation_list():
            if str(name).to_lower().contains(clip.to_lower()):
                best = str(name)
                break
    if best == "":
        return false
    if str(actor.get_meta("clip_state", "")) != best or not player.is_playing():
        player.play(best, blend, rate)
        actor.set_meta("clip_state", best)
    return true

func _pose_fantasy_skeleton(actor: Node3D, speed: float) -> void:
    # Cache joint handles once. On phone, scanning the full rig hierarchy for
    # every enemy at 60 FPS was more expensive than the actual arm animation.
    var joints: Array = actor.get_meta("pose_joint_cache", [])
    if not actor.has_meta("pose_joint_cache"):
        for part in actor.find_children("*", "Skeleton3D", true, false):
            var skeleton: Skeleton3D = part as Skeleton3D
            if skeleton == null:
                continue
            for bone_id in range(skeleton.get_bone_count()):
                var name_lower: String = skeleton.get_bone_name(bone_id).to_lower()
                var left: bool = name_lower.contains("left") or name_lower.ends_with("_l") or name_lower.ends_with(".l")
                var right: bool = name_lower.contains("right") or name_lower.ends_with("_r") or name_lower.ends_with(".r")
                if not left and not right:
                    continue
                var arm: bool = (name_lower.contains("upperarm") or name_lower.contains("upper_arm") or name_lower.contains("arm_upper") or name_lower.contains("shoulder") or ((name_lower.contains("leftarm") or name_lower.contains("rightarm") or name_lower.contains("arm_l") or name_lower.contains("arm_r")) and not name_lower.contains("forearm")))
                var leg: bool = name_lower.contains("upperleg") or name_lower.contains("upper_leg") or name_lower.contains("thigh") or name_lower.contains("upleg") or name_lower.contains("up_leg")
                if arm or leg:
                    joints.append({"skeleton": skeleton, "index": bone_id, "left": left, "arm": arm})
        actor.set_meta("pose_joint_cache", joints)
    var effort: float = clampf(speed / 2.4, 0.0, 1.0)
    var cycle: float = sin(chaos_time * 8.8)
    for joint in joints:
        var skeleton: Skeleton3D = joint["skeleton"] as Skeleton3D
        if skeleton == null or not is_instance_valid(skeleton):
            continue
        var left_side: bool = bool(joint["left"])
        var is_arm: bool = bool(joint["arm"])
        var bone_id: int = int(joint["index"])
        var axis: Vector3 = Vector3.FORWARD if is_arm else Vector3.RIGHT
        var angle: float = ((1.42 if left_side else -1.42) + cycle * 0.30 * effort * (-1.0 if left_side else 1.0)) if is_arm else cycle * 0.36 * effort * (-1.0 if left_side else 1.0)
        var pose: Quaternion = skeleton.get_bone_pose_rotation(bone_id)
        skeleton.set_bone_pose_rotation(bone_id, pose.slerp(Quaternion(axis, angle), 0.87))


func _animate_actor(actor: Node3D, speed: float) -> void:
    if actor == null or not is_instance_valid(actor):
        return
    var now: int = Time.get_ticks_msec()
    if now < int(actor.get_meta("action_until", 0)):
        return
    var wanted: String = "Jog_Fwd" if speed > 1.55 else "Walk" if speed > 0.22 else "Idle"
    var has_motion: bool = _play_actor_clip(actor, wanted, 0.16, 1.04 if speed > 0.22 else 1.0)
    if not has_motion and speed > 0.22:
        has_motion = _play_actor_clip(actor, "Run", 0.14, 1.0)
    if not has_motion:
        _play_actor_clip(actor, "Idle", 0.16)
    var model: Node3D = actor.get_child(0) as Node3D if actor.get_child_count() > 0 else null
    if model != null:
        var effort: float = clampf(speed / 2.6, 0.0, 1.0)
        var breathing: float = sin(chaos_time * 2.3 + float(actor.get_instance_id() % 11))
        model.rotation.z = lerpf(model.rotation.z, sin(chaos_time * 10.0) * 0.048 * effort + breathing * 0.012, clampf(get_process_delta_time() * 8.0, 0.0, 1.0))
        model.position.y = lerpf(model.position.y, maxf(0.0, sin(chaos_time * 13.2)) * 0.065 * effort + breathing * 0.008, clampf(get_process_delta_time() * 10.0, 0.0, 1.0))
    _pose_fantasy_skeleton(actor, speed)

func _actor_attack(actor: Node3D, magic: bool = false) -> void:
    if actor == null or not is_instance_valid(actor):
        return
    if Time.get_ticks_msec() < int(actor.get_meta("action_until", 0)) - 80:
        return
    var clip := "Spell_Simple_Shoot" if magic else "Sword_Regular_A"
    if _play_actor_clip(actor, clip, 0.10, 1.65):
        actor.set_meta("action_until", Time.get_ticks_msec() + 390)
    else:
        _trigger_combat_animation(actor)
        actor.set_meta("action_until", Time.get_ticks_msec() + 240)

func _update_camera(delta: float) -> void:
    if camera_ref == null or hero == null or not is_instance_valid(hero):
        return
    if not cinematic_camera:
        return
    camera_time += delta
    # Portrait-isometric tracking down a long world, not an orbit of one arena.
    # Lead the hero by several metres so the next room is in view.
    var focus: Vector3 = hero.global_position + Vector3(0, 0.70, -3.3)
    var target: Node3D = _choose_target()
    if target != null and hero.position.distance_to(target.position) < 7.5:
        focus = focus.lerp(target.global_position + Vector3(0, 0.8, 0), 0.17)
    camera_focus = camera_focus.lerp(focus, clampf(delta * 3.1, 0, 1))
    var boss_fight: bool = stage % BOSS_INTERVAL == 0 and dungeon_room_index == 3
    var random_shake := Vector3(sin(camera_time * 83.0) * camera_shake, cos(camera_time * 69.0) * camera_shake * 0.5, sin(camera_time * 51.0) * camera_shake * 0.5)
    var destination: Vector3 = camera_focus + Vector3(0, 19.0 if boss_fight else 17.7, 19.4) + random_shake + Vector3(0, 0, -camera_kick * 0.18)
    camera_ref.global_position = camera_ref.global_position.lerp(destination, clampf(delta * 3.2, 0, 1))
    camera_ref.look_at(camera_focus, Vector3.UP)
    camera_ref.fov = lerpf(camera_ref.fov, 48.0 if boss_fight else 47.0, clampf(delta * 1.5, 0, 1))
    if fire_light != null:
        fire_light.position = hero.position + Vector3(2.8, 3.7, -1.4)
    if mystic_light != null:
        mystic_light.position = hero.position + Vector3(-3.8, 3.4, -5.5)
    camera_kick = move_toward(camera_kick, 0.0, delta * 2.7)
    camera_shake = move_toward(camera_shake, 0.0, delta * 0.95)

func _trigger_combat_animation(actor: Node3D) -> void:
    if actor == null or not is_instance_valid(actor):
        return
    for found in actor.find_children("*", "AnimationPlayer", true, false):
        var player: AnimationPlayer = found as AnimationPlayer
        if player == null:
            continue
        var attack_name := ""
        var idle_name := ""
        for candidate in player.get_animation_list():
            var lower: String = str(candidate).to_lower()
            if attack_name == "" and (lower.contains("attack") or lower.contains("slash") or lower.contains("melee") or lower.contains("cast") or lower.contains("sword")):
                attack_name = str(candidate)
            if idle_name == "" and lower.contains("idle"):
                idle_name = str(candidate)
        if attack_name != "":
            player.play(attack_name, 0.09, 1.4)
            if idle_name != "":
                player.queue(idle_name)
            return

func _hit_mob(target: Node3D, damage: float, crit: bool) -> void:
    if not is_instance_valid(target) or not arena_mobs.has(target):
        return
    # Guardian enemies absorb a portion of direct and area damage.
    if str(target.get_meta("ai_role", "")) == "guardian":
        damage *= 0.82
    var health: float = float(target.get_meta("hp", 1.0)) - damage
    target.set_meta("hp", health)
    # Physical readability: every hit interrupts forward motion briefly,
    # with stronger knockback on a critical strike.
    if hero != null and is_instance_valid(hero):
        var push_direction: Vector3 = target.position - hero.position
        push_direction.y = 0.0
        if push_direction.length_squared() > 0.02:
            target.set_meta("knockback", push_direction.normalized() * (2.4 if crit else 0.95))
        target.set_meta("stagger", 0.18 if crit else 0.08)
    last_target_pos = target.global_position
    _impact(last_target_pos + Vector3(0.0, 0.75, 0.0), Color("ffc769") if crit else Color("b477ff"))
    if crit:
        var flare_tone: Color = [Color("ffc17a"), Color("bbf2ff"), Color("d1ee9c"), Color("dbacff"), Color("ff9458")][biome_index if biome_index >= 0 else 0]
        _burst_particles(last_target_pos + Vector3(0, 0.9, 0), flare_tone, 24, 1.6, 0.24)
    _damage_popup(int(damage), last_target_pos + Vector3(0.0, 1.45, 0.0), crit)
    if crit and is_instance_valid(target):
        var pulse := TorusMesh.new()
        pulse.inner_radius = 0.36
        pulse.outer_radius = 0.37
        var ring := _mesh(self, pulse, target.global_position + Vector3(0, 0.17, 0), _bright(Color("ffae54")))
        spell_fx.append({"node": ring, "time": 0.22, "total": 0.22, "type": "spell"})
    if health <= 0.0:
        _kill_mob(target)
    _update_wave_health()

func _kill_mob(target: Node3D) -> void:
    if not is_instance_valid(target):
        return
    var boss: bool = bool(target.get_meta("boss", false))
    var drop_pos: Vector3 = target.global_position
    arena_mobs.erase(target)
    # Elemental death breakup is distinct in each biome; the animated model
    # still visibly tumbles before disappearing.
    var death_tint: Color = [Color("df7e54"), Color("b6ebff"), Color("8ba965"), Color("b07cff"), Color("ff853c")][clampi(biome_index, 0, 4)]
    _burst_particles(drop_pos + Vector3(0, 1.1, 0), death_tint, 80 if boss else 20, 3.9 if boss else 1.25, 0.76 if boss else 0.42)
    # Keep the defeated mesh visible for a short physical fall instead of
    # popping enemies out of existence on the same frame as a hit.
    var fall_duration: float = 0.69 if boss else 0.36
    if target.is_inside_tree():
        var death_tween := target.create_tween()
        death_tween.set_parallel(true)
        death_tween.tween_property(target, "rotation:z", -1.10 if boss else -1.36, fall_duration).set_trans(Tween.TRANS_CUBIC)
        death_tween.tween_property(target, "position:y", -0.46 if boss else -0.31, fall_duration)
        death_tween.set_parallel(false)
        death_tween.tween_callback(target.queue_free)
    else:
        target.queue_free()
    wave_kills += 1
    kills += 1
    # Bastion path converts finishing blows into survivability, including
    # during long unattended boss grinds.
    if _evolution_weight(1) > 0.0:
        var kill_heal: float = 0.008 * _evolution_weight(1)
        if hero_class == 1 or hero_class == 3:
            kill_heal *= 1.35
        hp = minf(_max_hp(), hp + _max_hp() * kill_heal)
    gold += stage * 2 + (25 if boss else 3)
    xp += 5 + stage * 2 + (60 if boss else 0)
    if boss or rng.randf() < 0.22:
        _drop_loot_at(drop_pos, boss)
    if boss:
        _burst_particles(drop_pos + Vector3(0, 1.1, 0), Color("ff9142"), 160, 5.6, 1.15)
        _play_audio(4)
        earned_bosses[BOSS_NAMES[_boss_variant()]] = int(earned_bosses.get(BOSS_NAMES[_boss_variant()], 0)) + 1
        battle_statistics["bosses"] = int(battle_statistics.get("bosses", 0)) + 1
        _clear_boss_telegraph()
        combat_note = "BOSS DEFEATED — LEGENDARY REWARDS"
    var old_level: int = level
    while xp >= level * 30:
        xp -= level * 30
        level += 1
        skill_points += 1
        hp = _max_hp()
        combat_note = "LEVEL UP — TALENT POINT EARNED"
        _play_audio(6)
    if level > old_level and EVO.next_tier(level, _evolution_picks()) >= 0:
        call_deferred("_offer_evolution")

func _update_wave_health() -> void:
    enemy_hp = 0.0
    enemy_max = 0.0
    boss_health = 0.0
    boss_max = 0.0
    for mob in arena_mobs:
        if is_instance_valid(mob):
            enemy_hp += maxf(0.0, float(mob.get_meta("hp", 0.0)))
            enemy_max += float(mob.get_meta("max_hp", 0.0))
            if bool(mob.get_meta("boss", false)):
                boss_health += maxf(0.0, float(mob.get_meta("hp", 0.0)))
                boss_max += float(mob.get_meta("max_hp", 0.0))
    enemy_max = maxf(enemy_max, 1.0)
    boss_max = maxf(boss_max, 1.0)

func _complete_wave() -> void:
    # A floor has three linked encounters; clearing one opens the NEXT room.
    # Progressing beyond the final encounter generates the following floor.
    _encounter_victory()
    if dungeon_room_index < 3:
        dungeon_room_index += 1
        combat_note = "GATE OPEN — FORWARD TO CHAMBER %d / 3" % dungeon_room_index
        _play_audio(1)
        hp = minf(_max_hp(), hp + _max_hp() * 0.10)
        _spawn_horde()
        _update_wave_health()
        _refresh()
        return
    var was_boss: bool = stage % BOSS_INTERVAL == 0
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
        combat_note = "BOSS DEFEATED — A NEW REALM AWAITS" if was_boss else "FLOOR CLEARED — DESCENDING DEEPER"
    hp = _max_hp()
    mp = _max_mp()
    _spawn_enemy()
    _apply_biome()
    _save_game()

func _try_boss() -> void:
    grind_mode = false
    if highest < BOSS_INTERVAL:
        combat_note = "FIRST BOSS UNLOCKS ON FLOOR 10"
        _refresh()
        return
    stage = maxi(BOSS_INTERVAL, int(floor(float(highest) / float(BOSS_INTERVAL))) * BOSS_INTERVAL)
    hp = _max_hp()
    mp = _max_mp()
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

func _show_hero_panel(at_start: bool = false) -> void:
    if legendary_overlay.visible or skill_overlay.visible or inventory_overlay.visible or (evolution_overlay != null and evolution_overlay.visible):
        return
    # Opening a portrait again does NOT unlock the class. Only a real restart does.
    startup_selection = at_start and not class_selection_locked
    popup_shade.visible = true
    hero_overlay.visible = true
    if hero_return_button != null:
        hero_return_button.visible = not startup_selection
    for button in hero_choice_buttons:
        (button as Button).disabled = class_selection_locked

func _close_hero_panel() -> void:
    if startup_selection:
        return
    hero_overlay.visible = false
    popup_shade.visible = false
    call_deferred("_offer_evolution")

func _select_class(next_class: int) -> void:
    if class_selection_locked or not startup_selection or next_class < 0 or next_class >= CLASSES.size():
        return
    class_talents[str(hero_class)] = skills.duplicate()
    hero_class = next_class
    skills = class_talents.get(str(hero_class), [0, 0, 0]).duplicate()
    class_talents[str(hero_class)] = skills.duplicate()
    # Swapping class during a dungeon must not teleport the player back to its entrance.
    var current_position: Vector3 = dungeon_points[0] if not dungeon_points.is_empty() else Vector3.ZERO
    if hero != null and is_instance_valid(hero):
        current_position = hero.position
        hero.queue_free()
    hero = _make_animated_character(["Knight", "Rogue", "Mage", "Barbarian"][hero_class], current_position, false)
    hp = _max_hp()
    mp = _max_mp()
    combat_note = "NEW CLASS: " + CLASSES[hero_class]
    class_selection_locked = true
    if hero_overlay != null and hero_overlay.visible:
        startup_selection = false
        _close_hero_panel()
    for button in hero_choice_buttons:
        (button as Button).disabled = true
    _sync_equipment_visuals()
    _save_game()
    _refresh()
    call_deferred("_offer_evolution")

func _switch_class() -> void:
    # The old shortcut must never bypass the startup-only selection.
    combat_note = "RESTART TO CHOOSE A DIFFERENT HERO"
    _refresh()

func _evolution_picks() -> Array:
    return EVO.valid_choices(evolution_choices.get(str(hero_class), []))

func _evolution_weight(branch: int) -> float:
    return EVO.branch_weight(_evolution_picks(), branch)

func _offer_evolution() -> void:
    if not class_selection_locked or popup_shade == null or popup_shade.visible:
        return
    if EVO.next_tier(level, _evolution_picks()) >= 0:
        _open_evolution_panel()

func _open_evolution_panel() -> void:
    if evolution_overlay == null or popup_shade.visible or not class_selection_locked:
        return
    _update_evolution_panel()
    popup_shade.visible = true
    evolution_overlay.visible = true

func _update_evolution_panel() -> void:
    if evolution_title == null:
        return
    var choices: Array = _evolution_picks()
    var active_tier: int = EVO.next_tier(level, choices)
    var display_tier: int = active_tier
    if display_tier < 0:
        for tier in range(4):
            if int(choices[tier]) < 0:
                display_tier = tier
                break
    var ascensions: int = EVO.total_evolutions(choices)
    if display_tier < 0:
        evolution_title.text = "APOTHEOSIS COMPLETE"
    else:
        evolution_title.text = "%s  •  LEVEL %d" % [EVO.PHASES[display_tier], int(EVO.MILESTONES[display_tier])]
    var path_history := ""
    for tier in range(4):
        if tier > 0:
            path_history += "  |  "
        if int(choices[tier]) >= 0:
            path_history += "%d: %s" % [int(EVO.MILESTONES[tier]), str(EVO.BRANCH_NAMES[hero_class][int(choices[tier])])]
        else:
            path_history += "%d: LOCKED" % int(EVO.MILESTONES[tier])
    evolution_summary.text = "%s   •   %d / 4 EVOLUTIONS\n%s\n%s" % [
        CLASSES[hero_class].to_upper(), ascensions, path_history,
        "CHOOSE YOUR NEXT PERMANENT BRANCH" if active_tier >= 0 else "LEVEL UP TO UNLOCK THE NEXT ASCENSION" if display_tier >= 0 else "ALL FOUR ASCENSIONS UNLOCKED"
    ]
    for branch in range(3):
        var button: Button = evolution_buttons[branch] as Button
        if display_tier < 0:
            button.text = "%s\nFULL EVOLUTION ACHIEVED" % str(EVO.BRANCH_NAMES[hero_class][branch])
        else:
            button.text = "%s\n%s" % [
                str(EVO.BRANCH_NAMES[hero_class][branch]),
                EVO.perk_description(hero_class, display_tier, branch)
            ]
        button.disabled = active_tier < 0
    evolution_close_button.text = "RETURN TO BATTLE" if active_tier < 0 else "DECIDE LATER"

func _choose_evolution(branch: int) -> void:
    if not class_selection_locked or evolution_overlay == null or not evolution_overlay.visible or branch < 0 or branch >= 3:
        return
    var choices: Array = _evolution_picks()
    var tier: int = EVO.next_tier(level, choices)
    if tier < 0 or int(choices[tier]) >= 0:
        return
    choices[tier] = branch
    evolution_choices[str(hero_class)] = choices
    hp = _max_hp()
    mp = _max_mp()
    combat_note = "EVOLVED: %s  •  %s" % [str(EVO.PHASES[tier]), str(EVO.BRANCH_NAMES[hero_class][branch])]
    _sync_equipment_visuals()
    evolution_overlay.visible = false
    popup_shade.visible = false
    var evo_colors := [Color("ff994e"), Color("89d0fa"), Color("b08af8")]
    _burst_particles(hero.position + Vector3(0, 1.1, 0), evo_colors[branch], 52, 2.0, 0.55)
    _play_audio(6)
    _save_game()
    _refresh()
    call_deferred("_offer_evolution")

func _close_evolution_panel() -> void:
    if evolution_overlay == null:
        return
    evolution_overlay.visible = false
    popup_shade.visible = false


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
        _burst_particles(drop_pos + Vector3(0, 1.1, 0), loot_color, 110, 4.0, 0.92)
    _play_audio(2 if rarity == "LEGENDARY" else 1)
    battle_statistics["loot"] = int(battle_statistics.get("loot", 0)) + 1
    if auto_equip:
        _auto_equip_item(item)
    if rarity == "LEGENDARY":
        # Legendary drops must not freeze an unattended idle run.
        combat_note = "LEGENDARY FOUND — " + name.to_upper()

func _item_score(item: Dictionary) -> float:
    if item.is_empty():
        return 0.0
    return float(item.get("damage", 0)) * 2.5 + float(item.get("hp", 0)) * 0.30 + float(item.get("crit", 0)) * 1.15 + float(item.get("speed", 0)) * 1.35 + float(item.get("elemental", 0)) * 0.75

func _toggle_auto_gear() -> void:
    auto_equip = not auto_equip
    combat_note = "AUTO EQUIP ENABLED" if auto_equip else "MANUAL EQUIPMENT MODE"
    _save_game()
    _refresh()

func _auto_equip_item(item: Dictionary) -> bool:
    var slot: String = str(item.get("slot", "Weapon"))
    var old: Dictionary = equipped.get(slot, {})
    var minimum: float = _item_score(old) + 1.5
    if not old.is_empty():
        var set_name: String = str(old.get("set", ""))
        if set_name != "":
            var pieces := 0
            for other in equipped.values():
                if str(other.get("set", "")) == set_name:
                    pieces += 1
            if pieces == 2 or pieces == 4:
                minimum += 34.0
    if not old.is_empty() and _item_score(item) <= minimum:
        return false
    equipped[slot] = item.duplicate(true)
    hp = minf(_max_hp(), hp + 8.0)
    _sync_equipment_visuals()
    combat_note = "UPGRADED: " + str(item.get("name", "Equipment"))
    return true

func _forge_weakest() -> void:
    if equipped.is_empty():
        combat_note = "EQUIP AN ITEM TO FORGE IT"
        _refresh()
        return
    var target_slot := ""
    var lowest_score := INF
    for slot in SLOTS:
        if not equipped.has(slot):
            continue
        var candidate: Dictionary = equipped[slot]
        var current_score := _item_score(candidate)
        if current_score < lowest_score:
            lowest_score = current_score
            target_slot = slot
    if target_slot == "":
        return
    var upgraded: Dictionary = equipped[target_slot].duplicate(true)
    var forging_level := int(upgraded.get("forge", 0))
    var cost: int = 25 + level * 4 + forging_level * (18 + level)
    if gold < cost:
        combat_note = "FORGE %s: NEED %d GOLD" % [target_slot.to_upper(), cost]
        _refresh()
        return
    gold -= cost
    upgraded["forge"] = forging_level + 1
    upgraded["damage"] = int(upgraded.get("damage", 0)) + 2 + maxi(1, int(level / 5))
    upgraded["hp"] = int(upgraded.get("hp", 0)) + 7 + maxi(1, int(level / 3))
    equipped[target_slot] = upgraded
    battle_statistics["forged"] = int(battle_statistics.get("forged", 0)) + 1
    hp = minf(_max_hp(), hp + 15.0)
    _sync_equipment_visuals()
    _spell_burst(Color("ffbb62"), 1.4, 4)
    combat_note = "%s FORGED TO +%d" % [target_slot.to_upper(), forging_level + 1]
    _save_game()
    _refresh()

func _sync_equipment_visuals() -> void:
    if hero == null:
        return
    if equipped_vfx != null and is_instance_valid(equipped_vfx):
        equipped_vfx.queue_free()
    equipped_vfx = Node3D.new()
    hero.add_child(equipped_vfx)
    var set_pieces: Dictionary = {}
    for item in equipped.values():
        var set_name: String = str(item.get("set", ""))
        if set_name != "":
            set_pieces[set_name] = int(set_pieces.get(set_name, 0)) + 1
    var aura_color := Color("6a879b")
    for set_name in set_pieces.keys():
        if int(set_pieces[set_name]) >= 2:
            aura_color = Color("ff824d") if set_name == "Cinderborn" else Color("9c78e0") if set_name == "Gravewarden" else Color("d1bd74")
    var underglow := TorusMesh.new()
    underglow.inner_radius = 0.46
    underglow.outer_radius = 0.50
    _mesh(equipped_vfx, underglow, Vector3(0, 0.10, 0), _mat(aura_color.darkened(0.38), 0.0, true))
    # Distinct, cheap persistent evolution aura. Each invested branch adds one
    # narrow luminous ring; strength grows with the four evolution milestones.
    var branch_tints := [Color("fc8b4f"), Color("71c4e1"), Color("b58ef5")]
    for branch in range(3):
        var path_power: float = _evolution_weight(branch)
        if path_power <= 0.0:
            continue
        var halo := TorusMesh.new()
        halo.inner_radius = 0.53 + path_power * 0.018 + float(branch) * 0.11
        halo.outer_radius = halo.inner_radius + 0.025
        var glow: MeshInstance3D = _mesh(equipped_vfx, halo, Vector3(0, 0.11 + float(branch) * 0.035, 0), _bright(branch_tints[branch]))
        glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if equipped.has("Armor"):
        var armor_item: Dictionary = equipped["Armor"]
        var armor_color := Color("7e3f35") if str(armor_item.get("element", "")) == "FIRE" else Color("494e71")
        var mantle := _box(equipped_vfx, Vector3(0.49, 0.73, 0.07), Vector3(0, 0.80, -0.31), armor_color)
        mantle.rotation.x = 0.20
    if equipped.has("Helm"):
        var helm_item: Dictionary = equipped["Helm"]
        var gem_color := Color("ffb66c") if str(helm_item.get("element", "")) == "FIRE" else Color("a1c9ea")
        var gem := _sphere_part(equipped_vfx, 0.075, Vector3(0, 1.59, 0), gem_color)
        gem.material_override = _bright(gem_color)

func _equip(index: int) -> void:
    if index < 0 or index >= gear.size():
        return
    var item: Dictionary = gear[index]
    equipped[str(item.get("slot", "Weapon"))] = item.duplicate(true)
    hp = minf(hp, _max_hp())
    _sync_equipment_visuals()
    combat_note = "EQUIPPED: " + str(item.get("name", "Item"))
    _save_game()
    _refresh()

func _refresh() -> void:
    if status == null or inventory == null:
        return
    var ascension_count: int = EVO.total_evolutions(_evolution_picks())
    status.text = "%s   LVL %d  %s" % [CLASSES[hero_class], level, "✦" + str(ascension_count) if ascension_count > 0 else ""]
    if evolution_action_button != null:
        evolution_action_button.text = "EVOLVE!" if EVO.next_tier(level, _evolution_picks()) >= 0 else "EVOLVE"
    details.text = "HP %.0f / %.0f   DEF %.0f%%\nXP %d / %d" % [hp, _max_hp(), _defense_reduction() * 100.0, xp, level * 30]
    power_label.text = "POWER %d   GOLD %d" % [int(_damage() * 90 + _max_hp() * 2), gold]
    if auto_gear_button != null:
        auto_gear_button.text = "AUTO: ON" if auto_equip else "AUTO: OFF"
    hero_heart.scale.x = clampf(hp / maxf(1.0, _max_hp()), 0.03, 1.0)
    if hero_mana_bar != null:
        hero_mana_bar.scale.x = clampf(mp / maxf(1.0, _max_mp()), 0.01, 1.0)
    if hero_mana_label != null:
        hero_mana_label.text = "MP %.0f / %.0f   +%.0f / sec" % [mp, _max_mp(), _mana_regeneration()]
    stage_banner.text = "ACT %d   FLOOR %d/10   ROOM %d/3" % [floori(float(stage - 1) / float(BOSS_INTERVAL)) + 1, posmod(stage - 1, BOSS_INTERVAL) + 1, dungeon_room_index]
    var boss_panel: Control = overlay.get_node_or_null("BossHPPanel") as Control
    if boss_panel != null:
        boss_panel.visible = stage % BOSS_INTERVAL == 0 and dungeon_room_index == 3
        boss_hp_label.text = "%s  •  %.0f / %.0f HP" % [BOSS_NAMES[_boss_variant()], maxf(0.0, boss_health), boss_max]
        boss_hp_bar.color = [Color("d94339"), Color("9e55e8"), Color("dc9c46")][_boss_variant()]
        boss_hp_bar.scale.x = clampf(boss_health / maxf(1.0, boss_max), 0.03, 1.0)
    center_banner.modulate.a = 0.87 + sin(chaos_time * 4.0) * 0.13
    combat.text = combat_note
    info.text = "%.0f DMG  •  %d/%d FOES  •  %d KILLS  •  %d SKILLS" % [_damage(), wave_size - arena_mobs.size(), wave_size, kills, skill_points]
    offline.text = offline_note
    combat_bar.scale.x = clampf(enemy_hp / maxf(1.0, enemy_max), 0.02, 1.0)
    if stage != last_map_stage:
        last_map_stage = stage
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
            var rarity: String = str(item.get("rarity", "COMMON")).to_upper()
            var text_value := "[%s] %s  +%d ATK  +%d HP" % [rarity, str(item.get("name", "")), int(item.get("damage", 0)), int(item.get("hp", 0))]
            var loot_button := _ornate_button(text_value, _equip.bind(i), Vector2(600, 40))
            var rarity_tint: Color = Color("eebc6c") if rarity == "LEGENDARY" else Color("c396df") if rarity == "EPIC" else Color("93c6ee") if rarity == "RARE" else Color("a9b0a7")
            loot_button.add_theme_color_override("font_color", rarity_tint)
            inventory.add_child(loot_button)

func _save_game() -> void:
    var data = {
        "class": hero_class, "level": level, "xp": xp, "gold": gold, "evolutions": evolution_choices,
        "stage": stage, "highest": highest, "kills": kills, "hp": hp, "mp": mp,
        "gear": gear, "equipped": equipped, "skills": skills, "class_talents": class_talents, "class_skill_ranks": class_skill_ranks,
        "skill_points": skill_points, "auto_equip": auto_equip,
        "boss_history": earned_bosses, "statistics": battle_statistics, "sound": audio_enabled,
        "encounter_ai": encounter_director.save_state(),
        "saved_at": Time.get_unix_time_from_system()
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
    var raw_evolutions: Variant = data.get("evolutions", {})
    evolution_choices = raw_evolutions if raw_evolutions is Dictionary else {}
    for class_key in evolution_choices.keys():
        evolution_choices[class_key] = EVO.valid_choices(evolution_choices[class_key])
    level = maxi(1, int(data.get("level", 1)))
    xp = maxi(0, int(data.get("xp", 0)))
    gold = maxi(0, int(data.get("gold", 0)))
    stage = maxi(1, int(data.get("stage", 1)))
    highest = maxi(stage, int(data.get("highest", 1)))
    kills = maxi(0, int(data.get("kills", 0)))
    gear = data.get("gear", [])
    equipped = data.get("equipped", {})
    auto_equip = bool(data.get("auto_equip", true))
    earned_bosses = data.get("boss_history", {})
    battle_statistics = data.get("statistics", {"bosses": 0, "loot": 0, "forged": 0})
    audio_enabled = bool(data.get("sound", true))
    encounter_director.load_state(data.get("encounter_ai", {}))
    skills = data.get("skills", [0, 0, 0])
    if skills.size() != 3:
        skills = [0, 0, 0]
    class_talents = data.get("class_talents", {})
    class_skill_ranks = data.get("class_skill_ranks", {})
    if class_talents.has(str(hero_class)):
        skills = class_talents[str(hero_class)].duplicate()
    else:
        class_talents[str(hero_class)] = skills.duplicate()
    skill_points = maxi(0, int(data.get("skill_points", 0)))
    hp = float(data.get("hp", _max_hp()))
    mp = clampf(float(data.get("mp", _max_mp())), 0.0, _max_mp())
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
        var found_relics := mini(4, int(offline_kills / 35))
        for relic_i in range(found_relics):
            var slot: String = SLOTS[(relic_i + stage) % SLOTS.size()]
            var prize: Dictionary = {
                "slot": slot, "name": "Forgotten " + slot,
                "damage": 4 + int(level * 0.9) + relic_i * 2,
                "hp": 12 + int(level * 1.5) + relic_i * 5,
                "set": "",
                "rarity": "RARE",
                "crit": 3 + int(level * 0.12),
                "speed": 2 + int(level * 0.08),
                "element": "FROST",
                "elemental": 4 + int(level * 0.4)
            }
            gear.push_front(prize)
            if gear.size() > 36:
                gear.pop_back()
            if auto_equip:
                _auto_equip_item(prize)
        offline_note = "OFFLINE: %d KILLS  +%d GOLD  +%d ITEMS" % [offline_kills, offline_kills * (3 + stage * 2), found_relics]
    hp = _max_hp()
    mp = _max_mp()
    _spawn_enemy()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_game()

func _skin(bg: Color, edge: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = edge
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.67)
    style.shadow_size = 7
    style.anti_aliasing = true
    style.content_margin_left = 11
    style.content_margin_right = 11
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _ornate_button(title: String, callback: Callable, dims: Vector2) -> Button:
    var b := Button.new()
    b.text = title
    # Godot buttons otherwise request their unbroken text width, forcing
    # modal VBox/HBox layouts past the phone's right edge.
    b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    b.clip_text = true
    b.custom_minimum_size = dims
    b.add_theme_font_size_override("font_size", 15)
    b.add_theme_stylebox_override("normal", _skin(Color("101016ed"), Color("68605f")))
    b.add_theme_stylebox_override("hover", _skin(Color("26212be9"), Color("e4a568")))
    b.add_theme_stylebox_override("pressed", _skin(Color("51382ce9"), Color("f4bc77")))
    b.add_theme_stylebox_override("focus", _skin(Color("382c38d8"), Color("e4b676")))
    b.add_theme_color_override("font_color", Color("f8e8d2"))
    b.add_theme_color_override("font_pressed_color", Color("ffffff"))
    b.pressed.connect(callback)
    return b

func _show_inventory() -> void:
    if legendary_overlay.visible or skill_overlay.visible or hero_overlay.visible:
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
        var bonus_hint := "FIRE DPS" if set_name == "Cinderborn" else "DEFENSE" if set_name == "Gravewarden" else "CRIT/SPEED"
        var pieces: int = int(set_counts[set_name])
        set_parts.append("%s %d/4  %s%s" % [str(set_name), pieces, bonus_hint, "  ACTIVE" if pieces >= 2 else ""])
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
    for child in map_dots.get_children():
        child.queue_free()
    var current: int = posmod(stage - 1, BOSS_INTERVAL)
    # Two rows, five stages per row: all ten gates remain legible in portrait.
    for row_index in range(2):
        var rail := ColorRect.new()
        rail.color = Color("65534b")
        rail.position = Vector2(19, 28 + row_index * 28)
        rail.size = Vector2(140, 2)
        map_dots.add_child(rail)
    for i in range(BOSS_INTERVAL):
        var node := PanelContainer.new()
        var col_index: int = posmod(i, 5)
        var row_index: int = int(i / 5)
        node.position = Vector2(11 + col_index * 34, 17 + row_index * 28)
        node.size = Vector2(20, 20)
        var style := StyleBoxFlat.new()
        style.bg_color = Color("d7ba8b") if i < current else Color("db603d") if i == current else Color("1c2330")
        style.border_color = Color("edc78f") if i <= current else Color("736253")
        style.set_border_width_all(1)
        style.set_corner_radius_all(10)
        node.add_theme_stylebox_override("panel", style)
        map_dots.add_child(node)
        var numeral := _label(str(i + 1), 10, Color("10131b") if i <= current else Color("c4b6ae"))
        numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        node.add_child(numeral)
    var hint := _label("BOSS ON FLOOR 10", 12, Color("d8b37d"))
    hint.position = Vector2(8, 79)
    hint.size = Vector2(165, 20)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_dots.add_child(hint)

func _hide_legendary() -> void:
    popup_shade.visible = false
    legendary_overlay.visible = false

func _equip_legendary() -> void:
    if last_legendary.is_empty():
        return
    equipped[str(last_legendary.get("slot", "Weapon"))] = last_legendary.duplicate(true)
    combat_note = "LEGENDARY EQUIPPED!"
    hp = _max_hp()
    _sync_equipment_visuals()
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

func _skill_rank(index: int) -> int:
    if index < 0 or index > 2 or level < int(SKILL_UNLOCK_LEVELS[index]):
        return 0
    var ranks: Array = class_skill_ranks.get(str(hero_class), [1, 1, 1])
    if ranks.size() != 3:
        return 1
    return clampi(int(ranks[index]), 1, SKILL_MAX_RANK)

func _upgrade_class_skill(index: int) -> void:
    if skill_points <= 0 or index < 0 or index >= 3 or level < int(SKILL_UNLOCK_LEVELS[index]):
        return
    var current: int = _skill_rank(index)
    if current >= SKILL_MAX_RANK:
        return
    var ranks: Array = class_skill_ranks.get(str(hero_class), [1, 1, 1]).duplicate()
    ranks[index] = current + 1
    class_skill_ranks[str(hero_class)] = ranks
    skill_points -= 1
    combat_note = "%s RANK %d" % [CLASS_SPELLS[hero_class][index], int(ranks[index])]
    _play_audio(6)
    _update_talent_labels()
    _save_game()
    _refresh()

func _cast_chain_lightning(rank: int, damage: float) -> int:
    if hero == null or arena_mobs.is_empty():
        return 0
    var visited: Array = []
    var start: Vector3 = hero.global_position + Vector3(0, 1.36, 0)
    var jumps: int = mini(arena_mobs.size(), 2 + rank)
    for hop in range(jumps):
        var selected: Node3D = null
        var nearest: float = INF
        for candidate in arena_mobs:
            var mob: Node3D = candidate as Node3D
            if mob == null or not is_instance_valid(mob) or visited.has(mob):
                continue
            var squared_distance: float = start.distance_squared_to(mob.global_position + Vector3(0, 0.95, 0))
            if squared_distance < nearest and squared_distance < 75.0:
                selected = mob
                nearest = squared_distance
        if selected == null:
            break
        visited.append(selected)
        var finish: Vector3 = selected.global_position + Vector3(0, 1.02, 0)
        _jagged_lightning(start, finish, rank)
        _burst_particles(finish, Color("badfff"), 6, 0.85, 0.24)
        _hit_mob(selected, damage * pow(0.84, float(hop)), hop == 0 and rank >= 5)
        start = finish
    return visited.size()


func _use_skill(index: int) -> void:
    if index < 0 or index >= 3 or popup_shade.visible:
        return
    if level < int(SKILL_UNLOCK_LEVELS[index]):
        combat_note = "%s UNLOCKS AT LEVEL %d" % [CLASS_SPELLS[hero_class][index], int(SKILL_UNLOCK_LEVELS[index])]
        _refresh()
        return
    if float(skill_cooldowns[index]) > 0.0:
        return
    var rank: int = _skill_rank(index)
    var mana_cost: float = float(CLASS_SKILL_COSTS[hero_class][index]) + float(rank - 1)
    if mp < mana_cost:
        combat_note = "%s: NEED %.0f MP" % [CLASS_SPELLS[hero_class][index], mana_cost]
        _refresh()
        return
    mp -= mana_cost
    skill_cooldowns[index] = float([3.2, 5.2, 12.0][index]) * maxf(0.58, 1.0 - 0.035 * float(rank - 1)) * maxf(0.50, 1.0 - 0.06 * _evolution_weight(2))
    if hero_class == 0 and _evolution_weight(2) > 0.0:
        skill_cooldowns[index] *= maxf(0.78, 1.0 - 0.025 * _evolution_weight(2))
    if hero_class == 3 and _evolution_weight(2) > 0.0:
        mp = minf(_max_mp(), mp + 3.0 * _evolution_weight(2))
    var palettes: Array = [
        [Color("ff6b20"), Color("e2bd68"), Color("ffb23a")],
        [Color("87c866"), Color("95d9db"), Color("fff09a")],
        [Color("ff7435"), Color("7ae2fd"), Color("d9a8ff")],
        [Color("bf566c"), Color("814de7"), Color("f793cc")]
    ]
    var tint: Color = palettes[hero_class][index]
    _cast_class_visual(index, tint)
    _actor_attack(hero, true)
    camera_kick = maxf(camera_kick, 0.9 if index == 2 else 0.4)
    camera_shake = maxf(camera_shake, 0.28 if index == 2 else 0.09)
    _play_audio(5 if hero_class == 2 and index == 1 else 3)
    var multiplier: float = float([1.25, 1.60, 2.80][index]) * (1.0 + float(rank - 1) * 0.16) * (1.0 + 0.12 * _evolution_weight(2))
    if hero_class == 2:
        multiplier *= 1.0 + 0.04 * _evolution_weight(0)
    if hero_class == 2:
        multiplier *= 1.18
    elif hero_class == 3 and index == 2:
        multiplier *= 1.30
    if hero_class == 0 and index == 1:
        hp = minf(_max_hp(), hp + _max_hp() * 0.11)
    if hero_class == 2 and index == 1:
        var num_jumps: int = _cast_chain_lightning(rank + EVO.count_branch(_evolution_picks(), 2), _damage() * multiplier)
        combat_note = "CHAIN LIGHTNING R%d — %d TARGETS" % [rank, num_jumps]
        if arena_mobs.is_empty():
            _complete_wave()
        _refresh()
        return
    var targets: Array = arena_mobs.duplicate()
    targets.shuffle()
    var seeker_volley: int = EVO.count_branch(_evolution_picks(), 2) if hero_class == 1 else 0
    var target_count: int = mini(targets.size(), int([3, 5, 10][index]) + (2 if hero_class == 1 else 0) + int((rank - 1) / 3) + seeker_volley)
    for i in range(target_count):
        var mob: Node3D = targets[i] as Node3D
        if is_instance_valid(mob) and arena_mobs.has(mob):
            # NIGHTFALL and ARCANE get focused layered beams instead of just a generic area burst.
            if index == 2 and (hero_class == 2 or hero_class == 3) and i < 2:
                var ray_color: Color = Color("e82745") if hero_class == 3 else Color("a86bff")
                _signature_ray(hero.global_position + Vector3(0.0, 1.45, 0.0), mob.global_position + Vector3(0.0, 1.03, 0.0), ray_color, 1.20 if i == 0 else 0.76)
            _hit_mob(mob, _damage() * multiplier, index == 2)
    combat_note = str(CLASS_SPELLS[hero_class][index]) + "!"
    if index == 2:
        var final_target: Node3D = _choose_target()
        var epic_center: Vector3 = final_target.global_position if final_target != null else hero.position
        _burst_particles(epic_center + Vector3(0, 1.25, 0), tint, 60, 3.3, 0.58)
    if arena_mobs.is_empty():
        _complete_wave()
    _refresh()

func _cast_class_visual(index: int, tint: Color) -> void:
    # Each hero has its own readable silhouette, not a recolored generic nova.
    # Especially important for isometric play at small portrait-screen sizes.
    if hero == null:
        return
    var origin: Vector3 = hero.global_position + Vector3(0, 1.4, 0)
    var focus: Node3D = _choose_target()
    var target_pos: Vector3 = focus.global_position + Vector3(0, 0.95, 0) if focus != null else origin + Vector3(0, 0, -1.0)
    match hero_class:
        0:
            if index == 0:
                _slash_trail(target_pos, false)
                _burst_particles(target_pos, tint, 18, 1.2, 0.31)
            elif index == 1:
                # A restrained shield sigil wraps the defender.
                _spell_burst(tint, 0.92, 2)
            else:
                _spell_burst(tint, 2.1, 8)
        1:
            # A volley of clear, thin arrows instead of a full-screen fireball.
            var shafts: int = 3 + index * 2
            for i in range(shafts):
                var arc: float = float(i) * TAU / float(shafts)
                var tip: Vector3 = target_pos + Vector3(cos(arc), 0.0, sin(arc)) * (0.24 if index == 0 else 1.07)
                var from: Vector3 = origin + Vector3(sin(float(i) * 2.0) * 0.15, 0.14 * float(i % 3), 0.0)
                _energy_arc(from, tip, tint, 0.03)
            _burst_particles(target_pos, tint, 19, 1.45 if index < 2 else 2.2, 0.35)
        2:
            if index == 0:
                _energy_arc(origin, target_pos, tint, 0.065)
                _burst_particles(target_pos, tint, 34, 1.8, 0.42)
            elif index == 1:
                # Real hop-by-hop arcs are emitted by _cast_chain_lightning.
                _burst_particles(origin, tint, 13, 0.9, 0.26)
            else:
                # Arcane beams are drawn for each target in the damage loop.
                _burst_particles(origin, tint, 19, 1.0, 0.27)
        3:
            if index == 0:
                _signature_ray(target_pos, origin, tint, 0.46)
            elif index == 1:
                _energy_arc(origin, target_pos, tint, 0.09)
                _burst_particles(target_pos, tint, 29, 2.0, 0.40)
            else:
                # Blood-red execution beams appear in the damage loop.
                _burst_particles(origin, tint, 21, 1.2, 0.30)


func _random_spawn() -> Vector3:
    var a := rng.randf_range(0.0, TAU)
    var d := rng.randf_range(0.8, 2.8)
    return Vector3(cos(a) * d, 0, sin(a) * d)


func _spawn_horde() -> void:
    for mob in arena_mobs:
        if is_instance_valid(mob):
            mob.queue_free()
    arena_mobs.clear()
    wave_kills = 0
    var is_boss: bool = stage % BOSS_INTERVAL == 0 and dungeon_room_index == 3
    current_encounter = encounter_director.choose(stage, dungeon_room_index, hero_class,
        grind_mode, hp / maxf(1.0, _max_hp()), rng)
    encounter_started_ms = Time.get_ticks_msec()
    var mob_count: int = (5 + mini(int(stage / 20), 3)) if is_boss else (5 + mini(int(stage / 16), 3))
    mob_count = clampi(mob_count + int(current_encounter.get("count_bonus", 0)), 4, 10)
    wave_size = mob_count
    for i in range(mob_count):
        var elite: bool = is_boss and i == 0
        var ai_role: String = encounter_director.enemy_role(current_encounter, i, elite)
        var boss_models := ["ashen_shadow_knight", "ashen_mage", "ashen_armored_knight"]
        var role_models := {"raider": "skeleton_dark", "flanker": "ashen_ranger",
            "guardian": "ashen_armored_knight", "caster": "ashen_mage"}
        var model_name: String = str(boss_models[_boss_variant()]) if elite else str(role_models.get(ai_role, "skeleton_dark"))
        var root := Node3D.new()
        add_child(root)
        var packed := _get_asset_scene(model_name)
        if packed == null:
            packed = _get_asset_scene("Skeleton_Warrior" if elite else "Skeleton_Minion")
        if packed != null:
            var instance: Node3D = packed.instantiate() as Node3D
            if instance != null:
                root.add_child(instance)
                _fit_visual_model(instance, [3.12, 3.26, 3.48][_boss_variant()] if elite else 1.63)
                _darken_character_materials(instance, elite)
                if model_name.begins_with("ashen_"):
                    _attach_hero_clips(instance)
                _bind_motion_driver(root)
                _play_actor_clip(root, "Idle", 0.0, 1.0)
                _pose_fantasy_skeleton(root, 0.0)
        if elite:
            var aura_tint: Color = [Color("d74931"), Color("8847da"), Color("e6a44e")][_boss_variant()]
            var halo := TorusMesh.new()
            halo.inner_radius = 1.07
            halo.outer_radius = 1.12
            _mesh(root, halo, Vector3(0, 0.11, 0), _mat(aura_tint.darkened(0.40), 0.0, true))
            # The boss silhouette must be recognizable from a zoomed-out phone
            # camera, not only a scaled-up player GLB.
            for sign in [-1.0, 1.0]:
                var horn := _cone(root, 0.22, 0.01, 1.17, Vector3(sign * 0.61, 2.78, 0.1), aura_tint.darkened(0.42))
                horn.rotation.z = sign * -0.30
            var crown_glow := _sphere_part(root, 0.21, Vector3(0, 3.19, 0.0), aura_tint.lightened(0.25))
            crown_glow.material_override = _bright(aura_tint)
            for rune_i in range(5 + _boss_variant()):
                var angle := TAU * float(rune_i) / float(5 + _boss_variant())
                var shard_height := 0.30 + float(rune_i % 3) * 0.19
                var shard := _cone(root, 0.13, 0.012, shard_height, Vector3(cos(angle) * 0.91, 0.22 + shard_height * 0.5, sin(angle) * 0.91), aura_tint.darkened(0.15))
                shard.rotation.z = sin(angle) * 0.14
        if root.get_child_count() == 0:
            var body := CapsuleMesh.new()
            body.radius = 0.38 if not elite else 0.67
            body.height = 1.18 if not elite else 2.1
            _mesh(root, body, Vector3(0, 0.8, 0), _mat(Color("80404f")))
        var spawn_center: Vector3 = dungeon_points[dungeon_room_index] if dungeon_points.size() > dungeon_room_index else Vector3.ZERO
        root.position = spawn_center + (Vector3(0.0, 0.0, -0.90) if elite else _random_spawn())
        var variant_hp: float = [13.0, 10.5, 16.0][_boss_variant()]
        var mob_health := (14.0 + float(stage) * 5.0 + float(level) * 0.20) * (variant_hp if elite else float(current_encounter.get("hp_factor", 1.0)))
        root.set_meta("ai_role", "boss" if elite else ai_role)
        root.set_meta("ai_next_cast", rng.randf_range(3.5, 6.5))
        root.set_meta("hp", mob_health)
        root.set_meta("max_hp", mob_health)
        root.set_meta("boss", elite)
        root.set_meta("speed", 0.22 + rng.randf_range(0.01, 0.10))
        root.set_meta("phase", rng.randf_range(0.0, TAU))
        arena_mobs.append(root)
    combat_note = "BOSS: " + BOSS_NAMES[_boss_variant()] if is_boss else str(current_encounter.get("title", "HORDE APPROACHING"))

func _impact(pos: Vector3, color: Color) -> void:
    _burst_particles(pos, color, 12, 2.6, 0.33)
    var flare := QuadMesh.new()
    flare.size = Vector2(0.85, 0.85)
    var spark := _mesh(self, flare, pos, _fx_material(color, 0.85))
    spell_fx.append({"node": spark, "time": 0.18, "total": 0.18, "type": "hit"})
    if spell_fx.size() > 90:
        var previous: Dictionary = spell_fx.pop_front()
        if is_instance_valid(previous["node"]):
            previous["node"].queue_free()

func _spell_burst(color: Color, size: float, shards: int) -> void:
    var center: Vector3 = hero.position + Vector3(0.0, 1.05, 0.0) if hero != null else Vector3(0.0, 1.05, 0.0)
    _burst_particles(center, color, 44 + shards * 7, size * 2.7, 0.55)
    if screen_flash != null:
        screen_flash.color = color
        screen_flash_fade = 0.08
        screen_flash.modulate.a = screen_flash_fade
    _burst_particles(center + Vector3(0.0, 0.16, 0.0), Color("ffe4b6"), 13, size * 1.35, 0.29)
    var ground_glow := PlaneMesh.new()
    ground_glow.size = Vector2(size * 2.55, size * 2.55)
    var ground_mat := _fx_material(color, 0.15)
    ground_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    var aoe := _mesh(self, ground_glow, Vector3(center.x, 0.104, center.z), ground_mat)
    aoe.scale = Vector3.ONE * 0.72
    spell_fx.append({"node": aoe, "time": 0.44, "total": 0.44, "type": "spell"})
    var burst_light := OmniLight3D.new()
    burst_light.position = center + Vector3(0, 0.7, 0)
    burst_light.light_color = color
    burst_light.light_energy = 0.74
    burst_light.omni_range = 8.4
    add_child(burst_light)
    get_tree().create_timer(0.26).timeout.connect(burst_light.queue_free)
    var shock := TorusMesh.new()
    shock.inner_radius = size * 0.64
    shock.outer_radius = size * 0.655
    var ring_mat := _fx_material(color, 0.29)
    ring_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    ring_mat.albedo_texture = null
    var wave := _mesh(self, shock, hero.position + Vector3(0, 0.10, 0) if hero != null else Vector3.ZERO, ring_mat)
    wave.scale = Vector3.ONE * 0.3
    spell_fx.append({"node": wave, "time": 0.31, "total": 0.31, "type": "spell"})
    for strike_i in range(mini(shards + 1, 8)):
        var angle := TAU * float(strike_i) / float(shards + 1)
        var origin := center + Vector3(cos(angle) * 0.34, 0.85, sin(angle) * 0.34)
        var end := center + Vector3(cos(angle) * size * 0.93, rng.randf_range(-0.45, 0.35), sin(angle) * size * 0.93)
        _energy_arc(origin, end, color, 0.023 + 0.008 * float(strike_i % 3))
    # Beams of rising energy, individual sparks and sharp concentric shockwave.
    for i in range(mini(shards + 2, 7)):
        var theta := TAU * float(i) / float(shards + 2)
        var point := center + Vector3(cos(theta) * size * 0.26, 0.16, sin(theta) * size * 0.26)
        var plume_mesh := QuadMesh.new()
        plume_mesh.size = Vector2(0.38, 1.96)
        var ray := _mesh(self, plume_mesh, point, _fx_material(color, 0.45))
        ray.scale = Vector3(0.75, 1.0, 0.75)
        spell_fx.append({"node": ray, "time": 0.45, "total": 0.45, "type": "hit"})

func _energy_arc(from: Vector3, to: Vector3, tint: Color, thickness: float) -> void:
    var heading: Vector3 = to - from
    var distance: float = heading.length()
    if distance < 0.05:
        return
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = thickness * 0.22
    cylinder.bottom_radius = thickness
    cylinder.height = distance
    var shaft := _mesh(self, cylinder, (from + to) * 0.5, _beam_material(tint, 0.35))
    shaft.quaternion = Quaternion(Vector3.UP, heading.normalized())
    spell_fx.append({"node": shaft, "time": 0.28, "total": 0.28, "type": "hit"})

func _signature_ray(start: Vector3, finish: Vector3, tint: Color, width: float = 1.0) -> void:
    # Reference-inspired crimson energy lance: three concentric beams, hot core,
    # drifting outer glow and an impact burst. Lightweight enough for Android GL.
    var heading: Vector3 = finish - start
    var distance: float = heading.length()
    if distance < 0.10:
        return
    var center: Vector3 = (start + finish) * 0.5
    for layer in range(3):
        var shaft := CylinderMesh.new()
        var thickness: float = float([0.155, 0.075, 0.028][layer]) * width
        shaft.top_radius = thickness
        shaft.bottom_radius = thickness
        shaft.height = distance + 0.12
        var ray_color: Color = tint if layer == 0 else tint.lightened(0.20 if layer == 1 else 0.82)
        var opacity: float = float([0.24, 0.66, 0.98][layer])
        var visual := _mesh(self, shaft, center, _beam_material(ray_color, opacity))
        visual.quaternion = Quaternion(Vector3.UP, heading.normalized())
        visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        spell_fx.append({"node": visual, "time": 0.32, "total": 0.32, "type": "ray"})
    _burst_particles(finish, tint, 22, 1.9, 0.35)
    _burst_particles(finish, Color("fff2d5"), 8, 0.95, 0.20)


func _bright(color: Color) -> Material:
    var m := _mat(color.darkened(0.16))
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = 1.36
    return m

func _beam_material(color: Color, alpha: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_color = Color(color.r, color.g, color.b, alpha)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 1.42
    return mat

func _loot_beam(pos: Vector3, color: Color, title: String) -> void:
    var pillar := CylinderMesh.new()
    pillar.top_radius = 0.06
    pillar.bottom_radius = 0.12
    pillar.height = 3.9
    var column := _mesh(self, pillar, pos + Vector3(0, 2.0, 0), _beam_material(color, 0.23))
    var core := CylinderMesh.new()
    core.top_radius = 0.017
    core.bottom_radius = 0.039
    core.height = 4.2
    var core_mesh := _mesh(self, core, pos + Vector3(0, 2.10, 0), _beam_material(color.lightened(0.52), 0.84))
    var pool := CylinderMesh.new()
    pool.top_radius = 0.26
    pool.bottom_radius = 0.26
    pool.height = 0.015
    var disc := _mesh(self, pool, pos + Vector3(0, 0.07, 0), _beam_material(color, 0.40))
    _burst_particles(pos + Vector3(0, 0.75, 0), color, 18, 1.3, 0.66)
    var label := _label(title, 18, color.lightened(0.35))
    label.size = Vector2(260, 32)
    label.visible = false
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    overlay.add_child(label)
    loot_beams.append({"mesh": column, "core": core_mesh, "disc": disc, "label": label, "pos": pos, "time": 5.0})
    if loot_beams.size() > 13:
        _clear_beam(loot_beams.pop_front())

func _clear_beam(beam: Dictionary) -> void:
    for key in ["mesh", "core", "disc", "label"]:
        if is_instance_valid(beam[key]):
            beam[key].queue_free()

func _damage_popup(value: int, pos: Vector3, crit: bool) -> void:
    if overlay == null:
        return
    var label := _label(str(value), 25 if crit else 18, Color("ffdf83") if crit else Color("f3e2dc"))
    label.size = Vector2(135, 34)
    label.add_theme_color_override("font_shadow_color", Color("08060d"))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 3)
    label.visible = false
    overlay.add_child(label)
    hit_texts.append({"label": label, "pos": pos, "time": 0.84})
    if hit_texts.size() > 30:
        var old = hit_texts.pop_front()
        if is_instance_valid(old["label"]):
            old["label"].queue_free()

func _update_chaos(delta: float) -> void:
    for i in range(arena_mobs.size()):
        var mob: Node3D = arena_mobs[i] as Node3D
        if not is_instance_valid(mob):
            continue
        var boss: bool = bool(mob.get_meta("boss", false))
        var phase: float = float(mob.get_meta("phase", 0))
        var center: Vector3 = dungeon_points[dungeon_room_index] if dungeon_points.size() > dungeon_room_index else Vector3.ZERO
        var engaged: bool = hero != null and hero.position.distance_to(center) <= 7.6
        # Keep the next room populated but stationary until the hero approaches.
        # Once engaged, creatures close in, stagger and attack naturally.
        var desired: Vector3 = mob.position
        if engaged:
            var angle: float = float(i) * 2.40 + sin(chaos_time * 0.38 + phase) * 0.24
            var radius: float = 1.45 if boss else 1.23 + float(i % 4) * 0.31
            desired = hero.position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
        var last_position: Vector3 = mob.position
        var stagger: float = maxf(0, float(mob.get_meta("stagger", 0)) - delta)
        mob.set_meta("stagger", stagger)
        var knockback: Vector3 = mob.get_meta("knockback", Vector3.ZERO)
        mob.position += knockback * delta
        mob.set_meta("knockback", knockback.move_toward(Vector3.ZERO, delta * 7.0))
        var chase: Vector3 = desired - mob.position
        chase.y = 0
        # Natural start/stop speeds make the horde close in organically
        # instead of sliding at a constant velocity around the player.
        var ideal_velocity := Vector3.ZERO
        if engaged and stagger <= 0.0 and chase.length_squared() > 0.0324:
            var pursuit_speed: float = 1.28 + float(mob.get_meta("speed", 0.25)) * 1.35
            ideal_velocity = chase.normalized() * pursuit_speed
        var pursuit_velocity: Vector3 = mob.get_meta("pursuit_velocity", Vector3.ZERO)
        pursuit_velocity = pursuit_velocity.move_toward(ideal_velocity, delta * (7.0 if boss else 9.0))
        var chase_step: Vector3 = pursuit_velocity * delta
        if chase_step.length_squared() > chase.length_squared():
            chase_step = chase
            pursuit_velocity = Vector3.ZERO
        mob.position += chase_step
        mob.set_meta("pursuit_velocity", pursuit_velocity)
        var velocity: float = mob.position.distance_to(last_position) / maxf(0.001, delta)
        # Faraway unengaged enemies already have an Idle animation playing.
        # Avoid repeatedly traversing and posing their full skeletons off camera.
        if engaged or (hero != null and mob.position.distance_squared_to(hero.position) < 196.0):
            _animate_actor(mob, velocity)
        mob.position.y = 0
        if engaged and hero != null:
            var face: Vector3 = hero.position - mob.position
            if face.length_squared() > 0.02:
                mob.rotation.y = lerp_angle(mob.rotation.y, atan2(face.x, face.z), clampf(delta * 5.0, 0, 1))
    for i in range(spell_fx.size() - 1, -1, -1):
        var fx: Dictionary = spell_fx[i]
        fx["time"] = float(fx["time"]) - delta
        var m: MeshInstance3D = fx["node"]
        if is_instance_valid(m):
            var p := 1.0 - float(fx["time"]) / float(fx["total"])
            if fx["type"] == "ray":
                # Do not stretch directional beams: fade the beam material in place.
                var ray_material: StandardMaterial3D = m.material_override as StandardMaterial3D
                if ray_material != null:
                    var ray_color: Color = ray_material.albedo_color
                    ray_color.a = clampf(1.0 - p, 0.0, 1.0)
                    ray_material.albedo_color = ray_color
            else:
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
            label.visible = p.y > 455.0 and p.y < overlay.size.y - 360.0 and p.x > 160.0 and p.x < overlay.size.x - 150.0
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
            label.visible = text_screen_pos.x > 155.0 and text_screen_pos.x < overlay.size.x - 150.0 and text_screen_pos.y > 440.0 and text_screen_pos.y < overlay.size.y - 355.0
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

func _dark_character_name(source_name: String, enemy: bool) -> String:
    match source_name:
        "Knight": return "ashen_armored_knight"
        "Barbarian": return "ashen_shadow_knight"
        "Rogue": return "ashen_ranger"
        "Mage": return "ashen_mage"
        "Skeleton_Warrior": return "ashen_armored_knight" if enemy else "skeleton_dark"
        "Skeleton_Mage": return "ashen_mage"
        "Skeleton_Minion": return "skeleton_dark"
        "Skeleton_Rogue": return "skeleton_dark"
    return source_name

func _fit_visual_model(model: Node3D, intended_height: float) -> void:
    var points := AABB()
    var initialized := false
    for found in model.find_children("*", "MeshInstance3D", true, false):
        var part := found as MeshInstance3D
        if part == null or part.mesh == null:
            continue
        var transform_in_root: Transform3D = model.global_transform.affine_inverse() * part.global_transform
        var local_bounds: AABB = transform_in_root * part.get_aabb()
        if not initialized:
            points = local_bounds
            initialized = true
        else:
            points = points.merge(local_bounds)
    if initialized and points.size.y > 0.01:
        var factor: float = clampf(intended_height / points.size.y, 0.055, 15.0)
        model.scale = Vector3.ONE * factor
        model.position.y = -points.position.y * factor
    else:
        model.scale = Vector3.ONE

func _darken_character_materials(model: Node3D, is_elite: bool) -> void:
    for found in model.find_children("*", "MeshInstance3D", true, false):
        var part := found as MeshInstance3D
        if part == null or part.mesh == null:
            continue
        for surface_i in range(part.mesh.get_surface_count()):
            var source_mat := part.get_active_material(surface_i) as BaseMaterial3D
            if source_mat == null:
                continue
            var deeper := source_mat.duplicate() as BaseMaterial3D
            deeper.albedo_color = deeper.albedo_color * (Color("a1a3b3") if not is_elite else Color("8e7892"))
            deeper.roughness = 0.80
            deeper.metallic = 0.10
            part.set_surface_override_material(surface_i, deeper)

func _attach_hero_clips(model: Node3D) -> void:
    # Quaternius Universal rigs are compatible; copy each Godot animation track
    # to the matching destination bone rather than relying on FBX retarget services.
    var shared := _get_asset_scene("ashen_shared_anims")
    if shared == null:
        return
    var receiver_skeleton: Skeleton3D
    for part in model.find_children("*", "Skeleton3D", true, false):
        receiver_skeleton = part as Skeleton3D
        break
    if receiver_skeleton == null:
        return
    var skeleton_path: String = String(model.get_path_to(receiver_skeleton))
    if shared_animation_cache.has(skeleton_path):
        var cached_player := AnimationPlayer.new()
        cached_player.name = "CombatAnimationPlayer"
        model.add_child(cached_player)
        cached_player.add_animation_library("", shared_animation_cache[skeleton_path])
        return
    var donor: Node3D = shared.instantiate() as Node3D
    if donor == null:
        return
    add_child(donor)
    var donor_player: AnimationPlayer
    for part in donor.find_children("*", "AnimationPlayer", true, false):
        donor_player = part as AnimationPlayer
        break
    if receiver_skeleton == null or donor_player == null:
        donor.queue_free()
        return
    var result := AnimationLibrary.new()
    for clip_name in donor_player.get_animation_list():
        var source: Animation = donor_player.get_animation(clip_name)
        if source == null:
            continue
        var target_anim := Animation.new()
        target_anim.length = source.length
        target_anim.loop_mode = source.loop_mode
        for idx in range(source.get_track_count()):
            var track_type: Animation.TrackType = source.track_get_type(idx)
            if track_type != Animation.TYPE_POSITION_3D and track_type != Animation.TYPE_ROTATION_3D and track_type != Animation.TYPE_SCALE_3D:
                continue
            var raw_path: String = String(source.track_get_path(idx))
            var sep: int = raw_path.rfind(":")
            if sep < 0:
                continue
            var bone: String = raw_path.substr(sep + 1)
            if receiver_skeleton.find_bone(bone) < 0:
                continue
            var idx_new: int = target_anim.add_track(track_type)
            target_anim.track_set_path(idx_new, NodePath(String(model.get_path_to(receiver_skeleton)) + ":" + bone))
            for key_idx in range(source.track_get_key_count(idx)):
                target_anim.track_insert_key(idx_new,
                    source.track_get_key_time(idx, key_idx),
                    source.track_get_key_value(idx, key_idx),
                    source.track_get_key_transition(idx, key_idx))
        if target_anim.get_track_count() > 0:
            result.add_animation(clip_name, target_anim)
    if result.get_animation_list().size() > 0:
        shared_animation_cache[skeleton_path] = result
        var receiver := AnimationPlayer.new()
        receiver.name = "CombatAnimationPlayer"
        model.add_child(receiver)
        receiver.add_animation_library("", result)
    donor.queue_free()

func _make_animated_character(model_name: String, at: Vector3, enemy: bool) -> Node3D:
    var dark_name := _dark_character_name(model_name, enemy)
    var packed := _get_asset_scene(dark_name)
    if packed == null:
        packed = _get_asset_scene(model_name)
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
    _fit_visual_model(model, 1.89 if not enemy else 1.58)
    model.rotation.y = PI
    _darken_character_materials(model, false)
    if not enemy:
        _attach_hero_clips(model)
    _bind_motion_driver(root)
    _play_actor_clip(root, "Idle", 0.0, 1.0)
    _pose_fantasy_skeleton(root, 0.0)
    # Subtle class-colored ground contact; silhouettes stay readable at the
    # wider portrait camera distance without cartoon outlines.
    var contact := TorusMesh.new()
    contact.inner_radius = 0.45 if enemy else 0.58
    contact.outer_radius = 0.47 if enemy else 0.605
    var color: Color = Color("ac4c49") if enemy else [Color("f1a16e"), Color("9ccf77"), Color("85caff"), Color("bb91f7")][hero_class]
    var contact_mesh := _mesh(root, contact, Vector3(0, 0.045, 0), _bright(color.darkened(0.35)))
    contact_mesh.name = "GroundContactGlow"
    contact_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

func _rift_line(point_a: Vector3, point_b: Vector3, width: float, color: Color) -> void:
    # Angular low glowing seams on the dungeon floor; entirely procedural and lightweight.
    var segment := point_b - point_a
    var length := segment.length()
    if length < 0.05:
        return
    var crack_mesh := BoxMesh.new()
    crack_mesh.size = Vector3(width * 0.72, 0.007, length)
    var crack := _mesh(self, crack_mesh, (point_a + point_b) * 0.5 + Vector3(0, 0.078, 0), _mat(color.darkened(0.66), 0.0, true))
    crack.rotation.y = atan2(segment.x, segment.z)

func _decorate_arena() -> void:
    # A broken ritual seal, basalt shards and twin flaming beacons bring the arena to life.
    # Geometry is intentionally inexpensive so GL Compatibility remains fast on Android.
    var ring := TorusMesh.new()
    ring.inner_radius = 2.68
    ring.outer_radius = 2.70
    _mesh(self, ring, Vector3(0, 0.11, 0), _mat(Color("5d251f"), 0.1, true))
    var outer_ring := TorusMesh.new()
    outer_ring.inner_radius = 4.23
    outer_ring.outer_radius = 4.25
    _mesh(self, outer_ring, Vector3(0, 0.105, 0), _mat(Color("37252d"), 0.1, true))
    for mark_i in range(12):
        var a := TAU * float(mark_i) / 12.0
        var axis := Vector3(cos(a), 0, sin(a))
        var transverse := Vector3(-axis.z, 0, axis.x)
        var from := axis * 2.80
        var to := axis * 3.70
        _rift_line(from, to, 0.028, Color("d46035") if mark_i % 3 == 0 else Color("6d3640"))
        if mark_i % 3 == 0:
            _rift_line(to + transverse * 0.10, to + transverse * 0.63, 0.02, Color("dc7841"))
    for branch_i in range(16):
        var a := TAU * float(branch_i) / 16.0 + 0.22
        var start := Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.3, 5.0)
        var mid := start + Vector3(cos(a + 0.32), 0, sin(a + 0.32)) * rng.randf_range(0.34, 0.86)
        var end := mid + Vector3(cos(a - 0.19), 0, sin(a - 0.19)) * rng.randf_range(0.36, 1.02)
        _rift_line(start, mid, 0.018 + rng.randf() * 0.018, Color("ae4a2c"))
        _rift_line(mid, end, 0.014, Color("9b422e"))
    var debris_mat := (pbr_floor.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
    debris_mat.uv1_scale = Vector3(1.5, 1.5, 1.0)
    debris_mat.albedo_color = Color("777c82")
    for debris_idx in range(19):
        var angle := TAU * float(debris_idx) / 19.0 + 0.35
        var radius := 5.0 + float(debris_idx % 3) * 0.35
        var at := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
        var width := 0.16 + float(debris_idx % 3) * 0.14
        var depth := 0.3 + float(debris_idx % 4) * 0.11
        var stone_piece := BoxMesh.new()
        stone_piece.size = Vector3(width, 0.18, depth)
        var rubble := _mesh(self, stone_piece, at + Vector3(0, 0.08, 0), debris_mat)
        rubble.rotation.y = float(debris_idx) * 1.43
        rubble.rotation.x = 0.09 * sin(float(debris_idx) * 2.7)
    for beacon_i in range(2):
        var x := -5.45 if beacon_i == 0 else 5.45
        var base := Vector3(x, 0, -3.1)
        var pedestal := BoxMesh.new()
        pedestal.size = Vector3(0.72, 0.90, 0.72)
        _mesh(self, pedestal, base + Vector3(0, 0.45, 0), debris_mat)
        var brazier := CylinderMesh.new()
        brazier.top_radius = 0.44
        brazier.bottom_radius = 0.24
        brazier.height = 0.22
        _mesh(self, brazier, base + Vector3(0, 1.0, 0), _mat(Color("5c4a3c"), 0.66))
        var flame := CPUParticles3D.new()
        var flare_mesh := QuadMesh.new()
        flare_mesh.size = Vector2(0.36, 0.48)
        flare_mesh.material = _fx_material(Color("ff6d28"), 0.90)
        flame.mesh = flare_mesh
        flame.amount = 30
        flame.lifetime = 0.80
        flame.one_shot = false
        flame.explosiveness = 0.0
        flame.direction = Vector3(0, 1, 0)
        flame.spread = 22.0
        flame.initial_velocity_min = 0.8
        flame.initial_velocity_max = 1.7
        flame.gravity = Vector3.ZERO
        flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
        flame.emission_sphere_radius = 0.21
        flame.scale_amount_min = 0.5
        flame.scale_amount_max = 1.35
        flame.position = base + Vector3(0, 1.10, 0)
        add_child(flame)
        flame.emitting = true
    # Distinct center sigil becomes a memorable landmark underneath the combatants.
    var center := CylinderMesh.new()
    center.top_radius = 0.60
    center.bottom_radius = 0.60
    center.height = 0.035
    _mesh(self, center, Vector3(0, 0.075, 0), _mat(Color("222632"), 0.62))
    for spoke in range(6):
        var ang := TAU * float(spoke) / 6.0
        _rift_line(Vector3.ZERO, Vector3(cos(ang) * 0.64, 0, sin(ang) * 0.64), 0.044, Color("9e4b34"))

func _scatter_embers() -> void:
    # Tiny drifting emissive ash sparks provide depth without a heavy particle shader.
    for i in range(12):
        var spark_mesh := QuadMesh.new()
        spark_mesh.size = Vector2(rng.randf_range(0.055, 0.10), rng.randf_range(0.055, 0.10))
        var spark := _mesh(self, spark_mesh, Vector3(rng.randf_range(-5.8, 5.8), 0.2, rng.randf_range(-5.8, 5.8)), _fx_material(Color("f27e34") if i % 3 else Color("ffbf5a"), 0.40))
        var phase := rng.randf_range(0.0, TAU)
        ember_motes.append({"node": spark, "x": spark.position.x, "z": spark.position.z, "phase": phase, "rate": rng.randf_range(0.22, 0.53)})

func _update_ember_motes() -> void:
    for mote in ember_motes:
        var spark: MeshInstance3D = mote["node"]
        if not is_instance_valid(spark):
            continue
        var t: float = chaos_time * float(mote["rate"]) + float(mote["phase"])
        spark.position = Vector3(float(mote["x"]) + sin(t * 1.4) * 0.28, 0.15 + fposmod(t, 3.2), float(mote["z"]) + cos(t * 1.1) * 0.24)

func _create_flash_layer() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 0
    add_child(layer)
    screen_flash = ColorRect.new()
    screen_flash.color = Color("ff713a")
    screen_flash.size = get_viewport().get_visible_rect().size
    screen_flash.modulate.a = 0.0
    screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(screen_flash)

func _create_fx_textures() -> void:
    var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var radial: float = Vector2(float(x) - 31.5, float(y) - 31.5).length() / 31.0
            var falloff: float = pow(maxf(0.0, 1.0 - radial), 2.3)
            img.set_pixel(x, y, Color(1.0, 1.0, 1.0, falloff))
    spark_texture = ImageTexture.create_from_image(img)

func _fx_material(tint: Color, opacity: float = 0.86) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    result.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    result.cull_mode = BaseMaterial3D.CULL_DISABLED
    result.albedo_texture = spark_texture
    result.albedo_color = Color(tint.r, tint.g, tint.b, opacity)
    result.emission_enabled = true
    result.emission = tint
    result.emission_energy_multiplier = 0.96
    return result

func _burst_particles(at: Vector3, tint: Color, count: int = 28, radius: float = 2.8, duration: float = 0.57) -> void:
    if get_tree() == null:
        return
    var sprite := QuadMesh.new()
    sprite.size = Vector2(0.35, 0.35)
    sprite.material = _fx_material(tint, 0.69)
    var parts := CPUParticles3D.new()
    parts.mesh = sprite
    # A restrained cap prevents dozens of overlapping burst emitters from
    # causing a large frame-time spike during chain lightning and boss kills.
    parts.amount = mini(count, 52)
    parts.lifetime = duration
    parts.one_shot = true
    parts.explosiveness = 1.0
    parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    parts.emission_sphere_radius = 0.14
    parts.direction = Vector3(0.0, 0.7, 0.0)
    parts.spread = 180.0
    parts.initial_velocity_min = radius * 0.45
    parts.initial_velocity_max = radius
    parts.gravity = Vector3(0, -1.1, 0)
    parts.scale_amount_min = 0.35
    parts.scale_amount_max = 0.98
    parts.position = at
    add_child(parts)
    parts.emitting = true
    get_tree().create_timer(duration + 0.22).timeout.connect(parts.queue_free)

func _make_dungeon_floor() -> void:
    var ground := PlaneMesh.new()
    ground.size = Vector2(23.5, 23.5)
    pbr_floor = MeshInstance3D.new()
    pbr_floor.mesh = ground
    pbr_floor.position = Vector3(0.0, 0.018, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("7b797a")
    material.roughness = 0.94
    material.metallic = 0.04
    material.uv1_scale = Vector3(6.0, 6.0, 1.0)
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    if ResourceLoader.exists("res://assets/pbr/stone_floor_diff_1k.jpg"):
        material.albedo_texture = load("res://assets/pbr/stone_floor_diff_1k.jpg")
        material.albedo_color = Color("acb4c2")
        material.roughness = 0.87
        if ResourceLoader.exists("res://assets/pbr/stone_floor_nor_gl_1k.jpg"):
            material.normal_enabled = true
            material.normal_scale = 1.30
            material.normal_texture = load("res://assets/pbr/stone_floor_nor_gl_1k.jpg")
        if ResourceLoader.exists("res://assets/pbr/stone_floor_rough_1k.jpg"):
            material.roughness_texture = load("res://assets/pbr/stone_floor_rough_1k.jpg")
    pbr_floor.material_override = material
    add_child(pbr_floor)
    var world_edge := BoxMesh.new()
    world_edge.size = Vector3(23.0, 1.55, 1.8)
    for idx in range(2):
        _mesh(self, world_edge, Vector3(0, 0.13, (-11.7 if idx == 0 else 11.7)), _mat(Color("171a21")))
        var long_edge := _mesh(self, world_edge, Vector3((-11.7 if idx == 0 else 11.7), 0.13, 0), _mat(Color("171a21")))
        long_edge.rotation.y = PI * 0.5

func _place_dungeon_detail() -> void:
    # Broken battlements: realistic PBR stone, not the huge toy-like KayKit columns.
    var slab_mat := (pbr_floor.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
    slab_mat.albedo_color = Color("727b87")
    slab_mat.uv1_scale = Vector3(1.7, 1.7, 1.0)
    for i in range(13):
        var angle: float = PI + float(i) * PI / 12.0
        var pos := Vector3(cos(angle) * 8.5, 0, sin(angle) * 8.5)
        var height: float = 1.4 + float(i % 4) * 0.41
        var capital := CylinderMesh.new()
        capital.top_radius = 0.57
        capital.bottom_radius = 0.70
        capital.height = height
        var broken := _mesh(self, capital, pos + Vector3(0.0, height * 0.5, 0.0), slab_mat)
        broken.rotation.z = 0.12 * sin(float(i) * 4.1)
        for n in range(2):
            var chip := BoxMesh.new()
            chip.size = Vector3(0.80, 0.20, 0.78)
            var fragment := _mesh(self, chip, pos + Vector3(sin(float(i + n) * 3.5), -0.04, cos(float(i + n) * 4.0)) * 0.85, slab_mat)
            fragment.rotation.y = float(i + n) * 0.66
        if i % 4 == 0:
            var lamp := OmniLight3D.new()
            lamp.light_color = Color("ff7742") if i % 2 == 0 else Color("8667e8")
            lamp.light_energy = 0.90
            lamp.omni_range = 4.2
            lamp.position = pos + Vector3(0, 2.2, 0)
            add_child(lamp)
            art_brazier_lights.append(lamp)
    # Thin cracks and ancient broken ritual marks are accents rather than the entire floor.
    for i in range(11):
        var a: float = TAU * float(i) / 11.0
        var start := Vector3(cos(a) * 4.7, 0, sin(a) * 4.7)
        var end := Vector3(cos(a + 0.11) * 5.7, 0, sin(a + 0.11) * 5.7)
        _rift_line(start, end, 0.008, Color("964333"))


func _open_talent_panel() -> void:
    if legendary_overlay.visible or hero_overlay.visible:
        return
    _update_talent_labels()
    popup_shade.visible = true
    skill_overlay.visible = true

func _close_talent_panel() -> void:
    skill_overlay.visible = false
    popup_shade.visible = false
    call_deferred("_offer_evolution")

func _update_talent_labels() -> void:
    if skill_count_label == null:
        return
    skill_count_label.text = "%s  •  POINTS: %d  •  EVO: %d/4" % [CLASSES[hero_class].to_upper(), skill_points, EVO.total_evolutions(_evolution_picks())]
    for i in range(3):
        var button: Button = skill_choice_buttons[i]
        var paths: Array = CLASS_TALENT_NAMES[hero_class]
        button.text = str(paths[i]) + "  •  RANK " + str(int(skills[i])) + "/20\n" + ["+4 ATTACK / RANK", "+24 MAX HP / RANK", "LESS DAMAGE TAKEN"][i]
        button.disabled = skill_points < 1 or int(skills[i]) >= 20
    for i in range(skill_upgrade_buttons.size()):
        var upgrade: Button = skill_upgrade_buttons[i]
        var requirement: int = int(SKILL_UNLOCK_LEVELS[i])
        var rank: int = _skill_rank(i)
        if level < requirement:
            upgrade.text = "LOCKED   %s — UNLOCK AT LVL %d" % [CLASS_SPELLS[hero_class][i], requirement]
        else:
            var ability: String = "  •  +1 CHAIN JUMP EACH RANK" if hero_class == 2 and i == 1 else "  •  +16% DMG / -3.5% COOLDOWN"
            upgrade.text = "%s   RANK %d/%d\n%s" % [CLASS_SPELLS[hero_class][i], rank, SKILL_MAX_RANK, ability]
        upgrade.disabled = level < requirement or skill_points < 1 or rank >= SKILL_MAX_RANK

func _invest_talent(index: int) -> void:
    if skill_points < 1 or index < 0 or index >= 3:
        return
    if int(skills[index]) >= 20:
        return
    skills[index] = int(skills[index]) + 1
    class_talents[str(hero_class)] = skills.duplicate()
    skill_points -= 1
    hp = minf(_max_hp(), hp + 24.0)
    combat_note = str(CLASS_TALENT_NAMES[hero_class][index]) + " INCREASED"
    _update_talent_labels()
    _save_game()
    _refresh()

func _update_item_preview(item: Dictionary) -> void:
    if legendary_item_display == null:
        return
    for child in legendary_item_display.get_children():
        child.queue_free()
    legendary_item_display.rotation = Vector3.ZERO
    # Actual 3D equipment art instead of a distant low-detail imported placeholder.
    var preview_root := Node3D.new()
    legendary_item_display.add_child(preview_root)
    preview_root.rotation.z = -0.11
    preview_root.rotation.y = 0.28
    var slot: String = str(item.get("slot", "Weapon"))
    var name: String = str(item.get("name", "")).to_lower()
    var element: String = str(item.get("element", "FIRE")).to_upper()
    var gem_color := Color("ff873d")
    if element == "VOID":
        gem_color = Color("aa73f0")
    elif element == "FROST":
        gem_color = Color("73e1f5")
    elif element == "LIGHTNING":
        gem_color = Color("ffe388")
    # Floating circular etched seal frames every legendary item.
    var seal := TorusMesh.new()
    seal.inner_radius = 1.17
    seal.outer_radius = 1.185
    var halo := _mesh(preview_root, seal, Vector3(0, 0.16, -0.55), _mat(gem_color.darkened(0.73), 0.0, true))
    halo.rotation.x = PI / 2.0
    var seal_inner := TorusMesh.new()
    seal_inner.inner_radius = 0.91
    seal_inner.outer_radius = 0.921
    var halo_inner := _mesh(preview_root, seal_inner, Vector3(0, 0.16, -0.57), _mat(Color("63513f"), 0.65))
    halo_inner.rotation.x = PI / 2.0
    if slot == "Ring":
        var ring := TorusMesh.new()
        ring.inner_radius = 0.48
        ring.outer_radius = 0.69
        var ring_mesh := _mesh(preview_root, ring, Vector3(0, 0.12, 0), _mat(Color("d4a34c"), 0.8))
        ring_mesh.rotation.x = PI / 2.0
        _sphere_part(preview_root, 0.29, Vector3(0, 0.77, 0.12), gem_color).material_override = _bright(gem_color)
        for i in range(5):
            var a := PI * float(i) / 4.0
            _sphere_part(preview_root, 0.055, Vector3(cos(a) * 0.63, sin(a) * 0.63 + 0.12, 0.18), Color("eec67c"))
    elif slot == "Helm":
        _cone(preview_root, 0.62, 0.48, 0.85, Vector3(0, 0.10, 0), Color("3d4758"))
        _cone(preview_root, 0.54, 0.04, 0.82, Vector3(0, 0.82, 0), Color("adb8c8"))
        _box(preview_root, Vector3(1.33, 0.15, 0.43), Vector3(0, -0.19, 0.20), Color("bd8c4d"))
        _box(preview_root, Vector3(0.85, 0.14, 0.16), Vector3(0, 0.19, 0.43), Color("151826"))
        _sphere_part(preview_root, 0.20, Vector3(0, 0.51, 0.42), gem_color).material_override = _bright(gem_color)
        for side in [-1, 1]:
            var horn := _cone(preview_root, 0.17, 0.01, 0.76, Vector3(float(side) * 0.46, 0.87, 0), Color("ddcbb2"))
            horn.rotation.z = float(side) * 0.29
    elif slot == "Armor":
        _cone(preview_root, 0.82, 0.56, 1.65, Vector3(0, 0, 0), Color("435265"))
        _box(preview_root, Vector3(0.88, 1.12, 0.19), Vector3(0, 0.15, 0.50), Color("7c8794"))
        _box(preview_root, Vector3(0.70, 0.10, 0.22), Vector3(0, -0.49, 0.54), Color("c89e5d"))
        for side in [-1, 1]:
            var shoulder := _sphere_part(preview_root, 0.40, Vector3(float(side) * 0.77, 0.63, 0.0), Color("354150"))
            shoulder.scale = Vector3(1.35, 0.78, 1.0)
            var rivet := _sphere_part(preview_root, 0.075, Vector3(float(side) * 0.80, 0.72, 0.38), Color("e0ae6d"))
        var breast_gem := _sphere_part(preview_root, 0.22, Vector3(0, 0.29, 0.66), gem_color)
        breast_gem.material_override = _bright(gem_color)
    elif name.contains("staff") or name.contains("scepter"):
        var wood := _cone(preview_root, 0.08, 0.11, 2.35, Vector3(0, 0.05, 0), Color("563b34"))
        var shaft := _box(preview_root, Vector3(0.16, 0.16, 0.16), Vector3(0, -0.72, 0), Color("d4a557"))
        var mount := _cone(preview_root, 0.35, 0.09, 0.61, Vector3(0, 1.04, 0), Color("c2a272"))
        var crystal := _sphere_part(preview_root, 0.36, Vector3(0, 1.40, 0), gem_color)
        crystal.scale = Vector3(0.75, 1.48, 0.72)
        crystal.material_override = _bright(gem_color)
        for side in [-1, 1]:
            var spur := _cone(preview_root, 0.08, 0.015, 0.66, Vector3(float(side) * 0.27, 0.96, 0), Color("c99b57"))
            spur.rotation.z = float(side) * 0.65
    else:
        # Detailed greatsword: broad two-tone blade, gold crossguard, glowing runic core.
        var grip := _cone(preview_root, 0.10, 0.11, 0.77, Vector3(0, -0.77, 0), Color("594039"))
        _sphere_part(preview_root, 0.15, Vector3(0, -1.19, 0), Color("d1a15e"))
        _box(preview_root, Vector3(1.11, 0.15, 0.23), Vector3(0, -0.33, 0), Color("c7a05b"))
        for side in [-1, 1]:
            var quillon := _cone(preview_root, 0.11, 0.02, 0.47, Vector3(float(side) * 0.60, -0.21, 0), Color("d2ac6c"))
            quillon.rotation.z = float(side) * -1.15
        var blade_mesh := BoxMesh.new()
        blade_mesh.size = Vector3(0.42, 1.54, 0.12)
        _mesh(preview_root, blade_mesh, Vector3(0, 0.50, 0), _mat(Color("9ba9bc"), 0.8))
        _box(preview_root, Vector3(0.13, 1.39, 0.16), Vector3(0, 0.47, 0.02), Color("dae5ed"))
        _cone(preview_root, 0.275, 0.005, 0.72, Vector3(0, 1.56, 0), Color("d1ddeb"))
        _box(preview_root, Vector3(0.065, 1.11, 0.03), Vector3(0, 0.45, 0.11), gem_color, true)
        var gem := _sphere_part(preview_root, 0.15, Vector3(0, -0.31, 0.19), gem_color)
        gem.material_override = _bright(gem_color)
