CREATE SCHEMA public;
CREATE TYPE rol_turu AS ENUM ('calisan', 'bant_sefi', 'yonetici');
ALTER TABLE Personel ADD COLUMN email VARCHAR(255);


CREATE TABLE Birim (
    birim_no SERIAL PRIMARY KEY,
    birim_adi VARCHAR(40)
);

CREATE TABLE Bant (
    bant_no SERIAL PRIMARY KEY,
    birim_no INTEGER REFERENCES Birim(birim_no) ON DELETE CASCADE,
    bant_adi VARCHAR(100),
    UNIQUE (birim_no, bant_adi)
);

CREATE TABLE Personel (

    sicil_no VARCHAR(30) PRIMARY KEY,
    ad_soyad VARCHAR(60) NOT NULL,
    birim_no INTEGER REFERENCES Birim(birim_no) ON DELETE RESTRICT,
    rol rol_turu NOT NULL,
    sifre_hash VARCHAR(60) NOT NULL,
    servis_no VARCHAR(60),
    aktif BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (rol = 'calisan' OR birim_no IS NOT NULL)
);

CREATE TABLE Kayit (
    kayit_id SERIAL PRIMARY KEY,
    sicil_no VARCHAR(30) NOT NULL REFERENCES Personel(sicil_no) ON DELETE RESTRICT,
    bant_no INTEGER NOT NULL REFERENCES Bant(bant_no) ON DELETE RESTRICT,
    giris_saati TIMESTAMP NOT NULL,
    cikis_saati TIMESTAMP
);

CREATE TABLE Ek_Mesai (
    ek_mesai_id SERIAL PRIMARY KEY,
    sicil_no VARCHAR(30) NOT NULL REFERENCES Personel(sicil_no) ON DELETE RESTRICT,
    baslangic_saati TIMESTAMP NOT NULL,
    bitis_saati TIMESTAMP,
    birim_no INTEGER NOT null REFERENCES Birim(birim_no) ON DELETE RESTRICT
);

CREATE TABLE Gunluk_Arsiv (
    arsiv_id SERIAL PRIMARY KEY,
    sicil_no VARCHAR(30) NOT NULL REFERENCES Personel(sicil_no) ON DELETE RESTRICT,
    bant_no INTEGER NOT NULL REFERENCES Bant(bant_no) ON DELETE RESTRICT,
    tarih DATE,
    giris_saati TIMESTAMP,
    cikis_saati TIMESTAMP
);
CREATE TABLE Ek_Mesai_Arsiv (
    ek_mesai_arsiv_id SERIAL PRIMARY KEY,
    sicil_no VARCHAR(20) NOT NULL REFERENCES Personel(sicil_no),
    birim_no INTEGER NOT NULL REFERENCES Birim(birim_no) ON DELETE RESTRICT,
    tarih DATE NOT NULL,
    baslangic_saati TIMESTAMP NOT NULL,
    bitis_saati TIMESTAMP
);