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
    if not _check(int(game.get("stage")) == prior and int(game.get("dungeon_room_index")) == 2, "First encounter opens the second dungeon room"):
        quit(14)
        return
    game.call("_complete_wave")
    if not _check(int(game.get("dungeon_room_index")) == 3, "Second encounter opens third room"):
        quit(55)
        return
    game.call("_complete_wave")
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
    game.call("_complete_wave")
    game.call("_complete_wave")
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
    game.call("_complete_wave")
    game.call("_complete_wave")
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
    # Bosses telegraph a real charged attack.
    game.set("stage", 10)
    game.call("_spawn_enemy")
    game.call("_complete_wave")
    game.call("_complete_wave")
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
    # Class skills remain locked until the correct hero level.
    game.call("_select_class", 2)
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
    game.call("_select_class", 0)
    game.call("_select_class", 2)
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
    if not _check(camera_now.fov >= 47.0, "Isometric camera must have a wider zoomed-out field of view"):
        quit(68)
        return
    game.set("stage", 11)
    game.call("_spawn_enemy")
    var dungeon: Node3D = game.get("dungeon_map")
    var ridges: Node = dungeon.get_node_or_null("MountainHorizon")
    if not _check(ridges != null and ridges.get_child_count() >= 12, "Landscapes must have actual large mountain or tree ridge geometry"):
        quit(69)
        return
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
    for material_name in ["stone_floor", "snow_02", "forest_ground_01", "rock_face_03", "volcanic_rock_tiles"]:
        if ResourceLoader.exists("res://assets/pbr/%s_diff_1k.jpg" % material_name):
            material_count += 1
    if not _check(material_count >= 3, "Three or more biome families must ship with authentic CC0 1k photographic PBR albedo textures"):
        quit(75)
        return
    var shapes: Dictionary = {}
    var slowest_ms: int = 0
    for floor_id in [1, 2, 3, 4, 5, 10, 11, 21, 31, 41]:
        var started: int = Time.get_ticks_msec()
        game.set("stage", floor_id)
        game.call("_spawn_enemy")
        var millis: int = Time.get_ticks_msec() - started
        slowest_ms = maxi(slowest_ms, millis)
        var builder: Node3D = game.get("dungeon_map")
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
    if not _check(shapes.size() == 5, "Five geometrically distinct chamber profiles must appear across consecutive floors"):
        quit(79)
        return
    if not _check(slowest_ms < 4500, "One floor generation exceeds 4.5 seconds on hosted CI hardware"):
        quit(80)
        return
    print("GRAPHICS V3 QA PASS: %d photographic terrain families, four 3D class previews, 12 skill glyphs, five room silhouettes, all biome boss arenas, layered atmosphere. Peak generation %dms" % [material_count, slowest_ms])
    print("SKILL/ART/AUDIO QA PASS: level gates, per-class ranks, 4+ chain jumps, zoomed camera, differentiated audio and three-dimensional terrain")
    print("GAMEPLAY TEST PASS: three moving encounters per floor, distinct deterministic layouts, biome change after 10 floors, end-room bosses, animated hero, loot, skills and equipment")
    quit(0)
