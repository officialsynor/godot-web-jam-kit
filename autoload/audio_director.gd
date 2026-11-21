extends Node
## Music and SFX playback, plus the one thing every Godot web build needs.
##
## Browsers refuse to start an AudioContext until the page has been interacted
## with. Godot's web layer resumes it on the first real input, so music started
## from _ready() is silently dropped — the build looks fine and is mute.
## Everything therefore queues behind `unlock()`, which the first input event
## triggers.

var _unlocked: bool = false
var _queued_music: AudioStream = null
var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer


func _ready() -> void:
	# Autoloads must keep running while the tree is paused, otherwise a paused
	# game cannot play its own UI sounds.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	add_child(_music)

	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Sfx"
	add_child(_sfx)


## Called once, from the first input event. Safe to call repeatedly.
func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	if _queued_music != null:
		var stream := _queued_music
		_queued_music = null
		play_music(stream)


func is_unlocked() -> bool:
	return _unlocked


func play_music(stream: AudioStream, loop: bool = true) -> void:
	if stream == null:
		return
	if not _unlocked:
		_queued_music = stream
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_queued_music = null
	_music.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or not _unlocked:
		return
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()


## Builds a short decaying sine tone as an AudioStreamWAV, with no asset file.
## Handy for placeholder SFX and for proving audio works in the browser.
static func make_tone(frequency: float = 440.0, seconds: float = 0.12, mix_rate: int = 22050) -> AudioStreamWAV:
	var frame_count := int(mix_rate * seconds)
	var data := PackedByteArray()
	data.resize(frame_count * 2)  # 16-bit mono => 2 bytes per frame

	for i in frame_count:
		var t := float(i) / float(mix_rate)
		var envelope := 1.0 - (t / seconds)  # linear decay, avoids clicks
		var sample := sin(TAU * frequency * t) * envelope * 0.35
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav
