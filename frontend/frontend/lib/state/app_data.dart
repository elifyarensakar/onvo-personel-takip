import 'package:flutter/foundation.dart';

/// Backend'in bir taramaya/kayda verdiği cevabın türü.
enum ScanAction { girisYapildi, cikisYapildi }

class ScanResult {
  const ScanResult({
    required this.employeeName,
    required this.action,
    this.isKnownPersonnel = true,
  });
  final String employeeName;
  final ScanAction action;

  /// false ise bu sicil no personel listesinde kayıtlı değil — QR/manuel
  /// girişteki bilgi doğrudan kaydedildi. Fabrikada akışı yavaşlatmamak
  /// için bulunamayan personel reddedilmiyor, sadece bilgi amaçlı işaretleniyor.
  final bool isKnownPersonnel;
}

/// Sicil no bulunamadığında / backend'e ulaşılamadığında fırlatılır.
class ScanException implements Exception {
  const ScanException(this.message);
  final String message;
}

/// Birim + o birime bağlı bantlar.
class BirimData {
  BirimData({required this.name, required List<String> bants})
      : bants = List<String>.of(bants);

  String name;
  final List<String> bants;
}

class Personel {
  Personel({
    required this.sicilNo,
    required this.adSoyad,
    required this.birim,
    required this.bant,
    required this.rol,
  });

  final String sicilNo;
  String adSoyad;
  String birim;
  String bant;
  String rol; // 'Bant Şefi' | 'Yönetici'
}

/// O an bantta aktif (cikis_saati IS NULL) olan bir kayıt.
class ActiveRecord {
  ActiveRecord({
    required this.sicilNo,
    required this.adSoyad,
    required this.birim,
    required this.bantAdi,
    required this.girisSaati,
  });

  final String sicilNo;
  final String adSoyad;
  final String birim;
  final String bantAdi;
  final DateTime girisSaati;
}

class ReportLogEntry {
  const ReportLogEntry({
    required this.sentAt,
    required this.birim,
    required this.recipients,
  });

  final DateTime sentAt;
  final String birim;
  final List<String> recipients;
}

/// Uygulama genelinde paylaşılan tek durum kaynağı.
///
/// Login, QR ekranı, Manuel Giriş, İstatistikler ve Admin Paneli hepsi bu
/// sınıfı okuyup üzerinde değişiklik yapıyor — bir ekrandaki değişiklik
/// (yeni bant eklenmesi, bir taramanın sonucu, gönderilen rapor) diğer
/// ekranlara `notifyListeners()` üzerinden otomatik yansıyor. Böylece
/// ekranlar artık birbirinden habersiz kendi mock verisini tutmuyor.
class AppData extends ChangeNotifier {
  AppData() {
    _seedMockData();
  }

  final List<BirimData> birimler = [];
  final List<Personel> personelListesi = [];
  final List<ActiveRecord> aktifKayitlar = [];
  final List<ReportLogEntry> raporGecmisi = [];

  void _seedMockData() {
    // TODO: gerçek entegrasyonda bu başlangıç verisi yerine backend'den
    // ilk yükleme (login sonrası) yapılacak.
    birimler.addAll([
      BirimData(name: 'A Blok', bants: ['Bant 1', 'Bant 2']),
      BirimData(name: 'B Blok', bants: ['Bant 1', 'Bant 3']),
      BirimData(name: 'C Blok', bants: ['Bant 1']),
    ]);

    personelListesi.addAll([
      Personel(
        sicilNo: '048213',
        adSoyad: 'Ahmet Yılmaz',
        birim: 'A Blok',
        bant: 'Bant 1',
        rol: 'Bant Şefi',
      ),
      Personel(
        sicilNo: '051902',
        adSoyad: 'Elif Demir',
        birim: 'A Blok',
        bant: 'Bant 2',
        rol: 'Bant Şefi',
      ),
      Personel(
        sicilNo: '039841',
        adSoyad: 'Mehmet Kaya',
        birim: 'B Blok',
        bant: 'Bant 1',
        rol: 'Bant Şefi',
      ),
      Personel(
        sicilNo: '062217',
        adSoyad: 'Zeynep Arslan',
        birim: 'B Blok',
        bant: 'Bant 3',
        rol: 'Bant Şefi',
      ),
      Personel(
        sicilNo: '071355',
        adSoyad: 'Can Öztürk',
        birim: 'C Blok',
        bant: 'Bant 1',
        rol: 'Bant Şefi',
      ),
      Personel(
        sicilNo: '010001',
        adSoyad: 'Selin Aydın',
        birim: 'A Blok',
        bant: 'Bant 1',
        rol: 'Yönetici',
      ),
    ]);

    final now = DateTime.now();
    // Demoyu baştan canlı göstermek için birkaç kişi başlangıçta "aktif"
    // (hâlâ bantta, henüz çıkış yapmamış) olarak işaretlendi.
    aktifKayitlar.addAll([
      ActiveRecord(
        sicilNo: '048213',
        adSoyad: 'Ahmet Yılmaz',
        birim: 'A Blok',
        bantAdi: 'Bant 1',
        girisSaati: now.subtract(const Duration(minutes: 42)),
      ),
      ActiveRecord(
        sicilNo: '051902',
        adSoyad: 'Elif Demir',
        birim: 'A Blok',
        bantAdi: 'Bant 2',
        girisSaati: now.subtract(const Duration(hours: 1, minutes: 10)),
      ),
      ActiveRecord(
        sicilNo: '039841',
        adSoyad: 'Mehmet Kaya',
        birim: 'B Blok',
        bantAdi: 'Bant 1',
        girisSaati: now.subtract(const Duration(minutes: 18)),
      ),
    ]);

    raporGecmisi.addAll([
      ReportLogEntry(
        sentAt: now.subtract(const Duration(hours: 3)),
        birim: 'A Blok',
        recipients: const ['[email protected]', '[email protected]'],
      ),
      ReportLogEntry(
        sentAt: now.subtract(const Duration(days: 1, hours: 2)),
        birim: 'B Blok',
        recipients: const ['[email protected]'],
      ),
    ]);
  }

