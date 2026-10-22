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

func _ready() -> void:
    rng.randomize()
    _load_game()
    _build_world()
    _build_ui()
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
    var root = Node3D.new()
    root.position = at
    add_child(root)
    var boots = Color("22232e")
    _box(root, Vector3(0.31, 0.72, 0.4), Vector3(-0.24, 0.42, 0), boots)
    _box(root, Vector3(0.31, 0.72, 0.4), Vector3(0.24, 0.42, 0), boots)
    var chest = CapsuleMesh.new()
    chest.radius = 0.43
    chest.height = 1.35
    var body = _mesh(root, chest, Vector3(0, 1.38, 0), _mat(color, 0.48))
    if enemy:
        foe_body = body
    var head = SphereMesh.new()
    head.radius = 0.32
    _mesh(root, head, Vector3(0, 2.34, 0), _mat(Color("9c8580") if enemy else Color("dab79b")))
    _box(root, Vector3(0.93, 0.24, 0.42), Vector3(0, 1.92, 0), Color("37343e"))
    _box(root, Vector3(0.20, 1.05, 0.25), Vector3(-0.60, 1.39, 0), color)
    _box(root, Vector3(0.20, 1.05, 0.25), Vector3(0.60, 1.39, 0), color)
    if enemy:
        var horns = Color("30262a")
        _box(root, Vector3(0.19, 0.61, 0.18), Vector3(-0.26, 2.79, 0), horns)
        _box(root, Vector3(0.19, 0.61, 0.18), Vector3(0.26, 2.79, 0), horns)
        _box(root, Vector3(0.13, 0.12, 0.07), Vector3(-0.17, 2.39, 0.30), Color("ff592f"), true)
        _box(root, Vector3(0.13, 0.12, 0.07), Vector3(0.17, 2.39, 0.30), Color("ff592f"), true)
    else:
        _box(root, Vector3(0.15, 1.55, 0.16), Vector3(0.88, 1.61, 0), Color("a9a9af"), true)
        _box(root, Vector3(0.49, 0.17, 0.20), Vector3(0.88, 1.17, 0), Color("c88d4b"))
        _box(root, Vector3(0.8, 1.22, 0.12), Vector3(0, 1.45, -0.33), Color("762d39"))
    return root

