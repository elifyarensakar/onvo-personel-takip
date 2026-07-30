from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class LoginRequest(BaseModel):
    sicil_no: str
    sifre: str

    
class PersonelSicilNo(BaseModel):
    sicil_no: str

class BirimCreate(BaseModel):
    birim_adi: str

class BantCreate(BaseModel):
    bant_no: int
    birim_no: int
    bant_adi : str

class PersonelCreate(BaseModel):
    sicil_no: str
    ad_soyad: str
    birim_no: Optional[int] = None
    rol: str
    sifre: str
    servis_no: Optional[str] = None

class KayitCreate(BaseModel):
    sicil_no: str
    bant_no: int

class EkMesaiCreate(BaseModel):
    sicil_no: str



class BirimOut(BaseModel):
    birim_no:int
    birim_adi:str

    class Config:
        from_attributes = True


class BantOut(BaseModel):
    bant_no: int
    birim_no: int
    bant_adi : str

    class Config:
        from_attributes = True
    
class PersonelOut(BaseModel):
    sicil_no: str
    ad_soyad: str
    birim_no: Optional[int] = None
    rol: str
    servis_no: Optional[str] = None
    aktif: bool

    class Config:
        from_attributes = True

class KayitOut(BaseModel):
    kayit_id: int
    sicil_no: str
    bant_no: int
    giris_saati: datetime
    cikis_saati: Optional[datetime] = None

    class Config:
        from_attributes = True 

class EkMesaiOut(BaseModel):
    ek_mesai_id: int
    sicil_no: str
    baslangic_saati: datetime
    bitis_saati: Optional[datetime] = None

    class Config:
        from_attributes = True