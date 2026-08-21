import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class LoginResult {
  const LoginResult({
    required this.token,
    required this.rol,
    required this.sicilNo,
    this.birimNo,
  });

  final String token;
  final String rol;
  final String sicilNo;
  final int? birimNo;
}

class ApiService {
  static const String baseUrl =
      'http://172.17.49.24:8000'; 
  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<LoginResult> login(String sicilNo, String sifre) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sicil_no': sicilNo, 'sifre': sifre}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final payload = JwtDecoder.decode(token);
      return LoginResult(
        token: token,
        rol: payload['rol'] as String,
        sicilNo: payload['sicil_no'] as String,
        birimNo: payload['birim_no'] as int?,
      );
    }
    throw Exception(_extractDetail(response.body, 'Giriş başarısız'));
  }

  Future<List<Map<String, dynamic>>> fetchBirimler(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/birim'),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Birimler alınamadı'));
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<List<Map<String, dynamic>>> fetchBantlar(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bant'),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Bantlar alınamadı'));
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<List<Map<String, dynamic>>> fetchPersonel(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/personel'),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(
          _extractDetail(response.body, 'Personel listesi alınamadı'));
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<List<Map<String, dynamic>>> fetchKayitlar(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/kayit'),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Kayıtlar alınamadı'));
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> createKayit({
    required String token,
    required String sicilNo,
    required int bantNo,
    String? adSoyad,
    String? servisNo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/kayit'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'sicil_no': sicilNo,
        'bant_no': bantNo,
        'ad_soyad': adSoyad,
        'servis_no': servisNo,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractDetail(response.body, 'Kayıt oluşturulamadı'));
  }

  Future<void> createPersonel({
    required String token,
    required String sicilNo,
    required String adSoyad,
    required int? birimNo,
    required String rol,
    required String sifre,
    String? email,
    String? servisNo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/personel'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'sicil_no': sicilNo,
        'ad_soyad': adSoyad,
        'birim_no': birimNo,
        'rol': rol,
        'sifre': sifre,
        'email': email,
        'servis_no': servisNo,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Personel eklenemedi'));
    }
  }

  Future<void> updatePersonel({
    required String token,
    required String sicilNo,
    required String adSoyad,
    required int? birimNo,
    required String rol,
    String? email,
    String? servisNo,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/personel/$sicilNo'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'ad_soyad': adSoyad,
        'birim_no': birimNo,
        'rol': rol,
        'email': email,
        'servis_no': servisNo,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Personel güncellenemedi'));
    }
  }

  Future<void> togglePersonelAktif({
    required String token,
    required String sicilNo,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/personel/aktif'),
      headers: _authHeaders(token),
      body: jsonEncode({'sicil_no': sicilNo}),
    );

    if (response.statusCode != 200) {
      throw Exception(
          _extractDetail(response.body, 'Personel durumu değiştirilemedi'));
    }
  }

  Future<void> createBirim({
    required String token,
    required String birimAdi,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/birim'),
      headers: _authHeaders(token),
      body: jsonEncode({'birim_adi': birimAdi}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Birim eklenemedi'));
    }
  }

  Future<void> createBant({
    required String token,
    required int birimNo,
    required String bantAdi,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bant'),
      headers: _authHeaders(token),
      body: jsonEncode({
        // Backend bant_no'yu şema seviyesinde zorunlu tutuyor ama DB'de
        // serial olduğu için gerçek kayıtta kullanmıyor — rastgele
        // bir değer (0) gönderiyoruz, backend görmezden geliyor.
        'bant_no': 0,
        'birim_no': birimNo,
        'bant_adi': bantAdi,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Bant eklenemedi'));
    }
  }

  Future<Map<String, dynamic>> checkRaporDurumu({
    required String token,
    required int birimNo,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rapor-durumu/$birimNo'),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Durum alınamadı'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> changePassword({
    required String token,
    required String eskiSifre,
    required String yeniSifre,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/personel/sifre-degistir'),
      headers: _authHeaders(token),
      body: jsonEncode({'eski_sifre': eskiSifre, 'yeni_sifre': yeniSifre}),
    );
    if (response.statusCode != 200) {
      throw Exception(_extractDetail(response.body, 'Şifre değiştirilemedi'));
    }
  }

  Future<List<String>> sendReport({
    required String token,
    required int birimNo,
    String? notMetni,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rapor-gonder/$birimNo'),
      headers: _authHeaders(token),
      body: jsonEncode({'not_metni': notMetni}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<String>.from(data['aliciler'] as List);
    }
    throw Exception(_extractDetail(response.body, 'Rapor gönderilemedi'));
  }

  String _extractDetail(String body, String fallback) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}