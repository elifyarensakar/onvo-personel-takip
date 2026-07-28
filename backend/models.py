from database import Base
from sqlalchemy import Column, Integer, String
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import Enum

class Birim(Base):
    __tablename__ = "birim"

    birim_no = Column(Integer,primary_key =True)
    birim_adi =Column(String(40))


class Bant(Base):
    __tablename__ = "bant"

    bant_no = Column(Integer,primary_key = True)
    birim_no = Column(Integer,ForeignKey("birim.birim_no"))
    bant_adi= Column(String(100))

class Personel(Base):
    __tablename__ = "personel"

    sicil_no = Column(String(30),primary_key = True)
    ad_soyad = Column(String(60),nullable=False)
    birim_no = Column(Integer, ForeignKey("birim.birim_no"))
    rol = Column(Enum("calisan","bant_sefi","yonetici",name="rol_turu"),nullable=False)
    sifre_hash = Column(String(60),nullable=False)
    servis_no= Column(String(60))


