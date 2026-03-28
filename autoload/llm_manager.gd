class_name LLMManagerClass
extends Node

signal server_ready
signal server_failed
signal download_started(model_name: String)
signal download_progress(percent: float, speed_bps: float, downloaded: int, total: int)
signal download_completed
signal download_failed(reason: String)
signal setup_finished

const DEFAULT_N_PREDICT := 150
const GENERATE_TIMEOUT_SEC := 8.0

const MODEL_NAME := "Qwen2.5-3B-Instruct-Q8_0"
const MODEL_FILENAME := "qwen2.5-3b-instruct-q8_0.gguf"
const MODEL_URL := "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q8_0.gguf"
const MODEL_EXPECTED_BYTES := 3616088480

const DOWNLOAD_OVERLAY_SCENE := preload("res://scenes/ui/download_overlay.tscn")

const TEMPERATURE := 0.7
const TOP_P := 0.8
const TOP_K := 20
const PRESENCE_PENALTY := 1.5

var _enabled := false
var _model_loaded := false
var _llm: LLMInference = null
var _download_request: HTTPRequest = null
var _downloading := false
var _download_start_time := 0.0
var _setup_complete := false
var _pending_callbacks: Array[Callable] = []
var _request_queue: Array[Dictionary] = []
var _warming_up := false
var _generate_timer: Timer = null
var _generate_start_msec := 0


func _ready() -> void:
	_llm = LLMInference.new()
	_llm.n_gpu_layers = 99
	_llm.n_ctx = 2048
	_llm.n_predict = DEFAULT_N_PREDICT
	_llm.temperature = TEMPERATURE
	_llm.top_k = TOP_K
	_llm.top_p = TOP_P
	_llm.presence_penalty = PRESENCE_PENALTY
	_llm.generate_completed.connect(_on_generate_completed)
	_llm.model_loaded.connect(_on_model_loaded)
	add_child(_llm)

	_generate_timer = Timer.new()
	_generate_timer.one_shot = true
	_generate_timer.timeout.connect(_on_generate_timeout)
	add_child(_generate_timer)

	var overlay := DOWNLOAD_OVERLAY_SCENE.instantiate()
	add_child(overlay)

	_kill_stale_servers()
	_deferred_boot()


func _deferred_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_boot()


func _boot() -> void:
	var model_path := _find_model()
	print("[LLMManager] Model: %s" % model_path)

	if model_path != "":
		_load_model(model_path)
	else:
		_start_model_download()


func _process(_delta: float) -> void:
	if _downloading and _download_request != null:
		_emit_download_progress(_download_request, MODEL_EXPECTED_BYTES, _download_start_time, download_progress)


func _emit_download_progress(request: HTTPRequest, known_total: int, start_time: float, sig: Signal) -> void:
	var downloaded := request.get_downloaded_bytes()
	if downloaded <= 0:
		return

	var total := known_total if known_total > 0 else request.get_body_size()
	if total <= 0:
		return

	var percent := clampf((float(downloaded) / float(total)) * 100.0, 0.0, 99.9)
	var elapsed := (Time.get_ticks_msec() / 1000.0) - start_time
	var speed := float(downloaded) / maxf(elapsed, 0.1)

	sig.emit(percent, speed, downloaded, total)


func is_available() -> bool:
	return _enabled and _model_loaded


func is_downloading() -> bool:
	return _downloading


func is_setup_complete() -> bool:
	return _setup_complete


func generate(prompt: String, grammar: String, callback: Callable) -> void:
	if not is_available():
		callback.call("")
		return

	if _llm.is_running() or _warming_up:
		_request_queue.append({"prompt": prompt, "grammar": grammar, "callback": callback})
		return

	_pending_callbacks.append(callback)
	_generate_start_msec = Time.get_ticks_msec()
	_generate_timer.start(GENERATE_TIMEOUT_SEC)
	print("[LLMManager] Generate started (prompt %d chars)" % prompt.length())
	_llm.generate_async(prompt, grammar)


func _process_queue() -> void:
	if _request_queue.is_empty():
		return
	if _llm.is_running() or _warming_up:
		return
	if not is_available():
		for req: Dictionary in _request_queue:
			var cb: Callable = req.callback
			cb.call("")
		_request_queue.clear()
		return
	var req: Dictionary = _request_queue.pop_front()
	_pending_callbacks.append(req.callback)
	_generate_start_msec = Time.get_ticks_msec()
	_generate_timer.start(GENERATE_TIMEOUT_SEC)
	print("[LLMManager] Generate started from queue (prompt %d chars)" % req.prompt.length())
	_llm.generate_async(req.prompt, req.grammar)


