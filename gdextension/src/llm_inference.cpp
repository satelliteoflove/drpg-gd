#include "llm_inference.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <llama.h>

#include <ggml.h>

#include <cstring>
#include <vector>

static int s_min_log_level = GGML_LOG_LEVEL_WARN;

static bool str_contains(const char *haystack, const char *needle) {
    return haystack && needle && strstr(haystack, needle) != nullptr;
}

static void llm_log_callback(enum ggml_log_level level, const char *text, void *) {
    if (level == GGML_LOG_LEVEL_CONT || level < s_min_log_level) {
        return;
    }
    if (!text || text[0] == '\0' || (text[0] == '\n' && text[1] == '\0')) {
        return;
    }
    if (str_contains(text, "n_ctx_seq") && str_contains(text, "n_ctx_train")) {
        return;
    }
    if (level >= GGML_LOG_LEVEL_ERROR) {
        godot::UtilityFunctions::printerr("[llama.cpp] ", text);
    } else {
        godot::UtilityFunctions::print("[llama.cpp] ", text);
    }
}

namespace godot {

LLMInference::LLMInference() {
    llama_log_set(llm_log_callback, nullptr);
}

LLMInference::~LLMInference() {
    cancel_requested.store(true);
    if (worker.joinable()) {
        worker.join();
    }
    if (loader.joinable()) {
        loader.join();
    }
    if (model) {
        llama_model_free(model);
        model = nullptr;
    }
}

void LLMInference::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_model_path", "path"), &LLMInference::set_model_path);
    ClassDB::bind_method(D_METHOD("get_model_path"), &LLMInference::get_model_path);
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "model_path"), "set_model_path", "get_model_path");

    ClassDB::bind_method(D_METHOD("set_log_level", "level"), &LLMInference::set_log_level);
    ClassDB::bind_method(D_METHOD("get_log_level"), &LLMInference::get_log_level);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "log_level", PROPERTY_HINT_ENUM, "None:0,Debug:1,Info:2,Warn:3,Error:4"), "set_log_level", "get_log_level");

    ClassDB::bind_method(D_METHOD("set_n_gpu_layers", "layers"), &LLMInference::set_n_gpu_layers);
    ClassDB::bind_method(D_METHOD("get_n_gpu_layers"), &LLMInference::get_n_gpu_layers);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "n_gpu_layers"), "set_n_gpu_layers", "get_n_gpu_layers");

    ClassDB::bind_method(D_METHOD("set_n_ctx", "ctx"), &LLMInference::set_n_ctx);
    ClassDB::bind_method(D_METHOD("get_n_ctx"), &LLMInference::get_n_ctx);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "n_ctx"), "set_n_ctx", "get_n_ctx");

    ClassDB::bind_method(D_METHOD("set_n_predict", "predict"), &LLMInference::set_n_predict);
    ClassDB::bind_method(D_METHOD("get_n_predict"), &LLMInference::get_n_predict);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "n_predict"), "set_n_predict", "get_n_predict");

    ClassDB::bind_method(D_METHOD("set_temperature", "temp"), &LLMInference::set_temperature);
    ClassDB::bind_method(D_METHOD("get_temperature"), &LLMInference::get_temperature);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "temperature"), "set_temperature", "get_temperature");

    ClassDB::bind_method(D_METHOD("set_top_k", "k"), &LLMInference::set_top_k);
    ClassDB::bind_method(D_METHOD("get_top_k"), &LLMInference::get_top_k);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "top_k"), "set_top_k", "get_top_k");

    ClassDB::bind_method(D_METHOD("set_top_p", "p"), &LLMInference::set_top_p);
    ClassDB::bind_method(D_METHOD("get_top_p"), &LLMInference::get_top_p);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "top_p"), "set_top_p", "get_top_p");

    ClassDB::bind_method(D_METHOD("set_presence_penalty", "penalty"), &LLMInference::set_presence_penalty);
    ClassDB::bind_method(D_METHOD("get_presence_penalty"), &LLMInference::get_presence_penalty);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "presence_penalty"), "set_presence_penalty", "get_presence_penalty");

    ClassDB::bind_method(D_METHOD("load_model_async"), &LLMInference::load_model_async);
    ClassDB::bind_method(D_METHOD("is_loading"), &LLMInference::is_loading);
    ClassDB::bind_method(D_METHOD("unload_model"), &LLMInference::unload_model);
    ClassDB::bind_method(D_METHOD("generate_async", "prompt", "grammar"), &LLMInference::generate_async);
    ClassDB::bind_method(D_METHOD("is_running"), &LLMInference::is_running);
    ClassDB::bind_method(D_METHOD("is_model_loaded"), &LLMInference::is_model_loaded);

    ADD_SIGNAL(MethodInfo("model_loaded", PropertyInfo(Variant::BOOL, "success")));
    ADD_SIGNAL(MethodInfo("generate_completed", PropertyInfo(Variant::STRING, "text")));
}

