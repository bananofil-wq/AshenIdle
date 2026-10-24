extends RefCounted
## 60 Hz mobile render budget with hysteresis.
## No frame time is assumed from CI: real device FPS is sampled every second.
const TARGET_FPS := 60
const QUALITY_LOW := 0
const QUALITY_BALANCED := 1
const QUALITY_HIGH := 2

var tier: int = QUALITY_HIGH
var smoothed_fps: float = 60.0
var consecutive_slow: float = 0.0
var consecutive_fast: float = 0.0

func observe(fps: float, elapsed_seconds: float = 1.0) -> int:
    if fps <= 0.0 or elapsed_seconds <= 0.0:
        return tier
    # Follow sustained GPU/CPU load while ignoring short shader/asset spikes.
    smoothed_fps = lerpf(smoothed_fps, fps, clampf(elapsed_seconds * 0.34, 0.0, 0.50))
    var down_threshold: float = 45.0 if tier == QUALITY_HIGH else 36.0
    var up_threshold: float = 54.0 if tier == QUALITY_BALANCED else 57.0
    if tier > QUALITY_LOW and smoothed_fps < down_threshold:
        consecutive_slow += elapsed_seconds
    else:
        consecutive_slow = 0.0
    if tier < QUALITY_HIGH and smoothed_fps > up_threshold:
        consecutive_fast += elapsed_seconds
    else:
        consecutive_fast = 0.0
    if consecutive_slow >= 3.0:
        tier -= 1
        consecutive_slow = 0.0
        consecutive_fast = 0.0
    elif consecutive_fast >= 9.0:
        tier += 1
        consecutive_slow = 0.0
        consecutive_fast = 0.0
    return tier

func reset(start_tier: int = QUALITY_HIGH) -> void:
    tier = clampi(start_tier, QUALITY_LOW, QUALITY_HIGH)
    smoothed_fps = 60.0
    consecutive_slow = 0.0
    consecutive_fast = 0.0
