extends Node
## Small synthesized musical effects. No network, audio files or looping background noise.

var muted: bool = false
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var samples: Dictionary = {}

func _ready() -> void:
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -16.0
		add_child(voice)
		voices.append(voice)
	samples["jump"] = _tone([370.0, 550.0], 0.14, 0.5)
	samples["bounce"] = _tone([270.0, 440.0], 0.16, 0.5)
	samples["food"] = _tone([880.0, 1174.66, 1567.98], 0.25, 0.25)
	samples["checkpoint"] = _tone([523.25, 659.25, 783.99, 1046.5], 0.52, 0.25)
	samples["fall"] = _tone([330.0, 261.63, 196.0], 0.30, 0.5)
	samples["buy"] = _tone([659.25, 880.0, 1318.5], 0.35, 0.25)
	samples["finish"] = _tone([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.8, 0.3)

func play(kind: String) -> void:
	if muted or not samples.has(kind) or voices.is_empty():
		return
	var voice: AudioStreamPlayer = voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = samples[kind]
	voice.play()

func _exit_tree() -> void:
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	samples.clear()

func _tone(notes: Array, duration: float, harmonic: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count: int = int(duration * 22050.0)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var note: int = mini(int(t * notes.size()), notes.size() - 1)
		phase += TAU * float(notes[note]) / 22050.0
		var envelope: float = minf(t * 30.0, 1.0) * pow(1.0 - t, 1.3)
		var value: float = (sin(phase) + harmonic * sin(phase * 2.0)) * envelope * 0.48
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32760.0))
	stream.data = bytes
	return stream
