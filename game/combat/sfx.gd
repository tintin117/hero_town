extends Node
## Tiny one-shot sound pool for the arena. Quiet by design; a missing file or a busy pool
## just means silence. Kinds: hit, skill, bell, win, coin.

const STREAMS := {
	&"hit": "res://asset/audio/sfx/hit.wav",
	&"skill": "res://asset/audio/sfx/crit.wav",
	&"bell": "res://asset/audio/sfx/summon.wav",
	&"win": "res://asset/audio/sfx/upgrade.wav",
	&"coin": "res://asset/audio/sfx/coin.wav",
}
const VOICES := 4
const VOLUME_DB := -14.0
const MIN_GAP_MS := 70  # a melee never machine-guns one sound

var _players: Array[AudioStreamPlayer] = []
var _last := {}  # kind -> tick of its last play


func play(kind: StringName) -> void:
	var now := Time.get_ticks_msec()
	if not STREAMS.has(kind) or now - int(_last.get(kind, -MIN_GAP_MS)) < MIN_GAP_MS or not ResourceLoader.exists(STREAMS[kind]):
		return
	_last[kind] = now
	if _players.is_empty():
		for i in VOICES:
			var player := AudioStreamPlayer.new()
			player.volume_db = VOLUME_DB
			add_child(player)
			_players.append(player)
	for player in _players:
		if not player.playing:
			player.stream = load(STREAMS[kind])
			player.play()
			return
