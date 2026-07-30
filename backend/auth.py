import os
from datetime import datetime, timedelta
from jose import jwt
from dotenv import load_dotenv
from pathlib import Path
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError

oauth2_scheme = HTTPBearer()




load_dotenv(dotenv_path=Path(__file__).parent / ".env")

SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = "HS256"
TOKEN_SURESI_DAKIKA = 12 * 60  # 12 saat


def get_current_user(kimlik: HTTPAuthorizationCredentials = Depends(oauth2_scheme)):
    token = kimlik.credentials
    try:
        veri = token_dogrula(token)
        return veri
    except JWTError:
        raise HTTPException(status_code=401, detail="Token geçersiz veya süresi dolmuş")

def token_olustur(veri: dict):
    veri_kopya = veri.copy()
    son_kullanma = datetime.now() + timedelta(minutes=TOKEN_SURESI_DAKIKA)
    veri_kopya.update({"exp": son_kullanma})
    return jwt.encode(veri_kopya, SECRET_KEY, algorithm=ALGORITHM)


def token_dogrula(token: str):
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])