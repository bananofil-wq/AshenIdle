extends SceneTree
# Fast integration coverage for wave combat, stage progression, loot and modal UI.
func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
    if not ok:
        push_error("GAMEPLAY TEST FAIL: " + message)
        return false
    return true

# Only the test harness can emulate a process restart without rebuilding the
# whole heavy 3D scene. Players cannot access these state flags in the game UI.
func _choose_after_simulated_restart(game: Node, class_id: int) -> void:
    game.set("class_selection_locked", false)
    game.set("startup_selection", true)
    game.call("_select_class", class_id)
    game.set("startup_selection", false)

func _complete_synthetic_room(game: Node) -> void:
    # Unit tests advance rooms without killing the newly spawned wave.
    # A random loot-convoy bonus would produce an unreachable pickup and
    # occasionally block the next stage, making this test flaky. Natural loot
    # and mandatory pickup are explicitly tested by the adjacent assertions.
    game.call("_clear_ground_drops")
    var encounter: Dictionary = game.get("current_encounter")
    encounter["loot_bonus"] = false
    game.set("current_encounter", encounter)
    game.call("_complete_wave")


func _run() -> void:
    # CI must not inherit a prior run's chosen evolution paths, offline levels
    # or class lock. The smoke/render checks use their own fresh sessions too.
    var save_path: String = ProjectSettings.globalize_path("user://save_v2.json")
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
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
        _choose_after_simulated_restart(game, class_id)
        if not _check(game.call("_max_mp") >= 65.0, "Each hero needs a real class-specific MP pool"):
            quit(48)
            return
        if not _check(game.call("_defense_reduction") > 0.0, "Each class needs defensive specialization"):
            quit(49)
            return
    _choose_after_simulated_restart(game, 0)
    if not _check(game.call("_defense_reduction") > 0.20, "Knight should have high innate defense"):
        quit(50)
        return
    _choose_after_simulated_restart(game, 2)
    if not _check(game.call("_max_mp") > 2.0 * float(game.get("level")), "Mage should have a large magic resource pool"):
        quit(51)
        return
    _choose_after_simulated_restart(game, 0)

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
    # Regression: an actor's +Z axis must always point into real movement.
    # The previous fixes added PI to BOTH the hero root and its GLB model, and
    # another PI to enemies, so meshes visibly ran with their backs forward.
    var hero_visual: Node3D = actor.get_child(0) as Node3D
    if not _check(hero_visual != null and absf(hero_visual.rotation.y) < 0.01, "No double 180-degree yaw on animated hero mesh"):
        quit(104)
        return
    for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
        game.call("_turn_actor_towards", actor, direction, 1.0, 12.0)
        var facing_direction: Vector3 = actor.global_transform.basis.z.normalized()
        if not _check(facing_direction.dot(direction) > 0.99, "Running actor must face its travel vector in all four directions"):
            quit(105)
            return
    if not _check(hero_visual.position.distance_to(actor.get_meta("visual_rest_position", Vector3.INF)) < 0.02, "Jogging must preserve the fitted visual's ground position"):
        quit(106)
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
    # A class cannot be changed by buttons or the old switch shortcut until a restart.
    var locked_class: int = int(game.get("hero_class"))
    var route_position: Vector3 = actor.position
    game.call("_select_class", 1)
    game.call("_switch_class")
    game.call("_show_hero_panel", true)
    if not _check(int(game.get("hero_class")) == locked_class and bool(game.get("class_selection_locked")) and not bool(game.get("startup_selection")), "Classes must be locked for the entire session"):
        quit(86)
        return
    var disabled_choices := 0
    for item in (game.get("hero_choice_buttons") as Array):
        if (item as Button).disabled:
            disabled_choices += 1
    if not _check(disabled_choices == 4, "All class selection buttons must be disabled after starting"):
        quit(87)
        return
    game.call("_close_hero_panel")
    if not _check((game.get("hero") as Node3D).position.distance_to(route_position) < 0.01, "Blocked class switch must not teleport the exploring hero"):
        quit(88)
        return
    print("MOTION QA PASS: animation, tracking camera and locked class selection")

    game.set("stage", 1)
    game.set("highest", 1)
    game.set("grind_mode", false)
    game.call("_spawn_enemy")
    var enemies: Array = game.get("arena_mobs")
    if not _check(enemies.size() >= 5, "Initial wave should contain several real enemies"):
        quit(11)
        return
    for enemy in enemies:
        var actor_enemy: Node3D = enemy as Node3D
        if actor_enemy == null or not is_instance_valid(actor_enemy):
            continue
        var to_hero: Vector3 = (game.get("hero") as Node3D).position - actor_enemy.position
        to_hero.y = 0.0
        if to_hero.length_squared() > 0.02:
            if not _check(actor_enemy.global_transform.basis.z.normalized().dot(to_hero.normalized()) > 0.985,
                "Enemies must spawn facing their approaching hero, never backwards"):
                quit(107)
                return
    print("DIRECTION QA PASS: hero jog +Z forward, no visual double yaw, enemy initial facing and ground-height preserved")
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
    # Stage advance must wait until the hero physically collects surviving
    # ground drops (if the cleared horde spawned one).
    var waiting_loot: Array = game.get("ground_drops")
    if not waiting_loot.is_empty():
        game.call("_complete_wave")
        if not _check(int(game.get("dungeon_room_index")) == 1, "Room cannot skip uncollected loot"):
            quit(111)
            return
        game.call("_clear_ground_drops")
    _complete_synthetic_room(game)
    if not _check(int(game.get("stage")) == prior and int(game.get("dungeon_room_index")) == 2, "First encounter opens the second dungeon room"):
        quit(14)
        return
    # The synthetic test deliberately skips each battle and therefore has no
    # hero walk-to-loot interval. Clear bonus rewards between forced room
    # advances; normal gameplay still refuses to skip an uncollected item.
    for target_room in [3]:
        for attempt in range(3):
            game.call("_clear_ground_drops")
            _complete_synthetic_room(game)
            if int(game.get("dungeon_room_index")) == target_room:
                break
    if not _check(int(game.get("dungeon_room_index")) == 3, "Second encounter opens third room"):
        quit(55)
        return
    game.call("_clear_ground_drops")
    _complete_synthetic_room(game)
    if not _check(int(game.get("stage")) == prior + 1, "Finishing all three rooms advances to next floor"):
        quit(56)
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
    # Synthetic QA skips combat, so explicitly clear any bonus treasure the
    # director spawns on the way. Real play NEVER skips an uncollected drop.
    for target_room in [2, 3]:
        for attempt in range(3):
            game.call("_clear_ground_drops")
            _complete_synthetic_room(game)
            if int(game.get("dungeon_room_index")) == target_room:
                break
    if not _check(int(game.get("dungeon_room_index")) == 3, "Boss must guard final room after two regular encounters"):
        quit(57)
        return
    var has_boss := false
    for mob in (game.get("arena_mobs") as Array):
        if bool(mob.get_meta("boss", false)):
            has_boss = true
    if not _check(has_boss, "Boss wave must spawn an actual boss mob"):
        quit(16)
        return

    # Simulate a cleared arena and verify actual walking-distance pickup.
    game.call("_clear_ground_drops")
    for remnant in (game.get("arena_mobs") as Array).duplicate():
        if is_instance_valid(remnant):
            remnant.queue_free()
    (game.get("arena_mobs") as Array).clear()
    var items: Array = game.get("gear")
    var original_bag_size: int = items.size()
    game.set("auto_equip", true)
    game.call("_hide_legendary")
    var loot_position: Vector3 = (game.get("hero") as Node3D).position + Vector3(3.8, 0, 0)
    game.call("_drop_loot_at", loot_position, true)
    if not _check((game.get("ground_drops") as Array).size() == 1 and items.size() == original_bag_size,
        "Loot must remain on the ground, not enter inventory immediately"):
        quit(112)
        return
    game.call("_complete_wave")
    if not _check(int(game.get("dungeon_room_index")) == 3, "Uncollected legendary must pause stage progress"):
        quit(113)
        return
    game.call("_update_ground_pickup")
    if not _check(items.size() == original_bag_size, "Loot cannot teleport from outside pickup reach"):
        quit(114)
        return
    (game.get("hero") as Node3D).position = loot_position
    game.call("_update_ground_pickup")
    if not _check((game.get("ground_drops") as Array).is_empty() and items.size() > original_bag_size,
        "Approaching drop should collect it into backpack"):
        quit(115)
        return
    if not _check(not (game.get("popup_shade") as Control).visible,
        "Idle pickup and auto equip must not interrupt autoplay"):
        quit(37)
        return
    game.call("_equip", 0)
    # In manual mode, a strictly superior drop must ask first, compare stats,
    # and only change equipment after explicit confirmation.
    game.set("auto_equip", false)
    var sample := {"slot": "Weapon", "name": "Manual Hero Upgrade",
        "damage": 9000, "hp": 18000, "crit": 90, "speed": 100,
        "element": "VOID", "elemental": 500, "set": "", "rarity": "EPIC"}
    game.call("_place_ground_drop", loot_position, Color("af7cff"), sample)
    game.call("_update_ground_pickup")
    if not _check((game.get("drop_prompt") as Control).visible
        and not (game.get("pending_comparison") as Dictionary).is_empty()
        and (game.get("drop_comparison") as Label).text.contains("CURRENT:"),
        "Manual mode requires side-by-side equipment comparison"):
        quit(116)
        return
    game.call("_answer_drop_comparison", true)
    if not _check(str((game.get("equipped") as Dictionary)["Weapon"]["name"]) == "Manual Hero Upgrade"
        and not (game.get("drop_prompt") as Control).visible,
        "Confirming an upgrade must equip it and unpause"):
        quit(117)
        return
    game.set("auto_equip", true)
    print("PHYSICAL LOOT QA PASS: ground drops, walk-to-pickup, idle auto equip, manual comparison")
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
    for target_room in [2, 3]:
        for attempt in range(3):
            game.call("_clear_ground_drops")
            game.call("_complete_wave")
            if int(game.get("dungeon_room_index")) == target_room:
                break
    if not _check(int(game.call("_boss_variant")) == 1 and float(game.get("boss_health")) > 0.0, "Second boss must be at end of floor 20 with distinct identity"):
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
    # A single positive step is not enough: traverse several metres, and
    # verify the portrait camera travels with the actor along the dungeon.
    var journey_start: Vector3 = moving_hero.position
    var camera_route_start: Vector3 = (game.get("camera_ref") as Camera3D).global_position
    for travel_step in range(36):
        game.call("_move_hero", 0.10)
        game.call("_update_camera", 0.10)
    if not _check(moving_hero.position.distance_to(journey_start) > 4.5, "Autoplay must walk meaningfully through dungeon corridors"):
        quit(82)
        return
    if not _check((game.get("camera_ref") as Camera3D).global_position.distance_to(camera_route_start) > 2.0, "Portrait camera must track real room-to-room travel"):
        quit(83)
        return
    # Bosses telegraph a real charged attack.
    game.set("stage", 10)
    game.call("_spawn_enemy")
    for target_room in [2, 3]:
        for attempt in range(3):
            game.call("_clear_ground_drops")
            game.call("_complete_wave")
            if int(game.get("dungeon_room_index")) == target_room:
                break
    game.call("_update_boss_cast", 5.0)
    if not _check(float(game.get("boss_cast_windup")) > 0.0, "Boss cast must warn before impact"):
        quit(30)
        return
    game.call("_update_boss_cast", 1.5)
    if not _check(float(game.get("boss_cast_windup")) <= 0.0, "Boss cast should resolve"):
        quit(31)
        return
    # Biome and dungeon path QA: each room has a unique physical location,
    # each floor changes the route, and boss floors change the landscape AFTER floor 10.
    game.set("stage", 1)
    game.call("_spawn_enemy")
    var first_dungeon: PackedVector3Array = game.get("dungeon_points")
    if not _check(first_dungeon.size() == 4 and first_dungeon[0].distance_to(first_dungeon[3]) > 32.0, "A floor must physically traverse three separate chambers"):
        quit(58)
        return
    var dungeon_model: Node3D = game.get("dungeon_map") as Node3D
    if not _check(int(dungeon_model.get("landmark_count")) == 3, "Each floor should have three biome-specific 3D landmark structures"):
        quit(70)
        return
    if not _check(dungeon_model.get_node_or_null("ExitGate") != null, "Floor exit must have an identifiable rendered gateway"):
        quit(71)
        return
    var biome_a: int = int(dungeon_model.get("current_theme"))
    game.set("stage", 2)
    game.call("_spawn_enemy")
    var second_dungeon: PackedVector3Array = game.get("dungeon_points")
    if not _check(second_dungeon[2].distance_to(first_dungeon[2]) > 0.1, "Adjacent levels must not duplicate exact room layout"):
        quit(59)
        return
    game.set("stage", 10)
    game.call("_spawn_enemy")
    if not _check(int((game.get("dungeon_map") as Node).get("current_theme")) == biome_a, "All first 10 floors share a coherent biome"):
        quit(60)
        return
    game.set("stage", 11)
    game.call("_spawn_enemy")
    if not _check(int((game.get("dungeon_map") as Node).get("current_theme")) != biome_a, "The landscape must change immediately after floor 10 boss"):
        quit(61)
        return

    # Class-specific talents survive a simulated game restart and re-selection.
    _choose_after_simulated_restart(game, 2)
    game.set("skill_points", 2)
    game.call("_invest_talent", 0)
    var mage_rank: int = int((game.get("skills") as Array)[0])
    _choose_after_simulated_restart(game, 0)
    _choose_after_simulated_restart(game, 2)
    if not _check(int((game.get("skills") as Array)[0]) == mage_rank, "Changing heroes must preserve invested class talents"):
        quit(32)
        return
    game.call("_show_hero_panel")
    if not _check(game.get("hero_overlay").visible and bool(game.get("class_selection_locked")), "Read-only hero showcase must not unlock classes"):
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
    var spell_visuals: Node3D = game.get("cinematic_skills") as Node3D
    var shot_origin: Vector3 = (game.get("hero") as Node3D).global_position + Vector3(0, 1.2, 0)
    var shot_target: Vector3 = shot_origin + Vector3(3.5, -0.1, -2.0)
    spell_visuals.call("shoot_basic", 1, shot_origin, shot_target, true)
    var active_shot: Dictionary = {}
    for candidate in (spell_visuals.get("effects") as Array):
        if str(candidate.get("kind", "")) == "travel":
            active_shot = candidate
            break
    if not _check(not active_shot.is_empty() and active_shot.has("to"),
        "Ranged hero attacks must spawn actual moving projectile entities"):
        quit(118)
        return
    var moving_projectile: MeshInstance3D = active_shot["node"] as MeshInstance3D
    spell_visuals.call("_process", 0.13)
    if not _check(is_instance_valid(moving_projectile) and moving_projectile.position.distance_to(shot_origin) > 0.5,
        "Projectile must physically cross the world, not instantly appear on enemy"):
        quit(119)
        return
    for archer_class in [2, 3]:
        spell_visuals.call("shoot_basic", archer_class, shot_origin, shot_target, false)
    print("PROJECTILE QA PASS: arrows, magic and shadow bolts traverse world space")
    if not _check(spell_visuals != null and spell_visuals.get("haze_texture") != null, "Cinematic procedural smoke/textures must be initialized"):
        quit(108)
        return
    var casts_before: int = int(spell_visuals.get("total_casts"))
    var mana_before: float = float(game.get("mp"))
    game.call("_use_skill", 0)
    if not _check(float(game.get("mp")) < mana_before, "Casting must consume class-specific MP"):
        quit(54)
        return
    if not _check(int(spell_visuals.get("total_casts")) > casts_before
        and (spell_visuals.get("effects") as Array).size() >= 2,
        "Basic skills must spawn layered directional VFX, not a static sprite"):
        quit(109)
        return
    var hero_position: Vector3 = (game.get("hero") as Node3D).global_position
    var visual_destination: Vector3 = hero_position + Vector3(2.0, 0.0, -2.0)
    for class_id in range(4):
        for slot in range(3):
            spell_visuals.call("cast", class_id, slot, 5,
                hero_position, visual_destination, [visual_destination])
    if not _check(int(spell_visuals.get("total_casts")) >= casts_before + 13
        and (spell_visuals.get("effects") as Array).size() <= 125,
        "Twelve cinematic spell families must render within Android effect budget"):
        quit(110)
        return
    print("CINEMATIC SKILLS QA PASS: all four classes, basic/core/ultimate, procedural layers, bounded VFX")
    var cds: Array = game.get("skill_cooldowns")
    if not _check(float(cds[0]) > 0.0, "Using spell activates cooldown"):
        quit(21)
        return
    # Class skills remain locked until the correct hero level.
    _choose_after_simulated_restart(game, 2)
    game.set("level", 1)
    game.set("skill_cooldowns", [0.0, 0.0, 0.0])
    game.set("mp", game.call("_max_mp"))
    var locked_mp: float = float(game.get("mp"))
    game.call("_use_skill", 1)
    if not _check(float(game.get("mp")) == locked_mp and int(game.call("_skill_rank", 1)) == 0, "Chain Lightning must be locked at level 1"):
        quit(62)
        return
    game.set("level", 5)
    game.set("skill_points", 4)
    var before_points: int = int(game.get("skill_points"))
    game.call("_upgrade_class_skill", 1)
    if not _check(int(game.call("_skill_rank", 1)) == 2 and int(game.get("skill_points")) == before_points - 1, "Skill upgrade must spend one point and increase rank"):
        quit(63)
        return
    _choose_after_simulated_restart(game, 0)
    _choose_after_simulated_restart(game, 2)
    if not _check(int(game.call("_skill_rank", 1)) == 2, "Each class must preserve skill ranks independently"):
        quit(64)
        return
    game.set("stage", 6)
    game.call("_spawn_enemy")
    (game.get("hero") as Node3D).position = (game.get("dungeon_points") as PackedVector3Array)[1]
    var fx_before: int = (game.get("spell_fx") as Array).size()
    var linked: int = int(game.call("_cast_chain_lightning", 2, 1.0))
    if not _check((game.get("spell_fx") as Array).size() >= fx_before + 12, "Chain Lightning should render jagged multi-segment arcs, not straight lines"):
        quit(72)
        return
    if not _check(linked >= 4, "Higher ranked Chain Lightning must reach at least four enemies"):
        quit(65)
        return
    game.set("level", 10)
    if not _check(int(game.call("_skill_rank", 2)) == 1, "Third class ability must unlock at level 10"):
        quit(66)
        return
    var sound: Node = game.get("sound_bank")
    if not _check(sound != null and (sound.get("banks") as Dictionary).size() >= 10, "Layered sound bank must include distinct class, combat and reward cues"):
        quit(67)
        return
    var camera_now: Camera3D = game.get("camera_ref")
    game.call("_update_camera", 0.85)
    if not _check(camera_now.fov >= 44.0 and camera_now.fov <= 49.0, "Portrait isometric camera must remain readable without shrinking hero to a dot"):
        quit(68)
        return
    game.set("stage", 11)
    game.call("_spawn_enemy")
    var dungeon: Node3D = game.get("dungeon_map")
    var ridges: Node = dungeon.get_node_or_null("MountainHorizon")
    if not _check(ridges != null and ridges.get_child_count() >= 12, "Landscapes must have actual large mountain or tree ridge geometry"):
        quit(69)
        return
    # Four ascension thresholds, each offering three class-specific branches.
    # Choices are permanent and saved per class; branch effects alter real stats.
    _choose_after_simulated_restart(game, 2)
    game.set("level", 74)
    game.call("_open_evolution_panel")
    var evo_buttons: Array = game.get("evolution_buttons")
    if not _check(evo_buttons.size() == 3 and (evo_buttons[0] as Button).disabled and (evo_buttons[1] as Button).disabled and (evo_buttons[2] as Button).disabled, "Evolution cannot unlock before level 75"):
        quit(89)
        return
    game.call("_close_evolution_panel")
    game.set("level", 75)
    var damage_without_evo: float = float(game.call("_damage"))
    game.call("_open_evolution_panel")
    if not _check(evo_buttons.size() == 3 and not (evo_buttons[0] as Button).disabled and str((evo_buttons[0] as Button).text).contains("PYROMANCER"), "Level 75 must present three distinct mage branches"):
        quit(90)
        return
    game.call("_choose_evolution", 0)
    if not _check(float(game.call("_damage")) > damage_without_evo, "Offensive evolution must increase real combat damage"):
        quit(91)
        return
    if not _check(int((game.call("_evolution_picks") as Array)[0]) == 0, "First branch choice must be committed permanently"):
        quit(92)
        return
    # Reopening at the same milestone must not offer a reroll.
    game.call("_open_evolution_panel")
    if not _check((evo_buttons[0] as Button).disabled, "A completed tier must not be rerolled before the next milestone"):
        quit(93)
        return
    game.call("_close_evolution_panel")
    game.set("level", 170)
    var hp_without_guardian: float = float(game.call("_max_hp"))
    game.call("_open_evolution_panel")
    game.call("_choose_evolution", 1)
    if not _check(float(game.call("_max_hp")) > hp_without_guardian, "Guardian path must increase real health at level 170"):
        quit(94)
        return
    game.set("level", 250)
    var regen_before: float = float(game.call("_mana_regeneration"))
    game.call("_open_evolution_panel")
    game.call("_choose_evolution", 2)
    if not _check(float(game.call("_mana_regeneration")) > regen_before, "Arcane path must improve mana recovery at level 250"):
        quit(95)
        return
    game.set("level", 500)
    var endgame_damage: float = float(game.call("_damage"))
    game.call("_open_evolution_panel")
    game.call("_choose_evolution", 0)
    var ascension_history: Array = game.call("_evolution_picks")
    if not _check(ascension_history == [0, 1, 2, 0] and float(game.call("_damage")) > endgame_damage, "Level 500 must complete the fourth independent evolution"):
        quit(96)
        return
    game.call("_open_evolution_panel")
    if not _check((evo_buttons[0] as Button).disabled and (evo_buttons[1] as Button).disabled and (evo_buttons[2] as Button).disabled, "Four ascensions is the maximum; choices cannot be reset"):
        quit(97)
        return
    game.call("_close_evolution_panel")
    game.call("_save_game")
    var evolution_save: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://save_v2.json"))
    if not _check(evolution_save is Dictionary and evolution_save.has("evolutions") and (evolution_save["evolutions"] as Dictionary).has("2"), "All four ascensions must be stored in the existing save file"):
        quit(98)
        return
    _choose_after_simulated_restart(game, 1)
    if not _check(game.call("_evolution_picks") == [-1, -1, -1, -1], "Ranger must have independent evolution choices"):
        quit(99)
        return
    _choose_after_simulated_restart(game, 2)
    if not _check(game.call("_evolution_picks") == [0, 1, 2, 0], "Mage evolutions must survive class re-selection after restart"):
        quit(100)
        return
    print("EVOLUTION QA PASS: levels 75/170/250/500, 3 branches, 4 persisted choices, stat effects, session-locked heroes")

    # V3 graphical quality is part of the release gate, not a design document.
    var characters: Array = (game.get("hero_overlay") as Control).find_children("*", "SubViewport", true, false)
    if not _check(characters.size() >= 4, "Every selectable class needs a genuine rendered 3D hero preview"):
        quit(73)
        return
    var glyphs: Array = (game.get("overlay") as Control).find_children("AbilityGlyph", "Control", true, false)
    if not _check(glyphs.size() >= 3, "Each equipped skill must have a bespoke fantasy glyph"):
        quit(74)
        return
    var material_count: int = 0
    for material_name in ["stone_floor", "snow_02", "forrest_ground_01", "rock_face_03", "volcanic_rock_tiles"]:
        if ResourceLoader.exists("res://assets/pbr/%s_diff_1k.jpg" % material_name):
            material_count += 1
    if not _check(material_count == 5, "All five biome families must ship with authentic CC0 1k photographic PBR albedo textures"):
        quit(75)
        return
    var shapes: Dictionary = {}
    var tested_biomes: Dictionary = {}
    var slowest_ms: int = 0
    for floor_id in [1, 2, 3, 4, 5, 10, 11, 21, 31, 41, 51, 61, 71, 81, 91]:
        var started: int = Time.get_ticks_msec()
        game.set("stage", floor_id)
        game.call("_spawn_enemy")
        var millis: int = Time.get_ticks_msec() - started
        slowest_ms = maxi(slowest_ms, millis)
        var builder: Node3D = game.get("dungeon_map")
        var expected_biome: int = posmod(int((floor_id - 1) / 10), 10)
        var active_biome: int = int(builder.get("current_theme"))
        if not _check(active_biome == expected_biome, "Stage %d must select the correct one of ten biomes" % floor_id):
            quit(108)
            return
        tested_biomes[active_biome] = true
        if floor_id == 1:
            if not _check(ResourceLoader.exists("res://assets/models/halloween/crypt.gltf")
                    and builder.find_children("Authentic_halloween_*", "Node3D", true, false).size() >= 8,
                    "First crypt must render authentic licensed tombs, arches, coffins and monuments"):
                quit(114)
                return
        if floor_id == 11:
            if not _check(ResourceLoader.exists("res://assets/models/citytree/tree1.glb")
                    and builder.find_children("Authentic_citytree_*", "Node3D", true, false).size() >= 5,
                    "Enchanted forest must render actual broad-canopy CC0 tree assets"):
                quit(115)
                return
        var creatures: Array = game.get("arena_mobs")
        if not _check(not creatures.is_empty() and str((creatures[0] as Node3D).get_meta("species", "")) != "", "Each act needs a named biome-specific enemy family"):
            quit(109)
            return
        if not _check(int(builder.get("authentic_prop_count")) >= 2,
                "Each biome must place real sculpted CC0 dungeon GLB props, not only procedural cubes"):
            quit(111)
            return
        if floor_id in [1, 11, 21, 41, 91]:
            if not _check(int(builder.get("atmosphere_feature_count")) >= 2,
                    "Cave/forest/swamp/lava/rift require distinctive physical set dressing"):
                quit(112)
                return
        if floor_id in [11, 21, 51, 61, 71]:
            if not _check(builder.get_node_or_null("Chamber_1/WindingTrail_1") != null,
                    "Exterior biomes must render a winding walkable trail rather than one flat empty textured floor"):
                quit(113)
                return
        if floor_id == 11:
            var forest_trees: Array[Node] = builder.find_children("ForestCanopyTree", "Node3D", true, false)
            if not _check(forest_trees.size() >= 4,
                    "Enchanted forest needs actual branched bark-and-leaf models rather than primitive cone trees"):
                quit(114)
                return
            var canopy_draw_batches: int = 0
            var canopy_instances: int = 0
            for candidate in builder.find_children("BatchedEnvironment_*", "MultiMeshInstance3D", true, false):
                var batch: MultiMeshInstance3D = candidate as MultiMeshInstance3D
                if bool(batch.get_meta("forest_canopy", false)):
                    canopy_draw_batches += 1
                    canopy_instances += batch.multimesh.instance_count
            if not _check(canopy_draw_batches >= 2 and
                    canopy_instances >= forest_trees.size() * 2,
                    "Forest bark and leaves must be real GPU MultiMesh instances, not one draw call per tree"):
                quit(115)
                return
            var sunlight: MeshInstance3D = builder.get_node_or_null("Chamber_1/CanopySunDapples_1") as MeshInstance3D
            if not _check(sunlight != null and sunlight.mesh != null,
                    "Forest needs instanced sunlight and foliage shadows on the path"):
                quit(116)
                return
            var forest_road: MeshInstance3D = builder.get_node_or_null("Chamber_1/WindingTrail_1") as MeshInstance3D
            var road_material: StandardMaterial3D = forest_road.material_override as StandardMaterial3D if forest_road != null else null
            if not _check(road_material != null and road_material.albedo_texture != null and
                    road_material.cull_mode == BaseMaterial3D.CULL_DISABLED,
                    "Winding forest road must use real dirt texture and remain visible from the mobile camera"):
                quit(117)
                return
        var original_primitives: int = int(builder.get("unbatched_box_count"))
        var new_batches: int = int(builder.get("box_batch_count"))
        if not _check(original_primitives > 140 and new_batches > 0 and original_primitives > new_batches * 3, "Environment geometry must use GPU instancing rather than hundreds of individual primitive draw calls"):
            quit(81)
            return
        # Graphics V4: relief must be real geometry and distant props should
        # not share one scene-wide MultiMesh that defeats frustum culling.
        var left_bank: MeshInstance3D = builder.get_node_or_null("ExteriorTerrain/TerrainBank_Left") as MeshInstance3D
        var right_bank: MeshInstance3D = builder.get_node_or_null("ExteriorTerrain/TerrainBank_Right") as MeshInstance3D
        if not _check(left_bank != null and right_bank != null and left_bank.mesh != null and right_bank.mesh != null, "Every biome requires two real sculpted terrain banks"):
            quit(101)
            return
        if not _check(left_bank.mesh.get_aabb().size.y > 0.25 and right_bank.mesh.get_aabb().size.y > 0.25, "Exterior landscape must not be a flat plane"):
            quit(102)
            return
        var regions: Dictionary = {}
        for batch_node in builder.find_children("BatchedEnvironment_*", "MultiMeshInstance3D", true, false):
            regions[int(batch_node.get_meta("spatial_chunk", 10000))] = true
        if not _check(regions.size() >= 2 and not regions.has(10000), "Batched scenery must have separate spatially culled sections"):
            quit(103)
            return
        var room_mesh: MeshInstance3D = builder.get_node_or_null("Chamber_1/IrregularFloor_1") as MeshInstance3D
        if not _check(room_mesh != null and room_mesh.mesh != null, "Rooms need genuine irregular polygon meshes, not rectangle primitives"):
            quit(76)
            return
        shapes[int(room_mesh.get_meta("room_shape"))] = true
        if not _check(builder.get_node_or_null("Chamber_3/BossSanctum_%d" % int(builder.get("current_theme"))) != null if floor_id % 10 == 0 else true, "Every tenth stage requires an actual biome-specific boss sanctuary"):
            quit(77)
            return
        if not _check(builder.find_children("Atmosphere_*", "CPUParticles3D", true, false).size() >= 2, "Biomes require lightweight active atmospheric particles"):
            quit(78)
            return
        await process_frame
    if not _check(tested_biomes.size() == 10, "All ten distinct environments must generate through floor 91"):
        quit(110)
        return
    if not _check(shapes.size() == 5, "Five geometrically distinct chamber profiles must appear across consecutive floors"):
        quit(79)
        return
    if not _check(slowest_ms < 4500, "One floor generation exceeds 4.5 seconds on hosted CI hardware"):
        quit(80)
        return
    print("PERFORMANCE QA PASS: dungeon primitives instanced into material batches, %d generated in %d batches. Peak stage generation %dms" % [int(dungeon.get("unbatched_box_count")), int(dungeon.get("box_batch_count")), slowest_ms])
    print("GRAPHICS V5 QA PASS: ten fantasy biomes, ten named bosses, biome-specific enemy families, %d PBR materials, sculpted terrain, mobile GPU batching. Peak generation %dms" % [material_count, slowest_ms])
    print("SKILL/ART/AUDIO QA PASS: level gates, per-class ranks, 4+ chain jumps, zoomed camera, differentiated audio and three-dimensional terrain")
    print("GAMEPLAY TEST PASS: ten distinct biome maps across floors 1-100, three moving encounters per stage, tenth-floor bosses, animated enemies, loot, skills and equipment")
    quit(0)
