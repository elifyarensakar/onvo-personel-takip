import os
import smtplib
from email.message import EmailMessage
from pathlib import Path
from dotenv import load_dotenv
from models import Personel


load_dotenv(dotenv_path=Path(__file__).parent / ".env")

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = os.getenv("SMTP_PORT")
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")


def yonetici_maillerini_getir(db):
   
    sonuc = db.query(Personel.email).filter(
        Personel.rol == "yonetici",
        Personel.email.isnot(None)
    ).all()
    return [r[0] for r in sonuc]


def gunluk_rapor_maili_gonder(db, birim_adi, hedef_tarih, dosya_yollari, not_metni=None):
    aliciler = yonetici_maillerini_getir(db)
    if not aliciler:
        print(f"[UYARI] {birim_adi} için mail gönderilecek yönetici bulunamadı.")
        return False

    tarih_str = hedef_tarih.strftime("%d.%m.%Y")

    msg = EmailMessage()
    msg["Subject"] = f"{birim_adi} - Günlük Personel Takip Raporu ({tarih_str})"
    msg["From"] = SMTP_USER
    msg["To"] = ", ".join(aliciler)

    govde = f"{birim_adi} birimine ait {tarih_str} tarihli günlük personel takip raporu ektedir."
    if not_metni:
        govde += f"\n\nNot: {not_metni}"
    msg.set_content(govde)

    for dosya_yolu in dosya_yollari:
        yol = Path(dosya_yolu)
        with open(yol, "rb") as f:
            msg.add_attachment(
                f.read(),
                maintype="application",
                subtype="vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                filename=yol.name,
            )

    try:
        with smtplib.SMTP_SSL(SMTP_HOST, int(SMTP_PORT)) as server:
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        print(f"[OK] {birim_adi} raporu {len(aliciler)} yöneticiye gönderildi.")
        return True
    except Exception as e:
        print(f"[HATA] {birim_adi} raporu gönderilemedi: {e}")
        return False
    