  /// Şu an login olmuş bant şefinin birimi.
  // TODO: gerçek uygulamada bu, login cevabından (JWT / sicil no'dan
  // çözülen birim) gelecek. Henüz gerçek oturum/birim bilgisi olmadığı
  // için ilk birim varsayılan olarak kullanılıyor.
  BirimData get currentBirim => birimler.isNotEmpty
      ? birimler.first
      : BirimData(name: '—', bants: const []);

  // ---------------------------------------------------------------------
  // Birim & Bant yönetimi
  // ---------------------------------------------------------------------

  void addBirim(String name) {
    // TODO: backend'e yeni birim oluşturma isteği gönderilecek.
    birimler.add(BirimData(name: name, bants: const []));
    notifyListeners();
  }

  void addBant(BirimData birim, String bantName) {
    // TODO: backend'e yeni bant oluşturma isteği gönderilecek.
    birim.bants.add(bantName);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Personel yönetimi
  // ---------------------------------------------------------------------

  void updatePersonel(
    Personel personel, {
    required String adSoyad,
    required String birim,
    required String bant,
    required String rol,
  }) {
    // TODO: backend'e personel güncelleme isteği gönderilecek.
    personel.adSoyad = adSoyad;
    personel.birim = birim;
    personel.bant = bant;
    personel.rol = rol;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Giriş / Çıkış kaydı — QR ekranı ve Manuel Giriş bu tek fonksiyonu
  // paylaşıyor, ikisi de aynı sonucu üretiyor.
  // ---------------------------------------------------------------------

  Future<ScanResult> recordScan({
    required String sicilNo,
    required String birim,
    required String bant,
  }) async {
    // TODO: gerçek backend entegrasyonu — bu mantık (kişiyi bulma, başka
    // bantta aktifse otomatik çıkış kararı) sunucuda çalışacak; burada
    // prototip için local olarak simüle ediliyor.
    await Future.delayed(const Duration(milliseconds: 900));

    // Önemli: personel listesinde kaydı olmayan biri de okutabilir (yeni
    // işe başlayan, geçici personel vb.) — fabrikada akışı yavaşlatacak
    // bir doğrulama/filtreleme yapmıyoruz, QR'daki sicil no bilgisini
    // doğrudan kaydediyoruz. Listede varsa adı gösteriliyor, yoksa sicil
    // no'nun kendisi "isim" alanında gösteriliyor ve isKnownPersonnel
    // false olarak işaretleniyor (ekranda küçük bir bilgi notu için).
    final matches = personelListesi.where((p) => p.sicilNo == sicilNo);
    final isKnown = matches.isNotEmpty;
    final displayName = isKnown ? matches.first.adSoyad : sicilNo;

    final existingIndex = aktifKayitlar.indexWhere((r) => r.sicilNo == sicilNo);
    if (existingIndex >= 0) {
      // Zaten aktif (başka bir bantta olsa bile) — otomatik çıkış.
      aktifKayitlar.removeAt(existingIndex);
      notifyListeners();
      return ScanResult(
        employeeName: displayName,
        action: ScanAction.cikisYapildi,
        isKnownPersonnel: isKnown,
      );
    }

    aktifKayitlar.add(
      ActiveRecord(
        sicilNo: sicilNo,
        adSoyad: displayName,
        birim: birim,
        bantAdi: bant,
        girisSaati: DateTime.now(),
      ),
    );
    notifyListeners();
    return ScanResult(
      employeeName: displayName,
      action: ScanAction.girisYapildi,
      isKnownPersonnel: isKnown,
    );
  }

  // ---------------------------------------------------------------------
  // Rapor gönderme
  // ---------------------------------------------------------------------

  Future<void> sendReport(
      {required String birim, required List<String> recipients}) async {
    // TODO: backend'e mesai yoklama raporu gönderme isteği atılacak.
    await Future.delayed(const Duration(milliseconds: 1200));
    raporGecmisi.insert(
      0,
      ReportLogEntry(
          sentAt: DateTime.now(), birim: birim, recipients: recipients),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Türetilmiş veriler
  // ---------------------------------------------------------------------

  List<String> get birimFilterOptions {
    final unique = birimler.map((b) => b.name).toList()..sort();
    return ['Tüm Birimler', ...unique];
  }

  List<ActiveRecord> activeRecordsForBirim(String birim) {
    if (birim == 'Tüm Birimler') return List.unmodifiable(aktifKayitlar);
    return aktifKayitlar.where((r) => r.birim == birim).toList();
  }

  ReportLogEntry? latestReportForBirimToday(String birim) {
    final now = DateTime.now();
    for (final entry in raporGecmisi) {
      final sameDay = entry.sentAt.year == now.year &&
          entry.sentAt.month == now.month &&
          entry.sentAt.day == now.day;
      if (entry.birim == birim && sameDay) return entry;
    }
    return null;
  }
}
