import sys
import os
import json

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

# Check for llama-cpp-python
try:
    from llama_cpp import Llama
except ImportError:
    print("Error: 'llama-cpp-python' is not installed. Run 'pip install llama-cpp-python'.", file=sys.stderr)
    sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print(json.dumps([]))
        return

    notes_text = sys.argv[1]
    if not notes_text.strip():
        print(json.dumps([]))
        return

    try:
        # Load the model
        llm = Llama(
            model_path=model_path,
            n_ctx=512,
            n_threads=4,
            verbose=False
        )
        
        # Prompt to extract subtasks
        prompt = f"<|im_start|>system\nYou are the Remell AI subtask extractor. Analyze the user's task notes and notes/steps to extract a clean JSON array of subtasks. Return ONLY a valid JSON array of strings, e.g. [\"subtask 1\", \"subtask 2\"]. Do not include markdown code block syntax. Return only the JSON.<|im_end|>\n<|im_start|>user\n{notes_text}<|im_end|>\n<|im_start|>assistant\n"
        
        response = llm(
            prompt,
            max_tokens=256,
            stop=["<|im_end|>"],
            temperature=0.1
        )
        
        raw_output = response["choices"][0]["text"].strip()
        
        # Clean up code blocks if present
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

        # Parse and print
        parsed = json.loads(raw_output)
        if isinstance(parsed, list):
            print(json.dumps(parsed, ensure_ascii=False))
        elif isinstance(parsed, dict) and "subtasks" in parsed:
            print(json.dumps(parsed["subtasks"], ensure_ascii=False))
        else:
            print(json.dumps([]))
            
    except Exception as e:
        # Rule-based fallback if ML parser fails
        subtasks = []
        for line in notes_text.split('\n'):
            cleaned = line.strip()
            if not cleaned:
                continue
            if cleaned.startswith('-') or cleaned.startswith('*') or cleaned.startswith('•'):
                cleaned = cleaned[1:].strip()
            if cleaned:
                subtasks.append(cleaned)
        print(json.dumps(subtasks, ensure_ascii=False))

if __name__ == "__main__":
    main()