func _build_world() -> void:
    var world = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("100f18")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("6e6575")
    environment.ambient_light_energy = 0.58
    world.environment = environment
    add_child(world)
    var camera = Camera3D.new()
    add_child(camera)
    camera.position = Vector3(8.4, 11.2, 15.5)
    camera.look_at(Vector3(0, 0.75, 0), Vector3.UP)
    camera.fov = 33.0
    camera.current = true
    var sun = DirectionalLight3D.new()
    add_child(sun)
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.light_color = Color("e5c5a7")
    sun.light_energy = 1.3
    _box(self, Vector3(12, 0.5, 11), Vector3(0, -0.32, 0), Color("292631"))
    for i in range(11):
        var x = float(i % 4) * 2.8 - 4.2
        var z = float(i / 4) * 3.3 - 3.3
        if absf(x) < 2.5 and absf(z) < 2.3:
            continue
        _box(self, Vector3(1.0, 0.27, 1.0), Vector3(x, -0.05, z), Color("39313c"))
    for i in range(8):
        var a = TAU * float(i) / 8.0
        var x = cos(a) * 4.7
        var z = sin(a) * 3.95
        _box(self, Vector3(0.72, 1.7 + float(i % 3) * 0.4, 0.72), Vector3(x, 0.65, z), Color("443d49"))
        _box(self, Vector3(0.43, 0.25, 0.43), Vector3(x, 1.7 + float(i % 3) * 0.4, z), Color("dd6029"), true)
    hero = _fighter(Vector3(-1.65, 0, 0.5), Color("4f777e"), false)
    foe = _fighter(Vector3(1.60, 0, -0.6), Color("863f4d"), true)
    var ember = OmniLight3D.new()
    add_child(ember)
    ember.position = Vector3(0, 2.7, 0)
    ember.light_color = Color("fd713b")
    ember.light_energy = 1.8
    ember.omni_range = 9

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
    var layer = CanvasLayer.new()
    add_child(layer)
    var root = Control.new()
    layer.add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    var top = PanelContainer.new()
    root.add_child(top)
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_bottom = 194
    top.add_theme_stylebox_override("panel", _panel_color())
    var header = VBoxContainer.new()
    top.add_child(header)
    header.add_child(_label("ASHEN IDLE", 33, Color("ffc78f")))
    header.add_child(_label("THE CINDER RECKONING", 16, Color("c7aa8e")))
    status = _label("", 23)
    header.add_child(status)
    details = _label("", 18)
    header.add_child(details)
    offline = _label("", 16, Color("e4b96d"))
    header.add_child(offline)
    var bottom = PanelContainer.new()
    root.add_child(bottom)
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_top = -492
    bottom.add_theme_stylebox_override("panel", _panel_color())
    var scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    bottom.add_child(scroll)
    var content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    combat = _label("", 22, Color("f1be89"))
    content.add_child(combat)
    content.add_child(_label("AUTO-BATTLE  •  LOOT  •  OFFLINE", 16, Color("aeb0bc")))
    actions = HBoxContainer.new()
    content.add_child(actions)
    actions.add_child(_button("BOSS", _try_boss))
    actions.add_child(_button("GRINDA", _grind))
    actions.add_child(_button("FRAMÅT", _forward))
    var upgrades = HBoxContainer.new()
    content.add_child(upgrades)
    upgrades.add_child(_button("KLASS", _switch_class))
    upgrades.add_child(_button("SKILL +", _upgrade_skill))
    upgrades.add_child(_button("LÄK", _heal))
    info = _label("", 17)
    content.add_child(info)
    content.add_child(_label("LOOT – TRYCK FÖR ATT UTRUSTA", 19, Color("f5bf88")))
    inventory = VBoxContainer.new()
    content.add_child(inventory)

func _max_hp() -> float:
    var modifier = [1.2, 0.9, 0.85, 1.0][hero_class]
    return (100.0 + float(level) * 12.0 + float(skills[1]) * 24.0 + _bonus("hp")) * modifier

func _damage() -> float:
    var modifier = [1.0, 1.15, 1.32, 1.10][hero_class]
    return (8.0 + float(level) * 2.5 + float(skills[0]) * 4.0 + _bonus("damage")) * modifier

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
    for count in counts.values():
        if int(count) >= 2:
            total += 12.0 if key == "damage" else 25.0
        if int(count) >= 4:
            total += 28.0 if key == "damage" else 50.0
    return total

func _spawn_enemy() -> void:
    enemy_max = 30.0 + float(stage) * 17.0 + (65.0 + float(stage) * 7.0 if stage % 5 == 0 else 0.0)
    enemy_hp = enemy_max

func _process(delta: float) -> void:
    tick += delta
    save_timer += delta
    if hero != null:
        hero.rotation.y = sin(float(Time.get_ticks_msec()) / 370.0) * 0.08
    if foe != null:
        foe.rotation.y = sin(float(Time.get_ticks_msec()) / 580.0) * 0.1
    if foe_body != null:
        foe_body.scale = Vector3.ONE * (1.0 + attack_flash * 0.13)
    attack_flash = maxf(0.0, attack_flash - delta * 4.0)
    if tick >= 1.0:
        tick -= 1.0
        _fight()
    if save_timer >= 15.0:
        save_timer = 0.0
        _save_game()

