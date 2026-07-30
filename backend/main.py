from fastapi import FastAPI , Depends
from auth import token_olustur, get_current_user
from sqlalchemy.orm import Session
from database import SessionLocal
from fastapi import HTTPException
from passlib.context import CryptContext
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from models import Birim , Bant , Personel , Kayit ,Ek_Mesai
from schemas import (
    BirimCreate, BirimOut ,
    BantCreate , BantOut,
    PersonelCreate, PersonelOut,
    KayitCreate, KayitOut,
    EkMesaiCreate, EkMesaiOut,
    PersonelSicilNo,
    LoginRequest
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

def gun_sonu_kapat():
    db = SessionLocal()
    try:
        aktif_kayitlar = db.query(Kayit).filter(Kayit.cikis_saati == None).all()

        for kayit in aktif_kayitlar:
            kayit.cikis_saati = datetime.now().replace(hour=17, minute=0, second=0, microsecond=0)

        db.commit()
    finally:
        db.close()

scheduler = BackgroundScheduler()
scheduler.add_job(gun_sonu_kapat, "cron", hour=17, minute=00)
scheduler.start()



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

@app.post("/kayit", response_model=KayitOut)
def kayit_ekle(kayit: KayitCreate, db: Session = Depends(get_db)):

    aktif_kayit = db.query(Kayit).filter(
        Kayit.sicil_no == kayit.sicil_no,
        Kayit.cikis_saati == None
    ).first()

    if aktif_kayit is not None and aktif_kayit.bant_no == kayit.bant_no:
        gecen_sure = datetime.now() - aktif_kayit.giris_saati

        if gecen_sure < timedelta(minutes=5):
            raise HTTPException(
                status_code=400,
                detail="Bu personel bantta kısa süre önce okutuldu,yanlış okutma."
            )
        else:
            aktif_kayit.cikis_saati = datetime.now()
            db.commit()
            db.refresh(aktif_kayit)
            return aktif_kayit

    elif aktif_kayit is not None and aktif_kayit.bant_no != kayit.bant_no:
        aktif_kayit.cikis_saati = datetime.now()
        yeni_kayit = Kayit(
            sicil_no=kayit.sicil_no,
            bant_no=kayit.bant_no,
            giris_saati=datetime.now(),
        )
        db.add(yeni_kayit)
        db.commit()
        db.refresh(yeni_kayit)
        return yeni_kayit

    else:
        yeni_kayit = Kayit(
            sicil_no=kayit.sicil_no,
            bant_no=kayit.bant_no,
            giris_saati=datetime.now(),
        )
        db.add(yeni_kayit)
        db.commit()
        db.refresh(yeni_kayit)
        return yeni_kayit


@app.post("/ek-mesai", response_model=EkMesaiOut)
def ek_mesai_ekle(ek_mesai: EkMesaiCreate, db: Session = Depends(get_db)):
    aktif_mesai = db.query(Ek_Mesai).filter(
        Ek_Mesai.sicil_no == ek_mesai.sicil_no,
        Ek_Mesai.bitis_saati == None
    ).first()

    if aktif_mesai is not None:
        gecen_sure = datetime.now() - aktif_mesai.baslangic_saati
        if gecen_sure < timedelta(minutes=5):
            raise HTTPException(
                status_code=400,
                detail="Bu personel kısa süre önce mesaiye başladı, yanlış okutma."
            )
        else:
            aktif_mesai.bitis_saati = datetime.now()
            db.commit()
            db.refresh(aktif_mesai)
            return aktif_mesai
    else:
        yeni_mesai = Ek_Mesai(
            sicil_no=ek_mesai.sicil_no,
            baslangic_saati=datetime.now(),
        )
        db.add(yeni_mesai)
        db.commit()
        db.refresh(yeni_mesai)
        return yeni_mesai

@app.post("/login")
def login(veri: LoginRequest, db: Session = Depends(get_db)):
    personel = db.query(Personel).filter(Personel.sicil_no == veri.sicil_no).first()

    if personel is None:
        raise HTTPException(status_code=401, detail="Sicil no veya şifre hatalı")

    if pwd_context.verify(veri.sifre,personel.sifre_hash) == False:
        raise HTTPException(status_code=401, detail= "Şifre Hatalı")
    elif personel.aktif==False:
        raise HTTPException(status_code=403, detail= "Sicil no hatalı")
    else:
        token = token_olustur({"sicil_no": personel.sicil_no, "rol": personel.rol})
        return {"access_token": token, "token_type": "bearer"}

   
@app.patch("/personel/aktif", response_model=PersonelOut)
def personel_aktif_degistir(veri: PersonelSicilNo, db: Session = Depends(get_db),kullanici: dict = Depends(get_current_user)):
    personel = db.query(Personel).filter(Personel.sicil_no == veri.sicil_no).first()

    if personel is None:
        raise HTTPException(status_code=404, detail="Personel bulunamadı")
    
    if kullanici["rol"]=="calisan":
        raise HTTPException(status_code=403, detail="Bu işlem için yetkiniz yok")
    else:
        personel.aktif = not personel.aktif
        db.commit()
        db.refresh(personel)
        return personel



    
    


@app.get("/birim", response_model=list[BirimOut])
def birim_listele(db: Session = Depends(get_db)):
    return db.query(Birim).all()



@app.get("/bant", response_model=list[BantOut])
def bant_listele(db: Session = Depends(get_db)):
    return db.query(Bant).all()


@app.get("/personel", response_model=list[PersonelOut])
def personel_listele(db: Session = Depends(get_db)):
    return db.query(Personel).all()

@app.get("/kayit", response_model=list[KayitOut])
def kayit_listele(db: Session = Depends(get_db)):
    return db.query(Kayit).all()


@app.get("/ek-mesai", response_model=list[EkMesaiOut])
def ek_mesai_listele(db: Session = Depends(get_db)):
    return db.query(Ek_Mesai).all()

