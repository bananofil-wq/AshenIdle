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

    if not _check((game.get("hero_overlay") as Control).visible and bool(game.get("startup_selection")), "Character select must appear on every launch"):
        quit(44)
        return
    if not _check((game.get("popup_shade") as Control).visible and not (game.get("hero_return_button") as Button).visible, "Initial character selection must pause combat until chosen"):
        quit(45)
        return
    var selection: Control = game.get("hero_overlay")
    var named_classes := 0
    for button in selection.find_children("*", "Button", true, false):
        if str(button.text).contains("REGEN") and str(button.text).contains("MP"):
            named_classes += 1
    if not _check(named_classes == 4, "All four hero choices need visible MP/DEF/regen and spell descriptions"):
        quit(46)
        return
    game.call("_select_class", 0)
    if not _check(not (game.get("popup_shade") as Control).visible, "Choosing a hero starts gameplay"):
        quit(47)
        return
    for class_id in range(4):
        game.call("_select_class", class_id)
        if not _check(game.call("_max_mp") >= 65.0, "Each hero needs a real class-specific MP pool"):
            quit(48)
            return
        if not _check(game.call("_defense_reduction") > 0.0, "Each class needs defensive specialization"):
            quit(49)
            return
    game.call("_select_class", 0)
    if not _check(game.call("_defense_reduction") > 0.20, "Knight should have high innate defense"):
        quit(50)
        return
    game.call("_select_class", 2)
    if not _check(game.call("_max_mp") > 2.0 * float(game.get("level")), "Mage should have a large magic resource pool"):
        quit(51)
        return
    game.call("_select_class", 0)

    # Art QA is functional QA: ship genuine armored GLBs, not toy-model fallbacks.
    for character in ["ashen_armored_knight", "ashen_shadow_knight", "ashen_ranger", "ashen_mage", "ashen_shared_anims", "skeleton_dark"]:
        if not _check(game.call("_get_asset_scene", character) != null, "Required CC0 3D art missing: " + character):
            quit(34)
            return
    if not _check(ResourceLoader.exists("res://assets/pbr/stone_floor_diff_1k.jpg"), "Photographic stone texture must ship with Android"):
        quit(35)
        return
    var attached_animations := false
    var hero_node: Node3D = game.get("hero")
    for found in hero_node.find_children("*", "AnimationPlayer", true, false):
        var anim_player: AnimationPlayer = found as AnimationPlayer
        if anim_player != null:
            print("HERO ANIMATION PLAYER ", anim_player.name, " CLIPS ", anim_player.get_animation_list())
            if anim_player.get_animation_list().size() >= 3:
                attached_animations = true
    if not _check(attached_animations, "Armored hero must have several working animation clips"):
        quit(36)
        return

    # Verify dynamic animation and camera instead of testing only that clips exist.
    var actor: Node3D = game.get("hero")
    var player: AnimationPlayer = actor.get_meta("animation_driver", null) as AnimationPlayer
    if not _check(player != null, "Hero animation driver should be bound"):
        quit(38)
        return
    game.call("_animate_actor", actor, 3.0)
    if not _check(str(actor.get_meta("clip_state", "")).contains("Jog"), "Movement should select run clip"):
        quit(39)
        return
    var skeleton: Skeleton3D
    for part in actor.find_children("*", "Skeleton3D", true, false):
        skeleton = part as Skeleton3D
        break
    if not _check(skeleton != null, "Hero must have skeleton for motion"):
        quit(40)
        return
    player.advance(0.21)
    var first_pose: Array[Quaternion] = []
    for bone_id in range(skeleton.get_bone_count()):
        first_pose.append(skeleton.get_bone_pose_rotation(bone_id))
    player.advance(0.25)
    var moving_bones := false
    for bone_id in range(skeleton.get_bone_count()):
        if first_pose[bone_id].angle_to(skeleton.get_bone_pose_rotation(bone_id)) > 0.004:
            moving_bones = true
            break
    if not _check(moving_bones, "Skeletal animation should articulate the character"):
        quit(41)
        return
    game.call("_actor_attack", actor, false)
    if not _check(str(actor.get_meta("clip_state", "")).contains("Sword"), "Sword attacks should animate"):
        quit(42)
        return
    var camera: Camera3D = game.get("camera_ref")
    var camera_start: Vector3 = camera.global_position
    actor.position += Vector3(2.0, 0.0, -1.0)
    game.call("_update_camera", 0.4)
    if not _check(camera.global_position.distance_to(camera_start) > 0.09, "Camera should follow motion"):
        quit(43)
        return
    print("MOTION QA PASS: running pose, attack state and camera following")

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
    if not _check(int(game.get("stage")) == 2, "Boss shortcut must not skip the first nine floors"):
        quit(52)
        return
    game.set("highest", 10)
    game.call("_try_boss")
    if not _check(int(game.get("stage")) == 10, "First boss must unlock on floor 10"):
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
    game.set("auto_equip", true)
    game.call("_hide_legendary")
    game.call("_drop_loot_at", Vector3.ZERO, true)
    if not _check(not game.get("popup_shade").visible, "Legendary auto drops must not freeze unattended idle combat"):
        quit(37)
        return
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
    game.set("stage", 20)
    game.call("_spawn_enemy")
    if not _check(int(game.call("_boss_variant")) == 1 and float(game.get("boss_health")) > 0.0, "Second boss must be on floor 20 with distinct identity"):
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
    moving_hero.position = Vector3(0, 0, 6.5)
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
    game.set("skill_cooldowns", [0.0, 0.0, 0.0])
    game.set("mp", 0.0)
    game.call("_use_skill", 0)
    if not _check(float((game.get("skill_cooldowns") as Array)[0]) == 0.0, "Skills cannot cast without enough MP"):
        quit(53)
        return
    game.set("mp", game.call("_max_mp"))
    var mana_before: float = float(game.get("mp"))
    game.call("_use_skill", 0)
    if not _check(float(game.get("mp")) < mana_before, "Casting must consume class-specific MP"):
        quit(54)
        return
    var cds: Array = game.get("skill_cooldowns")
    if not _check(float(cds[0]) > 0.0, "Using spell activates cooldown"):
        quit(21)
        return
    print("GAMEPLAY TEST PASS: first-launch hero selection, class mana and defense, MP spell casting, 10-floor bosses, walking animation, boss mechanics, progression, loot, talents and equipment")
    quit(0)
