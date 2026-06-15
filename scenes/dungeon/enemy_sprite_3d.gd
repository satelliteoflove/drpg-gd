class_name EnemySprite3D
extends Sprite3D

const CELL_SIZE: float = 2.0
const FLOOR_SURFACE_Y: float = 1.05
const TARGET_HEIGHT: float = 1.4
const BOSS_TARGET_HEIGHT: float = 1.8

var enemy_group: EnemyGroup = null
var _last_grid_position: Vector2i = Vector2i(-999, -999)
var _sprite_y: float = 1.75
var _audio: AudioStreamPlayer3D = null


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = false
	transparent = true
	double_sided = true
	shaded = false


func setup(group: EnemyGroup) -> void:
	enemy_group = group
	_load_texture()
	_setup_audio()
	update_world_position()


# A faint, looping positional growl so a nearby roamer is heard in the dark
# before it is seen. Attenuates with distance from the camera (the audio
# listener); plays regardless of visual LOS, and frees with the sprite on death.
func _setup_audio() -> void:
	var path := "res://audio/sfx/roamer.wav"
	if not ResourceLoader.exists(path):
		return
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "SFX"
	var s := load(path)
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	_audio.stream = s
	_audio.unit_size = 2.5
	_audio.max_distance = 14.0
	_audio.volume_db = linear_to_db(0.4)
	_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	# autoplay (not play()) so the loop starts when the sprite is actually in the
	# tree — setup() runs before the sprite is added to the dungeon, and a play()
	# call outside the tree is silently dropped by the audio server.
	_audio.autoplay = true
	add_child(_audio)


func _load_texture() -> void:
	var texture_path := "res://textures/monsters/goblin.png"
	if enemy_group and not enemy_group.monsters.is_empty():
		var lead_monster := enemy_group.monsters[0]
		var specific_path := "res://textures/monsters/%s.png" % lead_monster.monster_name.to_lower().replace(" ", "_")
		if ResourceLoader.exists(specific_path):
			texture_path = specific_path
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path)
	else:
		_use_placeholder_texture()
	_adjust_sprite_size()


func _adjust_sprite_size() -> void:
	var is_boss := false
	if enemy_group and not enemy_group.monsters.is_empty():
		is_boss = enemy_group.monsters[0].is_boss
	var target_h := BOSS_TARGET_HEIGHT if is_boss else TARGET_HEIGHT
	var tex_height := 64.0
	if texture:
		tex_height = texture.get_height()
	pixel_size = target_h / tex_height
	_sprite_y = FLOOR_SURFACE_Y + target_h / 2.0


func _use_placeholder_texture() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2, 1.0))
	texture = ImageTexture.create_from_image(img)


const DARK_SILHOUETTE := Color(0.16, 0.16, 0.2)

## Darken the billboard toward a dim silhouette as it sits beyond the player's
## current light reach (passed in tiles), so a foe at the edge of the torchlight
## is a creeping shape and only fully visible when the light actually touches it.
## Revealed (map/scry) enemies always show at full brightness.
func update_visibility(dist_tiles: int, light_range_tiles: float, is_revealed: bool) -> void:
	if is_revealed:
		modulate = Color.WHITE
		return
	var lr := maxf(1.0, light_range_tiles)
	var t := clampf((float(dist_tiles) - lr * 0.4) / (lr * 0.6), 0.0, 1.0)
	modulate = Color.WHITE.lerp(DARK_SILHOUETTE, t)


func update_world_position() -> void:
	if enemy_group == null:
		return

	var current_grid := enemy_group.grid_position

	if _last_grid_position == Vector2i(-999, -999):
		position = Vector3(
			current_grid.x * CELL_SIZE + CELL_SIZE / 2.0,
			_sprite_y,
			current_grid.y * CELL_SIZE + CELL_SIZE / 2.0
		)
		_last_grid_position = current_grid
	elif current_grid != _last_grid_position:
		animate_move_to(current_grid)
		_last_grid_position = current_grid


func animate_move_to(target_grid: Vector2i, duration: float = 0.3) -> void:
	var target_pos := Vector3(
		target_grid.x * CELL_SIZE + CELL_SIZE / 2.0,
		_sprite_y,
		target_grid.y * CELL_SIZE + CELL_SIZE / 2.0
	)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", target_pos, duration)


func get_group_id() -> String:
	if enemy_group == null:
		return ""
	return enemy_group.id


func set_chase_indicator(_chasing: bool) -> void:
	pass
