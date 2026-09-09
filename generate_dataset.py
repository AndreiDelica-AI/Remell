import json
import os
import time
from typing import List, Optional
from pydantic import BaseModel, Field
from google import genai
from google.genai import types

class TaskItem(BaseModel):
    title: str = Field(description="Actionable, clean summary of the task")
    category: str = Field(description="One of: Work, Personal, Shopping, Finance, Health, General")
    due: Optional[str] = Field(description="ISO 8601 formatted date/time or null")
    priority: str = Field(description="Low, Medium, or High priority")

class TaskOutput(BaseModel):
    tasks: List[TaskItem]

class NotePair(BaseModel):
    raw_input: str = Field(description="Realistic raw voice/text note in Taglish, Tagalog, or English")
    parsed_output: TaskOutput

class BatchDataset(BaseModel):
    samples: List[NotePair]

def generate_large_dataset(total_target: int = 10000, batch_size: int = 50, output_file: str = "remell_dataset_10k.jsonl"):
    # Initialize genai Client
    client = genai.Client()
    current_count = 0
    system_prompt = "You are the Remell AI note parser. Extract actionable tasks into a valid JSON structure."
    
    data_gen_prompt = """
    Generate a diverse batch of realistic user note-taking inputs and their corresponding extracted JSON schemas for the note app 'Remell'.
    Guidelines:
    1. Languages: Heavy mix of Taglish (Filipino-English code-switching), colloquial Tagalog, and English slang.
    2. Context: Include messy typos, rushed voice-to-text phrasing, and casual conversational prompts ("Paki-buy ng...", "Need to submit...", "Bumili ng...", "Pa-remind sa...").
    3. Scale: Create unique everyday scenarios (errands, office tasks, school deadlines, bills, groceries).
    4. Dates: Assume reference time is August 2026. Resolve relative words ('mamaya', 'bukas', 'next Tuesday') into ISO 8601.
    """

    # List of candidate models to rotate through once daily limits are hit
    candidate_models = [
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-3.7-flash",
        "gemini-3.1-flash-lite",
        "gemini-3.5-flash-lite",
        "gemini-2.5-flash-lite"
    ]
    model_index = 0

    print(f"Generating {total_target} training samples for Remell...")
    
    # Check current progress if file already exists
    if os.path.exists(output_file):
        try:
            with open(output_file, "r", encoding="utf-8") as rf:
                current_count = sum(1 for _ in rf)
            print(f"Resuming from existing dataset file with {current_count} samples.")
        except Exception:
            pass

    # Append mode safely preserves progress if restarted
    with open(output_file, "a", encoding="utf-8") as f:
        while current_count < total_target:
            current_model = candidate_models[model_index]
            try:
                response = client.models.generate_content(
                    model=current_model,
                    contents=f"{data_gen_prompt}\nGenerate a batch of {batch_size} unique samples.",
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=BatchDataset,
                        temperature=0.95, # High temp for vocabulary variety
                    ),
                )
                
                batch_data: BatchDataset = response.parsed
                
                if not batch_data or not batch_data.samples:
                    print("Received empty batch, retrying...")
                    time.sleep(4)
                    continue

                for item in batch_data.samples:
                    chatml_record = {
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": item.raw_input},
                            {"role": "assistant", "content": item.parsed_output.model_dump_json()}
                        ]
                    }
                    f.write(json.dumps(chatml_record, ensure_ascii=False) + "\n")
                    current_count += 1
                
                print(f"Progress: {current_count}/{total_target} samples saved (using {current_model}).")
                
                # Sleep for 4 seconds to comply with Gemini API's 15 Requests Per Minute limit
                time.sleep(4.0)
                
            except Exception as e:
                err_str = str(e)
                if "RESOURCE_EXHAUSTED" in err_str or "quota" in err_str.lower() or "limit" in err_str.lower():
                    print(f"Quota exceeded for {current_model}.")
                    model_index += 1
                    if model_index >= len(candidate_models):
                        print("All candidate models exhausted for the day due to free-tier daily quotas. Exiting.")
                        break
                    print(f"Rotating to next model: {candidate_models[model_index]}...")
                    time.sleep(2.0)
                    continue
                else:
                    print(f"Network or api error: {e}. Retrying in 8 seconds...")
                    time.sleep(8.0)

    print(f"\nDone! {current_count} samples successfully saved to '{output_file}'.")

if __name__ == "__main__":
    generate_large_dataset(total_target=10000, batch_size=50)
