class_name LLMManagerClass
extends Node

signal server_ready
signal server_failed
signal download_started(model_name: String)
signal download_progress(percent: float, speed_bps: float, downloaded: int, total: int)
signal download_completed
signal download_failed(reason: String)
signal binary_download_started(variant: String)
signal binary_download_progress(percent: float, speed_bps: float, downloaded: int, total: int)
signal binary_download_completed
signal binary_download_failed(reason: String)
signal setup_finished

const PORT := 8787
const HEALTH_TIMEOUT := 30.0
const HEALTH_POLL_INTERVAL := 1.0
const DEFAULT_N_PREDICT := 128
const GENERATE_TIMEOUT_SEC := 15.0

const MODEL_NAME := "Qwen3.5-4B-Q8_0"
const MODEL_FILENAME := "Qwen3.5-4B-Q8_0.gguf"
const MODEL_URL := "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q8_0.gguf"
const MODEL_EXPECTED_BYTES := 4482403488

const LLAMA_VERSION := "b8575"
const LLAMA_RELEASE_BASE := "https://github.com/ggml-org/llama.cpp/releases/download"

const ARCHIVES := {
	"win-cuda": "llama-b8575-bin-win-cuda-12.4-x64.zip",
	"win-vulkan": "llama-b8575-bin-win-vulkan-x64.zip",
	"win-cpu": "llama-b8575-bin-win-cpu-x64.zip",
	"win-cudart": "cudart-llama-bin-win-cuda-12.4-x64.zip",
	"macos-arm64": "llama-b8575-bin-macos-arm64.tar.gz",
	"macos-x64": "llama-b8575-bin-macos-x64.tar.gz",
	"linux-vulkan": "llama-b8575-bin-ubuntu-vulkan-x64.tar.gz",
	"linux-cpu": "llama-b8575-bin-ubuntu-x64.tar.gz",
}

const DOWNLOAD_OVERLAY_SCENE := preload("res://scenes/ui/download_overlay.tscn")

const TEMPERATURE := 0.7
const TOP_P := 0.8
const TOP_K := 20
const PRESENCE_PENALTY := 1.5

var _enabled := false
var _server_healthy := false
var _pid: int = -1
var _generating := false
var _health_timer: Timer = null
var _health_elapsed := 0.0
var _health_request: HTTPRequest = null
var _completion_request: HTTPRequest = null
var _download_request: HTTPRequest = null
var _binary_download_request: HTTPRequest = null
var _downloading := false
var _downloading_binary := false
var _download_start_time := 0.0
var _binary_download_start_time := 0.0
var _gpu_vendor := ""
var _pending_cudart_dir := ""
var _setup_complete := false
var _pending_callbacks: Array[Callable] = []
var _request_queue: Array[Dictionary] = []
var _generate_timer: Timer = null
var _generate_start_msec := 0


func _ready() -> void:
	set_process(false)
	_health_request = HTTPRequest.new()
	_health_request.request_completed.connect(_on_health_completed)
	add_child(_health_request)

	_completion_request = HTTPRequest.new()
	_completion_request.request_completed.connect(_on_completion_completed)
	add_child(_completion_request)

	_generate_timer = Timer.new()
	_generate_timer.one_shot = true
	_generate_timer.timeout.connect(_on_generate_timeout)
	add_child(_generate_timer)

	var overlay := DOWNLOAD_OVERLAY_SCENE.instantiate()
	add_child(overlay)

	_gpu_vendor = _detect_gpu_vendor()
	_kill_stale_servers()
	_deferred_boot()


func _deferred_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_boot()


func _boot() -> void:
	var binary_path := _find_binary()
	var model_path := _find_model()
	print_debug("[LLMManager] Binary: %s" % binary_path)
	print_debug("[LLMManager] Model: %s" % model_path)

	if binary_path != "" and _check_binary_version(binary_path):
		if model_path != "":
			_start_server(model_path)
		else:
			_start_model_download()
	elif binary_path != "":
		print_debug("[LLMManager] Binary version mismatch, re-downloading")
		_start_binary_download()
	else:
		print_debug("[LLMManager] No llama-server binary found, attempting download")
		_start_binary_download()


