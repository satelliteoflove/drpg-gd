extends CanvasLayer

const FLAVOR_INTERVAL := 6.0

const FLAVOR_LINES: Array[String] = [
	"Sharpening swords...",
	"Polishing armor...",
	"Bribing the dungeon keeper...",
	"Teaching goblins table manners...",
	"Rolling for initiative...",
	"Arguing about marching order...",
	"Cutting hoagies for the sultan...",
	"Consulting the ancient tomes...",
	"Haggling with the innkeeper...",
	"Convincing the thief not to touch that...",
	"Reticulating dungeon splines...",
	"Feeding the mimics...",
	"Calibrating the magic compass...",
	"Stacking potions very carefully...",
	"Warming up the dragon...",
	"Counting torches...",
	"Mapping the first three floors...",
	"Tuning the bard's lute...",
	"Hiding treasure behind the waterfall...",
	"Training the skeletons to stand still...",
]

@onready var panel: PanelContainer = %Panel
@onready var status_label: Label = %StatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var speed_label: Label = %SpeedLabel
@onready var flavor_label: Label = %FlavorLabel

var _flavor_timer := 0.0
var _flavor_index := 0
var _showing_download := false


func _ready() -> void:
	set_process(false)
	visible = false
	flavor_label.text = ""

	LLMManager.download_started.connect(_on_download_started)
	LLMManager.download_progress.connect(_on_download_progress)
	LLMManager.download_completed.connect(_on_download_completed)
	LLMManager.download_failed.connect(_on_download_failed)
	LLMManager.binary_download_started.connect(_on_binary_download_started)
	LLMManager.binary_download_progress.connect(_on_download_progress)
	LLMManager.binary_download_completed.connect(_on_download_completed)
	LLMManager.binary_download_failed.connect(_on_download_failed)

	if LLMManager.is_downloading() or LLMManager.is_downloading_binary():
		visible = true
		_showing_download = true
		status_label.text = "Downloading AI components..."
		progress_bar.value = 0.0

	_shuffle_flavor()


func _process(delta: float) -> void:
	if not _showing_download:
		return
	_flavor_timer += delta
	if _flavor_timer >= FLAVOR_INTERVAL:
		_flavor_timer = 0.0
		_advance_flavor()


func _on_download_started(model_name: String) -> void:
	visible = true
	_showing_download = true
	set_process(true)
	status_label.text = "Downloading AI model %s..." % model_name
	progress_bar.value = 0.0
	speed_label.text = ""
	_advance_flavor()


func _on_binary_download_started(variant: String) -> void:
	visible = true
	_showing_download = true
	set_process(true)
	status_label.text = "Downloading AI engine (%s)..." % variant
	progress_bar.value = 0.0
	speed_label.text = ""
	_advance_flavor()


func _on_download_progress(percent: float, speed_bps: float, downloaded: int, total: int) -> void:
	progress_bar.value = percent
	speed_label.text = "%s  -  %s at %s" % [_format_bytes_of(downloaded, total), _format_percent(percent), _format_speed(speed_bps)]


func _on_download_completed() -> void:
	status_label.text = "AI model ready"
	progress_bar.value = 100.0
	speed_label.text = "Download complete"
	flavor_label.text = ""
	_showing_download = false
	set_process(false)
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(self, "visible", false, 0.0)


func _on_download_failed(reason: String) -> void:
	status_label.text = "AI model download failed"
	speed_label.text = reason
	progress_bar.value = 0.0
	flavor_label.text = ""
	_showing_download = false
	set_process(false)
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(self, "visible", false, 0.0)


func _shuffle_flavor() -> void:
	var shuffled := FLAVOR_LINES.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp: String = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	_flavor_index = 0


func _advance_flavor() -> void:
	if _flavor_index >= FLAVOR_LINES.size():
		_flavor_index = 0
	flavor_label.text = FLAVOR_LINES[_flavor_index]
	_flavor_index += 1


func _format_speed(bps: float) -> String:
	if bps >= 1048576.0:
		return "%.1f MB/s" % (bps / 1048576.0)
	elif bps >= 1024.0:
		return "%.0f KB/s" % (bps / 1024.0)
	return "%.0f B/s" % bps


func _format_percent(percent: float) -> String:
	return "%.1f%%" % percent


func _format_bytes_of(downloaded: int, total: int) -> String:
	if total >= 1073741824:
		return "%.2f / %.2f GB" % [float(downloaded) / 1073741824.0, float(total) / 1073741824.0]
	if total >= 1048576:
		return "%.1f / %.1f MB" % [float(downloaded) / 1048576.0, float(total) / 1048576.0]
	return "%d / %d KB" % [downloaded / 1024, total / 1024]
