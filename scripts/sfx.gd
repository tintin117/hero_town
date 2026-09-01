extends Node

## Tiny SFX bus: sfx.play("coin"). Pitch jitter keeps repeats from sounding robotic.

const SOUNDS := {
	"click": preload("res://asset/audio/sfx/click.wav"),
	"coin": preload("res://asset/audio/sfx/coin.wav"),
	"hit": preload("res://asset/audio/sfx/hit.wav"),
	"crit": preload("res://asset/audio/sfx/crit.wav"),
	"place": preload("res://asset/audio/sfx/place.wav"),
	"error": preload("res://asset/audio/sfx/error.wav"),
	"summon": preload("res://asset/audio/sfx/summon.wav"),
	"upgrade": preload("res://asset/audio/sfx/upgrade.wav"),
}
const VOICES := 8

var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)

func play(sound_name: String, pitch_jitter: float = 0.06) -> void:
	if not SOUNDS.has(sound_name):
		return
	for player in _players:
		if not player.playing:
			player.stream = SOUNDS[sound_name]
			player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			player.play()
			return
	# All voices busy: steal the first.
	_players[0].stream = SOUNDS[sound_name]
	_players[0].play()
