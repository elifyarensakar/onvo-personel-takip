import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/onvo_primary_button.dart';
import '../widgets/onvo_text_field.dart';
import 'admin_panel_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../state/app_data.dart';
import '../widgets/centered_scroll_content.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _sicilController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _sicilError;
  String? _passwordError;

  @override
  void dispose() {
    _sicilController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final sicilEmpty = _sicilController.text.trim().isEmpty;
    final passwordEmpty = _passwordController.text.trim().isEmpty;

    setState(() {
      _sicilError = sicilEmpty ? 'Sicil numaranızı girin' : null;
      _passwordError = passwordEmpty ? 'Şifrenizi girin' : null;
    });

    if (sicilEmpty || passwordEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService().login(
        _sicilController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      context.read<AppData>().setSession(
            token: result.token,
            rol: result.rol,
            birimNo: result.birimNo,
            sicilNo: result.sicilNo,
          );

      await context.read<AppData>().loadInitialData();

      setState(() => _isLoading = false);

      final isYonetici = result.rol == 'yonetici';

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              isYonetici ? const AdminPanelScreen() : const HomeScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _passwordError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    // Mobilde de dahil, decoration hiçbir zaman null değil —
                    // bu yüzden clipBehavior her koşulda güvenle uygulanabilir
                    // (önceki çökme burada decoration == null && clip != none
                    // çelişkisinden kaynaklanıyordu).
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
                    // Column + Expanded: kart her zaman tam yüksekliği
                    // kaplar (içerik kısa olsa bile). SingleChildScrollView
                    // tek başına kullanılsaydı sadece içeriği kadar
                    // küçülüyor, altta/üstte arka plan gradyanı görünüyordu
                    // — "sayfa dolmadı" sorunu buradan kaynaklanıyordu.
                    child: Column(
                      children: [
                        Expanded(
                          child: CenteredScrollContent(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _BrandHeader(),
                                _LoginForm(
                                  sicilController: _sicilController,
                                  passwordController: _passwordController,
                                  obscurePassword: _obscurePassword,
                                  isLoading: _isLoading,
                                  sicilError: _sicilError,
                                  passwordError: _passwordError,
                                  onTogglePassword: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  onClearSicilError: () {
                                    if (_sicilError != null) {
                                      setState(() => _sicilError = null);
                                    }
                                  },
                                  onClearPasswordError: () {
                                    if (_passwordError != null) {
                                      setState(() => _passwordError = null);
                                    }
                                  },
                                  onSubmit: _handleSubmit,
                                ),
                              ],
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

/// Üstteki logo alanı: artık ayrı renkli bir kutu değil, sayfanın beyaz
/// zeminiyle aynı — bu yüzden logo ile form arasında hiçbir sınır/geçiş
/// sorunu kalmıyor, ikisi zaten aynı zeminde.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // assets/images/onvo_logo_blue.png: aynı "onvo" amblemi, beyaz
          // zemin üzerinde okunması için marka mavisine boyanmış hali.
          Image.asset(
            'assets/images/onvo_logo_blue.png',
            width: 176,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          Text('ÜRETİM YÖNETİM SİSTEMİ', style: AppText.brandTag),
        ],
      ),
    );
  }
}

/// Giriş formu: başlık, sicil no / şifre alanları, buton.
///
/// Artık ayrı bir "kart" kutusu değil — header'ın altında, sayfayla aynı
/// beyaz zemin üzerinde doğrudan devam ediyor. Durumu kendisi tutmaz;
/// tüm değerler ve geri çağrılar üst widget'tan ([_LoginScreenState])
/// parametre olarak gelir.
class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.sicilController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.sicilError,
    required this.passwordError,
    required this.onTogglePassword,
    required this.onClearSicilError,
    required this.onClearPasswordError,
    required this.onSubmit,
  });

  final TextEditingController sicilController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final String? sicilError;
  final String? passwordError;
  final VoidCallback onTogglePassword;
  final VoidCallback onClearSicilError;
  final VoidCallback onClearPasswordError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 4, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VARDİYA GİRİŞİ',
            style: AppText.eyebrow,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Hoş geldiniz',
            style: AppText.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Vardiyanıza başlamak için sicil numaranız ve şifrenizle giriş yapın.',
            style: AppText.subtext,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OnvoTextField(
            label: 'Sicil No',
            controller: sicilController,
            icon: Icons.badge_outlined,
            placeholder: 'Örn. 048213',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            errorText: sicilError,
            onChanged: (_) => onClearSicilError(),
          ),
          const SizedBox(height: 14),
          OnvoTextField(
            label: 'Şifre',
            controller: passwordController,
            icon: Icons.lock_outline,
            placeholder: 'Şifrenizi girin',
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            errorText: passwordError,
            onChanged: (_) => onClearPasswordError(),
            suffix: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
                color: AppColors.muted,
              ),
              tooltip: obscurePassword ? 'Şifreyi göster' : 'Şifreyi gizle',
              onPressed: onTogglePassword,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Şifremi unuttum', style: AppText.link),
            ),
          ),
          const SizedBox(height: 4),
          OnvoPrimaryButton(
            label: 'Giriş Yap',
            isLoading: isLoading,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('ONVO Üretim Yönetim Sistemi', style: AppText.footer),
          ),
        ],
      ),
    );
  }
}