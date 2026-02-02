class_name EnemySprite3D
extends Sprite3D

const CELL_SIZE: float = 2.0
const SPRITE_HEIGHT: float = 1.35

var enemy_group: EnemyGroup = null
var _last_grid_position: Vector2i = Vector2i(-999, -999)


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = false
	transparent = true
	double_sided = true
	shaded = false
	pixel_size = 0.0035


func setup(group: EnemyGroup) -> void:
	enemy_group = group
	_load_texture()
	update_world_position()


func _load_texture() -> void:
	var texture_path := "res://textures/monsters/goblin.png"
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path)
	else:
		_use_placeholder_texture()


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
			SPRITE_HEIGHT,
			current_grid.y * CELL_SIZE + CELL_SIZE / 2.0
		)
		_last_grid_position = current_grid
	elif current_grid != _last_grid_position:
		animate_move_to(current_grid)
		_last_grid_position = current_grid


func animate_move_to(target_grid: Vector2i, duration: float = 0.3) -> void:
	var target_pos := Vector3(
		target_grid.x * CELL_SIZE + CELL_SIZE / 2.0,
		SPRITE_HEIGHT,
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
