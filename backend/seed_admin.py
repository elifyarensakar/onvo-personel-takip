from passlib.context import CryptContext
from database import SessionLocal
from models import Personel

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

db = SessionLocal()

ilk_yonetici = Personel(
    sicil_no="1234/1234",
    ad_soyad="Sıla Başkaya",
    birim_no=1,
    rol="yonetici",
    sifre_hash=pwd_context.hash("Sifre1234"),  # istersen değiştir, 8-16 karakter kuralına uy
    servis_no=None,
)

db.add(ilk_yonetici)
db.commit()
db.refresh(ilk_yonetici)

print(f"Eklendi: {ilk_yonetici.sicil_no} - {ilk_yonetici.rol}")

db.close()