import subprocess
import requests
import time
import json
import sys
import os
import signal
from pathlib import Path

PORT = 8787
HEALTH_TIMEOUT = 60
GENERATE_TIMEOUT = 30

TEMPERATURE = 0.7
TOP_P = 0.8
TOP_K = 20
PRESENCE_PENALTY = 1.5
N_PREDICT = 128

MODELS = {
    "Q8_0": {
        "filename": "Qwen3.5-4B-Q8_0.gguf",
        "url": "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q8_0.gguf",
    },
    "Q5_K_M": {
        "filename": "Qwen3.5-4B-Q5_K_M.gguf",
        "url": "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q5_K_M.gguf",
    },
    "UD-Q4_K_XL": {
        "filename": "Qwen3.5-4B-UD-Q4_K_XL.gguf",
        "url": "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-UD-Q4_K_XL.gguf",
    },
}

SYSTEM_MSG = (
    "You write casual, natural-sounding dialogue for RPG party members. "
    "They talk like real people -- not fantasy novels. No thee/thou, no dramatic "
    "monologues, no narration or stage directions. Just the spoken line. Short, "
    "conversational, sometimes funny. Each character has a distinct voice shaped "
    "by their personality."
)

PROMPTS = [
    # Micro conversation: two characters
    {
        "label": "Brave fighter + sarcastic rogue, post-combat",
        "user": (
            'Speaker: Theron, Human Fighter. Personality: Brave. '
            'Voice: confident, doesn\'t overthink it.\n'
            'Responder: Kess, Elf Rogue. Personality: Sarcastic. '
            'Voice: dry, says the opposite of what they mean.\n'
            'Situation: The party just barely survived a tough fight.\n'
            'Write two lines: first Theron speaks (5-20 words), then Kess '
            'replies to what they said (5-20 words).\n'
            'Respond with JSON array: [{"name": "Theron", "line": "..."}, '
            '{"name": "Kess", "line": "..."}]'
        ),
    },
    # Micro solo: single character
    {
        "label": "Cautious cleric, exploring dungeon",
        "user": (
            'Elara, Human Cleric. Personality: Cautious, Merciful. '
            'Voice: nervous, second-guesses things; soft-hearted, worries about everyone.\n'
            'Situation: The party enters a dark chamber with strange markings on the walls.\n'
            'Write one short spoken line (5-20 words).\n'
            'Respond with JSON: {"line": "..."}'
        ),
    },
    # Micro conversation: friends resting
    {
        "label": "Friendly healer + pessimistic mage, resting",
        "user": (
            'Speaker: Mira, Halfling Healer. Personality: Friendly, Optimistic. '
            'Voice: genuinely nice, checks on people; glass half full, annoyingly cheerful.\n'
            'Responder: Dorek, Dwarf Mage. Personality: Pessimistic, Gruff. '
            'Voice: assumes the worst, complains; short sentences, hates small talk.\n'
            'Relationship: Cautious Trust\n'
            'Situation: The party is resting after clearing a dungeon floor.\n'
            'Write two lines: first Mira speaks (5-20 words), then Dorek '
            'replies to what they said (5-20 words).\n'
            'Respond with JSON array: [{"name": "Mira", "line": "..."}, '
            '{"name": "Dorek", "line": "..."}]'
        ),
    },
    # Micro solo: treasure found
    {
        "label": "Self-interested rogue, found treasure",
        "user": (
            'Vex, Tiefling Rogue. Personality: Self-Interested, Calculating. '
            'Voice: always thinking about what\'s in it for them; always has an angle, thinks out loud.\n'
            'Situation: The party discovers a chest full of gold coins.\n'
            'Write one short spoken line (5-20 words).\n'
            'Respond with JSON: {"line": "..."}'
        ),
    },
    # Micro conversation: rivalry
    {
        "label": "Principled paladin + ruthless ranger, moral disagreement",
        "user": (
            'Speaker: Aldric, Human Paladin. Personality: Principled, Earnest. '
            'Voice: has strong opinions about right and wrong; honest to a fault, '
            'wears their heart on their sleeve.\n'
            'Responder: Syl, Elf Ranger. Personality: Ruthless, Stoic. '
            'Voice: pragmatic, uncomfortable to be around; unfazed, barely reacts.\n'
            'Relationship: Rivalry\n'
            'Situation: The party captured an enemy scout and must decide what to do.\n'
            'Write two lines: first Aldric speaks (5-20 words), then Syl '
            'replies to what they said (5-20 words).\n'
            'Respond with JSON array: [{"name": "Aldric", "line": "..."}, '
            '{"name": "Syl", "line": "..."}]'
        ),
    },
    # Event scene: multi-character
    {
        "label": "3-character event: descending to new floor",
        "user": (
            'Scene mood: tense\n'
            'Slot 0 - Theron, Human Fighter. Personality: Brave. '
            'Voice: confident, doesn\'t overthink it.\n'
            '  Direction: reassuring\n'
            'Slot 1 - Elara, Human Cleric. Personality: Cautious. '
            'Voice: nervous, second-guesses things.\n'
            '  Direction: worried\n'
            'Slot 2 - Kess, Elf Rogue. Personality: Sarcastic. '
            'Voice: dry, says the opposite of what they mean.\n'
            '  Direction: deflecting with humor\n'
            'Setup: The party stands at the top of a crumbling staircase '
            'leading deeper into the dungeon.\n'
            'Write 3-4 short dialogue lines between these characters. '
            'Each line 5-15 words. Respond with a JSON array: '
            '[{"slot": 0, "line": "..."}, ...]'
        ),
    },
    # Solo: combat close call
    {
        "label": "Reckless barbarian, close call",
        "user": (
            'Grunt, Orc Barbarian. Personality: Reckless, Brave. '
            'Voice: cocky, thinks they\'re invincible; confident, doesn\'t overthink it.\n'
            'Situation: Grunt just survived a fight with 1 HP remaining.\n'
            'Write one short spoken line (5-20 words).\n'
            'Respond with JSON: {"line": "..."}'
        ),
    },
    # Conversation: curious + stoic
    {
        "label": "Curious wizard + stoic monk, exploring",
        "user": (
            'Speaker: Pip, Gnome Wizard. Personality: Curious, Optimistic. '
            'Voice: nosy, always poking at things; glass half full, annoyingly cheerful.\n'
            'Responder: Zen, Human Monk. Personality: Stoic, Principled. '
            'Voice: unfazed, barely reacts; has strong opinions about right and wrong.\n'
            'Situation: They find a mysterious glowing rune on the dungeon wall.\n'
            'Write two lines: first Pip speaks (5-20 words), then Zen '
            'replies to what they said (5-20 words).\n'
            'Respond with JSON array: [{"name": "Pip", "line": "..."}, '
            '{"name": "Zen", "line": "..."}]'
        ),
    },
    # Solo: trap triggered
    {
        "label": "Pessimistic dwarf, triggered a trap",
        "user": (
            'Dorek, Dwarf Mage. Personality: Pessimistic, Gruff. '
            'Voice: assumes the worst, complains; short sentences, hates small talk.\n'
            'Situation: Dorek just stepped on a pressure plate that fired darts.\n'
            'Write one short spoken line (5-20 words).\n'
            'Respond with JSON: {"line": "..."}'
        ),
    },
    # Conversation: allies bonding
    {
        "label": "Two friends, quiet moment",
        "user": (
            'Speaker: Mira, Halfling Healer. Personality: Friendly, Earnest. '
            'Voice: genuinely nice, checks on people; honest to a fault, '
            'wears their heart on their sleeve.\n'
            'Responder: Theron, Human Fighter. Personality: Brave, Friendly. '
            'Voice: confident, doesn\'t overthink it; genuinely nice, checks on people.\n'
            'Relationship: Deep Trust\n'
            'Situation: A quiet moment between battles. Everyone is tired.\n'
            'Write two lines: first Mira speaks (5-20 words), then Theron '
            'replies to what they said (5-20 words).\n'
            'Respond with JSON array: [{"name": "Mira", "line": "..."}, '
            '{"name": "Theron", "line": "..."}]'
        ),
    },
]

