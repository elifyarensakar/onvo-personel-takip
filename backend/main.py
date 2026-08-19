from fastapi import FastAPI , Depends
import secrets
from auth import token_olustur, get_current_user, rol_filtreleme
from sqlalchemy.orm import Session
from database import SessionLocal
from fastapi import HTTPException
from passlib.context import CryptContext
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from models import Birim , Bant , Personel , Kayit ,Ek_Mesai, Rapor_Gonderim_Log
from schemas import (
    BirimCreate, BirimOut ,
    BantCreate , BantOut,
    PersonelCreate, PersonelOut, PersonelUpdate,
    KayitCreate, KayitOut,
    EkMesaiCreate, EkMesaiOut,
    PersonelSicilNo,
    LoginRequest,
    RaporNotu,
    SifreDegistir
    )
from report import excel_dosyalari_olustur, ek_mesai_verisi_getir
from mail import gunluk_rapor_maili_gonder, yonetici_maillerini_getir
from datetime import date


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
            if kayit.giris_saati.weekday()==4:
                 kayit.cikis_saati = datetime.now().replace(hour=17, minute=30, second=0, microsecond=0)
            else:
                 kayit.cikis_saati = datetime.now().replace(hour=17, minute=0, second=0, microsecond=0)    
           

        db.commit()
    finally:
        db.close()

scheduler = BackgroundScheduler()
scheduler.add_job(gun_sonu_kapat, "cron", day_of_week="mon-thu", hour=17, minute=0)
scheduler.add_job(gun_sonu_kapat, "cron", day_of_week="fri", hour=17, minute=30)
scheduler.start()



@app.post("/birim", response_model=BirimOut)
def birim_ekle(birim: BirimCreate, db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["yonetici"]))):
    yeni_birim = Birim(birim_adi=birim.birim_adi)
    db.add(yeni_birim)
    db.commit()
    db.refresh(yeni_birim)
    return yeni_birim

@app.post("/bant", response_model=BantOut)
def bant_ekle(bant: BantCreate, db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["yonetici"]))):
    yeni_bant = Bant(birim_no=bant.birim_no,bant_adi=bant.bant_adi)
    db.add(yeni_bant)
    db.commit()
    db.refresh(yeni_bant)
    return yeni_bant

@app.post("/personel", response_model=PersonelOut)
def personel_ekle(personel: PersonelCreate, db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["yonetici"]))):
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
        email=personel.email
    )
    db.add(yeni_personel)
    db.commit()
    db.refresh(yeni_personel)
    return yeni_personel

@app.put("/personel/{sicil_no}", response_model=PersonelOut)
def personel_guncelle(sicil_no: str, personel: PersonelUpdate, db: Session = Depends(get_db), kullanici: dict = Depends(rol_filtreleme(["yonetici"]))):
    mevcut = db.query(Personel).filter(Personel.sicil_no == sicil_no).first()
    if mevcut is None:
        raise HTTPException(status_code=404, detail="Personel bulunamadı.")

    if personel.rol != "calisan" and personel.birim_no is None:
        raise HTTPException(
            status_code=400,
            detail="bant_sefi ve yonetici rolündeki personelin bir birime atanmış olması gerekir."
        )

    mevcut.ad_soyad = personel.ad_soyad
    mevcut.birim_no = personel.birim_no
    mevcut.rol = personel.rol
    mevcut.servis_no = personel.servis_no
    mevcut.email = personel.email
    db.commit()
    db.refresh(mevcut)
    return mevcut

@app.post("/kayit", response_model=KayitOut)
def kayit_ekle(kayit: KayitCreate, db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["yonetici","bant_sefi"]))):

    # Sicil no Personel tablosunda yoksa: QR'dan gelen ad_soyad/servis_no ile
    # otomatik, minimal bir Personel kaydı oluşturuluyor (rol='calisan',
    # birim_no boş bırakılıyor — proje kararınca calisan rolü için birim
    # zorunlu değil). Bu kişi login yapamaz (rastgele/kullanılamaz bir şifre
    # hash'i atanıyor), sadece giriş/çıkış kaydı tutulabilsin diye var.
    mevcut_personel = db.query(Personel).filter(Personel.sicil_no == kayit.sicil_no).first()
    if mevcut_personel is None:
        otomatik_personel = Personel(
            sicil_no=kayit.sicil_no,
            ad_soyad=kayit.ad_soyad or kayit.sicil_no,
            birim_no=None,
            rol="calisan",
            sifre_hash=pwd_context.hash(secrets.token_urlsafe(24)),
            servis_no=kayit.servis_no,
        )
        db.add(otomatik_personel)
        db.commit()

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
def ek_mesai_ekle(ek_mesai: EkMesaiCreate, db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["yonetici","bant_sefi"]))):
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
        token = token_olustur({"sicil_no": personel.sicil_no, "rol": personel.rol , "birim_no":personel.birim_no})
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
def birim_listele(db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["bant_sefi", "yonetici"]))):
    return db.query(Birim).all()



