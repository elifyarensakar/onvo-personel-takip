from fastapi import FastAPI , Depends
from sqlalchemy.orm import Session
from database import SessionLocal
from fastapi import HTTPException
from passlib.context import CryptContext
from models import Birim , Bant , Personel
from schemas import (
    BirimCreate, BirimOut ,
    BantCreate , BantOut,
    PersonelCreate, PersonelOut
    )

app = FastAPI()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Her bir sessionu açıp kapatmak için
def get_db():
    db = SessionLocal()
    try:
        yield db #normal return'den farkı: fonksiyon yield satırında duraklar, değeri dışarı verir, çağıran taraf işini bitirince fonksiyona geri döner ve kalan kodu çalıştırır.
    finally:
        db.close()


@app.post("/birim", response_model=BirimOut)
def birim_ekle(birim: BirimCreate, db: Session = Depends(get_db)):
    yeni_birim = Birim(birim_adi=birim.birim_adi)
    db.add(yeni_birim)
    db.commit()
    db.refresh(yeni_birim)
    return yeni_birim

@app.post("/bant", response_model=BantOut)
def bant_ekle(bant: BantCreate, db: Session = Depends(get_db)):
    yeni_bant = Bant(birim_no=bant.birim_no,bant_adi=bant.bant_adi)
    db.add(yeni_bant)
    db.commit()
    db.refresh(yeni_bant)
    return yeni_bant

@app.post("/personel", response_model=PersonelOut)
def personel_ekle(personel: PersonelCreate, db: Session = Depends(get_db)):
    if personel.rol != "calisan" and personel.birim_no is None:
        raise HTTPException(
            status_code=400,
            detail="bant_sefi ve yonetici rolündeki personelin bir birime atanmış olması gerekir."
        )

    yeni_personel = Personel(
        sicil_no=personel.sicil_no,
        ad_soyad=personel.ad_soyad,
        birim_no=personel.birim_no,
        rol=personel.rol,
        sifre_hash=pwd_context.hash(personel.sifre),
        servis_no=personel.servis_no,
    )
    db.add(yeni_personel)
    db.commit()
    db.refresh(yeni_personel)
    return yeni_personel




@app.get("/birim", response_model=list[BirimOut])
def birim_listele(db: Session = Depends(get_db)):
    return db.query(Birim).all()



@app.get("/bant", response_model=list[BantOut])
def bant_listele(db: Session = Depends(get_db)):
    return db.query(Bant).all()


@app.get("/personel", response_model=list[PersonelOut])
def personel_listele(db: Session = Depends(get_db)):
    return db.query(Personel).all()