func _load_model(model_path: String) -> void:
	_llm.model_path = model_path
	print("[LLMManager] Loading model (background)...")
	_llm.load_model_async()


func _on_model_loaded(success: bool) -> void:
	if success:
		_model_loaded = true
		_enabled = true
		print("[LLMManager] Model ready")
		server_ready.emit()
		_warmup()
	else:
		print("[LLMManager] Model load failed")
		_enabled = false
		server_failed.emit()
	_mark_setup_complete()


func _warmup() -> void:
	_warming_up = true
	_generate_start_msec = Time.get_ticks_msec()
	_llm.n_predict = 10
	print("[LLMManager] Warming up model...")
	_llm.generate_async(
		"<|im_start|>user\nSay hello.<|im_end|>\n<|im_start|>assistant\n",
		""
	)


func _on_generate_completed(text: String) -> void:
	_generate_timer.stop()

	if _warming_up:
		_warming_up = false
		_llm.n_predict = DEFAULT_N_PREDICT
		var elapsed := (Time.get_ticks_msec() - _generate_start_msec) / 1000.0
		print("[LLMManager] Warmup complete (%.1fs)" % elapsed)
		_process_queue()
		return

	var elapsed := (Time.get_ticks_msec() - _generate_start_msec) / 1000.0
	var result_len := text.length()
	if result_len == 0:
		print("[LLMManager] Generate done in %.1fs - empty result" % elapsed)
	else:
		print("[LLMManager] Generate done in %.1fs - %d chars" % [elapsed, result_len])

	if not _pending_callbacks.is_empty():
		var cb: Callable = _pending_callbacks.pop_front()
		cb.call(text)

	_process_queue()


func _on_generate_timeout() -> void:
	push_warning("[LLMManager] Generation timed out after %ds - dialogue skipped" % int(GENERATE_TIMEOUT_SEC))
	_llm.cancel_generate()
	if not _pending_callbacks.is_empty():
		var cb: Callable = _pending_callbacks.pop_front()
		cb.call("")
	_process_queue()


func _find_model() -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	var export_path := exe_dir.path_join("llm/" + MODEL_FILENAME)
	if FileAccess.file_exists(export_path):
		return export_path

	var user_path := OS.get_user_data_dir().path_join("llm/" + MODEL_FILENAME)
	if FileAccess.file_exists(user_path):
		return user_path

	var project_path := ProjectSettings.globalize_path("res://").path_join("llm/" + MODEL_FILENAME)
	if FileAccess.file_exists(project_path):
		return project_path

	return ""


func _start_model_download() -> void:
	var dir_path := OS.get_user_data_dir().path_join("llm")
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var dest_path := dir_path.path_join(MODEL_FILENAME)
	var partial_path := dest_path + ".part"

	_download_request = HTTPRequest.new()
	_download_request.download_file = partial_path
	_download_request.use_threads = true
	_download_request.request_completed.connect(_on_model_download_completed.bind(partial_path, dest_path))
	add_child(_download_request)

	print("[LLMManager] Downloading %s from Hugging Face..." % MODEL_NAME)
	download_started.emit(MODEL_NAME)

	_downloading = true
	_download_start_time = Time.get_ticks_msec() / 1000.0

	var err := _download_request.request(MODEL_URL)
	if err != OK:
		push_warning("[LLMManager] Download request failed: %d" % err)
		_downloading = false
		download_failed.emit("HTTP request failed")
		_mark_setup_complete()
		_download_request.queue_free()
		_download_request = null


func _on_model_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, partial_path: String, dest_path: String) -> void:
	_downloading = false
	_download_request.queue_free()
	_download_request = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[LLMManager] Download failed: result=%d code=%d" % [result, response_code])
		if FileAccess.file_exists(partial_path):
			DirAccess.remove_absolute(partial_path)
		download_failed.emit("Download failed (HTTP %d)" % response_code)
		_mark_setup_complete()
		return

	var dir := DirAccess.open(partial_path.get_base_dir())
	if dir:
		dir.rename(partial_path.get_file(), dest_path.get_file())

	print("[LLMManager] Download complete: %s" % dest_path)
	download_completed.emit()
	_load_model(dest_path)


func _mark_setup_complete() -> void:
	if _setup_complete:
		return
	_setup_complete = true
	setup_finished.emit()


func _kill_stale_servers() -> void:
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/F", "/IM", "llama-server.exe"], [], false)
	else:
		OS.execute("pkill", ["-f", "llama-server"], [], false)
