import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/onvo_primary_button.dart';

class StatsAttendanceScreen extends StatefulWidget {
  const StatsAttendanceScreen({super.key});

  @override
  State<StatsAttendanceScreen> createState() => _StatsAttendanceScreenState();
}

class _StatsAttendanceScreenState extends State<StatsAttendanceScreen> {
  bool _isSendingReport = false;

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

  String _formatDate(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    return '${date.day} ${_months[date.month - 1]} ${date.year}, $weekday';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _handleSendReport() async {
    final appData = context.read<AppData>();
    final birim = appData.currentBirim.name;

    final zatenGonderildi = await appData.raporBugunGonderildiMi(birim);

    String? notMetni;
    if (zatenGonderildi) {
      final controller = TextEditingController();
      final devamEt = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rapor bugün zaten gönderildi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Yine de tekrar göndermek istiyor musunuz?'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'Örn. Geç çıkış oldu, düzeltme',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yine de Gönder'),
            ),
          ],
        ),
      );
      if (devamEt != true) return;
      notMetni = controller.text.trim().isEmpty ? null : controller.text.trim();
    }

    setState(() => _isSendingReport = true);

    try {
      await appData.sendReport(
        birim: birim,
        recipients: const [],
        notMetni: notMetni,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('ScanException: ', ''))),
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSendingReport = false);
  }

  void _handleBack() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final birim = appData.currentBirim;
    final records = appData.activeRecordsForBirim(birim.name);

    final countByBant = <String, int>{};
    for (final r in records) {
      countByBant[r.bantAdi] = (countByBant[r.bantAdi] ?? 0) + 1;
    }
    // Birimde tanımlı ama şu an kimsenin aktif olmadığı bantlar da 0
    // kayıtla listede görünsün.
    for (final bant in birim.bants) {
      countByBant.putIfAbsent(bant, () => 0);
    }

    final todaysReport = appData.latestReportForBirimToday(birim.name);

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
                                  _Header(
                                    birimName: birim.name,
                                    dateLabel: _formatDate(DateTime.now()),
                                    onBack: _handleBack,
                                  ),
                                  const SizedBox(height: 22),
                                  _RecordsCard(
                                    countByBant: countByBant,
                                    total: records.length,
                                  ),
                                  const SizedBox(height: 16),
                                  _ReportCard(
                                    isSending: _isSendingReport,
                                    isSent: todaysReport != null,
                                    sentAtLabel: todaysReport != null
                                        ? _formatTime(todaysReport.sentAt)
                                        : null,
                                    recipients:
                                        todaysReport?.recipients ?? const [],
                                    onSend: _handleSendReport,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.birimName,
    required this.dateLabel,
    required this.onBack,
  });

  final String birimName;
  final String dateLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          tooltip: 'Geri',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('İstatistikler ve Yoklama', style: AppText.h1),
              const SizedBox(height: 4),
              Text('$birimName · $dateLabel', style: AppText.subtext),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.countByBant, required this.total});

  final Map<String, int> countByBant;
  final int total;

  @override
  Widget build(BuildContext context) {
    final entries = countByBant.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_outlined,
                  size: 18, color: AppColors.onvoBlue),
              const SizedBox(width: 8),
              Text('Bugünkü Kayıtlar', style: AppText.label),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$total',
            style: AppText.h1.copyWith(fontSize: 40, color: AppColors.onvoBlue),
          ),
          Text('Toplam personel kaydı', style: AppText.footer),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child:
                  Text('Bu birimde tanımlı bant yok.', style: AppText.subtext),
            )
          else
            for (final entry in entries)
              _BantRow(name: entry.key, count: entry.value),
        ],
      ),
    );
  }
}

class _BantRow extends StatelessWidget {
  const _BantRow({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.onvoBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: AppText.label)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.onvoBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count kayıt',
              style: AppText.label.copyWith(color: AppColors.onvoBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.isSending,
    required this.isSent,
    required this.sentAtLabel,
    required this.recipients,
    required this.onSend,
  });

  final bool isSending;
  final bool isSent;
  final String? sentAtLabel;
  final List<String> recipients;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 18, color: AppColors.onvoBlue),
              const SizedBox(width: 8),
              Text('Mesai Yoklama Raporu', style: AppText.label),
            ],
          ),
          const SizedBox(height: 12),
          if (isSent) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle,
                    size: 18, color: Color(0xFF2E9E5B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bugün ${sentAtLabel ?? ''} itibarıyla şu kişilere gönderildi:',
                    style: AppText.subtext,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recipients
                  .map(
                    (email) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        email,
                        style: AppText.footer.copyWith(color: AppColors.ink),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text('Bugün henüz gönderilmedi.', style: AppText.subtext),
            const SizedBox(height: 16),
          ],
          OnvoPrimaryButton(
            label: isSent ? 'Tekrar Gönder' : 'Mail Gönder',
            isLoading: isSending,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
