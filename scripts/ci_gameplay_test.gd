extends SceneTree
# Fast integration coverage for wave combat, stage progression, loot and modal UI.
func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
    if not ok:
        push_error("GAMEPLAY TEST FAIL: " + message)
        return false
    return true

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        quit(10)
        return
    var game: Node = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame

    game.set("stage", 1)
    game.set("highest", 1)
    game.set("grind_mode", false)
    game.call("_spawn_enemy")
    var enemies: Array = game.get("arena_mobs")
    if not _check(enemies.size() >= 5, "Initial wave should contain several real enemies"):
        quit(11)
        return
    var first: Node3D = enemies[0]
    var old_health: float = float(first.get_meta("hp"))
    game.call("_hit_mob", first, 1.0, false)
    if not _check(float(first.get_meta("hp")) < old_health, "Damage must lower target's own HP"):
        quit(12)
        return
    for enemy in (game.get("arena_mobs") as Array).duplicate():
        game.call("_hit_mob", enemy, 999999.0, false)
    if not _check((game.get("arena_mobs") as Array).is_empty(), "Individual kills should empty a wave"):
        quit(13)
        return
    var prior: int = int(game.get("stage"))
    game.call("_complete_wave")
    if not _check(int(game.get("stage")) == prior + 1, "Wave completion advances stage"):
        quit(14)
        return

    game.call("_try_boss")
    if not _check(int(game.get("stage")) % 5 == 0, "Boss encounter must be a fifth stage"):
        quit(15)
        return
    var has_boss := false
    for mob in (game.get("arena_mobs") as Array):
        if bool(mob.get_meta("boss", false)):
            has_boss = true
    if not _check(has_boss, "Boss wave must spawn an actual boss mob"):
        quit(16)
        return

    game.call("_drop_loot")
    var items: Array = game.get("gear")
    if not _check(not items.is_empty(), "Loot should enter inventory"):
        quit(17)
        return
    game.call("_equip", 0)
    if not _check(not (game.get("equipped") as Dictionary).is_empty(), "Equip must change equipment state"):
        quit(18)
        return
    # Verify idle automation does not downgrade a stronger ring.
    var strong_ring := {
        "slot": "Ring", "name": "CI Hero Ring", "damage": 500,
        "hp": 400, "crit": 30, "speed": 20,
        "elemental": 60, "element": "FIRE", "set": "", "rarity": "LEGENDARY"
    }
    if not _check(bool(game.call("_auto_equip_item", strong_ring)), "Auto-equip should improve an empty slot"):
        quit(22)
        return
    var weak_ring := strong_ring.duplicate(true)
    weak_ring["damage"] = 1
    if not _check(not bool(game.call("_auto_equip_item", weak_ring)), "Auto-equip must never downgrade a superior ring"):
        quit(23)
        return
    game.set("gold", 90000)
    var before_gold: int = int(game.get("gold"))
    game.call("_forge_weakest")
    if not _check(int(game.get("gold")) < before_gold, "Forging should spend gold"):
        quit(24)
        return
    game.set("stage", 10)
    game.call("_spawn_enemy")
    if not _check(int(game.call("_boss_variant")) == 1 and float(game.get("boss_health")) > 0.0, "Second boss must have own HP and identity"):
        quit(25)
        return
    # Verify the three collectible sets really give different 2-piece effects.
    var equipped_for_set: Dictionary = game.get("equipped")
    equipped_for_set["Weapon"] = {"slot": "Weapon", "name": "Set Sword", "set": "Cinderborn", "damage": 1}
    equipped_for_set["Armor"] = {"slot": "Armor", "name": "Set Armor", "set": "Cinderborn", "damage": 1}
    if not _check(float(game.call("_bonus", "damage")) >= 18.0, "Cinderborn two-piece should increase damage"):
        quit(26)
        return
    equipped_for_set["Weapon"]["set"] = "Gravewarden"
    equipped_for_set["Armor"]["set"] = "Gravewarden"
    if not _check(float(game.call("_bonus", "hp")) >= 55.0, "Gravewarden two-piece should increase vitality"):
        quit(27)
        return
    equipped_for_set["Weapon"]["set"] = "Ashen Crown"
    equipped_for_set["Armor"]["set"] = "Ashen Crown"
    if not _check(float(game.call("_bonus", "crit")) >= 10.0, "Ashen Crown two-piece should add critical chance"):
        quit(28)
        return
    # A hero pursues living targets instead of striking a static decorative model.
    game.set("stage", 6)
    game.call("_spawn_enemy")
    var moving_hero: Node3D = game.get("hero")
    var origin: Vector3 = moving_hero.position
    game.call("_move_hero", 0.4)
    if not _check(moving_hero.position.distance_to(origin) > 0.01, "Hero should visibly seek enemies"):
        quit(29)
        return
    # Bosses telegraph a real charged attack.
    game.set("stage", 10)
    game.call("_spawn_enemy")
    game.call("_update_boss_cast", 5.0)
    if not _check(float(game.get("boss_cast_windup")) > 0.0, "Boss cast must warn before impact"):
        quit(30)
        return
    game.call("_update_boss_cast", 1.5)
    if not _check(float(game.get("boss_cast_windup")) <= 0.0, "Boss cast should resolve"):
        quit(31)
        return
    # Classes have independent talent allocations that survive class changes.
    game.call("_select_class", 2)
    game.set("skill_points", 2)
    game.call("_invest_talent", 0)
    var mage_rank: int = int((game.get("skills") as Array)[0])
    game.call("_select_class", 0)
    game.call("_select_class", 2)
    if not _check(int((game.get("skills") as Array)[0]) == mage_rank, "Changing heroes must preserve invested class talents"):
        quit(32)
        return
    game.call("_show_hero_panel")
    if not _check(game.get("hero_overlay").visible, "HERO must open class selector"):
        quit(33)
        return
    game.call("_close_hero_panel")
    game.call("_hide_legendary")
    game.call("_show_inventory")
    if not _check(game.get("inventory_overlay").visible, "LOOT opens full inventory"):
        quit(19)
        return
    game.call("_close_inventory_panel")
    game.call("_open_talent_panel")
    if not _check(game.get("skill_overlay").visible, "Talent tree can open"):
        quit(20)
        return
    game.call("_close_talent_panel")
    game.call("_use_skill", 0)
    var cds: Array = game.get("skill_cooldowns")
    if not _check(float(cds[0]) > 0.0, "Using spell activates cooldown"):
        quit(21)
        return
    print("GAMEPLAY TEST PASS: combat pursuit, telegraphed boss attacks, independent class talents, hero selector, enemy HP, waves, multiple bosses, unique 2-piece set bonuses, loot, smart auto-equip, forge, inventory, talent menu, spell cooldown")
    quit(0)
