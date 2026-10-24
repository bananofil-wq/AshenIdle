extends RefCounted
## The Hollowreach direwolf is high-detail, skinned and PBR textured, but
## its free GLB contains no motion clips. This adds real articulated 4-leg
## skeletal animation tracks instead of moving the entire model like a pawn.
## Bone selectors were verified against imported Godot Skeleton3D rests.
const JOINT_IDS := [9, 14, 22, 26]

func _add_rot_track(animation: Animation, path: NodePath, rotations: Array, length: float) -> void:
    var track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
    animation.track_set_path(track, path)
    var times: Array = [0.0, 0.5, 1.0]
    for i in range(3):
        animation.track_insert_key(track, times[i] * length, rotations[i] as Quaternion)

func attach(model: Node3D) -> bool:
    if model == null:
        return false
    if model.has_meta("hd_wolf_gait"):
        return true
    var skeleton: Skeleton3D
    for node in model.find_children("*", "Skeleton3D", true, false):
        skeleton = node as Skeleton3D
        break
    if skeleton == null or skeleton.get_bone_count() < 31:
        return false
    var motion := AnimationPlayer.new()
    motion.name = "WolfMotionDriver"
    model.add_child(motion)
    motion.root_node = NodePath("..")
    var rel: String = str(model.get_path_to(skeleton))
    var library := AnimationLibrary.new()
    for state in ["Idle", "Walk", "Jog", "Attack", "Hit", "Death"]:
        var clip := Animation.new()
        clip.length = 0.56 if state == "Jog" else 0.86 if state == "Walk" else 0.65 if state == "Attack" else 0.45 if state == "Hit" else 1.05 if state == "Death" else 1.4
        clip.loop_mode = Animation.LOOP_LINEAR if state in ["Idle", "Walk", "Jog"] else Animation.LOOP_NONE
        var amplitude: float = 0.42 if state == "Jog" else 0.28 if state == "Walk" else 0.06 if state == "Idle" else 0.34 if state == "Attack" else 0.16
        var locomoting: bool = state in ["Walk", "Jog"]
        for limb in range(JOINT_IDS.size()):
            var bone_idx: int = int(JOINT_IDS[limb])
            var base: Quaternion = skeleton.get_bone_pose_rotation(bone_idx)
            var phase: float = 1.0 if limb in [0, 3] else -1.0
            var a0: float = amplitude * phase if locomoting else 0.0
            var a1: float = -amplitude * phase if locomoting else 0.04 * phase
            if state == "Attack" and limb < 2:
                a0 = -0.22
                a1 = 0.52
            elif state == "Death":
                a1 = -0.45 if limb < 2 else 0.32
            elif state == "Hit":
                a1 = -0.23
            var bone: String = skeleton.get_bone_name(bone_idx)
            var track_path := NodePath("%s:%s" % [rel, bone])
            _add_rot_track(clip, track_path, [
                base * Quaternion(Vector3.BACK, a0),
                base * Quaternion(Vector3.BACK, a1),
                base * Quaternion(Vector3.BACK, a0)
            ], clip.length)
        library.add_animation(state, clip)
    motion.add_animation_library("", library)
    model.set_meta("hd_wolf_gait", true)
    return true
