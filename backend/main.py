from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def anasayfa():
    return {"mesaj": "Onvo Personel Takip API çalışıyor"}
    