class_name AudioManagerClass
extends Node

var music_player: AudioStreamPlayer = null
var sfx_players: Array[AudioStreamPlayer] = []

const MAX_SFX_PLAYERS: int = 8
const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 1.0

var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var music_enabled: bool = true
var sfx_enabled: bool = true

const UI_SOUND_PATHS: Dictionary = {
	"nav": "res://audio/ui/nav.wav",
	"hover": "res://audio/ui/hover.wav",
	"confirm": "res://audio/ui/confirm.wav",
	"back": "res://audio/ui/back.wav",
	"denied": "res://audio/ui/denied.wav",
}
var _ui_cache: Dictionary = {}


func _ready() -> void:
	_setup_music_player()
	_setup_sfx_players()


func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)


func _setup_sfx_players() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_players.append(player)


func play_music(stream: AudioStream, _fade_in: bool = false) -> void:
	if not music_enabled:
		return

	music_player.stream = stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()


func stop_music(_fade_out: bool = false) -> void:
	music_player.stop()


## Play a named UI sound (lazy-loaded and cached). Safe no-op if missing.
func play_ui(sound_name: String) -> void:
	if not sfx_enabled:
		return
	if not _ui_cache.has(sound_name):
		var path: String = UI_SOUND_PATHS.get(sound_name, "")
		if path.is_empty() or not ResourceLoader.exists(path):
			return
		_ui_cache[sound_name] = load(path)
	play_sfx(_ui_cache[sound_name])


func play_sfx(stream: AudioStream) -> void:
	if not sfx_enabled:
		return

	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			player.play()
			return

	sfx_players[0].stream = stream
	sfx_players[0].volume_db = linear_to_db(sfx_volume)
	sfx_players[0].play()


func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	if music_player:
		music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
