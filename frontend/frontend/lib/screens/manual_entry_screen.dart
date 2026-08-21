import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/onvo_primary_button.dart';
import '../widgets/onvo_text_field.dart';
import '../widgets/centered_scroll_content.dart';

/// QR okuyucu arızalandığında bant şefinin sicil no girerek manuel olarak
/// giriş/çıkış kaydı oluşturabildiği ekran. QR ekranıyla aynı paylaşılan
/// durumu (AppData) kullanıyor — ikisi de aynı backend akışının farklı
/// giriş yollarından ibaret. Personel listesinde kaydı olmayan bir sicil
/// no da reddedilmiyor, doğrudan kaydediliyor (fabrikada akışı yavaşlatacak
/// bir doğrulama yapılmıyor).
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _sicilController = TextEditingController();

  late String _selectedBant;

  bool _isLoading = false;
  String? _sicilError;
  ScanResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final bants = context.read<AppData>().currentBirim.bants;
    _selectedBant = bants.isNotEmpty ? bants.first : '';
  }

  @override
  void dispose() {
    _sicilController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final sicilNo = _sicilController.text.trim();
    final sicilEmpty = sicilNo.isEmpty;

    setState(() => _sicilError = sicilEmpty ? 'Sicil numarasını girin' : null);
    if (sicilEmpty) return;

    setState(() => _isLoading = true);

    final appData = context.read<AppData>();

    try {
      final result = await appData.recordScan(
        sicilNo: sicilNo,
        birim: appData.currentBirim.name,
        bant: _selectedBant,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _errorMessage = null;
        _isLoading = false;
      });
    } on ScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _result = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Kayıt oluşturulamadı. Lütfen tekrar deneyin.';
        _result = null;
        _isLoading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _sicilController.clear();
      _sicilError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final bants = appData.currentBirim.bants;
    final effectiveBant = bants.contains(_selectedBant)
        ? _selectedBant
        : (bants.isNotEmpty ? bants.first : '');

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.screenBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const isWide = false; // Tablet dahil her ekranda tam genişlik/köşesiz görünüm için kapatıldı.

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 420 : double.infinity,
                  ),
                  child: Container(
                    margin: isWide
                        ? const EdgeInsets.symmetric(vertical: 24)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: isWide
                          ? BorderRadius.circular(32)
                          : BorderRadius.zero,
                      boxShadow: isWide
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.onvoBlueDeeper.withOpacity(0.28),
                                blurRadius: 60,
                                offset: const Offset(0, 30),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: CenteredScrollContent(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon:
                                          const Icon(Icons.arrow_back_rounded),
                                      color: AppColors.ink,
                                      tooltip: 'Geri',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: _result != null
                                        ? _ResultView(
                                            result: _result!,
                                            onNewEntry: _reset)
                                        : _errorMessage != null
                                            ? _ErrorView(
                                                message: _errorMessage!,
                                                onRetry: _reset,
                                              )
                                            : _ManualEntryForm(
                                                sicilController:
                                                    _sicilController,
                                                sicilError: _sicilError,
                                                birimName:
                                                    appData.currentBirim.name,
                                                bants: bants,
                                                selectedBant: effectiveBant,
                                                isLoading: _isLoading,
                                                onBantChanged: (value) =>
                                                    setState(() =>
                                                        _selectedBant = value),
                                                onClearSicilError: () {
                                                  if (_sicilError != null) {
                                                    setState(() =>
                                                        _sicilError = null);
                                                  }
                                                },
                                                onSubmit: _handleSubmit,
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
            },
          ),
        ),
      ),
    );
  }
}

/// Sicil no + bant seçimi formu.
class _ManualEntryForm extends StatelessWidget {
  const _ManualEntryForm({
    required this.sicilController,
    required this.sicilError,
    required this.birimName,
    required this.bants,
    required this.selectedBant,
    required this.isLoading,
    required this.onBantChanged,
    required this.onClearSicilError,
    required this.onSubmit,
  });

  final TextEditingController sicilController;
  final String? sicilError;
  final String birimName;
  final List<String> bants;
  final String selectedBant;
  final bool isLoading;
  final ValueChanged<String> onBantChanged;
  final VoidCallback onClearSicilError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Manuel Giriş', style: AppText.h1, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'QR kod okutulamadığında personelin sicil numarasını girerek '
          'giriş/çıkış kaydı oluşturabilirsiniz.',
          style: AppText.subtext,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Bant · $birimName', style: AppText.label),
        ),
        const SizedBox(height: 7),
        if (bants.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            child: Text('Bu birimde tanımlı bant yok', style: AppText.footer),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedBant,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted),
                style: AppText.input,
                items: bants
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onBantChanged(value);
                },
              ),
            ),
          ),
        const SizedBox(height: 14),
        OnvoTextField(
          label: 'Sicil No',
          controller: sicilController,
          icon: Icons.badge_outlined,
          placeholder: 'Örn. 048213',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          errorText: sicilError,
          onChanged: (_) => onClearSicilError(),
        ),
        const SizedBox(height: 22),
        OnvoPrimaryButton(
          label: 'Kaydet',
          isLoading: isLoading,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

/// Başarılı kayıt sonrası gösterilen onay görünümü — QR ekranındaki sonuç
/// kartıyla aynı görsel dili taşıyor.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onNewEntry});

  final ScanResult result;
  final VoidCallback onNewEntry;

  @override
  Widget build(BuildContext context) {
    final isGiris = result.action == ScanAction.girisYapildi;
    final color = isGiris ? const Color(0xFF2E9E5B) : AppColors.amberDark;
    final label = isGiris ? 'Giriş yapıldı' : 'Çıkış yapıldı';
    final icon = isGiris ? Icons.login_rounded : Icons.logout_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 18),
        Text(result.employeeName,
            style: AppText.h1, textAlign: TextAlign.center),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Kayıtlı personel listesinde yok · kayıt yine de oluşturuldu',
              style: AppText.footer.copyWith(color: AppColors.amberDark),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 24),
        OnvoPrimaryButton(label: 'Yeni Kayıt Gir', onPressed: onNewEntry),
      ],
    );
  }
}

/// Backend hatası olduğunda gösterilen görünüm (bağlantı vb.) — sicil no
/// bulunamaması artık bir hata sebebi değil, bkz. AppData.recordScan.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 32),
        ),
        const SizedBox(height: 18),
        Text('Kayıt oluşturulamadı',
            style: AppText.h1, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message, style: AppText.subtext, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        OnvoPrimaryButton(label: 'Tekrar Dene', onPressed: onRetry),
      ],
    );
  }
}