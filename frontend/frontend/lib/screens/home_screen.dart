import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'qr_scan_screen.dart';
import 'stats_attendance_screen.dart';
import '../widgets/change_password_dialog.dart';
import 'personnel_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  static const _weekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  String _formatToday() {
    final now = DateTime.now();
    final weekday = _weekdays[now.weekday - 1];
    return '${now.day} ${_months[now.month - 1]} ${now.year}, $weekday';
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oturumu kapat'),
        content: const Text('Giriş ekranına dönmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.screenBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 480;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 460 : double.infinity,
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
                              padding:
                                  const EdgeInsets.fromLTRB(22, 20, 22, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Ana Sayfa',
                                                style: AppText.h1),
                                            const SizedBox(height: 4),
                                            Text(_formatToday(),
                                                style: AppText.subtext),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            showChangePasswordDialog(context),
                                        icon: const Icon(
                                          Icons.password_rounded,
                                          color: AppColors.muted,
                                        ),
                                        tooltip: 'Şifre değiştir',
                                      ),
                                      IconButton(
                                        onPressed: () => _handleLogout(context),
                                        icon: const Icon(
                                          Icons.logout_rounded,
                                          color: AppColors.muted,
                                        ),
                                        tooltip: 'Oturumu kapat',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  _HomeOptionCard(
                                    icon: Icons.qr_code_scanner_rounded,
                                    title: 'QR ile Yoklama Al',
                                    subtitle:
                                        'Personel giriş/çıkışını QR koduyla okutun',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const QrScanScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _HomeOptionCard(
                                    icon: Icons.bar_chart_rounded,
                                    title: 'İstatistikler ve Yoklama',
                                    subtitle:
                                        'Bugünün kayıtlarını görün, raporu gönderin',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const StatsAttendanceScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _HomeOptionCard(
                                    icon: Icons.groups_rounded,
                                    title: 'Personel Listesi',
                                    subtitle:
                                        'Biriminizde kayıtlı personeli görüntüleyin',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PersonnelListScreen(),
                                        ),
                                      );
                                    },
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

class _HomeOptionCard extends StatelessWidget {
  const _HomeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.onvoBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.onvoBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.label.copyWith(fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppText.footer),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
