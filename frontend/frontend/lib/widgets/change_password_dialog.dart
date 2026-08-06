import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';
import 'onvo_primary_button.dart';
import 'onvo_text_field.dart';

Future<void> showChangePasswordDialog(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _eskiController = TextEditingController();
  final _yeniController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _eskiController.dispose();
    _yeniController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final eski = _eskiController.text.trim();
    final yeni = _yeniController.text.trim();

    if (eski.isEmpty) {
      setState(() => _error = 'Mevcut şifrenizi girin.');
      return;
    }
    if (yeni.length < 8 || yeni.length > 16) {
      setState(() => _error = 'Yeni şifre 8-16 karakter olmalı.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<AppData>().changePassword(
            eskiSifre: eski,
            yeniSifre: yeni,
          );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('ScanException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            if (_success) ...[
              Text('Şifre güncellendi',
                  style: AppText.h1.copyWith(fontSize: 19)),
              const SizedBox(height: 8),
              Text('Şifreniz başarıyla değiştirildi.', style: AppText.subtext),
              const SizedBox(height: 20),
              OnvoPrimaryButton(
                label: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ] else ...[
              Text('Şifre Değiştir', style: AppText.h1.copyWith(fontSize: 19)),
              const SizedBox(height: 18),
              OnvoTextField(
                label: 'Mevcut Şifre',
                controller: _eskiController,
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 14),
              OnvoTextField(
                label: 'Yeni Şifre',
                controller: _yeniController,
                icon: Icons.lock_reset_rounded,
                obscureText: true,
                placeholder: '8-16 karakter',
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppText.errorMsg),
              ],
              const SizedBox(height: 20),
              OnvoPrimaryButton(
                label: 'Güncelle',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
