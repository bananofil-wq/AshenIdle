extends Node
# Layered, deterministic original fantasy SFX, generated once at startup.
# Distinct filtered-noise transients, pitch sweeps, harmonic resonances and
# multi-note loot cues avoid the former identical synthetic sine beeps.
const RATE := 22050
var banks: Dictionary = {}
var randomizer := RandomNumberGenerator.new()
var last_hit_ms := -10000
var footsteps: Dictionary = {}
var recorded_count := 0
var recent_sound_ms: Dictionary = {}
var active_voices: Array[AudioStreamPlayer] = []
const MAX_VOICES := 5

func _ready() -> void:
    randomizer.randomize()
    for sound_id in range(10):
        var options: Array = []
        for variant in range(2):
            options.append(_make_clip(sound_id, variant))
        banks[sound_id] = options
    _load_recorded()

func _load_recorded() -> void:
    # Prefer Kenney's real-world CC0 OGG recordings. Synthetic clips are only
    # fallback, e.g. when running a local Godot project without build assets.
    var names: Array = ["sword", "loot", "legendary", "knight", "boss",
        "ranger", "mage", "reaper", "chain", "level"]
    for sound_id in range(names.size()):
        var clips: Array = []
        for variant in range(2):
            var file: String = "res://assets/sfx/%s_%d.ogg" % [names[sound_id], variant]
            if ResourceLoader.exists(file):
                var stream: AudioStream = load(file) as AudioStream
                if stream != null:
                    clips.append(stream)
                    recorded_count += 1
        if not clips.is_empty():
            banks[sound_id] = clips
    for theme_id in range(5):
        var surface: String = ["concrete", "snow", "grass", "wood", "concrete"][theme_id]
        var steps: Array = []
        for variant in range(2):
            var file: String = "res://assets/sfx/step_%s_%d.ogg" % [surface, variant]
            if ResourceLoader.exists(file):
                var stream: AudioStream = load(file) as AudioStream
                if stream != null:
                    steps.append(stream)
        footsteps[theme_id] = steps

func play_step(theme_id: int) -> void:
    if not footsteps.has(theme_id):
        return
    var choices: Array = footsteps[theme_id]
    if choices.is_empty():
        return
    var stream: AudioStream = choices[randomizer.randi_range(0, choices.size() - 1)]
    _play_voice(stream, -32.0, randomizer.randf_range(0.98, 1.02))


func _play_voice(stream: AudioStream, volume: float, pitch: float) -> void:
    # Polyphony cap keeps crowds from turning into a pile of metallic noise,
    # with only a few short variations sounding at once on phone speakers.
    for i in range(active_voices.size() - 1, -1, -1):
        if not is_instance_valid(active_voices[i]):
            active_voices.remove_at(i)
    if active_voices.size() >= MAX_VOICES:
        return
    var voice := AudioStreamPlayer.new()
    voice.stream = stream
    voice.volume_db = volume
    voice.pitch_scale = pitch
    add_child(voice)
    active_voices.append(voice)
    voice.finished.connect(func() -> void:
        active_voices.erase(voice)
        voice.queue_free()
    )
    voice.play()

