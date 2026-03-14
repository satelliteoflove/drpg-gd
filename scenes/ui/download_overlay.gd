extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var status_label: Label = %StatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var speed_label: Label = %SpeedLabel


func _ready() -> void:
	visible = false
	LLMManager.binary_download_started.connect(_on_binary_download_started)
	LLMManager.binary_download_progress.connect(_on_binary_download_progress)
	LLMManager.binary_download_completed.connect(_on_binary_download_completed)
	LLMManager.binary_download_failed.connect(_on_binary_download_failed)
	LLMManager.download_started.connect(_on_download_started)
	LLMManager.download_progress.connect(_on_download_progress)
	LLMManager.download_completed.connect(_on_download_completed)
	LLMManager.download_failed.connect(_on_download_failed)

	if LLMManager.is_downloading_binary():
		visible = true
		status_label.text = "Downloading AI engine (detecting GPU)..."
		progress_bar.value = 0.0
	elif LLMManager.is_downloading():
		visible = true
		status_label.text = "Downloading AI model..."
		progress_bar.value = 0.0


func _on_binary_download_started(variant: String) -> void:
	visible = true
	status_label.text = "Downloading AI engine (%s)..." % variant
	progress_bar.value = 0.0
	speed_label.text = ""


func _on_binary_download_progress(percent: float, speed_bps: float) -> void:
	progress_bar.value = percent
	speed_label.text = "%s at %s" % [_format_percent(percent), _format_speed(speed_bps)]


func _on_binary_download_completed() -> void:
	status_label.text = "AI engine ready"
	progress_bar.value = 100.0
	speed_label.text = ""


func _on_binary_download_failed(reason: String) -> void:
	status_label.text = "AI engine download failed"
	speed_label.text = reason
	progress_bar.value = 0.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(self, "visible", false, 0.0)


func _on_download_started(model_name: String) -> void:
	visible = true
	status_label.text = "Downloading AI model %s..." % model_name
	progress_bar.value = 0.0
	speed_label.text = ""


func _on_download_progress(percent: float, speed_bps: float) -> void:
	progress_bar.value = percent
	speed_label.text = "%s at %s" % [_format_percent(percent), _format_speed(speed_bps)]


func _on_download_completed() -> void:
	status_label.text = "AI model ready"
	progress_bar.value = 100.0
	speed_label.text = "Download complete"
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(self, "visible", false, 0.0)


func _on_download_failed(reason: String) -> void:
	status_label.text = "AI model download failed"
	speed_label.text = reason
	progress_bar.value = 0.0
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(self, "visible", false, 0.0)


func _format_speed(bps: float) -> String:
	if bps >= 1048576.0:
		return "%.1f MB/s" % (bps / 1048576.0)
	elif bps >= 1024.0:
		return "%.0f KB/s" % (bps / 1024.0)
	return "%.0f B/s" % bps


func _format_percent(percent: float) -> String:
	return "%.1f%%" % percent
