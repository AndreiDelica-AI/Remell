import sys
import os
import json
import urllib.request

# Check candidate directories for the compiled GGUF model
root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

search_dirs = [
    os.path.join(root_dir, "remell_qwen_gguf"),
    os.path.join(backend_dir, "remell_qwen_gguf")
]

model_path = None

# Scan for any .gguf file in the directories
for s_dir in search_dirs:
    if os.path.exists(s_dir):
        files = os.listdir(s_dir)
        for f in files:
            if f.endswith(".gguf"):
                model_path = os.path.join(s_dir, f)
                break
        if model_path:
            break

# If no local model is found, set up default fallback download path in backend/remell_qwen_gguf
if not model_path:
    fallback_dir = os.path.join(backend_dir, "remell_qwen_gguf")
    model_path = os.path.join(fallback_dir, "qwen2.5-0.5b-instruct.Q4_K_M.gguf")
    
    if not os.path.exists(model_path):
        os.makedirs(fallback_dir, exist_ok=True)
        print("GGUF model not found locally. Downloading Qwen2.5-0.5B-Instruct-GGUF as fallback...", file=sys.stderr)
        url = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0_5b-instruct-q4_k_m.gguf"
        
        try:
            def progress_hook(count, block_size, total_size):
                if total_size > 0:
                    percent = int(count * block_size * 100 / total_size)
                    print(f"Downloading model: {percent}% completed", end="\r", file=sys.stderr)
            urllib.request.urlretrieve(url, model_path, reporthook=progress_hook)
            print("\nDownload complete!", file=sys.stderr)
        except Exception as e:
            print(f"Error downloading fallback model: {e}", file=sys.stderr)
            sys.exit(1)

# Check for llama-cpp-python
try:
    from llama_cpp import Llama
except ImportError:
    print("Error: 'llama-cpp-python' is not installed. Run 'pip install llama-cpp-python'.", file=sys.stderr)
    sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"tasks": []}))
        return

    input_text = sys.argv[1]
    
    try:
        # Load the model
        llm = Llama(
            model_path=model_path,
            n_ctx=1024,
            n_threads=4,
            verbose=False
        )
        
        # Format the prompt using Qwen ChatML template
        prompt = f"<|im_start|>system\nYou are the Remell AI note parser. Extract actionable tasks into a valid JSON structure.\nAllowed category list: Work, Personal, Shopping, Finance, Health, General.\nAllowed priority list: Low, Medium, High.\nResolve relative times assuming reference is August 2026. Return ONLY raw JSON matching: {{\"tasks\": [{{\"title\": \"Task title\", \"category\": \"Category\", \"due\": \"ISO-8601\", \"priority\": \"Priority\"}}]}}<|im_end|>\n<|im_start|>user\n{input_text}<|im_end|>\n<|im_start|>assistant\n"
        
        response = llm(
            prompt,
            max_tokens=256,
            stop=["<|im_end|>"],
            temperature=0.1
        )
        
        raw_output = response["choices"][0]["text"].strip()
        
        # Extract JSON from potential markdown tags
        if "```" in raw_output:
            lines = raw_output.split("\n")
            json_lines = []
            in_code = False
            for line in lines:
                if line.strip().startswith("```"):
                    in_code = not in_code
                    continue
                json_lines.append(line)
            raw_output = "\n".join(json_lines).strip()
            
        # Validate JSON parsing
        parsed = json.loads(raw_output)
        print(json.dumps(parsed, ensure_ascii=False))
        
    except Exception as e:
        # Fallback empty structure on any parsing error
        print(f"Error during inference: {e}", file=sys.stderr)
        print(json.dumps({"tasks": [{"title": input_text, "category": "General", "due": None, "priority": "Medium"}]}))

if __name__ == "__main__":
    main()
