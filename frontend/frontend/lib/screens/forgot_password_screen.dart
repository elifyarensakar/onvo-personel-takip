import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/onvo_primary_button.dart';
import '../widgets/onvo_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _sicilController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isSent = false;
  String? _sicilError;
  String? _emailError;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _sicilController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final sicilEmpty = _sicilController.text.trim().isEmpty;
    final email = _emailController.text.trim();
    final emailEmpty = email.isEmpty;
    final emailInvalid = !emailEmpty && !_emailRegex.hasMatch(email);

    setState(() {
      _sicilError = sicilEmpty ? 'Sicil numaranızı girin' : null;
      _emailError = emailEmpty
          ? 'E-posta adresinizi girin'
          : emailInvalid
              ? 'Geçerli bir e-posta adresi girin'
              : null;
    });

    if (sicilEmpty || emailEmpty || emailInvalid) return;

    setState(() => _isLoading = true);

    // TODO: gerçek servise bağlanınca burası sicil no + e-postayı backend'e
    // gönderip, kayıtlı e-postaya şifre sıfırlama bağlantısı yollayacak
    // şekilde değiştirilecek. Sicil no ile e-posta eşleşmiyorsa backend'in
    // döneceği hata da _sicilError / _emailError'a bağlanabilir.
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSent = true;
    });
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
              final isWide = constraints.maxWidth > 480;

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
                          child: SingleChildScrollView(
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
                                    child: _isSent
                                        ? _SentConfirmation(
                                            email: _emailController.text.trim(),
                                            onBackToLogin: () =>
                                                Navigator.of(context)
                                                    .maybePop(),
                                          )
                                        : _ForgotPasswordForm(
                                            sicilController: _sicilController,
                                            emailController: _emailController,
                                            isLoading: _isLoading,
                                            sicilError: _sicilError,
                                            emailError: _emailError,
                                            onClearSicilError: () {
                                              if (_sicilError != null) {
                                                setState(
                                                    () => _sicilError = null);
                                              }
                                            },
                                            onClearEmailError: () {
                                              if (_emailError != null) {
                                                setState(
                                                    () => _emailError = null);
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

/// Sicil no + e-posta formu.
class _ForgotPasswordForm extends StatelessWidget {
  const _ForgotPasswordForm({
    required this.sicilController,
    required this.emailController,
    required this.isLoading,
    required this.sicilError,
    required this.emailError,
    required this.onClearSicilError,
    required this.onClearEmailError,
    required this.onSubmit,
  });

  final TextEditingController sicilController;
  final TextEditingController emailController;
  final bool isLoading;
  final String? sicilError;
  final String? emailError;
  final VoidCallback onClearSicilError;
  final VoidCallback onClearEmailError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Şifremi Unuttum',
          style: AppText.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sicil numaranızı ve kayıtlı e-posta adresinizi girin',
          style: AppText.subtext,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
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
          label: 'E-posta',
          controller: emailController,
          icon: Icons.mail_outline,
          placeholder: 'ornek@sirket.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          errorText: emailError,
          onChanged: (_) => onClearEmailError(),
        ),
        const SizedBox(height: 22),
        OnvoPrimaryButton(
          label: 'Bağlantı Gönder',
          isLoading: isLoading,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

/// Bağlantı gönderildikten sonra gösterilen onay ekranı.
class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({
    required this.email,
    required this.onBackToLogin,
  });

  final String email;
  final VoidCallback onBackToLogin;

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
            color: AppColors.onvoBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.onvoBlue,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Bağlantı gönderildi',
          style: AppText.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          email.isEmpty
              ? 'E-posta adresinize şifre sıfırlama bağlantısı gönderdik.'
              : '$email adresine şifre sıfırlama bağlantısı gönderdik.',
          style: AppText.subtext,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Bağlantı 30 dakika içinde geçerliliğini yitirir. Gelen kutunuzu '
          've spam klasörünü kontrol edin.',
          style: AppText.footer,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OnvoPrimaryButton(
          label: 'Giriş Ekranına Dön',
          onPressed: onBackToLogin,
        ),
      ],
    );
  }
}