func _make_clip(sound_id: int, variant: int) -> AudioStreamWAV:
    var lengths: Array = [0.24, 0.48, 0.73, 0.48, 0.85, 0.50, 0.52, 0.51, 0.64, 0.43]
    var duration: float = float(lengths[sound_id])
    var n: int = int(float(RATE) * duration)
    var data := PackedByteArray()
    data.resize(n * 2)
    var local := RandomNumberGenerator.new()
    local.seed = 65371 + sound_id * 9091 + variant * 12341
    var filter_low: float = 0.0
    var shimmer: float = 0.0
    var phase: float = 0.0
    for i in range(n):
        var t: float = float(i) / float(RATE)
        var p: float = clampf(t / duration, 0, 1)
        var noise: float = local.randf_range(-1.0, 1.0)
        filter_low = lerpf(filter_low, noise, 0.035 if sound_id == 4 else 0.12)
        shimmer = lerpf(shimmer, noise, 0.40)
        var gritty: float = noise - filter_low
        var attack: float = minf(1.0, t * 310.0)
        var smooth: float = attack * pow(1.0 - p, 2.4)
        var bass_sweep: float = 75.0 * pow(1.0 - p, 1.8) + 48.0
        phase += TAU * bass_sweep / float(RATE)
        var bass: float = sin(phase) * pow(1.0 - p, 2.2)
        var sample: float = 0.0
        match sound_id:
            0: # sword: airy whoosh + metal clack + low impact
                sample = gritty * 0.27 * pow(1.0 - p, 4.2) + bass * 0.42
                sample += sin(TAU * (830.0 + 270.0 * p) * t) * 0.20 * pow(1.0 - p, 9.0)
                sample += filter_low * 0.36 * pow(1.0 - p, 3.1)
            1: # item pickup: two clear notes and a soft sparkle
                var note: float = 523.25 if t < 0.13 else 783.99
                sample = (sin(TAU * note * t) * 0.35 + sin(TAU * note * 2.01 * t) * 0.12) * smooth
                sample += shimmer * 0.07 * pow(1.0 - p, 6.0)
            2: # legendary: rising shimmering three-tone chord
                var note: float = 392.0 if t < 0.15 else 587.33 if t < 0.31 else 783.99
                sample = sin(TAU * note * t) * 0.29 * smooth
                sample += sin(TAU * note * 1.5 * t) * 0.13 * pow(1.0 - p, 1.8)
                sample += shimmer * 0.075 * pow(1.0 - p, 6.0)
            3: # knight: shield impact / steel slash
                sample = bass * 0.44 + gritty * 0.23 * pow(1.0 - p, 2.7)
                sample += sin(TAU * (450.0 - 260.0 * p) * t) * 0.17 * smooth
            4: # boss: cavernous low growl and descending metallic pressure
                sample = filter_low * 0.63 + bass * 0.36
                sample += sin(TAU * (140.0 - 70.0 * p) * t) * 0.21 * smooth
            5: # ranger: bow twang, arrow flight, soft impact
                sample = sin(TAU * (390.0 - 280.0 * p) * t) * 0.31 * smooth
                sample += gritty * 0.24 * (1.0 - p) * sin(PI * p)
                sample += filter_low * 0.10
            6: # mage: charged plasma with sizzling upper harmonics
                sample = sin(TAU * (270.0 + 1150.0 * p * p) * t) * 0.25 * smooth
                sample += sin(TAU * (810.0 + 500.0 * p) * t) * 0.18 * smooth
                sample += gritty * 0.22 * pow(1.0 - p, 1.4)
            7: # reaper: deep backwards inhale and dark vortex
                sample = sin(TAU * (240.0 - 170.0 * p) * t) * 0.36 * smooth
                sample += filter_low * 0.41 * sin(PI * p)
                sample += bass * 0.21
            8: # chain lightning: crackling arcs rather than a static electronic beep
                var sparks: float = pow(absf(sin(TAU * (41.0 + 190.0 * p) * t)), 6.0)
                sample = gritty * (0.21 + sparks * 0.34) * smooth
                sample += sin(TAU * (460.0 + 1800.0 * p) * t) * 0.14 * pow(1.0 - p, 3.0)
            9: # level-up: three ascending celebratory notes
                var note: float = 440.0 if p < 0.33 else 554.37 if p < 0.66 else 880.0
                sample = (sin(TAU * note * t) * 0.36 + sin(TAU * note * 2.0 * t) * 0.10) * smooth
        # Controlled soft clipping removes harsh digital peaks.
        sample = sample / (1.0 + absf(sample) * 0.55)
        data.encode_s16(i * 2, clampi(int(sample * 23000.0), -32767, 32767))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    stream.stereo = false
    stream.data = data
    return stream

func play_effect(kind: int, hero_class: int = 0) -> void:
    var sound_id: int = kind
    if kind == 3:
        sound_id = [3, 5, 6, 7][clampi(hero_class, 0, 3)]
    if kind == 5:
        sound_id = 8
    if kind == 6:
        sound_id = 9
    if not banks.has(sound_id):
        return
    var now: int = Time.get_ticks_msec()
    # Continuous idle combat needs restrained foley, not an impact every
    # few frames; reward, boss and skill cues must remain foreground sounds.
    var minimum_gap: int = [620, 220, 540, 450, 960, 660, 330][clampi(kind, 0, 6)]
    if now - int(recent_sound_ms.get(kind, -10000)) < minimum_gap:
        return
    recent_sound_ms[kind] = now
    var candidates: Array = banks[sound_id]
    if candidates.is_empty():
        return
    var clip: AudioStream = candidates[randomizer.randi_range(0, candidates.size() - 1)]
    # Game sound, not a collection of random video-game bleeps. Push
    # attacks and synthetic resonances back; only strong impact/loot cues
    # should sit near foreground. This also helps small phone speakers.
    var gain: float = [-27.0, -21.0, -19.0, -21.5, -16.0, -22.0, -19.0][clampi(kind, 0, 6)]
    _play_voice(clip, gain + randomizer.randf_range(-1.4, 0.0), randomizer.randf_range(0.99, 1.01))
