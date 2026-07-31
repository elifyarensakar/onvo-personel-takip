from database import Base
from sqlalchemy import Column, Integer, String , Boolean
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import Enum
from sqlalchemy import Column, Integer, String, ForeignKey, Enum, DateTime, Date

class Birim(Base):
    __tablename__ = "birim"

    birim_no = Column(Integer,primary_key =True)
    birim_adi =Column(String(40))


class Bant(Base):
    __tablename__ = "bant"

    bant_no = Column(Integer,primary_key = True)
    birim_no = Column(Integer,ForeignKey("birim.birim_no",ondelete="CASCADE"))
    bant_adi= Column(String(100))

class Personel(Base):
    __tablename__ = "personel"

    sicil_no = Column(String(30),primary_key = True)
    ad_soyad = Column(String(60),nullable=False)
    birim_no = Column(Integer, ForeignKey("birim.birim_no",ondelete="RESTRICT"))
    rol = Column(Enum("calisan","bant_sefi","yonetici",name="rol_turu"),nullable=False)
    sifre_hash = Column(String(60),nullable=False)
    servis_no= Column(String(60))
    aktif = Column(Boolean, nullable=False, default=True)


class Kayit(Base):
    __tablename__ = "kayit"

    kayit_id = Column(Integer, primary_key=True)
    sicil_no = Column(String(30), ForeignKey("personel.sicil_no",ondelete="RESTRICT"), nullable=False)
    bant_no = Column(Integer, ForeignKey("bant.bant_no",ondelete="RESTRICT"), nullable=False)
    giris_saati = Column(DateTime, nullable=False)
    cikis_saati = Column(DateTime)


class Ek_Mesai(Base):
    __tablename__ = "ek_mesai"

    ek_mesai_id = Column(Integer, primary_key=True)
    sicil_no = Column(String(30), ForeignKey("personel.sicil_no",ondelete="RESTRICT"), nullable=False)
    baslangic_saati = Column(DateTime, nullable=False)
    bitis_saati = Column(DateTime)
    birim_no = Column(Integer,ForeignKey("birim.birim_no",ondelete="RESTRICT"),nullable=False)


class Gunluk_Arsiv(Base):
    __tablename__ = "gunluk_arsiv"

    arsiv_id = Column(Integer, primary_key=True)
    sicil_no = Column(String(30), ForeignKey("personel.sicil_no",ondelete="RESTRICT"), nullable=False)
    bant_no = Column(Integer, ForeignKey("bant.bant_no",ondelete="RESTRICT"), nullable=False)
    tarih = Column(Date)
    giris_saati = Column(DateTime)
    cikis_saati = Column(DateTime)