func _process(_delta: float) -> void:
	if _downloading and _download_request != null:
		_emit_download_progress(_download_request, MODEL_EXPECTED_BYTES, _download_start_time, download_progress)

	if _downloading_binary and _binary_download_request != null:
		_emit_download_progress(_binary_download_request, 0, _binary_download_start_time, binary_download_progress)

	if not _downloading and not _downloading_binary:
		set_process(false)


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


var debug_force_fallback := false


func is_available() -> bool:
	if debug_force_fallback:
		return false
	return _enabled and _server_healthy


func toggle_debug_fallback() -> void:
	debug_force_fallback = not debug_force_fallback
	var state := "ON (forcing fallback)" if debug_force_fallback else "OFF (LLM active)"
	print_debug("[LLMManager] Debug fallback: %s" % state)


func is_downloading() -> bool:
	return _downloading


func is_downloading_binary() -> bool:
	return _downloading_binary


func is_setup_complete() -> bool:
	return _setup_complete


func generate(messages: Dictionary, grammar: String, callback: Callable) -> void:
	if not is_available():
		print_debug("[LLMManager] Not available, falling back to static dialogue")
		callback.call("")
		return

	if _generating:
		_request_queue.append({"messages": messages, "grammar": grammar, "callback": callback})
		return

	_send_completion(messages, grammar, callback)


func _send_completion(messages: Dictionary, grammar: String, callback: Callable) -> void:
	_generating = true
	_pending_callbacks = [callback]
	_generate_start_msec = Time.get_ticks_msec()

	var prompt := "<|im_start|>system\n%s<|im_end|>\n<|im_start|>user\n%s<|im_end|>\n<|im_start|>assistant\n<think>\n</think>\n" % [messages.get("system", ""), messages.get("user", "")]

	var body := {
		"prompt": prompt,
		"n_predict": DEFAULT_N_PREDICT,
		"temperature": TEMPERATURE,
		"top_p": TOP_P,
		"top_k": TOP_K,
		"presence_penalty": PRESENCE_PENALTY,
		"stop": ["<|im_end|>"],
		"timings": true,
	}
	if grammar != "":
		body["grammar"] = grammar

	var headers := ["Content-Type: application/json"]
	var url := "http://127.0.0.1:%d/completion" % PORT
	var json_body := JSON.stringify(body)
	var err := _completion_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		push_warning("[LLMManager] HTTP request failed: %d" % err)
		_generating = false
		callback.call("")
		_process_queue()
		return

	_generate_timer.start(GENERATE_TIMEOUT_SEC)
	print_debug("[LLMManager] Generate started (prompt %d chars)" % prompt.length())


func _process_queue() -> void:
	if _request_queue.is_empty():
		return
	var next: Dictionary = _request_queue.pop_front()
	_send_completion(next["messages"], next["grammar"], next["callback"])


func _on_completion_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_generate_timer.stop()
	var elapsed_ms := Time.get_ticks_msec() - _generate_start_msec
	var timed_out := _timed_out
	_timed_out = false

	if timed_out:
		_log_timeout_response(result, response_code, body, elapsed_ms)
		_generating = false
		_process_queue()
		return

	_generating = false

	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("[LLMManager] HTTP result error: %d (code %d) after %.1fs" % [result, response_code, elapsed_ms / 1000.0])
	var callback: Callable = _pending_callbacks[0] if not _pending_callbacks.is_empty() else Callable()
	_pending_callbacks.clear()

	if not callback.is_valid():
		_process_queue()
		return

	if response_code != 200:
		push_warning("[LLMManager] Completion request failed: %d" % response_code)
		push_warning("[LLMManager] Generate done in %.1fs - failed (HTTP %d)" % [elapsed_ms / 1000.0, response_code])
		callback.call("")
		_process_queue()
		return

	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d := parsed as Dictionary
		var raw_content: String = d.get("content", "")
		var content := _strip_think_block(raw_content)
		var think_len := raw_content.length() - content.length()
		var timings_str := _format_timings(d)
		print_debug("[LLMManager] Generate done in %.1fs - %d think + %d content chars%s" % [elapsed_ms / 1000.0, think_len, content.length(), timings_str])
		if content.length() > 0 and content.length() < 80:
			print_debug("[LLMManager] Content: %s" % content)
		elif content.length() == 0 and raw_content.length() > 0:
			print_debug("[LLMManager] Think-only response (no usable content)")
		callback.call(content)
	else:
		push_warning("[LLMManager] Failed to parse completion response")
		push_warning("[LLMManager] Generate done in %.1fs - parse error" % [elapsed_ms / 1000.0])
		callback.call("")

	_process_queue()


