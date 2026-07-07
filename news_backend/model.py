import os
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

MODEL_PATH = os.environ.get("MODEL_PATH", os.path.join(os.path.dirname(__file__), "gemma-model"))
MAX_INPUT_TOKENS = 1024
MAX_NEW_TOKENS = 200
MAX_DOC_WORDS = 600

# Global model and tokenizer instances
_tokenizer = None
_model = None
_load_error = None
_is_fallback = False

def load_model_if_needed():
    global _tokenizer, _model, _load_error, _is_fallback
    if _tokenizer is not None and _model is not None:
        return True
    if _is_fallback or _load_error is not None:
        return False
        
    # Standardize path
    target_path = os.path.abspath(MODEL_PATH)
    print(f"Attempting to load Gemma model from path: {target_path} ...")
    if not os.path.exists(target_path):
        print(f"Warning: Model directory not found at {target_path}. Falling back to rule-based summary.")
        _is_fallback = True
        return False
        
    try:
        print("Loading tokenizer...")
        _tokenizer = AutoTokenizer.from_pretrained(target_path, local_files_only=True)
        print("Loading model...")
        _model = AutoModelForCausalLM.from_pretrained(
            target_path,
            local_files_only=True,
            dtype=torch.float32,
            device_map="cpu",
        )
        _model.eval()
        print("Model loaded successfully! ✅")
        return True
    except Exception as e:
        print(f"Error loading local model: {e}")
        _load_error = str(e)
        _is_fallback = True
        return False

def summarize_article_fallback(title: str, content: str) -> str:
    """
    A simple extractive summary algorithm as a fallback when the Gemma model is not loaded.
    It takes sentences from the article to formulate a structured summary matching the API format.
    """
    paragraphs = [p.strip() for p in content.split('\n\n') if p.strip()]
    if not paragraphs:
        return "TOPIC_1_NAME: Overview\nTOPIC_1_SUMMARY: No content available to summarize."
    
    all_sentences = []
    for p in paragraphs:
        sentences = [s.strip() for s in p.split('.') if s.strip()]
        all_sentences.extend(sentences)
        
    lead_sentences = all_sentences[:5]
    summary_body = ". ".join(lead_sentences) + "."
    
    # Ensure it's long enough for the API format expectations (80+ words)
    words = summary_body.split()
    if len(words) < 80 and len(all_sentences) > 5:
        additional_sentences = all_sentences[5:12]
        summary_body += " " + ". ".join(additional_sentences) + "."
        
    return (
        "TOPIC_1_NAME: Overview\n"
        f"TOPIC_1_SUMMARY: {summary_body}\n"
        "TOPIC_2_NAME: NONE\n"
        "TOPIC_2_SUMMARY: NONE\n"
        "TOPIC_3_NAME: NONE\n"
        "TOPIC_3_SUMMARY: NONE"
    )

def summarize_article(title: str, author: str, date: str, content: str) -> str:
    if not load_model_if_needed():
        return summarize_article_fallback(title, content)
        
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

    inputs = _tokenizer(
        prompt,
        return_tensors="pt",
        truncation=True,
        max_length=MAX_INPUT_TOKENS
    ).to(_model.device)

    with torch.no_grad():
        output_ids = _model.generate(
            **inputs,
            max_new_tokens=MAX_NEW_TOKENS,
            do_sample=False,
            pad_token_id=_tokenizer.eos_token_id
        )

    generated_ids = output_ids[0][inputs["input_ids"].shape[1]:]
    raw = "TOPIC_1_NAME:" + _tokenizer.decode(generated_ids, skip_special_tokens=True).strip()
    return raw

def get_model_status() -> dict:
    # Trigger checks to establish accurate initial state
    load_success = load_model_if_needed()
    return {
        "loaded": _model is not None,
        "is_fallback": _is_fallback,
        "load_error": _load_error,
        "model_path": os.path.abspath(MODEL_PATH)
    }