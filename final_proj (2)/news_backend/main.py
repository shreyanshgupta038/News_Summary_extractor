from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from scrapper import scrape_article
from model import summarize_article
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class URLRequest(BaseModel):
    url: str

@app.get("/")
def root():
    return {"status": "Server is running ✅"}

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
        return {
            "title": data["title"],
            "author": data["author"],
            "date": data["date"], 
            "content": data["content"],
            "summary": summary
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))