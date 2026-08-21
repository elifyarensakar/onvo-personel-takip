import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/onvo_primary_button.dart';
import 'manual_entry_screen.dart';

enum _ScanPhase { scanning, success, error }

/// QR kodun içeriği bant şefi uygulamasında "Ad Soyad: ...", "Sicil No: ...",
/// "Servis No: ..." alanlarını içeriyor. Bu alanlar bazen satır sonuyla
/// (\n) bazen sadece boşlukla ayrılmış geliyor — bu yüzden her alanı, bir
/// sonraki etiket başlayana (ya da metin bitene) kadar okuyoruz; sadece
/// metnin sonuna kadar almıyoruz (aksi halde bir alan diğerlerini içine
/// yutar).
const _sicilNoLabel = r'Sicil\s*No\s*:';
const _adSoyadLabel = r'Ad\s*Soyad\s*:';
const _servisNoLabel = r'Servis\s*No\s*:';
const _herhangiEtiket =
    '(?:$_sicilNoLabel|$_adSoyadLabel|$_servisNoLabel|\$)';

String _extractField(String rawValue, String label) {
  final match =
      RegExp('$label\\s*(.*?)\\s*$_herhangiEtiket').firstMatch(rawValue);
  return match?.group(1)?.trim() ?? '';
}

/// "Sicil No:" satırındaki değeri ayıklar; format eşleşmezse (örn. eski/
/// farklı bir QR) tüm metni olduğu gibi sicil no kabul eder — geriye
/// dönük uyumluluk için.
String _extractSicilNo(String rawValue) {
  final value = _extractField(rawValue, _sicilNoLabel);
  return value.isNotEmpty ? value : rawValue.trim();
}

/// "Ad Soyad:" satırındaki değeri ayıklar, yoksa null döner.
String? _extractAdSoyad(String rawValue) {
  final value = _extractField(rawValue, _adSoyadLabel);
  return value.isNotEmpty ? value : null;
}

/// "Servis No:" satırındaki değeri ayıklar, yoksa null döner.
String? _extractServisNo(String rawValue) {
  final value = _extractField(rawValue, _servisNoLabel);
  return value.isNotEmpty ? value : null;
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;

  bool _cameraReady = false;
  String? _cameraError;

  _ScanPhase _phase = _ScanPhase.scanning;
  bool _isProcessing = false;
  ScanResult? _lastResult;
  String? _errorMessage;

  late String _selectedBant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final bants = context.read<AppData>().currentBirim.bants;
    _selectedBant = bants.isNotEmpty ? bants.first : '';
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoStart: false,
    );
    _startCamera();
  }

  Future<void> _startCamera() async {
    setState(() => _cameraError = null);
    try {
      await _controller.start();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraError =
            'Kameraya erişilemiyor. Ayarlardan kamera iznini kontrol edip tekrar deneyin.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraReady) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _phase != _ScanPhase.scanning) return;

    final rawValue =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);

    final appData = context.read<AppData>();
    final bants = appData.currentBirim.bants;
    final effectiveBant = bants.contains(_selectedBant)
        ? _selectedBant
        : (bants.isNotEmpty ? bants.first : '');

    try {
      // Not: personel listesinde kaydı olmayan bir sicil no okutulsa bile
      // reddedilmiyor — QR'daki bilgi doğrudan kaydediliyor (bkz. AppData.
      // recordScan). Fabrikada akışı yavaşlatacak bir doğrulama yapılmıyor.
      final result = await appData.recordScan(
        sicilNo: _extractSicilNo(rawValue),
        birim: appData.currentBirim.name,
        bant: effectiveBant,
        adSoyad: _extractAdSoyad(rawValue),
        servisNo: _extractServisNo(rawValue),
      );
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _phase = _ScanPhase.success;
        _isProcessing = false;
      });
    } on ScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _phase = _ScanPhase.error;
        _isProcessing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'QR kod okunamadı. Lütfen tekrar deneyin.';
        _phase = _ScanPhase.error;
        _isProcessing = false;
      });
    }

    // Sonuç/hata birkaç saniye gösterildikten sonra otomatik olarak
    // taramaya geri dönülüyor — bir sonraki personel hemen okutabilsin.
    Future.delayed(const Duration(seconds: 3), _resumeScanning);
  }

  void _resumeScanning() {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.scanning;
      _lastResult = null;
      _errorMessage = null;
    });
  }

  void _goToManualEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
    );
  }

  void _handleClose() {
    // Bu ekranın altında (push ile gelinen) bir sayfa var — Ana Sayfa ya
    // da İstatistikler — bu yüzden X butonu basitçe geri dönüyor.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final bants = appData.currentBirim.bants;
    final effectiveBant = bants.contains(_selectedBant)
        ? _selectedBant
        : (bants.isNotEmpty ? bants.first : '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraError == null)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              fit: BoxFit.cover,
            ),

          // Karartma maskesi + ortadaki tarama çerçevesi + ipucu metni.
          if (_cameraError == null)
            LayoutBuilder(
              builder: (context, constraints) {
                final shortestSide =
                    constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;
                final cutOutSize = shortestSide * 0.64;
                final centerY = constraints.maxHeight / 2;
                final hintTop = centerY + cutOutSize / 2 + 20;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScannerOverlayPainter(
                          cutOutSize: cutOutSize,
                          borderColor: AppColors.amber,
                        ),
                      ),
                    ),
                    Positioned(
                      top: hintTop,
                      left: 24,
                      right: 24,
                      child: Text(
                        'Personel kartındaki QR kodu çerçeve içine tutun',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          // Üst bar (geri + bant seçici + fener) ve alttaki manuel giriş
          // butonu — kameranın üzerine, SafeArea içinde.
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  birimName: appData.currentBirim.name,
                  bants: bants,
                  selectedBant: effectiveBant,
                  onBantChanged: (value) =>
                      setState(() => _selectedBant = value),
                  onClose: _handleClose,
                  onToggleTorch: () => _controller.toggleTorch(),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: OutlinedButton.icon(
                    onPressed: _goToManualEntry,
                    icon: const Icon(Icons.keyboard_outlined,
                        color: Colors.white),
                    label: Text(
                      'Manuel Giriş',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_cameraError != null)
            _CameraErrorView(
              message: _cameraError!,
              onRetry: _startCamera,
              onClose: _handleClose,
              onManualEntry: _goToManualEntry,
            ),

          if (_phase == _ScanPhase.success && _lastResult != null)
            _ResultOverlay(result: _lastResult!),

          if (_phase == _ScanPhase.error && _errorMessage != null)
            _ErrorOverlay(message: _errorMessage!, onRetry: _resumeScanning),
        ],
      ),
    );
  }
}