@app.get("/bant", response_model=list[BantOut])
def bant_listele(db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["bant_sefi", "yonetici"]))): 
    if kullanici["rol"]=="yonetici": 
        return db.query(Bant).all()
    elif kullanici["rol"] == "bant_sefi":
        return db.query(Bant).filter(Bant.birim_no == kullanici["birim_no"]).all()


@app.get("/personel", response_model=list[PersonelOut])
def personel_listele(db: Session = Depends(get_db) ,kullanici: dict = Depends(rol_filtreleme(["bant_sefi", "yonetici"]))):
    if kullanici["rol"]=="yonetici": 
        return db.query(Personel).all()
    elif kullanici["rol"] == "bant_sefi":
        return db.query(Personel).filter(Personel.birim_no == kullanici["birim_no"]).all()

@app.get("/kayit", response_model=list[KayitOut])
def kayit_listele(db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["yonetici","bant_sefi"]))):
    return db.query(Kayit).all()


@app.get("/ek-mesai", response_model=list[EkMesaiOut])
def ek_mesai_listele(db: Session = Depends(get_db),kullanici: dict = Depends(rol_filtreleme(["yonetici"]))):
    return db.query(Ek_Mesai).all()


@app.get("/rapor-durumu/{birim_no}")
def rapor_durumu(
    birim_no: int,
    db: Session = Depends(get_db),
    kullanici: dict = Depends(rol_filtreleme(["yonetici", "bant_sefi"])),
):
    hedef_tarih = date.today()
    sayi = db.query(Rapor_Gonderim_Log).filter(
        Rapor_Gonderim_Log.birim_no == birim_no,
        Rapor_Gonderim_Log.tarih == hedef_tarih,
    ).count()
    return {"bugun_gonderildi": sayi > 0, "gonderim_sayisi": sayi}


@app.post("/rapor-gonder/{birim_no}")
def rapor_gonder(
    birim_no: int,
    veri: RaporNotu = RaporNotu(),
    db: Session = Depends(get_db),
    kullanici: dict = Depends(rol_filtreleme(["yonetici", "bant_sefi"])),
):
    birim = db.query(Birim).filter(Birim.birim_no == birim_no).first()
    if birim is None:
        raise HTTPException(status_code=404, detail="Birim bulunamadı")

    hedef_tarih = date.today()
    aliciler = yonetici_maillerini_getir(db)

    kayit_dosya, ek_mesai_dosya = excel_dosyalari_olustur(
        db, birim_no, birim.birim_adi, hedef_tarih
    )

    ek_mesai_var = len(ek_mesai_verisi_getir(db, birim_no, hedef_tarih)) > 0
    dosyalar = [kayit_dosya] + ([ek_mesai_dosya] if ek_mesai_var else [])

    basarili = gunluk_rapor_maili_gonder(
        db, birim.birim_adi, hedef_tarih, dosyalar, veri.not_metni
    )

    if not basarili:
        raise HTTPException(status_code=502, detail="Mail gönderilemedi")

    db.add(Rapor_Gonderim_Log(
        birim_no=birim_no,
        tarih=hedef_tarih,
        saat=datetime.now(),
        not_metni=veri.not_metni,
    ))
    db.commit()

    return {"basarili": True, "aliciler": aliciler}

@app.post("/personel/sifre-degistir")
def sifre_degistir(
    veri: SifreDegistir,
    db: Session = Depends(get_db),
    kullanici: dict = Depends(get_current_user),
):
    personel = db.query(Personel).filter(
        Personel.sicil_no == kullanici["sicil_no"]
    ).first()
    if personel is None:
        raise HTTPException(status_code=404, detail="Personel bulunamadı")

    if not pwd_context.verify(veri.eski_sifre, personel.sifre_hash):
        raise HTTPException(status_code=401, detail="Mevcut şifre hatalı")

    personel.sifre_hash = pwd_context.hash(veri.yeni_sifre)
    db.commit()
    return {"basarili": True}