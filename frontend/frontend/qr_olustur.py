import os
import pandas as pd
import qrcode

# --- AYARLAR ---
PERSONEL_DOSYASI = 'GÜNCEL SCOOTER PERSONEL LİSTESİ ÜRETİM06 08.xlsx'
SERVIS_DOSYASI = 'XX.06.2026 MESAİ LİSTESİ TEMEL ÖZDEMİR.xlsx'

print('Dosyalar okunuyor...')
# 1. Personel dosyasını yükle
df_personel = pd.read_excel(PERSONEL_DOSYASI)

# 2. Servis dosyasını yükle (Başlık 4. satırda olduğu için skiprows=3 kullanıyoruz)
df_servis = pd.read_excel(SERVIS_DOSYASI, skiprows=3)

# İsimlerde olası boşluk hatalarını önlemek için temizlik yapalım
df_personel['Ad Soyad'] = df_personel['Ad Soyad'].astype(str).str.strip()
df_servis['PERSONEL ADI SOYADI'] = (
    df_servis['PERSONEL ADI SOYADI'].astype(str).str.strip()
)

# 3. İki tabloyu 'Ad Soyad' üzerinden birleştir (Left Join)
merged_df = pd.merge(
    df_personel,
    df_servis[['PERSONEL ADI SOYADI', 'SERVİS NO']],
    left_on='Ad Soyad',
    right_on='PERSONEL ADI SOYADI',
    how='left',
)

# 4. Servis numarası olmayan (null olan) personellere "Servis Yok" yaz
merged_df['SERVİS NO'] = merged_df['SERVİS NO'].fillna('Servis Yok')

# 5. QR kodların kaydedileceği klasörü oluştur
if not os.path.exists('QR_Kodlar'):
  os.makedirs('QR_Kodlar')

# 6. QR Kodları Döngü ile Üret
print('QR kodlar oluşturuluyor...')
basarili_sayisi = 0

for index, row in merged_df.iterrows():
  ad = row['Ad Soyad']
  sicil = str(row['Sicil No'])
  servis = str(row['SERVİS NO'])

  # QR içinde yer alacak metin içeriği
  data = f'Ad Soyad: {ad}\nSicil No: {sicil}\nServis No: {servis}'

  # QR kod nesnesi oluştur
  qr = qrcode.QRCode(version=1, box_size=10, border=4)
  qr.add_data(data)
  qr.make(fit=True)

  img = qr.make_image(fill_color='black', back_color='white')

  # Dosya adı olarak Sicil No ve Ad Soyad kullan (KARIŞIKLIK OLMASIN DİYE)
  dosya_adi = f"QR_Kodlar/{sicil}_{ad.replace(' ', '_')}.png"
  img.save(dosya_adi)
  basarili_sayisi += 1

print(
    f'İşlem tamam! Toplam {basarili_sayisi} adet personel QR kodu "QR_Kodlar"'
    ' klasörüne kaydedildi.'
)