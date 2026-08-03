from database import SessionLocal
from archive import kayit_arsivle, ek_mesai_arsivle, kayit_sifirla, ek_mesai_sifirla
import datetime

db = SessionLocal()

hedef_tarih = datetime.date(2026, 7, 31)  

kayit_sayisi = kayit_sifirla(db, hedef_tarih)
ek_mesai_sayisi = ek_mesai_sifirla(db, hedef_tarih)

print(f"Silinen Kayit sayısı: {kayit_sayisi}")
print(f"Silinen Ek_Mesai sayısı: {ek_mesai_sayisi}")

db.close()