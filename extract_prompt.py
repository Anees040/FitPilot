import json

with open(r"C:\Users\Anees\.gemini\antigravity-ide\brain\592a19b0-2bc0-4173-b3f3-09ada3aa2abc\.system_generated\logs\transcript_full.jsonl", "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        if data.get("type") == "USER_INPUT":
            content = data.get("content", "")
            if "Fix photo food scan and label scan" in content:
                with open(r"d:\fitpilot\prompt_output.txt", "w", encoding="utf-8") as out:
                    out.write(content)
                break