void LLMInference::set_model_path(const String &p_path) { model_path = p_path; }
String LLMInference::get_model_path() const { return model_path; }
void LLMInference::set_log_level(int p_level) { log_level = p_level; s_min_log_level = p_level; }
int LLMInference::get_log_level() const { return log_level; }
void LLMInference::set_n_gpu_layers(int p_layers) { n_gpu_layers = p_layers; }
int LLMInference::get_n_gpu_layers() const { return n_gpu_layers; }
void LLMInference::set_n_ctx(int p_ctx) { n_ctx = p_ctx; }
int LLMInference::get_n_ctx() const { return n_ctx; }
void LLMInference::set_n_predict(int p_predict) { n_predict = p_predict; }
int LLMInference::get_n_predict() const { return n_predict; }
void LLMInference::set_temperature(float p_temp) { temperature = p_temp; }
float LLMInference::get_temperature() const { return temperature; }
void LLMInference::set_top_k(int p_top_k) { top_k = p_top_k; }
int LLMInference::get_top_k() const { return top_k; }
void LLMInference::set_top_p(float p_top_p) { top_p = p_top_p; }
float LLMInference::get_top_p() const { return top_p; }
void LLMInference::set_presence_penalty(float p_penalty) { presence_penalty = p_penalty; }
float LLMInference::get_presence_penalty() const { return presence_penalty; }

void LLMInference::load_model_async() {
    if (loading.load()) {
        return;
    }
    if (loader.joinable()) {
        loader.join();
    }

    if (model) {
        llama_model_free(model);
        model = nullptr;
        vocab = nullptr;
    }

    loading.store(true);
    load_result_ready.store(false);

    std::string path = model_path.utf8().get_data();
    loader = std::thread(&LLMInference::_load_model_thread, this, path);
}

bool LLMInference::is_loading() const {
    return loading.load();
}

void LLMInference::_load_model_thread(std::string path) {
    llama_model_params params = llama_model_default_params();
    params.n_gpu_layers = n_gpu_layers;

    llama_model *m = llama_model_load_from_file(path.c_str(), params);
    if (m) {
        model = m;
        vocab = llama_model_get_vocab(m);
        load_succeeded.store(true);
    } else {
        load_succeeded.store(false);
    }
    load_result_ready.store(true);
    loading.store(false);
}

void LLMInference::unload_model() {
    cancel_requested.store(true);
    if (worker.joinable()) {
        worker.join();
    }
    cancel_requested.store(false);

    if (model) {
        llama_model_free(model);
        model = nullptr;
        vocab = nullptr;
    }
}

bool LLMInference::is_running() const {
    return running.load();
}

bool LLMInference::is_model_loaded() const {
    return model != nullptr;
}

void LLMInference::generate_async(const String &prompt, const String &grammar) {
    if (running.load()) {
        UtilityFunctions::printerr("[LLMInference] Generation already in progress");
        return;
    }
    if (!model) {
        UtilityFunctions::printerr("[LLMInference] No model loaded");
        emit_signal("generate_completed", String(""));
        return;
    }

    if (worker.joinable()) {
        worker.join();
    }

    cancel_requested.store(false);
    result_ready.store(false);
    running.store(true);

    std::string prompt_str = prompt.utf8().get_data();
    std::string grammar_str = grammar.utf8().get_data();

    worker = std::thread(&LLMInference::_generate_thread, this, prompt_str, grammar_str);
}

