import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum ScanAction { girisYapildi, cikisYapildi }

class ScanResult {
  const ScanResult({
    required this.employeeName,
    required this.action,
    this.isKnownPersonnel = true,
  });
  final String employeeName;
  final ScanAction action;
  final bool isKnownPersonnel;
}

class ScanException implements Exception {
  const ScanException(this.message);
  final String message;

  @override
  String toString() => message;
}

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
    this.email,
    this.servisNo,
  });

  final String sicilNo;
  String adSoyad;
  String birim;
  String bant;
  String rol;
  String? email;
  String? servisNo;
}

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

class AppData extends ChangeNotifier {
  final List<BirimData> birimler = [];
  final List<Personel> personelListesi = [];
  final List<ActiveRecord> aktifKayitlar = [];
  final List<ReportLogEntry> raporGecmisi = [];

  // ---------------------------------------------------------------------
  // Oturum
  // ---------------------------------------------------------------------

  String? authToken;
  String? currentRol;
  int? currentBirimNo;
  String? currentSicilNo;

  void setSession({
    required String token,
    required String rol,
    int? birimNo,
    required String sicilNo,
  }) {
    authToken = token;
    currentRol = rol;
    currentBirimNo = birimNo;
    currentSicilNo = sicilNo;
    notifyListeners();
  }