RUNS_PER_PROMPT = 3


def find_binary():
    candidates = [
        Path(os.environ.get("LLM_DIR", "")) / "llama-server",
        Path.home() / "Library/Application Support/Godot/app_userdata/drpg-gd/llm/llama-server-arm64",
        Path.home() / "Library/Application Support/Godot/app_userdata/drpg-gd/llm/llama-server-x64",
        Path("llm/llama-server"),
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    print("ERROR: Could not find llama-server binary.")
    print("Set LLM_DIR env var to the directory containing the binary.")
    sys.exit(1)


def find_or_download_model(model_key):
    info = MODELS[model_key]
    search_dirs = [
        Path(os.environ.get("LLM_DIR", "")),
        Path.home() / "Library/Application Support/Godot/app_userdata/drpg-gd/llm",
        Path("llm"),
    ]
    for d in search_dirs:
        path = d / info["filename"]
        if path.exists():
            print(f"  Found {info['filename']} at {path}")
            return str(path)

    download_dir = search_dirs[1] if search_dirs[1].parent.exists() else Path("llm")
    download_dir.mkdir(parents=True, exist_ok=True)
    dest = download_dir / info["filename"]
    print(f"  Downloading {info['filename']} ({info['url']})...")
    subprocess.run(["curl", "-L", "-o", str(dest), info["url"]], check=True)
    print(f"  Downloaded to {dest}")
    return str(dest)


def kill_existing_servers():
    subprocess.run(["pkill", "-f", "llama-server"], capture_output=True)
    time.sleep(1)


def start_server(binary, model_path):
    args = [
        binary,
        "--port", str(PORT),
        "--model", model_path,
        "--ctx-size", "2048",
        "--n-predict", str(N_PREDICT),
        "--reasoning-format", "none",
        "-ngl", "99",
        "--no-context-shift",
        "--log-disable",
    ]
    proc = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    start = time.time()
    while time.time() - start < HEALTH_TIMEOUT:
        try:
            r = requests.get(f"http://127.0.0.1:{PORT}/health", timeout=2)
            if r.status_code == 200:
                startup_ms = int((time.time() - start) * 1000)
                print(f"  Server healthy ({startup_ms}ms startup)")
                return proc
        except requests.ConnectionError:
            pass
        time.sleep(1)
    proc.kill()
    print("  ERROR: Server failed to start")
    sys.exit(1)


def strip_think_block(content):
    idx = content.find("</think>")
    if idx >= 0:
        return content[idx + 8:].strip()
    if content.startswith("<think>"):
        return ""
    return content


def generate(prompt_data):
    prompt = (
        f"<|im_start|>system\n{SYSTEM_MSG}<|im_end|>\n"
        f"<|im_start|>user\n{prompt_data['user']}<|im_end|>\n"
        f"<|im_start|>assistant\n<think>\n</think>\n"
    )
    body = {
        "prompt": prompt,
        "n_predict": N_PREDICT,
        "temperature": TEMPERATURE,
        "top_p": TOP_P,
        "top_k": TOP_K,
        "presence_penalty": PRESENCE_PENALTY,
        "stop": ["<|im_end|>"],
        "timings": True,
    }
    start = time.time()
    try:
        r = requests.post(
            f"http://127.0.0.1:{PORT}/completion",
            json=body,
            timeout=GENERATE_TIMEOUT,
        )
        elapsed_ms = int((time.time() - start) * 1000)
        if r.status_code != 200:
            return {"error": f"HTTP {r.status_code}", "latency_ms": elapsed_ms}
        data = r.json()
        raw = data.get("content", "")
        content = strip_think_block(raw)
        timings = data.get("timings", {})
        return {
            "content": content,
            "latency_ms": elapsed_ms,
            "prompt_n": int(timings.get("prompt_n", 0)),
            "predicted_n": int(timings.get("predicted_n", 0)),
            "tok_per_sec": round(timings.get("predicted_per_second", 0), 1),
        }
    except requests.Timeout:
        return {"error": "timeout", "latency_ms": GENERATE_TIMEOUT * 1000}
    except Exception as e:
        return {"error": str(e), "latency_ms": 0}


def run_test_suite(model_key, binary, model_path):
    print(f"\n{'='*60}")
    print(f"Testing: {model_key} ({Path(model_path).name})")
    print(f"{'='*60}")

    kill_existing_servers()
    proc = start_server(binary, model_path)

    # warmup
    print("  Warming up...")
    requests.post(
        f"http://127.0.0.1:{PORT}/completion",
        json={
            "prompt": "<|im_start|>user\nSay hello.<|im_end|>\n<|im_start|>assistant\n",
            "n_predict": 8,
            "temperature": TEMPERATURE,
            "stop": ["<|im_end|>"],
        },
        timeout=30,
    )

    results = []
    for i, prompt_data in enumerate(PROMPTS):
        prompt_results = []
        for run in range(RUNS_PER_PROMPT):
            result = generate(prompt_data)
            result["label"] = prompt_data["label"]
            result["run"] = run + 1
            prompt_results.append(result)
            status = "OK" if "content" in result else f"ERR: {result.get('error')}"
            print(f"  [{i+1}/{len(PROMPTS)}] Run {run+1}/{RUNS_PER_PROMPT}: {status} "
                  f"({result['latency_ms']}ms, {result.get('tok_per_sec', 0)} tok/s)")
        results.append(prompt_results)

    proc.terminate()
    proc.wait()
    return results


def format_report(all_results):
    report = []
    report.append("\n" + "=" * 80)
    report.append("A/B TEST RESULTS")
    report.append("=" * 80)

    model_names = list(all_results.keys())

    # per-prompt comparison
    for i, prompt_data in enumerate(PROMPTS):
        report.append(f"\n--- Prompt {i+1}: {prompt_data['label']} ---")
        for model in model_names:
            runs = all_results[model][i]
            report.append(f"\n  [{model}]")
            for run in runs:
                if "content" in run:
                    report.append(f"    Run {run['run']}: {run['content']}")
                    report.append(f"      ({run['latency_ms']}ms, "
                                  f"{run['predicted_n']} tok, "
                                  f"{run['tok_per_sec']} tok/s)")
                else:
                    report.append(f"    Run {run['run']}: ERROR - {run.get('error')}")

    # aggregate stats
    report.append(f"\n{'='*80}")
    report.append("AGGREGATE STATS")
    report.append(f"{'='*80}")
    report.append(f"\n{'Model':<16} {'Avg ms':>8} {'Min ms':>8} {'P95 ms':>8} "
                  f"{'Avg tok/s':>10} {'Avg tok':>8} {'Errors':>7}")
    report.append("-" * 75)

    for model in model_names:
        latencies = []
        tok_rates = []
        tok_counts = []
        errors = 0
        for prompt_runs in all_results[model]:
            for run in prompt_runs:
                if "content" in run:
                    latencies.append(run["latency_ms"])
                    if run["tok_per_sec"] > 0:
                        tok_rates.append(run["tok_per_sec"])
                    tok_counts.append(run["predicted_n"])
                else:
                    errors += 1

        if latencies:
            sorted_lat = sorted(latencies)
            avg_lat = sum(latencies) / len(latencies)
            min_lat = sorted_lat[0]
            p95_idx = max(0, int(len(sorted_lat) * 0.95) - 1)
            p95_lat = sorted_lat[p95_idx]
            avg_tok_s = sum(tok_rates) / len(tok_rates) if tok_rates else 0
            avg_tok_n = sum(tok_counts) / len(tok_counts) if tok_counts else 0
            report.append(f"{model:<16} {avg_lat:>8.0f} {min_lat:>8} {p95_lat:>8} "
                          f"{avg_tok_s:>10.1f} {avg_tok_n:>8.1f} {errors:>7}")
        else:
            report.append(f"{model:<16} {'--':>8} {'--':>8} {'--':>8} "
                          f"{'--':>10} {'--':>8} {errors:>7}")

    return "\n".join(report)


def main():
    binary = find_binary()
    print(f"Using binary: {binary}")

    # find or download all models
    model_paths = {}
    for key in MODELS:
        print(f"\nLocating {key}...")
        model_paths[key] = find_or_download_model(key)

    all_results = {}
    for key in MODELS:
        all_results[key] = run_test_suite(key, binary, model_paths[key])

    report = format_report(all_results)
    print(report)

    # save results
    output_path = Path("tests/quant_ab_results.json")
    raw = {}
    for model, prompt_results in all_results.items():
        raw[model] = []
        for prompt_runs in prompt_results:
            raw[model].append(prompt_runs)
    with open(output_path, "w") as f:
        json.dump(raw, f, indent=2)
    print(f"\nRaw results saved to {output_path}")

    report_path = Path("tests/quant_ab_report.txt")
    with open(report_path, "w") as f:
        f.write(report)
    print(f"Report saved to {report_path}")


if __name__ == "__main__":
    main()