func _fight() -> void:
    var damage = _damage() * rng.randf_range(0.85, 1.15)
    enemy_hp -= damage
    attack_flash = 1.0
    combat_note = "SLAG  -%.0f" % damage
    if enemy_hp <= 0.0:
        var boss_won = stage % 5 == 0
        kills += 1
        gold += 3 + stage * 2
        xp += 8 + stage * 3
        if rng.randf() < 0.35 or boss_won:
            _drop_loot()
        while xp >= level * 30:
            xp -= level * 30
            level += 1
            skill_points += 1
            hp = _max_hp()
        highest = maxi(highest, stage + 1)
        stage = highest
        combat_note = "BOSS FÄLLD!" if boss_won else "SEGER! NYTT OMRÅDE"
        _spawn_enemy()
        _save_game()
    else:
        var incoming = maxf(1.0, float(stage) * 0.85 - float(skills[2]) * 1.2)
        if stage % 5 == 0:
            incoming *= 1.7
        hp -= incoming
        if hp <= 0.0:
            hp = _max_hp()
            stage = maxi(1, stage - 1)
            combat_note = "FÖRLUST – GRINDAR FÖR ATT BLI STARKARE"
            _spawn_enemy()
    _refresh()

func _try_boss() -> void:
    stage = maxi(5, int(ceil(float(highest) / 5.0)) * 5)
    hp = _max_hp()
    combat_note = "BOSSEN HAR VÄCKTS"
    _spawn_enemy()
    _refresh()

func _grind() -> void:
    stage = maxi(1, highest - 1)
    hp = _max_hp()
    combat_note = "GRINDAR UTRUSTNING OCH XP"
    _spawn_enemy()
    _refresh()

func _forward() -> void:
    stage = highest
    hp = _max_hp()
    combat_note = "FRAMÅT MOT ASKANS HJÄRTA"
    _spawn_enemy()
    _refresh()

func _switch_class() -> void:
    hero_class = (hero_class + 1) % 4
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
    var slot: String = SLOTS[rng.randi_range(0, SLOTS.size() - 1)]
    var prefixes = ["Smoldering", "Forsaken", "Infernal", "Ancient", "Hollow", "Ruinous"]
    var item = {
        "slot": slot,
        "name": prefixes[rng.randi_range(0, prefixes.size() - 1)] + " " + slot,
        "damage": rng.randi_range(1, 5) + stage,
        "hp": rng.randi_range(4, 13) + stage * 2,
        "set": ""
    }
    if rng.randf() < 0.35:
        item["set"] = SETS[rng.randi_range(0, SETS.size() - 1)]
    gear.push_front(item)
    if gear.size() > 36:
        gear.pop_back()

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
    status.text = "%s   •   NIVÅ %d" % [CLASSES[hero_class], level]
    details.text = "HP %.0f/%.0f  •  XP %d/%d  •  GULD %d\nSKILLPOÄNG %d  •  KILLS %d" % [hp, _max_hp(), xp, level * 30, gold, skill_points, kills]
    offline.text = offline_note
    combat.text = "OMRÅDE %d%s\nFIENDE %.0f/%.0f  •  SKADA %.0f\n%s" % [stage, "  •  BOSS" if stage % 5 == 0 else "", maxf(0.0, enemy_hp), enemy_max, _damage(), combat_note]
    info.text = "Högsta område: %d\nTalanger: Eldkraft %d  |  Vitalitet %d  |  Skydd %d\nSET: 2 delar +12 ATK / +25 HP, 4 delar +28 ATK / +50 HP" % [highest, int(skills[0]), int(skills[1]), int(skills[2])]
    for child in inventory.get_children():
        inventory.remove_child(child)
        child.queue_free()
    if gear.is_empty():
        inventory.add_child(_label("Inga föremål ännu – besegra fiender för loot.", 17))
    else:
        for i in range(mini(gear.size(), 9)):
            var item: Dictionary = gear[i]
            var set_label = "  [SET: %s]" % str(item.get("set", "")) if str(item.get("set", "")) != "" else ""
            var text_value = "%s%s   +%d ATK  +%d HP" % [str(item.get("name", "Item")), set_label, int(item.get("damage", 0)), int(item.get("hp", 0))]
            inventory.add_child(_button(text_value, _equip.bind(i)))

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
