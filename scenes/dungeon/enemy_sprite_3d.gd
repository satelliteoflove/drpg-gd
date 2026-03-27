class_name EnemySprite3D
extends Sprite3D

const CELL_SIZE: float = 2.0
const FLOOR_SURFACE_Y: float = 1.05
const TARGET_HEIGHT: float = 1.4
const BOSS_TARGET_HEIGHT: float = 1.8

var enemy_group: EnemyGroup = null
var _last_grid_position: Vector2i = Vector2i(-999, -999)
var _sprite_y: float = 1.75


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = false
	transparent = true
	double_sided = true
	shaded = false


func setup(group: EnemyGroup) -> void:
	enemy_group = group
	_load_texture()
	update_world_position()


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


func update_visibility(_distance: int, _is_revealed: bool) -> void:
	visible = true


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
