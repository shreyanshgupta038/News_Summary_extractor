import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

MODEL_PATH = "D:/news_backend/gemma-model"
MAX_INPUT_TOKENS = 1024
MAX_NEW_TOKENS = 200
MAX_DOC_WORDS = 600

print("Loading tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, local_files_only=True)

print("Loading model...")
model = AutoModelForCausalLM.from_pretrained(
    MODEL_PATH,
    local_files_only=True,
    dtype=torch.float32,
    device_map="cpu",
)
model.eval()
print("Model loaded successfully! ✅")


def summarize_article(title: str, author: str, date: str, content: str) -> str:
    trimmed_content = " ".join(content.split()[:MAX_DOC_WORDS])

    prompt = (
        "You are a news analyst. Read the article and identify up to 3 distinct topics.\n"
        "Reply ONLY in this exact format. Each SUMMARY must be at least 80 words in full sentences.\n\n"
        "TOPIC_1_NAME: <label>\n"
        "TOPIC_1_SUMMARY: <80+ word summary>\n"
        "TOPIC_2_NAME: <label or NONE>\n"
        "TOPIC_2_SUMMARY: <80+ word summary or NONE>\n"
        "TOPIC_3_NAME: <label or NONE>\n"
        "TOPIC_3_SUMMARY: <80+ word summary or NONE>\n\n"
        f"Title: {title}\n"
        f"Author: {author}\n"
        f"Date: {date}\n\n"
        f"Article:\n{trimmed_content}\n\n"
        "Analysis:\n"
        "TOPIC_1_NAME:"
    )

    inputs = tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=MAX_INPUT_TOKENS
    ).to(model.device)

    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_new_tokens=MAX_NEW_TOKENS,
            do_sample=False,
            pad_token_id=tokenizer.eos_token_id
        )

    generated_ids = output_ids[0][inputs["input_ids"].shape[1]:]
    raw = "TOPIC_1_NAME:" + tokenizer.decode(generated_ids, skip_special_tokens=True).strip()
    return raw