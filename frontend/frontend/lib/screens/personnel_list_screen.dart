import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';

const Map<String, String> _personnelListRolLabels = {
  'calisan': 'Çalışan',
  'bant_sefi': 'Bant Şefi',
  'yonetici': 'Yönetici',
};
String _personnelListRolLabel(String rol) =>
    _personnelListRolLabels[rol] ?? rol;

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

/// Bant şefinin kendi biriminde kayıtlı personeli görebildiği, salt okunur
/// ekran. Liste zaten backend'den (GET /personel) role göre filtrelenmiş
/// geliyor — bant şefi sadece kendi biriminin personelini görür, yönetici
/// tüm personeli görür (bkz. main.py personel_listele). Burada ekstra bir
/// filtreleme yapmıyoruz, appData.personelListesi'ni doğrudan gösteriyoruz.
class PersonnelListScreen extends StatelessWidget {
  const PersonnelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final personelListesi = appData.personelListesi;
    final birim = appData.currentBirim.name;

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
                              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            Navigator.of(context).maybePop(),
                                        icon: const Icon(
                                            Icons.arrow_back_rounded,
                                            color: AppColors.ink),
                                        tooltip: 'Geri',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 40, minHeight: 40),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Personel Listesi',
                                                style: AppText.h1),
                                            const SizedBox(height: 4),
                                            Text(birim, style: AppText.subtext),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  if (personelListesi.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 24),
                                      child: Text(
                                          'Bu birimde kayıtlı personel yok.',
                                          style: AppText.subtext),
                                    )
                                  else
                                    for (final p in personelListesi) ...[
                                      _PersonnelListRow(personel: p),
                                      const SizedBox(height: 10),
                                    ],
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

class _PersonnelListRow extends StatelessWidget {
  const _PersonnelListRow({required this.personel});
  final Personel personel;

  @override
  Widget build(BuildContext context) {
    final isYonetici = personel.rol == 'yonetici';
    final detailParts = <String>[
      personel.sicilNo,
      if (personel.servisNo != null && personel.servisNo!.isNotEmpty)
        'Servis ${personel.servisNo}',
      if (personel.email != null && personel.email!.isNotEmpty) personel.email!,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.onvoBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(personel.adSoyad),
              style: AppText.label
                  .copyWith(color: AppColors.onvoBlue, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(personel.adSoyad, style: AppText.label),
                const SizedBox(height: 2),
                Text(detailParts.join(' · '), style: AppText.footer),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isYonetici
                  ? AppColors.amber.withOpacity(0.15)
                  : AppColors.onvoBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _personnelListRolLabel(personel.rol),
              style: AppText.footer.copyWith(
                color: isYonetici ? AppColors.amberDark : AppColors.onvoBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
