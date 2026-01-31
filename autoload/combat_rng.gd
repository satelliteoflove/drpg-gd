extends Node

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _current_seed: int = 0


func _ready() -> void:
	randomize_seed()


static func set_seed(seed_value: int) -> void:
	_current_seed = seed_value
	_rng.seed = seed_value


static func get_seed() -> int:
	return _current_seed


static func randi() -> int:
	return _rng.randi()


static func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


static func randf() -> float:
	return _rng.randf()


static func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


static func randomize_seed() -> void:
	_rng.randomize()
	_current_seed = _rng.seed
