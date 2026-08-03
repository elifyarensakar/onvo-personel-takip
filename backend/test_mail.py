from database import SessionLocal
from mail import gunluk_rapor_maili_gonder
import datetime

db = SessionLocal()

hedef_tarih = datetime.date(2026, 7, 31)   
birim_adi = "Tv"                       


dosya_yollari = [
    "31.07.2026 TV_ekMesai.xlsx",
    "31.07.2026 TV.xlsx",
]

basarili = gunluk_rapor_maili_gonder(db, birim_adi, hedef_tarih, dosya_yollari)
print("Sonuç:", basarili)

db.close()