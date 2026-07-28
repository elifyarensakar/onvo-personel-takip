from pydantic import BaseModel
from typing import Optional


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

    class Config:
        from_attributes = True