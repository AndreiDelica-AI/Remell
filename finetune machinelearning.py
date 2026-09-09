# ==============================================================================
# REMELL AI: Windows-Native Fine-Tuning Qwen2.5-0.5B on 10k Dataset to GGUF
# Runs natively on Windows using standard PyTorch & Hugging Face libraries.
# Loads the base model from the local './backend/qwen_base' folder.
# Optimizes for CPU training (30 samples, 64 max length, Adafactor, 30 steps).
# ==============================================================================

import sys
import subprocess
import os
import json
import time

def install_deps():
    print("Installing native Hugging Face and PyTorch dependencies...")
    subprocess.run([
        sys.executable, "-m", "pip", "install", "--upgrade",
        "torch", "transformers", "peft", "trl", "datasets", "accelerate", "huggingface_hub"
    ], check=True)

try:
    import torch
    from datasets import load_dataset
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from peft import LoraConfig, get_peft_model, PeftModel
    from trl import SFTTrainer, SFTConfig
except ImportError:
    install_deps()
    import torch
    from datasets import load_dataset
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from peft import LoraConfig, get_peft_model, PeftModel
    from trl import SFTTrainer, SFTConfig

def main():
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Using training device: {device.upper()}")
    
    model_id = "./backend/qwen_base"
    # CPU Optimization: Reduce context length to 64 since task notes are short.
    max_seq_length = 64

    # 1. Load tokenizer and base model
    print(f"Loading base model from local folder {model_id}...")
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    tokenizer.pad_token = tokenizer.eos_token
    
    torch_dtype = torch.float16 if device == "cuda" else torch.float32
    
    base_model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch_dtype,
        device_map="auto" if device == "cuda" else None
    )

    # 2. Configure LoRA (PEFT)
    print("Applying LoRA adapters...")
    lora_config = LoraConfig(
        r=16,
        lora_alpha=16,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM"
    )
    model = get_peft_model(base_model, lora_config)
    model.print_trainable_parameters()

    # 3. Load JSONL dataset
    dataset_file = "remell_dataset_10k.jsonl"
    print(f"Loading dataset from {dataset_file}...")
    if not os.path.exists(dataset_file):
        print(f"Error: {dataset_file} not found. Please generate the dataset first.", file=sys.stderr)
        return
        
    full_dataset = load_dataset("json", data_files=dataset_file, split="train")

    # Ultra RAM & CPU Optimization: Slice dataset to 30 training samples
    # and 8 validation samples. This takes ~30 minutes on CPU.
    print(f"Selecting 30 training samples and 8 validation samples...")
    train_dataset = full_dataset.select(range(30))
    val_dataset = full_dataset.select(range(30, 38))

    # Format dataset messages using Qwen chat template
    def format_prompts(examples):
        texts = []
        for messages in examples["messages"]:
            text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)
            texts.append(text)
        return {"text": texts}

    # Use keep_in_memory=True to bypass Windows file locking issues on Hugging Face dataset cache
    train_dataset = train_dataset.map(format_prompts, batched=True, keep_in_memory=True)

    # 4. Initialize SFT Config and SFT Trainer (trl 1.10.0+ style)
    print("Starting native fine-tuning...")
    sft_config = SFTConfig(
        output_dir="remell_outputs",
        per_device_train_batch_size=1,       # Batch size 1 reduces memory footprint
        gradient_accumulation_steps=1,       # Gradient accumulation of 1 (effective batch size 1)
        warmup_steps=2,
        num_train_epochs=1,
        learning_rate=2e-4,
        fp16=(device == "cuda"),
        logging_steps=5,
        optim="adafactor",                  # Adafactor is extremely memory efficient on CPU
        weight_decay=0.01,
        lr_scheduler_type="linear",
        seed=3407,
        save_strategy="no",
        dataset_text_field="text",
        use_cpu=(device == "cpu"),
        max_length=max_seq_length,
        packing=False
    )

    trainer = SFTTrainer(
        model=model,
        train_dataset=train_dataset,
        args=sft_config,
        processing_class=tokenizer
    )

    trainer.train()
    print("Fine-tuning complete!")

    # 4.5 Evaluate Accuracy on Validation Set
    print("\nEvaluating model accuracy on validation set (8 samples)...")
    model.eval()
    valid_json_count = 0
    correct_format_count = 0
    
    eval_subset = val_dataset.select(range(min(8, len(val_dataset))))
    
    for i, example in enumerate(eval_subset):
        # Prepare ChatML prompt
        messages = example["messages"][:-1]  # Remove target assistant response
        prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        inputs = tokenizer(prompt, return_tensors="pt").to(device)
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=64,
                eos_token_id=tokenizer.eos_token_id,
                pad_token_id=tokenizer.pad_token_id
            )
            
        generated_text = tokenizer.decode(outputs[0][inputs.input_ids.shape[1]:], skip_special_tokens=True).strip()
        
        # Check if valid JSON and matching format
        try:
            parsed = json.loads(generated_text)
            valid_json_count += 1
            if "tasks" in parsed and isinstance(parsed["tasks"], list):
                correct_format_count += 1
        except Exception:
            pass
            
        if (i + 1) % 2 == 0:
            print(f"Evaluated {i + 1}/{len(eval_subset)} samples...")
            
    print("\n--- Accuracy Evaluation Summary ---")
    print(f"Total Samples Evaluated: {len(eval_subset)}")
    print(f"JSON Validity Rate: {valid_json_count / len(eval_subset) * 100:.1f}%")
    print(f"Format Conformance Rate: {correct_format_count / len(eval_subset) * 100:.1f}%")
    print("------------------------------------\n")

    # 5. Save adapter and merge with base model
    adapter_path = "remell_lora_adapter"
    merged_path = "remell_qwen_merged"
    
    print(f"Saving PEFT adapter to {adapter_path}...")
    trainer.save_model(adapter_path)
    
    # Free memory before merge
    del model
    del base_model
    if device == "cuda":
        torch.cuda.empty_cache()
        
    print("Merging PEFT adapter with base model for GGUF compilation...")
    raw_base = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch_dtype,
        device_map=None
    )
    peft_model = PeftModel.from_pretrained(raw_base, adapter_path)
    merged_model = peft_model.merge_and_unload()
    
    print(f"Saving merged model to {merged_path}...")
    merged_model.save_pretrained(merged_path)
    tokenizer.save_pretrained(merged_path)
    
    # Free merged memory
    del peft_model
    del merged_model
    if device == "cuda":
        torch.cuda.empty_cache()

    # 6. Convert to GGUF format locally using llama.cpp
    print("Preparing local GGUF conversion...")
    gguf_output_dir = "remell_qwen_gguf"
    os.makedirs(gguf_output_dir, exist_ok=True)
    
    if not os.path.exists("llama.cpp"):
        print("Cloning llama.cpp for GGUF compiler...")
        subprocess.run(["git", "clone", "https://github.com/ggerganov/llama.cpp"], check=True)
        
    print("Installing llama.cpp requirements...")
    subprocess.run([
        sys.executable, "-m", "pip", "install", "-r", "llama.cpp/requirements.txt"
    ], check=True)
    
    gguf_filename = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    gguf_path = os.path.join(gguf_output_dir, gguf_filename)
    
    print("Compiling model into GGUF bin...")
    convert_script = os.path.join("llama.cpp", "convert_hf_to_gguf.py")
    subprocess.run([
        sys.executable, convert_script, merged_path,
        "--outfile", gguf_path,
        "--outtype", "q4_k_m"
    ], check=True)
    
    print(f"\nSuccess! Local GGUF model compiled successfully at: {os.path.abspath(gguf_path)}")

if __name__ == "__main__":
    main()
