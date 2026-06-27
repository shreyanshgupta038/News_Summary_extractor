# 📰 News Backend — LLM-Powered Scraper & Summarizer

A FastAPI backend that scrapes news articles and summarizes them using a local Gemma 2B LLM. No external API calls — everything runs offline on your machine.

---

## 🗂 Project Structure

```
news_backend/
├── main.py          # FastAPI app with /scrape and /summarize endpoints
├── model.py         # Gemma 2B model loader + summarization logic
├── scrapper.py      # Article scraper (Firstpost, TOI, etc.)
├── gemma-model/     # Local Gemma 2B model weights (not in git)
└── venv/            # Python virtual environment
```

---

## ⚙️ Requirements

- Python 3.13 (NOT 3.14 — PyTorch doesn't support it yet)
- 10GB+ free RAM (runs entirely on CPU, no GPU needed)
- ~5GB free disk space for model weights
- Windows 10/11

> ⚠️ **Important**: You must increase your Windows paging file size before running (see below). Without this the model will crash on load even if you have enough RAM.

---

## 🚀 Setup

### 1. Clone / download the project
```
D:\news_backend\
```

### 2. Create virtual environment with Python 3.13
```powershell
py -3.13 -m venv venv
venv\Scripts\Activate.ps1
```

### 3. Set temp to D: if C: is low on space
```powershell
$env:TEMP = "D:\tmp"
$env:TMP = "D:\tmp"
mkdir D:\tmp
```

### 4. Install PyTorch (CPU version)
```powershell
pip install torch
```

### 5. Install remaining dependencies
```powershell
pip install transformers fastapi uvicorn requests lxml pydantic accelerate
```

### 6. Add model weights
Place the Gemma 2B model folder at:
```
D:\news_backend\gemma-model\
```
It should contain `config.json`, `tokenizer.json`, and `.safetensors` files.

---

## 🪟 Windows Paging File Fix (Required)

If you get `OSError: The paging file is too small`, do this:

1. `Win + R` → type `sysdm.cpl` → Enter
2. Advanced → Performance → Settings → Advanced → Virtual Memory → Change
3. Uncheck "Automatically manage"
4. Select **D:** → Custom size → Initial: `8192` Max: `16384` → Set
5. Click OK → **Restart PC**

> Note: Set it on D: not C: — C: needs to have enough free space for the paging file.

---

## ▶️ Running the Server

```powershell
cd D:\news_backend
venv\Scripts\Activate.ps1
uvicorn main:app --host 0.0.0.0 --port 8000
```

Server runs at `http://0.0.0.0:8000`. Teammates on the same WiFi can access it at `http://<your-ip>:8000`.

> Model takes ~30-60 seconds to load on first startup.

---

## 📡 API Endpoints

### `GET /`
Health check.
```json
{"status": "Server is running ✅"}
```

### `POST /scrape`
Scrapes a news article URL and returns raw content.

**Request:**
```json
{"url": "https://www.firstpost.com/india/some-article.html"}
```

**Response:**
```json
{
  "title": "Article title",
  "author": "Firstpost News Desk",
  "date": "2026-03-22T13:27:19+05:30",
  "content": "Full article text..."
}
```

### `POST /summarize`
Scrapes + summarizes the article using Gemma 2B.

**Request:**
```json
{"url": "https://www.firstpost.com/india/some-article.html"}
```

**Response:**
```json
{
  "title": "...",
  "author": "...",
  "date": "...",
  "content": "...",
  "summary": "TOPIC_1_NAME: ...\nTOPIC_1_SUMMARY: ...\n..."
}
```

---

## 🧠 How Summarization Works

We use a **zero-shot LLM-based approach** using Gemma 2B-IT for simultaneous topic identification and summarization. Rather than training a separate classifier, we leverage the instruction-following capability of the model through structured prompting.

Each article is passed to the model with a strict output format requiring up to 3 `TOPIC_NAME` + `TOPIC_SUMMARY` pairs. The model identifies latent themes from the article content without any labeled data or fine-tuning — making it a fully **unsupervised, training-free pipeline**.

---

## ⚠️ Known Issues

- `/summarize` is slow on CPU (~2-3 mins per request)
- Scraper may fail on paywalled or JS-heavy articles
- Model must be present locally — no HuggingFace download at runtime

---

## 🛠 Supported News Sources

- Firstpost
- Times of India
- The Hindu
- Hindustan Times
- Indian Express
- Economic Times
- Livemint
- The Wire
- Scroll
- The Print
- Outlook India
