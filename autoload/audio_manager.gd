class_name AudioManagerClass
extends Node

## Global audio. Music, ambient bed, and SFX route to their own buses (created at
## runtime, sent to Master) so they can be mixed independently. Music + ambient
## support fade/crossfade; loop flags are applied at runtime so plain WAVs loop.

const MAX_SFX_PLAYERS: int = 8
const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 1.0
const AMBIENT_VOLUME: float = 0.65
const SILENCE_DB: float = -50.0

const BUS_MUSIC := "Music"
const BUS_AMBIENT := "Ambient"
const BUS_SFX := "SFX"

var music_player: AudioStreamPlayer = null
var ambient_player: AudioStreamPlayer = null
var sfx_players: Array[AudioStreamPlayer] = []

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
var _sfx_cache: Dictionary = {}
var _music_tween: Tween = null
var _ambient_tween: Tween = null


func _ready() -> void:
	_setup_buses()
	_setup_music_player()
	_setup_ambient_player()
	_setup_sfx_players()


func _setup_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_AMBIENT, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	add_child(music_player)


func _setup_ambient_player() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = BUS_AMBIENT
	add_child(ambient_player)


func _setup_sfx_players() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		sfx_players.append(player)


# --- Music ------------------------------------------------------------------

func play_music(stream: AudioStream, fade_in: bool = false) -> void:
	if not music_enabled or stream == null:
		return
	_ensure_loop(stream)
	music_player.stream = stream
	if fade_in:
		music_player.volume_db = SILENCE_DB
		music_player.play()
		_music_tween = _fade(music_player, linear_to_db(music_volume), 1.5, _music_tween)
	else:
		music_player.volume_db = linear_to_db(music_volume)
		music_player.play()


func crossfade_music(stream: AudioStream, dur: float = 1.5) -> void:
	if not music_enabled or stream == null:
		return
	if music_player.stream == stream and music_player.playing:
		return
	_ensure_loop(stream)
	if not music_player.playing:
		play_music(stream, true)
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", SILENCE_DB, dur * 0.5)
	_music_tween.tween_callback(func() -> void:
		music_player.stream = stream
		music_player.play())
	_music_tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), dur * 0.5)


func stop_music(fade_out: bool = false) -> void:
	if fade_out and music_player.playing:
		if _music_tween and _music_tween.is_valid():
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.tween_property(music_player, "volume_db", SILENCE_DB, 1.0)
		_music_tween.tween_callback(music_player.stop)
	else:
		music_player.stop()


# --- Ambient ----------------------------------------------------------------

func play_ambient(stream: AudioStream, fade: float = 1.0) -> void:
	if stream == null:
		return
	if ambient_player.stream == stream and ambient_player.playing:
		return
	_ensure_loop(stream)
	ambient_player.stream = stream
	ambient_player.volume_db = SILENCE_DB
	ambient_player.play()
	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = _fade(ambient_player, linear_to_db(AMBIENT_VOLUME), fade, _ambient_tween)


func stop_ambient(fade: float = 0.8) -> void:
	if not ambient_player.playing:
		return
	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(ambient_player, "volume_db", SILENCE_DB, fade)
	_ambient_tween.tween_callback(ambient_player.stop)


# --- SFX --------------------------------------------------------------------

func play_ui(sound_name: String) -> void:
	if not sfx_enabled:
		return
	if not _ui_cache.has(sound_name):
		var path: String = UI_SOUND_PATHS.get(sound_name, "")
		if path.is_empty() or not ResourceLoader.exists(path):
			return
		_ui_cache[sound_name] = load(path)
	play_sfx(_ui_cache[sound_name])


## Play a one-shot SFX by resource path (lazy-loaded + cached). Safe no-op if
## missing. `pitch` and `volume` (linear 0..1) jitter individual plays.
func play_sfx_path(path: String, pitch: float = 1.0, volume: float = 1.0) -> void:
	if not sfx_enabled or path.is_empty():
		return
	if not _sfx_cache.has(path):
		if not ResourceLoader.exists(path):
			return
		_sfx_cache[path] = load(path)
	play_sfx(_sfx_cache[path], pitch, volume)


func play_sfx(stream: AudioStream, pitch: float = 1.0, volume: float = 1.0) -> void:
	if not sfx_enabled or stream == null:
		return
	var player := _free_sfx_player()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(clampf(sfx_volume * volume, 0.001, 1.0))
	player.play()


func _free_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	return sfx_players[0]


# --- Volume / helpers -------------------------------------------------------

func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	if music_player and music_player.playing:
		music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)


func set_bus_volume(bus_name: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(volume, 0.0, 1.0)))


func _fade(player: AudioStreamPlayer, to_db: float, dur: float, prev: Tween) -> Tween:
	if prev and prev.is_valid():
		prev.kill()
	var t := create_tween()
	t.tween_property(player, "volume_db", to_db, dur)
	return t


# Make plain WAVs (and OGGs) loop. AudioStreamWAV needs loop_mode + loop_end set
# from the frame count, since the imported default is no-loop.
func _ensure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var bps := 2
			if w.format == AudioStreamWAV.FORMAT_8_BITS:
				bps = 1
			elif w.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
				bps = 1
			var chans := 2 if w.stereo else 1
			var frames := w.data.size() / (bps * chans)
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = frames
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
