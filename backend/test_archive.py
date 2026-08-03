from database import SessionLocal
from archive import kayit_arsivle, ek_mesai_arsivle
import datetime

db = SessionLocal()

hedef_tarih = datetime.date(2026, 7, 31)  

kayit_sayisi = kayit_arsivle(db, hedef_tarih)
ek_mesai_sayisi = ek_mesai_arsivle(db, hedef_tarih)

print(f"Arşivlenen Kayit sayısı: {kayit_sayisi}")
print(f"Arşivlenen Ek_Mesai sayısı: {ek_mesai_sayisi}")

db.close()