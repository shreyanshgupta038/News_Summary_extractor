# 📰 News Summary Extractor

An AI-powered news article extraction and summarization system. It utilizes a **FastAPI** backend to scrape articles and summarize them using a local **Gemma 2B LLM**, paired with a **Flutter** mobile/desktop frontend application to present summaries, view topics, and export results.

---

## 🏗️ Project Architecture

```
                       ┌──────────────────────┐
                       │   News Article URL   │
                       └──────────┬───────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                          NEWS BACKEND                            │
│                                                                  │
│  ┌─────────────────┐       ┌──────────────┐      ┌────────────┐  │
│  │   FastAPI App   ├──────►│ SmartScraper ├─────►│ News Sites │  │
│  │   (main.py)     │       │(scrapper.py) │      │  (HTML)    │  │
│  └────────┬────────┘       └──────────────┘      └────────────┘  │
│           │                                                      │
│           ▼                                                      │
│  ┌─────────────────┐       ┌──────────────┐                      │
│  │  Summarizer     ├──────►│   Gemma LLM  │                      │
│  │  (model.py)     │       │  (or CPU     │                      │
│  └─────────────────┘       │   Fallback)  │                      │
│                            └──────────────┘                      │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ JSON Response
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                         NEWS FRONTEND                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                      Flutter Application                   │  │
│  │  • Sleek Indigo Dark Mode UI                               │  │
│  │  • Interactive Segmented Tabs (Scraped Content / Summary)  │  │
│  │  • Native PDF Export & Social Sharing                      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🗂️ Directory Structure

```
News_Summary_extractor/
├── news_backend/             # Python FastAPI Backend
│   ├── main.py               # API endpoints (/scrape, /summarize, /info)
│   ├── model.py              # Gemma model integration & fallback summarizer
│   ├── scrapper.py           # XPath-based article parser
│   ├── requirements.txt      # Python dependencies list
│   └── .env.example          # Environment template
│
├── news_frontend/            # Flutter Application
│   ├── lib/
│   │   └── main.dart         # Completed Flutter UI & client integration
│   ├── pubspec.yaml          # Flutter package definitions & assets
│   └── android/ ...          # Android build files
│
├── .gitignore                # Global workspace gitignore
└── README.md                 # Project documentation (this file)
```

---

## 🚀 Getting Started

### ⚡ Quick Start (Fallback Mode)
You don't need a GPU or to download a 5GB LLM model immediately to test the app flow. If the Gemma model weights are missing, the backend **gracefully falls back** to a text-extraction summarizer so the scraping, API, and Flutter frontend remain fully functional.

---

### 1. Backend Setup & Run

#### Prerequisites
* Python 3.10 to 3.13 (PyTorch is required)
* Windows 10/11 or macOS/Linux

#### Installation Steps
1. Navigate to the `news_backend` directory:
   ```bash
   cd news_backend
   ```
2. Create and activate a Python virtual environment:
   ```powershell
   # Windows PowerShell
   py -m venv venv
   .\venv\Scripts\Activate.ps1
   ```
3. Install the dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. **(Optional)** Add Gemma LLM weights:
   * Create a folder named `gemma-model` inside `news_backend/` (or set the `MODEL_PATH` environment variable).
   * Place the Gemma 2B instruction-tuned model weights (e.g., Hugging Face files: `config.json`, `tokenizer.json`, and `.safetensors` files) in that folder.
   * If you skip this, the backend automatically runs in **Fallback Mode** using an extractive summarizer.

#### Start the API Server
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
* The API will start at `http://localhost:8000`.
* The health check is available at `http://localhost:8000/`.
* The model status check is available at `http://localhost:8000/info`.

---

### 2. Frontend Setup & Run

#### Prerequisites
* Flutter SDK (v3.10.0 or higher)

#### Installation Steps
1. Navigate to the `news_frontend` directory:
   ```bash
   cd news_frontend
   ```
2. Fetch package dependencies:
   ```bash
   flutter pub get
   ```
3. Run the Flutter application on your emulator, device, or web browser:
   ```bash
   flutter run
   ```

#### Application Features
* **Settings Gear**: Update the Server IP/URL directly inside the app (useful if running the backend on a different device on your local WiFi network).
* **Connection Status Bar**: View real-time connection status (`Offline`, `API Connected • Fallback Mode Active`, or `API Connected • Gemma LLM Active`).
* **Share Summary**: Tap to share summary contents to other applications via the native share sheet.
* **Export PDF**: Generates and saves a clean, formatted PDF file containing the article details and extracted summaries to your local device.

---

## 🧠 Summarization Modes

1. **Gemma 2B LLM Mode (Offline & Private)**
   * When Gemma weights are placed in the path, it loads the model on CPU.
   * Employs zero-shot instruction prompting to simultaneously detect up to 3 distinct topics and summarize each into an 80+ word paragraph.

2. **Rule-Based Fallback Mode**
   * Automatically activated if local model files are not found.
   * Utilizes a text-analysis algorithm to score sentences and construct formatted, structured summaries on-the-fly with zero CPU overhead.

---

## 📡 Backend API Reference

### `GET /info`
Check model state.
```json
{
  "loaded": false,
  "is_fallback": true,
  "load_error": null,
  "model_path": "C:\\projects\\News_Summary_extractor\\news_backend\\gemma-model"
}
```

### `POST /summarize`
Scrapes a URL, extracts details, and returns summaries.
* **Request Body:**
  ```json
  {
    "url": "https://www.firstpost.com/india/sample-news-article.html"
  }
  ```
* **Response Body:**
  ```json
  {
    "title": "Article Title Example",
    "author": "News Desk",
    "date": "2026-07-07T12:00:00+05:30",
    "content": "Full article text content...",
    "summary": "TOPIC_1_NAME: Overview\nTOPIC_1_SUMMARY: ...",
    "fallback": true
  }
  ```
