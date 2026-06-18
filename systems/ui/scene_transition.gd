class_name SceneTransition extends CanvasLayer

## A full-screen veil + arcane sigil used to bridge scene changes. Owned by
## SceneManager (an autoload), so it survives change_scene_to_file and can
## animate across the swap. Call play_cover() before the swap and play_reveal()
## after.

var _veil: ColorRect
var _sigil: ArcaneSigil


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_veil = ColorRect.new()
	_veil.color = Color(0.02, 0.02, 0.035, 1.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.modulate.a = 0.0
	_veil.visible = false
	add_child(_veil)

	_sigil = ArcaneSigil.new()
	_sigil.size = Vector2(190, 190)
	_sigil.pivot_offset = Vector2(95, 95)
	_sigil.set_anchors_preset(Control.PRESET_CENTER)
	_sigil.position = -_sigil.size * 0.5
	_sigil.modulate.a = 0.0
	_veil.add_child(_sigil)


func play_cover(dur: float = 0.30) -> void:
	_veil.visible = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_sigil.spinning = true
	_sigil.scale = Vector2(0.7, 0.7)
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_veil, "modulate:a", 1.0, dur)
	tw.tween_property(_sigil, "modulate:a", 1.0, dur * 0.85)
	tw.tween_property(_sigil, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK)
	await tw.finished


func play_reveal(dur: float = 0.34) -> void:
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_veil, "modulate:a", 0.0, dur)
	tw.tween_property(_sigil, "modulate:a", 0.0, dur * 0.7)
	tw.tween_property(_sigil, "scale", Vector2(1.3, 1.3), dur)
	await tw.finished
	_veil.visible = false
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sigil.spinning = false
