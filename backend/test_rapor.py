from datetime import date
from database import SessionLocal
from report import excel_dosyalari_olustur, excel_bicimlendir

db = SessionLocal()

hedef_birim = 2
birim_adi = "TV"
hedef_tarih = date(2026, 7, 31)

kayit_dosya, ek_mesai_dosya = excel_dosyalari_olustur(db, hedef_birim, birim_adi, hedef_tarih)

excel_bicimlendir(kayit_dosya)
excel_bicimlendir(ek_mesai_dosya)

print("Oluşturuldu:", kayit_dosya)
print("Oluşturuldu:", ek_mesai_dosya)

db.close()