  void clearSession() {
    authToken = null;
    currentRol = null;
    currentBirimNo = null;
    currentSicilNo = null;
    birimler.clear();
    personelListesi.clear();
    aktifKayitlar.clear();
    _birimNoByAdi.clear();
    _bantNoByBirimVeAdi.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Backend'den gerçek veri yükleme (login sonrası çağrılır)
  // ---------------------------------------------------------------------

  final Map<String, int> _birimNoByAdi = {};
  final Map<String, Map<String, int>> _bantNoByBirimVeAdi = {};

  Future<void> loadInitialData() async {
    final token = authToken;
    if (token == null) return;

    final api = ApiService();
    final birimlerData = await api.fetchBirimler(token);
    final bantlarData = await api.fetchBantlar(token);
    final personelData = await api.fetchPersonel(token);

    _birimNoByAdi.clear();
    _bantNoByBirimVeAdi.clear();
    birimler.clear();
    personelListesi.clear();

    final birimAdiByNo = <int, String>{};
    for (final b in birimlerData) {
      final no = b['birim_no'] as int;
      final adi = b['birim_adi'] as String;
      birimAdiByNo[no] = adi;
      _birimNoByAdi[adi] = no;
    }

    final bantsByBirimAdi = <String, List<String>>{};
    for (final b in bantlarData) {
      final birimNo = b['birim_no'] as int;
      final bantNo = b['bant_no'] as int;
      final bantAdi = b['bant_adi'] as String;
      final birimAdi = birimAdiByNo[birimNo];
      if (birimAdi == null) continue;

      bantsByBirimAdi.putIfAbsent(birimAdi, () => []).add(bantAdi);
      _bantNoByBirimVeAdi.putIfAbsent(birimAdi, () => {})[bantAdi] = bantNo;
    }

    for (final adi in _birimNoByAdi.keys) {
      birimler.add(
        BirimData(name: adi, bants: bantsByBirimAdi[adi] ?? const []),
      );
    }

    for (final p in personelData) {
      personelListesi.add(
        Personel(
          sicilNo: p['sicil_no'] as String,
          adSoyad: p['ad_soyad'] as String,
          birim: birimAdiByNo[p['birim_no']] ?? '',
          bant: '',
          rol: p['rol'] as String,
          email: p['email'] as String?,
          servisNo: p['servis_no'] as String?,
        ),
      );
    }

    notifyListeners();
  }

  BirimData get currentBirim {
    if (currentBirimNo != null) {
      final adi = _birimAdiFromNo(currentBirimNo!);
      if (adi != null) {
        final match = birimler.where((b) => b.name == adi);
        if (match.isNotEmpty) return match.first;
      }
    }
    return birimler.isNotEmpty
        ? birimler.first
        : BirimData(name: '—', bants: const []);
  }

  String? _birimAdiFromNo(int no) {
    for (final entry in _birimNoByAdi.entries) {
      if (entry.value == no) return entry.key;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Birim & Bant yönetimi
  // ---------------------------------------------------------------------

  Future<void> addBirim(String name) async {
    final token = authToken;
    if (token == null) {
      throw const ScanException(
          'Oturum bulunamadı, lütfen tekrar giriş yapın.');
    }
    try {
      await ApiService().createBirim(token: token, birimAdi: name);
    } catch (e) {
      throw ScanException(e.toString().replaceFirst('Exception: ', ''));
    }
    await loadInitialData();
  }

  Future<void> addBant(BirimData birim, String bantName) async {
    final token = authToken;
    if (token == null) {
      throw const ScanException(
          'Oturum bulunamadı, lütfen tekrar giriş yapın.');
    }
    final birimNo = _birimNoByAdi[birim.name];
    if (birimNo == null) {
      throw const ScanException('Birim bilgisi bulunamadı.');
    }
    try {
      await ApiService().createBant(
        token: token,
        birimNo: birimNo,
        bantAdi: bantName,
      );
    } catch (e) {
      throw ScanException(e.toString().replaceFirst('Exception: ', ''));
    }
    await loadInitialData();
  }

  void updatePersonel(
    Personel personel, {
    required String adSoyad,
    required String birim,
    required String bant,
    required String rol,
  }) {
    personel.adSoyad = adSoyad;
    personel.birim = birim;
    personel.bant = bant;
    personel.rol = rol;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Giriş / Çıkış kaydı
  // ---------------------------------------------------------------------

  Future<ScanResult> recordScan({
    required String sicilNo,
    required String birim,
    required String bant,
  }) async {
    final token = authToken;
    if (token == null) {
      throw const ScanException(
          'Oturum bulunamadı, lütfen tekrar giriş yapın.');
    }

    final bantNo = _bantNoByBirimVeAdi[birim]?[bant];
    if (bantNo == null) {
      throw const ScanException('Bant bilgisi bulunamadı.');
    }

    Map<String, dynamic> kayit;
    try {
      kayit = await ApiService().createKayit(
        token: token,
        sicilNo: sicilNo,
        bantNo: bantNo,
      );
    } catch (e) {
      throw ScanException(e.toString().replaceFirst('Exception: ', ''));
    }

    final isCikis = kayit['cikis_saati'] != null;

    final matches = personelListesi.where((p) => p.sicilNo == sicilNo);
    final isKnown = matches.isNotEmpty;
    final displayName = isKnown ? matches.first.adSoyad : sicilNo;

    aktifKayitlar.removeWhere((r) => r.sicilNo == sicilNo);
    if (!isCikis) {
      aktifKayitlar.add(
        ActiveRecord(
          sicilNo: sicilNo,
          adSoyad: displayName,
          birim: birim,
          bantAdi: bant,
          girisSaati: DateTime.parse(kayit['giris_saati'] as String),
        ),
      );
    }
    notifyListeners();

    return ScanResult(
      employeeName: displayName,
      action: isCikis ? ScanAction.cikisYapildi : ScanAction.girisYapildi,
      isKnownPersonnel: isKnown,
    );
  }

  Future<void> addPersonelBackend({
    required String sicilNo,
    required String adSoyad,
    required String birim,
    required String rol,
    required String sifre,
    String? email,
    String? servisNo,
  }) async {
    final token = authToken;
    if (token == null) {
      throw const ScanException(
          'Oturum bulunamadı, lütfen tekrar giriş yapın.');
    }
    final birimNo = _birimNoByAdi[birim];

    try {
      await ApiService().createPersonel(
        token: token,
        sicilNo: sicilNo,
        adSoyad: adSoyad,
        birimNo: birimNo,
        rol: rol,
        sifre: sifre,
        email: email,
        servisNo: servisNo,
      );
    } catch (e) {
      throw ScanException(e.toString().replaceFirst('Exception: ', ''));
    }

    await loadInitialData();
  }

  Future<void> changePassword({
    required String eskiSifre,
    required String yeniSifre,
  }) async {
    final token = authToken;
    if (token == null) {
      throw const ScanException(
          'Oturum bulunamadı, lütfen tekrar giriş yapın.');
    }
    try {
      await ApiService().changePassword(
        token: token,
        eskiSifre: eskiSifre,
        yeniSifre: yeniSifre,
      );
    } catch (e) {
      throw ScanException(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ---------------------------------------------------------------------
  // Rapor gönderme
  // ---------------------------------------------------------------------

  Future<bool> raporBugunGonderildiMi(String birim) async {
    final token = authToken;
    final birimNo = _birimNoByAdi[birim];
    if (token == null || birimNo == null) return false;
    try {
      final durum = await ApiService().checkRaporDurumu(
        token: token,
        birimNo: birimNo,
      );
      return durum['bugun_gonderildi'] as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendReport({
    required String birim,
    required List<String> recipients,
    String? notMetni,
  }) async {
    final token = authToken;
    if (token == null) {
      throw const ScanException(
          'Oturum bulunamadı, lütfen tekrar giriş yapın.');
    }
    final birimNo = _birimNoByAdi[birim];
    if (birimNo == null) {
      throw const ScanException('Birim bilgisi bulunamadı.');
    }

    List<String> gercekAliciler;
    try {
      gercekAliciler = await ApiService().sendReport(
        token: token,
        birimNo: birimNo,
        notMetni: notMetni,
      );
    } catch (e) {
      throw ScanException(e.toString().replaceFirst('Exception: ', ''));
    }

    raporGecmisi.insert(
      0,
      ReportLogEntry(
          sentAt: DateTime.now(), birim: birim, recipients: gercekAliciler),
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
