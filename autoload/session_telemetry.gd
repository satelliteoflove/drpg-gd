class_name SessionTelemetryClass
extends Node

const MAX_ERRORS := 20
const TOAST_DURATION := 2.0

var _session_start_msec: int
var _call_count: int = 0
var _success_count: int = 0
var _timeout_count: int = 0
var _fallback_count: int = 0
var _latencies: PackedFloat64Array = PackedFloat64Array()
var _tok_per_sec_values: PackedFloat64Array = PackedFloat64Array()
var _predicted_n_values: PackedFloat64Array = PackedFloat64Array()
var _fps_during_inference: PackedFloat64Array = PackedFloat64Array()
var _errors: Array[Dictionary] = []
var _toast_label: Label = null
var _canvas_layer: CanvasLayer = null
var _inference_active := false


func _ready() -> void:
	_session_start_msec = Time.get_ticks_msec()
	LLMManager.completion_finished.connect(_on_completion_finished)
	_setup_toast()


func _process(_delta: float) -> void:
	if _inference_active:
		_fps_during_inference.append(Performance.get_monitor(Performance.TIME_FPS))


func _setup_toast() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.anchor_left = 0.0
	_toast_label.anchor_right = 1.0
	_toast_label.anchor_top = 0.0
	_toast_label.anchor_bottom = 0.0
	_toast_label.offset_top = 16.0
	_toast_label.offset_bottom = 48.0
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	_toast_label.visible = false
	_canvas_layer.add_child(_toast_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			_copy_report()
			get_viewport().set_input_as_handled()


func _on_completion_finished(result: Dictionary) -> void:
	_inference_active = false
	_call_count += 1
	if result.get("timed_out", false):
		_timeout_count += 1
	if result.get("error", "") == "fallback":
		_fallback_count += 1
	if result.get("success", false):
		_success_count += 1

	var latency_ms: int = result.get("latency_ms", 0)
	if latency_ms > 0:
		_latencies.append(float(latency_ms))

	var tok_s: float = result.get("predicted_per_sec", 0.0)
	if tok_s > 0.0:
		_tok_per_sec_values.append(tok_s)

	var predicted_n: int = result.get("predicted_n", 0)
	if predicted_n > 0:
		_predicted_n_values.append(float(predicted_n))

	if not result.get("success", false) and result.get("error", "") != "fallback":
		var entry := {
			"time": Time.get_datetime_string_from_system(false, true),
			"error": result.get("error", "unknown"),
			"latency_ms": latency_ms,
		}
		_errors.append(entry)
		if _errors.size() > MAX_ERRORS:
			_errors.pop_front()


func notify_generate_started() -> void:
	_inference_active = true


func _copy_report() -> void:
	var report := generate_report()
	var json := JSON.stringify(report, "  ")
	DisplayServer.clipboard_set(json)
	_show_toast("Telemetry report copied to clipboard")


func generate_report() -> Dictionary:
	var duration_sec := (Time.get_ticks_msec() - _session_start_msec) / 1000.0
	return {
		"session": {
			"game_version": ProjectSettings.get_setting("application/config/version", "dev"),
			"godot_version": Engine.get_version_info().string,
			"timestamp": Time.get_datetime_string_from_system(true, true),
			"duration_min": snappedf(duration_sec / 60.0, 0.1),
		},
		"hardware": {
			"os": OS.get_name(),
			"arch": "arm64" if OS.has_feature("arm64") else "x86_64",
			"cpu": _get_cpu_name(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"vram_total_mb": _get_vram_total_mb(),
			"vram_used_mb": _get_vram_used_mb(),
			"system_ram_mb": _get_system_ram_mb(),
			"system_ram_used_mb": _get_system_ram_used_mb(),
			"process_ram_mb": _get_process_ram_mb(),
		},
		"llm": {
			"model": LLMManager.MODEL_NAME,
			"backend": LLMManager.get_backend_label(),
			"llama_version": LLMManager.LLAMA_VERSION,
			"server_healthy": LLMManager.is_available(),
			"server_startup_ms": LLMManager.server_startup_ms,
		},
		"stats": {
			"total_calls": _call_count,
			"successes": _success_count,
			"timeouts": _timeout_count,
			"fallbacks": _fallback_count,
			"latency_min_ms": _min_val(_latencies),
			"latency_avg_ms": _avg(_latencies),
			"latency_p95_ms": _percentile(_latencies, 0.95),
			"tok_per_sec_avg": snappedf(_avg(_tok_per_sec_values), 0.1),
			"tok_per_sec_p5": snappedf(_percentile(_tok_per_sec_values, 0.05), 0.1),
			"predicted_tokens_avg": snappedf(_avg(_predicted_n_values), 0.1),
			"fps_during_inference_avg": snappedf(_avg(_fps_during_inference), 0.1),
			"fps_during_inference_min": _min_val(_fps_during_inference),
		},
		"recent_errors": _errors,
	}


func _get_cpu_name() -> String:
	var output := []
	match OS.get_name():
		"macOS":
			OS.execute("sysctl", ["-n", "machdep.cpu.brand_string"], output)
		"Windows":
			OS.execute("wmic", ["cpu", "get", "Name", "/value"], output)
			if not output.is_empty():
				var text: String = str(output[0])
				var eq: int = text.find("=")
				if eq >= 0:
					return text.substr(eq + 1).strip_edges()
				return ""
		_:
			OS.execute("/bin/sh", ["-c", "cat /proc/cpuinfo | grep 'model name' | head -1"], output)
			if not output.is_empty():
				var text: String = str(output[0])
				var colon: int = text.find(":")
				if colon >= 0:
					return text.substr(colon + 1).strip_edges()
				return ""
	if not output.is_empty():
		return str(output[0]).strip_edges()
	return ""


func _get_process_ram_mb() -> float:
	var peak: int = OS.get_static_memory_peak_usage()
	if peak > 0:
		return snappedf(peak / 1048576.0, 0.1)
	var output := []
	match OS.get_name():
		"Windows":
			var pid: int = OS.get_process_id()
			OS.execute("wmic", ["process", "where", "ProcessId=%d" % pid, "get", "WorkingSetSize", "/value"], output)
			if not output.is_empty():
				var text: String = str(output[0])
				var eq: int = text.find("=")
				if eq >= 0:
					var bytes: int = text.substr(eq + 1).strip_edges().to_int()
					if bytes > 0:
						return snappedf(bytes / 1048576.0, 0.1)
		"Linux":
			OS.execute("grep", ["VmPeak", "/proc/self/status"], output)
			if not output.is_empty():
				var text: String = str(output[0]).strip_edges()
				var parts: PackedStringArray = text.split(" ", false)
				if parts.size() >= 2:
					var kb: int = parts[1].to_int()
					if kb > 0:
						return snappedf(kb / 1024.0, 0.1)
	return -1.0


func _get_vram_total_mb() -> int:
	var output := []
	match OS.get_name():
		"Windows", "Linux":
			OS.execute("nvidia-smi", ["--query-gpu=memory.total", "--format=csv,noheader,nounits"], output)
			if not output.is_empty():
				var mb: int = str(output[0]).strip_edges().to_int()
				if mb > 0:
					return mb
			if OS.get_name() == "Linux":
				return _read_amd_vram_file("mem_info_vram_total")
	return -1


func _get_vram_used_mb() -> int:
	var output := []
	match OS.get_name():
		"Windows", "Linux":
			OS.execute("nvidia-smi", ["--query-gpu=memory.used", "--format=csv,noheader,nounits"], output)
			if not output.is_empty():
				var mb: int = str(output[0]).strip_edges().to_int()
				if mb > 0:
					return mb
			if OS.get_name() == "Linux":
				return _read_amd_vram_file("mem_info_vram_used")
	return -1


func _read_amd_vram_file(filename: String) -> int:
	var path := "/sys/class/drm/card0/device/%s" % filename
	if FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path).strip_edges()
		var bytes: int = text.to_int()
		if bytes > 0:
			return int(bytes / 1048576.0)
	return -1


func _get_system_ram_mb() -> int:
	var output := []
	match OS.get_name():
		"macOS":
			OS.execute("sysctl", ["-n", "hw.memsize"], output)
			if not output.is_empty():
				var raw: String = str(output[0]).strip_edges()
				var bytes: int = raw.to_int()
				if bytes > 0:
					return int(bytes / 1048576.0)
		"Windows":
			OS.execute("wmic", ["ComputerSystem", "get", "TotalPhysicalMemory", "/value"], output)
			if not output.is_empty():
				var text: String = str(output[0])
				var eq: int = text.find("=")
				if eq >= 0:
					var bytes: int = text.substr(eq + 1).strip_edges().to_int()
					if bytes > 0:
						return int(bytes / 1048576.0)
		_:
			OS.execute("grep", ["MemTotal", "/proc/meminfo"], output)
			if not output.is_empty():
				var text: String = str(output[0]).strip_edges()
				var parts: PackedStringArray = text.split(" ", false)
				if parts.size() >= 2:
					var kb: int = parts[1].to_int()
					if kb > 0:
						return int(kb / 1024.0)
	return -1


func _get_system_ram_used_mb() -> int:
	var output := []
	match OS.get_name():
		"macOS":
			OS.execute("/bin/zsh", ["-c", "vm_stat | head -5"], output)
			if not output.is_empty():
				var text: String = str(output[0])
				var active: int = 0
				var wired: int = 0
				var compressed: int = 0
				for line in text.split("\n"):
					var l: String = line.strip_edges()
					if l.begins_with("Pages active"):
						active = l.get_slice(":", 1).strip_edges().trim_suffix(".").to_int()
					elif l.begins_with("Pages wired"):
						wired = l.get_slice(":", 1).strip_edges().trim_suffix(".").to_int()
					elif l.begins_with("Pages occupied by compressor"):
						compressed = l.get_slice(":", 1).strip_edges().trim_suffix(".").to_int()
				var pages: int = active + wired + compressed
				if pages > 0:
					return int(pages * 16384.0 / 1048576.0)
		"Windows":
			OS.execute("wmic", ["OS", "get", "FreePhysicalMemory", "/value"], output)
			if not output.is_empty():
				var text: String = str(output[0])
				var eq: int = text.find("=")
				if eq >= 0:
					var free_kb: int = text.substr(eq + 1).strip_edges().to_int()
					var total: int = _get_system_ram_mb()
					if free_kb > 0 and total > 0:
						return total - int(free_kb / 1024.0)
		_:
			OS.execute("grep", ["MemAvailable", "/proc/meminfo"], output)
			if not output.is_empty():
				var text: String = str(output[0]).strip_edges()
				var parts: PackedStringArray = text.split(" ", false)
				if parts.size() >= 2:
					var avail_kb: int = parts[1].to_int()
					var total: int = _get_system_ram_mb()
					if avail_kb > 0 and total > 0:
						return total - int(avail_kb / 1024.0)
	return -1


func _avg(arr: PackedFloat64Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum := 0.0
	for v in arr:
		sum += v
	return snappedf(sum / arr.size(), 0.1)


func _min_val(arr: PackedFloat64Array) -> float:
	if arr.is_empty():
		return 0.0
	var m := arr[0]
	for i in range(1, arr.size()):
		if arr[i] < m:
			m = arr[i]
	return snappedf(m, 0.1)


func _percentile(arr: PackedFloat64Array, p: float) -> float:
	if arr.is_empty():
		return 0.0
	var sorted := arr.duplicate()
	sorted.sort()
	var idx := int(ceil(p * sorted.size())) - 1
	return snappedf(sorted[clampi(idx, 0, sorted.size() - 1)], 0.1)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(TOAST_DURATION)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_toast_label.set.bind("visible", false))
