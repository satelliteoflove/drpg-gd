class_name PartyChatLog
extends RichTextLabel

const LINE_DURATION := 16.0
const MAX_LINES := 4

var _line_times: Array[float] = []
var _bbcode_lines: Array[String] = []


func _ready() -> void:
	set_process(false)
	bbcode_enabled = true
	scroll_following = true
	text = ""


func add_line(speaker_name: String, line: String, color: Color = Color(0.9, 0.8, 0.5, 1)) -> void:
	var hex := color.to_html(false)
	var bbcode := "[color=#%s]%s:[/color] \"%s\"" % [hex, speaker_name, line]
	_bbcode_lines.append(bbcode)
	_line_times.append(LINE_DURATION)
	set_process(true)

	while _bbcode_lines.size() > MAX_LINES:
		_remove_oldest_line()

	_rebuild()


func add_response(responder_name: String, line: String) -> void:
	add_line(responder_name, line, Color(0.7, 0.7, 0.7, 1))


func _process(delta: float) -> void:
	if _line_times.is_empty():
		set_process(false)
		return

	_line_times[0] -= delta
	if _line_times[0] <= 0.0:
		_remove_oldest_line()
		_rebuild()


func _remove_oldest_line() -> void:
	if _bbcode_lines.is_empty():
		return
	_bbcode_lines.pop_front()
	_line_times.pop_front()


func _rebuild() -> void:
	text = ""
	clear()
	for i in _bbcode_lines.size():
		if i > 0:
			append_text("\n")
		append_text(_bbcode_lines[i])