var _timed_out := false


func _on_generate_timeout() -> void:
	push_warning("[LLMManager] Generate timed out after %.1fs - waiting for response to diagnose" % GENERATE_TIMEOUT_SEC)
	_timed_out = true

	var callback: Callable = _pending_callbacks[0] if not _pending_callbacks.is_empty() else Callable()
	_pending_callbacks.clear()
	if callback.is_valid():
		callback.call("")

	_request_queue.clear()


func _log_timeout_response(result: int, response_code: int, body: PackedByteArray, elapsed_ms: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[LLMManager] Timed-out request finally returned: result=%d code=%d after %.1fs" % [result, response_code, elapsed_ms / 1000.0])
		return
	var text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("[LLMManager] Timed-out request: unparseable after %.1fs" % [elapsed_ms / 1000.0])
		return
	var d := parsed as Dictionary
	var raw_content: String = d.get("content", "")
	var content := _strip_think_block(raw_content)
	var think_len := raw_content.length() - content.length()
	var timings_str := _format_timings(d)
	push_warning("[LLMManager] TIMEOUT diagnosed in %.1fs - %d think + %d content chars%s" % [elapsed_ms / 1000.0, think_len, content.length(), timings_str])
	push_warning("[LLMManager] TIMEOUT content: %s" % content.substr(0, 500))


func _format_timings(response: Dictionary) -> String:
	var timings: Variant = response.get("timings", null)
	if not timings is Dictionary:
		return ""
	var t := timings as Dictionary
	var prompt_n: int = int(t.get("prompt_n", 0))
	var predicted_n: int = int(t.get("predicted_n", 0))
	var predicted_per_sec: float = t.get("predicted_per_second", 0.0)
	var stop_type: String = response.get("stop_type", "unknown")
	return " | %d prompt tok, %d generated tok @ %.1f tok/s, stop: %s" % [prompt_n, predicted_n, predicted_per_sec, stop_type]



func _strip_think_block(content: String) -> String:
	var think_end := content.find("</think>")
	if think_end >= 0:
		content = content.substr(think_end + 8).strip_edges()
	elif content.begins_with("<think>"):
		return ""
	return _strip_markdown_fences(content)


func _strip_markdown_fences(content: String) -> String:
	var s := content.strip_edges()
	if not s.begins_with("```"):
		return s
	var first_newline := s.find("\n")
	if first_newline < 0:
		return s
	s = s.substr(first_newline + 1)
	if s.ends_with("```"):
		s = s.substr(0, s.length() - 3)
	return s.strip_edges()


func _get_platform_binary_name() -> String:
	match OS.get_name():
		"Windows":
			return "llama-server.exe"
		"macOS":
			if OS.has_feature("arm64"):
				return "llama-server-arm64"
			return "llama-server-x64"
		_:
			return "llama-server"


func _detect_gpu_vendor() -> String:
	var adapter := RenderingServer.get_video_adapter_name().to_upper()
	var vendor := "none"
	if "NVIDIA" in adapter or "GEFORCE" in adapter or "RTX" in adapter or "GTX" in adapter:
		vendor = "nvidia"
	elif "AMD" in adapter or "RADEON" in adapter:
		vendor = "amd"
	elif "INTEL" in adapter or "ARC" in adapter:
		vendor = "intel"
	print_debug("[LLMManager] GPU adapter: %s (vendor: %s)" % [RenderingServer.get_video_adapter_name(), vendor])
	return vendor


func _get_archive_key() -> String:
	match OS.get_name():
		"Windows":
			if _gpu_vendor == "nvidia":
				return "win-cuda"
			if _gpu_vendor == "amd" or _gpu_vendor == "intel":
				return "win-vulkan"
			return "win-cpu"
		"macOS":
			if OS.has_feature("arm64"):
				return "macos-arm64"
			return "macos-x64"
		_:
			if _gpu_vendor == "nvidia" or _gpu_vendor == "amd" or _gpu_vendor == "intel":
				return "linux-vulkan"
			return "linux-cpu"


func _get_variant_label() -> String:
	var key := _get_archive_key()
	if "cuda" in key:
		return "CUDA"
	if "vulkan" in key:
		return "Vulkan"
	if OS.get_name() == "macOS":
		return "Metal"
	return "CPU"


func _get_version_tag() -> String:
	return "%s:%s" % [LLAMA_VERSION, ARCHIVES[_get_archive_key()]]


func _check_binary_version(binary_path: String) -> bool:
	var llm_dir := binary_path.get_base_dir()
	var version_path := llm_dir.path_join(".version")
	if not FileAccess.file_exists(version_path):
		return true
	var stored := FileAccess.get_file_as_string(version_path).strip_edges()
	if ":" in stored:
		return stored == _get_version_tag()
	return stored == LLAMA_VERSION


func _clear_llm_binaries(llm_dir: String) -> void:
	var dir := DirAccess.open(llm_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and not fname.ends_with(".gguf") and not fname.ends_with(".gguf.part"):
			DirAccess.remove_absolute(llm_dir.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()


func _start_binary_download() -> void:
	var dir_path := OS.get_user_data_dir().path_join("llm")
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	_clear_llm_binaries(dir_path)

	var archive_key := _get_archive_key()
	var archive_name: String = ARCHIVES[archive_key]
	var url := "%s/%s/%s" % [LLAMA_RELEASE_BASE, LLAMA_VERSION, archive_name]
	var dest_path := dir_path.path_join(archive_name)

	_binary_download_request = HTTPRequest.new()
	_binary_download_request.download_file = dest_path
	_binary_download_request.use_threads = true
	_binary_download_request.request_completed.connect(_on_binary_download_completed.bind(dest_path, dir_path))
	add_child(_binary_download_request)

	var variant := _get_variant_label()
	print_debug("[LLMManager] Downloading llama-server %s (%s)..." % [LLAMA_VERSION, variant])
	binary_download_started.emit(variant)

	_downloading_binary = true
	set_process(true)
	_binary_download_start_time = Time.get_ticks_msec() / 1000.0

	var err := _binary_download_request.request(url)
	if err != OK:
		push_warning("[LLMManager] Binary download request failed: %d" % err)
		_downloading_binary = false
		binary_download_failed.emit("HTTP request failed")
		_mark_setup_complete()
		_binary_download_request.queue_free()
		_binary_download_request = null


func _on_binary_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, archive_path: String, llm_dir: String) -> void:
	_downloading_binary = false
	_binary_download_request.queue_free()
	_binary_download_request = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[LLMManager] Binary download failed: result=%d code=%d" % [result, response_code])
		if FileAccess.file_exists(archive_path):
			DirAccess.remove_absolute(archive_path)
		binary_download_failed.emit("Download failed (HTTP %d)" % response_code)
		_enabled = false
		_mark_setup_complete()
		return

	print_debug("[LLMManager] Binary archive downloaded, extracting...")
	var ok := _extract_binary_archive(archive_path, llm_dir)
	if not ok:
		return

	if _get_archive_key() == "win-cuda":
		_download_cudart(llm_dir)
	else:
		_finish_binary_setup(llm_dir)


func _download_cudart(llm_dir: String) -> void:
	var archive_name: String = ARCHIVES["win-cudart"]
	var url := "%s/%s/%s" % [LLAMA_RELEASE_BASE, LLAMA_VERSION, archive_name]
	var dest_path := llm_dir.path_join(archive_name)

	_pending_cudart_dir = llm_dir

	_binary_download_request = HTTPRequest.new()
	_binary_download_request.download_file = dest_path
	_binary_download_request.use_threads = true
	_binary_download_request.request_completed.connect(_on_cudart_download_completed.bind(dest_path, llm_dir))
	add_child(_binary_download_request)

	print_debug("[LLMManager] Downloading CUDA runtime DLLs...")
	_downloading_binary = true
	set_process(true)
	_binary_download_start_time = Time.get_ticks_msec() / 1000.0

	var err := _binary_download_request.request(url)
	if err != OK:
		push_warning("[LLMManager] CUDA runtime download failed: %d" % err)
		_downloading_binary = false
		binary_download_failed.emit("CUDA runtime download failed")
		_mark_setup_complete()
		_binary_download_request.queue_free()
		_binary_download_request = null


func _on_cudart_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, archive_path: String, llm_dir: String) -> void:
	_downloading_binary = false
	_binary_download_request.queue_free()
	_binary_download_request = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[LLMManager] CUDA runtime download failed: result=%d code=%d" % [result, response_code])
		if FileAccess.file_exists(archive_path):
			DirAccess.remove_absolute(archive_path)
		binary_download_failed.emit("CUDA runtime download failed (HTTP %d)" % response_code)
		_enabled = false
		_mark_setup_complete()
		return

	print_debug("[LLMManager] CUDA runtime downloaded, extracting...")
	var binary_name := _get_platform_binary_name()
	_extract_zip(archive_path, llm_dir, binary_name)
	DirAccess.remove_absolute(archive_path)

	_finish_binary_setup(llm_dir)


func _finish_binary_setup(llm_dir: String) -> void:
	var binary_name := _get_platform_binary_name()

	var version_path := llm_dir.path_join(".version")
	var f := FileAccess.open(version_path, FileAccess.WRITE)
	if f:
		f.store_string(_get_version_tag())
		f.close()

	if OS.get_name() != "Windows":
		var binary_path := llm_dir.path_join(binary_name)
		OS.execute("chmod", ["+x", binary_path])
		if OS.get_name() == "macOS":
			OS.execute("xattr", ["-cr", binary_path])

	print_debug("[LLMManager] Binary extracted to %s" % llm_dir)
	binary_download_completed.emit()

	var model_path := _find_model()
	if model_path != "":
		_start_server(model_path)
	else:
		_start_model_download()


func _extract_binary_archive(archive_path: String, llm_dir: String) -> bool:
	var binary_name := _get_platform_binary_name()
	var ok: bool

	if OS.get_name() == "Windows":
		ok = _extract_zip(archive_path, llm_dir, binary_name)
	else:
		ok = _extract_tar(archive_path, llm_dir, binary_name)

	DirAccess.remove_absolute(archive_path)

	if not ok:
		binary_download_failed.emit("Failed to extract archive")
		_enabled = false
		_mark_setup_complete()

	return ok


func _extract_zip(archive_path: String, llm_dir: String, binary_name: String) -> bool:
	var reader := ZIPReader.new()
	var err := reader.open(archive_path)
	if err != OK:
		push_warning("[LLMManager] Failed to open zip: %d" % err)
		return false

	for file_path in reader.get_files():
		var filename := file_path.get_file()
		if filename == "":
			continue
		if filename == "llama-server.exe" or filename.ends_with(".dll"):
			var data := reader.read_file(file_path)
			var out_name := filename
			if filename == "llama-server.exe":
				out_name = binary_name
			var out_path := llm_dir.path_join(out_name)
			var f := FileAccess.open(out_path, FileAccess.WRITE)
			if f:
				f.store_buffer(data)
				f.close()

	reader.close()
	return true


func _extract_tar(archive_path: String, llm_dir: String, binary_name: String) -> bool:
	var temp_dir := archive_path + "_extract"
	DirAccess.make_dir_recursive_absolute(temp_dir)

	var output := []
	var exit_code := OS.execute("tar", ["xzf", archive_path, "-C", temp_dir], output)
	if exit_code != 0:
		push_warning("[LLMManager] tar extraction failed (exit %d): %s" % [exit_code, str(output)])
		_rm_rf(temp_dir)
		return false

	var bin_src := _find_file_recursive(temp_dir, "llama-server")
	if bin_src == "":
		push_warning("[LLMManager] llama-server not found in archive")
		_rm_rf(temp_dir)
		return false

	var archive_dir := bin_src.get_base_dir()
	var data := FileAccess.get_file_as_bytes(bin_src)
	var dest := llm_dir.path_join(binary_name)
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()

	var dir := DirAccess.open(archive_dir)
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and (fname.ends_with(".dylib") or fname.ends_with(".so") or ".so." in fname):
				var src := archive_dir.path_join(fname)
				var lib_dest := llm_dir.path_join(fname)
				var lib_data := FileAccess.get_file_as_bytes(src)
				var out := FileAccess.open(lib_dest, FileAccess.WRITE)
				if out:
					out.store_buffer(lib_data)
					out.close()
			fname = dir.get_next()
		dir.list_dir_end()

	_rm_rf(temp_dir)
	return true


func _find_file_recursive(dir_path: String, target: String) -> String:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return ""
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := dir_path.path_join(fname)
		if dir.current_is_dir():
			var found := _find_file_recursive(full, target)
			if found != "":
				dir.list_dir_end()
				return found
		elif fname == target:
			dir.list_dir_end()
			return full
		fname = dir.get_next()
	dir.list_dir_end()
	return ""


func _rm_rf(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := path.path_join(fname)
		if dir.current_is_dir():
			_rm_rf(full)
		else:
			DirAccess.remove_absolute(full)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


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

	print_debug("[LLMManager] Downloading %s from Hugging Face..." % MODEL_NAME)
	download_started.emit(MODEL_NAME)

	_downloading = true
	set_process(true)
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

	print_debug("[LLMManager] Download complete: %s" % dest_path)
	download_completed.emit()
	_start_server(dest_path)


func _start_server(model_path: String) -> void:
	var binary_path := _find_binary()

	if binary_path == "":
		push_warning("[LLMManager] No llama-server binary found, LLM disabled")
		_enabled = false
		_mark_setup_complete()
		return

	var args := PackedStringArray([
		"--port", str(PORT),
		"--model", model_path,
		"--ctx-size", "2048",
		"--n-predict", str(DEFAULT_N_PREDICT),
		"--reasoning-format", "none",
		"-ngl", "99",
		"--no-context-shift",
		"--log-disable",
	])

	_pid = OS.create_process(binary_path, args)
	if _pid <= 0:
		push_warning("[LLMManager] Failed to launch llama-server")
		_enabled = false
		_mark_setup_complete()
		return

	_enabled = true
	print_debug("[LLMManager] Started llama-server (PID %d)" % _pid)

	_health_elapsed = 0.0
	_health_timer = Timer.new()
	_health_timer.wait_time = HEALTH_POLL_INTERVAL
	_health_timer.timeout.connect(_poll_health)
	add_child(_health_timer)
	_health_timer.start()


func _find_binary() -> String:
	var binary_name := _get_platform_binary_name()

	var exe_dir := OS.get_executable_path().get_base_dir()
	var export_path := exe_dir.path_join("llm/" + binary_name)
	if FileAccess.file_exists(export_path):
		return export_path

	var user_path := OS.get_user_data_dir().path_join("llm/" + binary_name)
	if FileAccess.file_exists(user_path):
		return user_path

	var project_path := ProjectSettings.globalize_path("res://").path_join("llm/" + binary_name)
	if FileAccess.file_exists(project_path):
		return project_path

	return ""


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


func _poll_health() -> void:
	_health_elapsed += HEALTH_POLL_INTERVAL
	if _health_elapsed >= HEALTH_TIMEOUT:
		push_warning("[LLMManager] Health check timed out after %.0fs" % HEALTH_TIMEOUT)
		_health_timer.stop()
		_health_timer.queue_free()
		_health_timer = null
		_enabled = false
		server_failed.emit()
		_mark_setup_complete()
		return

	var url := "http://127.0.0.1:%d/health" % PORT
	var err := _health_request.request(url)
	if err != OK:
		pass


func _on_health_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		_server_healthy = true
		print_debug("[LLMManager] Server healthy")
		if _health_timer:
			_health_timer.stop()
			_health_timer.queue_free()
			_health_timer = null
		server_ready.emit()
		_mark_setup_complete()
		_warmup()


func _warmup() -> void:
	var warmup_request := HTTPRequest.new()
	add_child(warmup_request)
	warmup_request.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		print_debug("[LLMManager] Warmup complete")
		warmup_request.queue_free()
	)
	var body := {
		"prompt": "<|im_start|>user\nSay hello.<|im_end|>\n<|im_start|>assistant\n",
		"n_predict": 8,
		"temperature": TEMPERATURE,
		"stop": ["<|im_end|>"],
	}
	var headers := ["Content-Type: application/json"]
	var url := "http://127.0.0.1:%d/completion" % PORT
	warmup_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	print_debug("[LLMManager] Warming up model...")


func _mark_setup_complete() -> void:
	if _setup_complete:
		return
	_setup_complete = true
	setup_finished.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_kill_server()


func _kill_server() -> void:
	if _pid > 0:
		OS.kill(_pid)
		print_debug("[LLMManager] Killed llama-server (PID %d)" % _pid)
		_pid = -1
	_server_healthy = false


func _kill_stale_servers() -> void:
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/F", "/IM", "llama-server.exe"], [], false)
	else:
		OS.execute("pkill", ["-f", "llama-server"], [], false)