/// Kamera üzerine karartma + ortada boşluk bırakılmış tarama çerçevesi çizer.
class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({
    required this.cutOutSize,
    required this.borderColor,
  });

  final double cutOutSize;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutOutPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(cutOutRect, const Radius.circular(28)));
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutOutPath,
    );

    canvas.drawPath(
        overlayPath, Paint()..color = Colors.black.withOpacity(0.55));

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;
    final r = cutOutRect;

    canvas.drawLine(
        Offset(r.left, r.top + cornerLen), Offset(r.left, r.top), borderPaint);
    canvas.drawLine(
        Offset(r.left, r.top), Offset(r.left + cornerLen, r.top), borderPaint);

    canvas.drawLine(Offset(r.right - cornerLen, r.top), Offset(r.right, r.top),
        borderPaint);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + cornerLen),
        borderPaint);

    canvas.drawLine(Offset(r.left, r.bottom - cornerLen),
        Offset(r.left, r.bottom), borderPaint);
    canvas.drawLine(Offset(r.left, r.bottom),
        Offset(r.left + cornerLen, r.bottom), borderPaint);

    canvas.drawLine(Offset(r.right - cornerLen, r.bottom),
        Offset(r.right, r.bottom), borderPaint);
    canvas.drawLine(Offset(r.right, r.bottom),
        Offset(r.right, r.bottom - cornerLen), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.cutOutSize != cutOutSize ||
      oldDelegate.borderColor != borderColor;
}

/// Geri butonu + birim adı + bant seçici + fener anahtarını içeren üst bar.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.birimName,
    required this.bants,
    required this.selectedBant,
    required this.onBantChanged,
    required this.onClose,
    required this.onToggleTorch,
  });

  final String birimName;
  final List<String> bants;
  final String selectedBant;
  final ValueChanged<String> onBantChanged;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Kapat',
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: bants.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '$birimName · bant tanımlı değil',
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 13),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBant,
                        isExpanded: true,
                        dropdownColor: AppColors.onvoBlueDeep,
                        iconEnabledColor: Colors.white,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        items: bants
                            .map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text('$b · $birimName'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onBantChanged(value);
                        },
                      ),
                    ),
            ),
          ),
          IconButton(
            onPressed: onToggleTorch,
            icon: const Icon(Icons.flash_on_outlined, color: Colors.white),
            tooltip: 'Fener',
          ),
        ],
      ),
    );
  }
}

/// Başarılı taramada personel adı + giriş/çıkış bilgisini gösteren kart.
class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final isGiris = result.action == ScanAction.girisYapildi;
    final color = isGiris ? const Color(0xFF2E9E5B) : AppColors.amberDark;
    final label = isGiris ? 'Giriş yapıldı' : 'Çıkış yapıldı';
    final icon = isGiris ? Icons.login_rounded : Icons.logout_rounded;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  result.employeeName,
                  style: AppText.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppText.subtext.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!result.isKnownPersonnel) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Kayıtlı personel listesinde yok · QR bilgisiyle kaydedildi',
                      style:
                          AppText.footer.copyWith(color: AppColors.amberDark),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// QR okunamadığında / backend'e ulaşılamadığında gösterilen hata kartı.
class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Okunamadı',
                    style: AppText.h1, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(message,
                    style: AppText.subtext, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OnvoPrimaryButton(label: 'Tekrar Dene', onPressed: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kamera hiç başlatılamadığında (izin reddi vb.) gösterilen tam ekran görünüm.
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.message,
    required this.onRetry,
    required this.onClose,
    required this.onManualEntry,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Kapat',
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_outlined,
                            color: Colors.white70, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        OnvoPrimaryButton(
                            label: 'Tekrar Dene', onPressed: onRetry),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: onManualEntry,
                          icon: const Icon(Icons.keyboard_outlined,
                              color: Colors.white),
                          label: Text(
                            'Manuel Giriş',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}