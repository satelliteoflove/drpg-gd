class_name ArcaneBackdrop extends Control

## A self-contained living backdrop: torch-lit stone, drifting fog, rising
## embers, floating dust, and a breathing vignette. Drop it in as the first
## child of any full-screen menu. Set `subdued = true` for dense work screens
## so the motion recedes behind the content.

const STONE := "res://textures/stone_brick_wall/diffuse.jpg"
const SH_TORCH := "res://scenes/ui/shaders/torch_stone.gdshader"
const SH_FOG := "res://scenes/ui/shaders/fog.gdshader"
const SH_VIGNETTE := "res://scenes/ui/shaders/vignette.gdshader"
const SH_FLAME := "res://scenes/ui/shaders/torch_flame.gdshader"
const SH_GLOW := "res://scenes/ui/shaders/torch_glow.gdshader"

# Sconce positions (match the warm light pools in torch_stone.gdshader).
const TORCH_UV := [Vector2(0.20, 0.28), Vector2(0.80, 0.28)]

@export var subdued: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0:
		vp = Vector2(1280, 720)

	# 1. Torch-lit stone wall
	var stone := TextureRect.new()
	stone.texture = load(STONE)
	stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fill(stone)
	var torch_mat := ShaderMaterial.new()
	torch_mat.shader = load(SH_TORCH)
	if subdued:
		torch_mat.set_shader_parameter("ambient", Color(0.10, 0.10, 0.15))
		torch_mat.set_shader_parameter("torch_strength", 0.8)
		torch_mat.set_shader_parameter("exposure", 0.62)
	stone.material = torch_mat
	add_child(stone)

	# 2. Unifying darken pass
	var darken := ColorRect.new()
	darken.color = Color(0.04, 0.035, 0.06, 0.34 if not subdued else 0.5)
	_fill(darken)
	add_child(darken)

	# 3. Drifting fog
	var fog := ColorRect.new()
	_fill(fog)
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = load(SH_FOG)
	fog_mat.set_shader_parameter("fog_strength", 0.11 if not subdued else 0.06)
	fog.material = fog_mat
	add_child(fog)

	var dot := _soft_dot()

	# Real torch flames at the sconces (hero screens only).
	var torch_points: Array[Vector2] = []
	if not subdued:
		for uv in TORCH_UV:
			var p := Vector2(vp.x * uv.x, vp.y * uv.y)
			torch_points.append(p)
			_build_torch(p)
		_build_torch_sparks(dot, torch_points)

	# 4. Floating dust motes
	var dust := _make_particles(
		dot,
		24 if subdued else 44,
		13.0,
		Vector2(vp.x * 0.5, vp.y * 0.45),
		Vector2(vp.x * 0.5, vp.y * 0.5),
		Color(0.82, 0.86, 1.0))
	dust.direction = Vector2(0, -0.2)
	dust.spread = 180.0
	dust.gravity = Vector2(0, 2.0)
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 8.0
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.1
	dust.color_ramp = _ramp([
		[0.0, Color(0.85, 0.88, 1.0, 0.0)],
		[0.25, Color(0.85, 0.88, 1.0, 0.22)],
		[0.75, Color(0.8, 0.84, 1.0, 0.18)],
		[1.0, Color(0.8, 0.84, 1.0, 0.0)],
	])
	add_child(dust)

	# 5. Rising embers
	var ember := _make_particles(
		dot,
		18 if subdued else 34,
		7.5,
		Vector2(vp.x * 0.5, vp.y + 12.0),
		Vector2(vp.x * 0.5, 8.0),
		Color(1.0, 0.6, 0.3))
	ember.direction = Vector2(0, -1)
	ember.spread = 24.0
	ember.gravity = Vector2(0, -7.0)
	ember.initial_velocity_min = 10.0
	ember.initial_velocity_max = 30.0
	ember.scale_amount_min = 0.30
	ember.scale_amount_max = 0.85
	ember.scale_amount_curve = _fade_curve()
	ember.tangential_accel_min = -6.0
	ember.tangential_accel_max = 6.0
	ember.damping_min = 1.0
	ember.damping_max = 3.0
	ember.color_ramp = _ramp([
		[0.0, Color(1.0, 0.68, 0.34, 0.0)],
		[0.12, Color(1.0, 0.62, 0.30, 0.8)],
		[0.7, Color(1.0, 0.45, 0.2, 0.45)],
		[1.0, Color(1.0, 0.3, 0.15, 0.0)],
	])
	ember.material = _add_mat()
	if not subdued:
		add_child(ember)

	# 6. Breathing vignette
	var vignette := ColorRect.new()
	_fill(vignette)
	var vig_mat := ShaderMaterial.new()
	vig_mat.shader = load(SH_VIGNETTE)
	if subdued:
		vig_mat.set_shader_parameter("strength", 1.0)
		vig_mat.set_shader_parameter("inner", 0.22)
	vignette.material = vig_mat
	add_child(vignette)


func _fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_torch(p: Vector2) -> void:
	# Soft additive halo behind the flame.
	var glow := _shader_rect(SH_GLOW)
	glow.size = Vector2(320, 320)
	glow.position = p - Vector2(160, 150)
	add_child(glow)

	# The flame itself, base resting at the sconce, rising upward.
	var flame := _shader_rect(SH_FLAME)
	flame.size = Vector2(112, 160)
	flame.position = p - Vector2(56, 146)
	add_child(flame)


func _build_torch_sparks(tex: Texture2D, points: Array[Vector2]) -> void:
	if points.is_empty():
		return
	var emit := PackedVector2Array()
	for p in points:
		emit.append(p + Vector2(0, -16))
	var sparks := _make_particles(tex, 24, 2.4, Vector2.ZERO, Vector2(2, 2),
		Color(1.0, 0.7, 0.42))
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	sparks.emission_points = emit
	sparks.direction = Vector2(0, -1)
	sparks.spread = 32.0
	sparks.gravity = Vector2(0, -26.0)
	sparks.initial_velocity_min = 14.0
	sparks.initial_velocity_max = 44.0
	sparks.scale_amount_min = 0.22
	sparks.scale_amount_max = 0.55
	sparks.scale_amount_curve = _fade_curve()
	sparks.tangential_accel_min = -12.0
	sparks.tangential_accel_max = 12.0
	sparks.damping_min = 2.0
	sparks.damping_max = 6.0
	sparks.color_ramp = _ramp([
		[0.0, Color(1.0, 0.8, 0.45, 0.0)],
		[0.12, Color(1.0, 0.72, 0.38, 0.95)],
		[0.6, Color(1.0, 0.5, 0.22, 0.6)],
		[1.0, Color(1.0, 0.32, 0.16, 0.0)],
	])
	sparks.material = _add_mat()
	add_child(sparks)


func _shader_rect(shader_path: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	rect.material = mat
	return rect


func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _make_particles(
	tex: Texture2D, amount: int, lifetime: float,
	pos: Vector2, extents: Vector2, color: Color
) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime * 0.9
	p.lifetime_randomness = 0.5
	p.position = pos
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.color = color
	return p


func _soft_dot() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.set_offset(0, 0.0)
	grad.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _fade_curve() -> Curve:
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 0.5))
	cv.add_point(Vector2(0.22, 1.0))
	cv.add_point(Vector2(1.0, 0.15))
	return cv


func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(s[1])
	g.offsets = offsets
	g.colors = colors
	return g