void LLMInference::_generate_thread(std::string prompt, std::string grammar) {
    std::string result;

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = n_ctx;
    ctx_params.n_batch = n_ctx;

    llama_context *ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        std::lock_guard<std::mutex> lock(result_mutex);
        pending_result = "";
        result_ready.store(true);
        running.store(false);
        return;
    }

    try {

    int n_prompt_tokens = -llama_tokenize(vocab, prompt.c_str(), prompt.size(), nullptr, 0, true, true);
    std::vector<llama_token> tokens(n_prompt_tokens);
    llama_tokenize(vocab, prompt.c_str(), prompt.size(), tokens.data(), tokens.size(), true, true);

    llama_sampler_chain_params chain_params = llama_sampler_chain_default_params();
    llama_sampler *sampler = llama_sampler_chain_init(chain_params);

    if (presence_penalty != 0.0f) {
        llama_sampler_chain_add(sampler, llama_sampler_init_penalties(64, 1.0f, 0.0f, presence_penalty));
    }

    if (!grammar.empty()) {
        llama_sampler *grammar_sampler = llama_sampler_init_grammar(vocab, grammar.c_str(), "root");
        if (grammar_sampler) {
            llama_sampler_chain_add(sampler, grammar_sampler);
        }
    }

    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(top_p, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(0));

    // Accept prompt tokens through the sampler chain so grammar tracks state
    for (size_t i = 0; i < tokens.size(); i++) {
        llama_sampler_accept(sampler, tokens[i]);
    }

    llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
    if (llama_decode(ctx, batch) != 0) {
        llama_sampler_free(sampler);
        llama_free(ctx);
        std::lock_guard<std::mutex> lock(result_mutex);
        pending_result = "";
        result_ready.store(true);
        running.store(false);
        return;
    }

    llama_token eos = llama_vocab_eos(vocab);
    int generated = 0;

    while (generated < n_predict && !cancel_requested.load()) {
        llama_token new_token = llama_sampler_sample(sampler, ctx, -1);
        llama_sampler_accept(sampler, new_token);

        if (new_token == eos) {
            break;
        }

        char piece_buf[64];
        int piece_len = llama_token_to_piece(vocab, new_token, piece_buf, sizeof(piece_buf), 0, false);
        if (piece_len > 0) {
            result.append(piece_buf, piece_len);

            if (result.size() >= 2) {
                size_t pos = result.find("\n\n");
                if (pos != std::string::npos) {
                    result.resize(pos);
                    break;
                }
            }
        }

        batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(ctx, batch) != 0) {
            break;
        }

        generated++;
    }

    llama_sampler_free(sampler);
    llama_free(ctx);

    } catch (...) {
        llama_free(ctx);
        result = "";
    }

    {
        std::lock_guard<std::mutex> lock(result_mutex);
        pending_result = result;
    }
    result_ready.store(true);
    running.store(false);
}

void LLMInference::_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) {
        return;
    }

    if (load_result_ready.load()) {
        load_result_ready.store(false);
        bool success = load_succeeded.load();
        emit_signal("model_loaded", success);
    }

    if (result_ready.load()) {
        result_ready.store(false);
        std::string result_copy;
        {
            std::lock_guard<std::mutex> lock(result_mutex);
            result_copy = pending_result;
            pending_result.clear();
        }
        emit_signal("generate_completed", String(result_copy.c_str()));
    }
}

void LLMInference::_notification(int p_what) {
    if (p_what == NOTIFICATION_PREDELETE || p_what == NOTIFICATION_WM_CLOSE_REQUEST) {
        cancel_requested.store(true);
        if (worker.joinable()) {
            worker.join();
        }
        if (loader.joinable()) {
            loader.join();
        }
    }
}

}
