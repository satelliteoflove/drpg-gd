#ifndef LLM_INFERENCE_H
#define LLM_INFERENCE_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <llama.h>

#include <atomic>
#include <mutex>
#include <string>
#include <thread>

namespace godot {

class LLMInference : public Node {
    GDCLASS(LLMInference, Node)

    String model_path;
    int log_level = 3; // GGML_LOG_LEVEL_WARN
    int n_gpu_layers = 99;
    int n_ctx = 2048;
    int n_predict = 200;
    float temperature = 0.7f;
    int top_k = 20;
    float top_p = 0.8f;
    float presence_penalty = 1.5f;

    llama_model *model = nullptr;
    const llama_vocab *vocab = nullptr;

    std::thread worker;
    std::atomic<bool> running{false};
    std::atomic<bool> cancel_requested{false};
    std::atomic<bool> result_ready{false};
    std::atomic<bool> loading{false};
    std::atomic<bool> load_result_ready{false};
    std::atomic<bool> load_succeeded{false};

    std::mutex result_mutex;
    std::string pending_result;
    std::string pending_stats;

    std::thread loader;

    void _generate_thread(std::string prompt, std::string grammar);
    void _load_model_thread(std::string path);

protected:
    static void _bind_methods();

public:
    void set_model_path(const String &p_path);
    String get_model_path() const;
    void set_log_level(int p_level);
    int get_log_level() const;
    void set_n_gpu_layers(int p_layers);
    int get_n_gpu_layers() const;
    void set_n_ctx(int p_ctx);
    int get_n_ctx() const;
    void set_n_predict(int p_predict);
    int get_n_predict() const;
    void set_temperature(float p_temp);
    float get_temperature() const;
    void set_top_k(int p_top_k);
    int get_top_k() const;
    void set_top_p(float p_top_p);
    float get_top_p() const;
    void set_presence_penalty(float p_penalty);
    float get_presence_penalty() const;

    void load_model_async();
    bool is_loading() const;
    void unload_model();
    void generate_async(const String &prompt, const String &grammar);
    void cancel_generate();
    bool is_running() const;
    bool is_model_loaded() const;

    void _process(double delta) override;
    void _notification(int p_what);

    LLMInference();
    ~LLMInference();
};

}

#endif
