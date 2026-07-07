from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from scrapper import scrape_article
from model import summarize_article, get_model_status
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="News Summary Extractor API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class URLRequest(BaseModel):
    url: str

@app.get("/")
def root():
    return {"status": "Server is running ✅"}

@app.get("/info")
def info():
    """
    Returns the current status of the LLM (loaded, fallback, load errors).
    """
    try:
        return get_model_status()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/scrape")
def scrape_news(request: URLRequest):
    try:
        data = scrape_article(request.url)
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/summarize")
def scrape_and_summarize(request: URLRequest):
    try:
        data = scrape_article(request.url)
        summary = summarize_article(
            title=data["title"],
            author=data["author"],
            date=data["date"],
            content=data["content"]
        )
        status = get_model_status()
        return {
            "title": data["title"],
            "author": data["author"],
            "date": data["date"], 
            "content": data["content"],
            "summary": summary,
            "fallback": status["is_fallback"]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))