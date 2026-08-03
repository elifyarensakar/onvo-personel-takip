from models import Kayit, Gunluk_Arsiv, Ek_Mesai, Ek_Mesai_Arsiv
from sqlalchemy import func


def kayit_arsivle(db, hedef_tarih):
    """

    Kayit tablosundaki hedef_tarih'e ait satırları Gunluk_Arsiv'e kopyalar.
   
    """
    kayitlar = db.query(Kayit).filter(
        func.date(Kayit.giris_saati) == hedef_tarih
    ).all()

    for k in kayitlar:
        db.add(Gunluk_Arsiv(
            sicil_no=k.sicil_no,
            bant_no=k.bant_no,
            tarih=hedef_tarih,
            giris_saati=k.giris_saati,
            cikis_saati=k.cikis_saati,
        ))

    db.commit()
    return len(kayitlar)


def ek_mesai_arsivle(db, hedef_tarih):
    """

    Ek_Mesai tablosundaki hedef_tarih'e ait satırları Ek_Mesai_Arsiv'e kopyalar.
    
    """
    kayitlar = db.query(Ek_Mesai).filter(
        func.date(Ek_Mesai.baslangic_saati) == hedef_tarih
    ).all()

    for k in kayitlar:
        db.add(Ek_Mesai_Arsiv(
            sicil_no=k.sicil_no,
            birim_no=k.birim_no,
            tarih=hedef_tarih,
            baslangic_saati=k.baslangic_saati,
            bitis_saati=k.bitis_saati,
        ))

    db.commit()
    return len(kayitlar)

def kayit_sifirla(db, hedef_tarih):
    """
    Kayit tablosundaki hedef_tarih'e ait satırları siler.
    """
    kayitlar = db.query(Kayit).filter(
        func.date(Kayit.giris_saati) == hedef_tarih
    ).all()

    for k in kayitlar:
        db.delete(k)

    db.commit()
    return len(kayitlar)


def ek_mesai_sifirla(db, hedef_tarih):
    """
    Ek_Mesai tablosundaki hedef_tarih'e ait satırları siler.
  
    """
    kayitlar = db.query(Ek_Mesai).filter(
        func.date(Ek_Mesai.baslangic_saati) == hedef_tarih
    ).all()

    for k in kayitlar:
        db.delete(k)

    db.commit()
    return len(kayitlar)