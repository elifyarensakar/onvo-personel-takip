import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/onvo_primary_button.dart';
import 'login_screen.dart';
import '../widgets/centered_scroll_content.dart';

// ---------------------------------------------------------------------------
// Bu ekrana özel yardımcı tipler (paylaşılan veri modelleri artık
// state/app_data.dart içinde: BirimData, Personel, ActiveRecord,
// ReportLogEntry).
// ---------------------------------------------------------------------------

class _PersonelEditResult {
  const _PersonelEditResult({
    required this.adSoyad,
    required this.birim,
    required this.bant,
    required this.rol,
    this.email,
    this.servisNo,
  });

  final String adSoyad;
  final String birim;
  final String bant;
  final String rol;
  final String? email;
  final String? servisNo;
}

const Map<String, String> _rolLabels = {
  'calisan': 'Çalışan',
  'bant_sefi': 'Bant Şefi',
  'yonetici': 'Yönetici',
};
String _rolLabel(String rol) => _rolLabels[rol] ?? rol;

class _PersonelAddResult {
  const _PersonelAddResult({
    required this.sicilNo,
    required this.adSoyad,
    required this.birim,
    required this.rol,
    required this.sifre,
    this.email,
    this.servisNo,
  });

  final String sicilNo;
  final String adSoyad;
  final String birim;
  final String rol;
  final String sifre;
  final String? email;
  final String? servisNo;
}

enum _AdminTab { overview, units, personnel }

// ---------------------------------------------------------------------------
// Yardımcı biçimlendirme fonksiyonları
// ---------------------------------------------------------------------------

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String _formatTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatLogDate(DateTime dt) {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  final isToday =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  final isYesterday = dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day;
  final time = _formatTime(dt);

  if (isToday) return 'Bugün $time';
  if (isYesterday) return 'Dün $time';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  return '$day.$month.${dt.year} $time';
}

InputDecoration _fieldDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceTint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
    ),
  );
}

Widget _dropdownField({
  required String value,
  required List<String> items,
  required ValueChanged<String?> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.line),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.muted),
        style: AppText.label,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Ana ekran
// ---------------------------------------------------------------------------

/// Erişim: bu ekran sadece rol='yonetici' kullanıcılar için — kısıt
/// backend tarafında zaten uygulanıyor, burada ek bir görsel kısıt yok.
/// Login sonrası yönlendirme mantığı (login_screen.dart) rol='yonetici'
/// ise buraya, değilse HomeScreen'e (QR/manuel) yönlendiriyor.
///
/// Tüm veri (aktif kayıtlar, birimler/bantlar, personel, rapor geçmişi)
/// paylaşılan AppData'dan okunuyor — QR/Manuel Giriş ekranlarında oluşan
/// kayıtlar ve buradan yapılan birim/bant/personel değişiklikleri diğer
/// ekranlara anında yansıyor.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
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

  _AdminTab _selectedTab = _AdminTab.overview;
  String _selectedBirimFilter = 'Tüm Birimler';
  String _personelBirimFilter = 'Tüm Birimler';
  String _personelAramaMetni = '';
  final _personelAramaController = TextEditingController();
  bool _isRefreshing = false;
  bool _isAddingPersonel = false;

  @override
  void dispose() {
    _personelAramaController.dispose();
    super.dispose();
  }

  String _formatToday() {
    final now = DateTime.now();
    final weekday = _weekdays[now.weekday - 1];
    return '${now.day} ${_months[now.month - 1]} ${now.year}, $weekday';
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    // TODO: backend bağlanınca burada gerçek bir yeniden çekme isteği
    // atılacak. AppData zaten reaktif olduğu için veri her değiştiğinde
    // ekran otomatik güncelleniyor — bu buton backend'e "şimdi tazele"
    // sinyali göndermek için.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  Future<void> _handleLogout() async {
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

    if (confirmed == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showAddBirimDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Birim Ekle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Birim adı, örn. D Blok'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      try {
        await context.read<AppData>().addBirim(name);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('ScanException: ', '')),
            ),
          );
        }
      }
    }
  }

  Future<void> _showAddBantDialog(BirimData birim) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${birim.name} — Yeni Bant Ekle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Bant adı, örn. Bant 4'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && mounted) {
      try {
        await context.read<AppData>().addBant(birim, name);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('ScanException: ', '')),
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditPersonelSheet(
      Personel personel, List<BirimData> birimler) async {
    final result = await showModalBottomSheet<_PersonelEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _EditPersonelSheet(personel: personel, birimler: birimler),
    );

    if (result == null || !mounted) return;

    setState(() => _isAddingPersonel = true);
    try {
      await context.read<AppData>().updatePersonel(
            personel,
            adSoyad: result.adSoyad,
            birim: result.birim,
            bant: result.bant,
            rol: result.rol,
            email: result.email,
            servisNo: result.servisNo,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ScanException: ', '')),
          ),
        );
      }
    }
    if (mounted) setState(() => _isAddingPersonel = false);
  }

  Future<void> _showAddPersonelSheet(List<BirimData> birimler) async {
    final result = await showModalBottomSheet<_PersonelAddResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPersonelSheet(birimler: birimler),
    );

    if (result == null || !mounted) return;

    setState(() => _isAddingPersonel = true);
    try {
      await context.read<AppData>().addPersonelBackend(
            sicilNo: result.sicilNo,
            adSoyad: result.adSoyad,
            birim: result.birim,
            rol: result.rol,
            sifre: result.sifre,
            email: result.email,
            servisNo: result.servisNo,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ScanException: ', '')),
          ),
        );
      }
    }
    if (mounted) setState(() => _isAddingPersonel = false);
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.screenBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const isWide = false; // Tablet dahil her ekranda tam genişlik/köşesiz görünüm için kapatıldı.

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 560 : double.infinity,
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
                                            Text('Yönetici Paneli',
                                                style: AppText.h1),
                                            const SizedBox(height: 4),
                                            Text(_formatToday(),
                                                style: AppText.subtext),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _handleLogout,
                                        icon: const Icon(
                                          Icons.logout_rounded,
                                          color: AppColors.muted,
                                        ),
                                        tooltip: 'Oturumu kapat',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _buildTabSwitcher(),
                                  const SizedBox(height: 18),
                                  if (_selectedTab == _AdminTab.overview)
                                    _buildOverviewTab(appData),
                                  if (_selectedTab == _AdminTab.units)
                                    _buildUnitsTab(appData),
                                  if (_selectedTab == _AdminTab.personnel)
                                    _buildPersonnelTab(appData),
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

  Widget _buildTabSwitcher() {
    final tabs = <_AdminTab, String>{
      _AdminTab.overview: 'Genel Bakış',
      _AdminTab.units: 'Birim & Bantlar',
      _AdminTab.personnel: 'Personel',
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.entries.map((entry) {
          final isSelected = _selectedTab == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: AppText.footer.copyWith(
                    color: isSelected ? AppColors.onvoBlue : AppColors.muted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewTab(AppData appData) {
    final filteredRecords = appData.activeRecordsForBirim(_selectedBirimFilter);
    final reportLog = appData.raporGecmisi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Birim filtresi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded,
                  size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdownField(
                  value: _selectedBirimFilter,
                  items: appData.birimFilterOptions,
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _selectedBirimFilter = value);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Aktif kayıtlar kartı
        Container(
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
                  Expanded(child: Text('Aktif Kayıtlar', style: AppText.label)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.onvoBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${filteredRecords.length} aktif',
                      style: AppText.label
                          .copyWith(color: AppColors.onvoBlue, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onvoBlue,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.onvoBlue),
                  label: Text(
                    _isRefreshing ? 'Yenileniyor...' : 'Yenile',
                    style: AppText.label
                        .copyWith(color: AppColors.onvoBlue, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 4),
              if (filteredRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Bu birimde şu anda aktif kayıt yok.',
                      style: AppText.subtext),
                )
              else
                for (final record in filteredRecords)
                  _ActiveRecordRow(record: record),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gönderilen raporlar kartı
        Container(
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
                  Text('Mailine Gelen Raporlar', style: AppText.label),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 4),
              if (reportLog.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Henüz gönderilmiş rapor yok.',
                      style: AppText.subtext),
                )
              else
                for (final entry in reportLog) _ReportLogRow(entry: entry),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsTab(AppData appData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final birim in appData.birimler) ...[
          _BirimCard(birim: birim, onAddBant: () => _showAddBantDialog(birim)),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _showAddBirimDialog,
          icon: const Icon(Icons.add_rounded, color: AppColors.onvoBlue),
          label: const Text('Yeni Birim Ekle'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onvoBlue,
            side: const BorderSide(color: AppColors.onvoBlue),
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonnelTab(AppData appData) {
    final filtrelenmisListe = appData.personelListesi.where((personel) {
      final aktifUyuyor = personel.aktif;
      final birimUyuyor = _personelBirimFilter == 'Tüm Birimler' ||
          personel.birim == _personelBirimFilter;
      final arama = _personelAramaMetni.trim().toLowerCase();
      final aramaUyuyor = arama.isEmpty ||
          personel.adSoyad.toLowerCase().contains(arama) ||
          personel.sicilNo.toLowerCase().contains(arama);
      return aktifUyuyor && birimUyuyor && aramaUyuyor;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _isAddingPersonel
              ? null
              : () => _showAddPersonelSheet(appData.birimler),
          icon: const Icon(Icons.person_add_alt_rounded,
              color: AppColors.onvoBlue),
          label:
              Text(_isAddingPersonel ? 'Ekleniyor...' : 'Yeni Personel Ekle'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onvoBlue,
            side: const BorderSide(color: AppColors.onvoBlue),
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded,
                  size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdownField(
                  value: _personelBirimFilter,
                  items: appData.birimFilterOptions,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _personelBirimFilter = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _personelAramaController,
          onChanged: (value) => setState(() => _personelAramaMetni = value),
          decoration: _fieldDecoration().copyWith(
            hintText: 'Sicil no veya ad soyad ara...',
            prefixIcon: const Icon(Icons.search_rounded,
                size: 20, color: AppColors.muted),
            suffixIcon: _personelAramaMetni.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.muted),
                    onPressed: () {
                      _personelAramaController.clear();
                      setState(() => _personelAramaMetni = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        if (filtrelenmisListe.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Eşleşen personel bulunamadı.',
                  style: AppText.subtext),
            ),
          )
        else
          for (final personel in filtrelenmisListe) ...[
            _PersonelRow(
              personel: personel,
              onTap: () => _showEditPersonelSheet(personel, appData.birimler),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Alt bileşenler
// ---------------------------------------------------------------------------

class _ActiveRecordRow extends StatelessWidget {
  const _ActiveRecordRow({required this.record});

  final ActiveRecord record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
              _initialsOf(record.adSoyad),
              style: AppText.label
                  .copyWith(color: AppColors.onvoBlue, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.adSoyad, style: AppText.label),
                const SizedBox(height: 2),
                Text(
                  '${record.sicilNo} · ${record.bantAdi} · ${record.birim}',
                  style: AppText.footer,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  _formatTime(record.girisSaati),
                  style: AppText.footer.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportLogRow extends StatelessWidget {
  const _ReportLogRow({required this.entry});

  final ReportLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_outlined,
              size: 18, color: AppColors.onvoBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatLogDate(entry.sentAt)} · ${entry.birim}',
                  style: AppText.label.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Text(entry.recipients.join(', '), style: AppText.footer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BirimCard extends StatelessWidget {
  const _BirimCard({required this.birim, required this.onAddBant});

  final BirimData birim;
  final VoidCallback onAddBant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_rounded,
                  size: 18, color: AppColors.onvoBlue),
              const SizedBox(width: 8),
              Expanded(child: Text(birim.name, style: AppText.label)),
              IconButton(
                onPressed: onAddBant,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.onvoBlue,
                  size: 20,
                ),
                tooltip: 'Bant ekle',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 10),
          birim.bants.isEmpty
              ? Text('Henüz bant eklenmedi', style: AppText.footer)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: birim.bants
                      .map(
                        (bant) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(bant,
                              style: AppText.footer
                                  .copyWith(color: AppColors.ink)),
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }
}

class _PersonelRow extends StatelessWidget {
  const _PersonelRow({required this.personel, required this.onTap});

  final Personel personel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isYonetici = personel.rol == 'yonetici';
    final isPasif = !personel.aktif;
    return Opacity(
      opacity: isPasif ? 0.55 : 1,
      child: Material(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                    _initialsOf(personel.adSoyad),
                    style: AppText.label
                        .copyWith(color: AppColors.onvoBlue, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                              child:
                                  Text(personel.adSoyad, style: AppText.label)),
                          if (isPasif) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.muted.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Silindi',
                                style: AppText.footer.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${personel.sicilNo} · ${personel.birim} · ${personel.bant}',
                        style: AppText.footer,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isYonetici
                        ? AppColors.amber.withOpacity(0.15)
                        : AppColors.onvoBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _rolLabel(personel.rol),
                    style: AppText.footer.copyWith(
                      color:
                          isYonetici ? AppColors.amberDark : AppColors.onvoBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Personel düzenleme alt sayfası — ad soyad, birim, bant ve yetki (rol)
/// güncellenebiliyor. Kaydet'e basınca sonucu üst ekrana döndürür.
///
/// NOT: Bu akış henüz backend'e bağlanmadı (AppData.updatePersonel hâlâ
/// yerel/mock günceller). _roller listesi, backend'in gerçek rol
/// değerleriyle (calisan/bant_sefi/yonetici) uyumlu tutuluyor ki
/// dropdown, gerçek personel verisiyle açıldığında çökmesin.
class _EditPersonelSheet extends StatefulWidget {
  const _EditPersonelSheet({required this.personel, required this.birimler});

  final Personel personel;
  final List<BirimData> birimler;

  @override
  State<_EditPersonelSheet> createState() => _EditPersonelSheetState();
}

class _EditPersonelSheetState extends State<_EditPersonelSheet> {
  static const _roller = ['calisan', 'bant_sefi', 'yonetici'];

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _servisController;
  late String _selectedBirim;
  late String _selectedBant;
  late String _selectedRol;
  bool _isTogglingAktif = false;
  String? _toggleAktifHata;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.personel.adSoyad);
    _emailController =
        TextEditingController(text: widget.personel.email ?? '');
    _servisController =
        TextEditingController(text: widget.personel.servisNo ?? '');
    _selectedBirim = widget.personel.birim;
    _selectedBant = widget.personel.bant;
    _selectedRol = widget.personel.rol;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _servisController.dispose();
    super.dispose();
  }

  List<String> get _bantOptions {
    final birim = widget.birimler.firstWhere(
      (b) => b.name == _selectedBirim,
      orElse: () => widget.birimler.first,
    );
    return birim.bants;
  }

  Future<void> _handleSilPersonel() async {
    final onaylandi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personeli sil'),
        content: Text(
          '${widget.personel.adSoyad} adlı personeli silmek istediğinize '
          'emin misiniz? Bu kişi artık listede görünmeyecek ve QR ile '
          'giriş/çıkış kaydı oluşturamayacak. Geçmiş kayıtları korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (onaylandi != true || !mounted) return;

    setState(() {
      _isTogglingAktif = true;
      _toggleAktifHata = null;
    });
    try {
      await context.read<AppData>().togglePersonelAktif(widget.personel);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTogglingAktif = false;
          _toggleAktifHata = e.toString().replaceFirst('ScanException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBant = _bantOptions.contains(_selectedBant)
        ? _selectedBant
        : (_bantOptions.isNotEmpty ? _bantOptions.first : '');

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
            Text('Personeli Düzenle', style: AppText.h1.copyWith(fontSize: 19)),
            const SizedBox(height: 4),
            Text('Sicil No: ${widget.personel.sicilNo}', style: AppText.footer),
            const SizedBox(height: 18),
            Text('Ad Soyad', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
                controller: _nameController, decoration: _fieldDecoration()),
            const SizedBox(height: 14),
            Text('E-posta (opsiyonel)', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
                controller: _emailController, decoration: _fieldDecoration()),
            const SizedBox(height: 14),
            Text('Servis No (opsiyonel)', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
                controller: _servisController, decoration: _fieldDecoration()),
            const SizedBox(height: 14),
            Text('Birim', style: AppText.label),
            const SizedBox(height: 6),
            _dropdownField(
              value: _selectedBirim,
              items: widget.birimler.map((b) => b.name).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedBirim = value;
                  final options =
                      widget.birimler.firstWhere((b) => b.name == value).bants;
                  _selectedBant = options.isNotEmpty ? options.first : '';
                });
              },
            ),
            const SizedBox(height: 14),
            Text('Bant', style: AppText.label),
            const SizedBox(height: 6),
            _bantOptions.isEmpty
                ? Text('Bu birimde henüz bant yok', style: AppText.footer)
                : _dropdownField(
                    value: effectiveBant,
                    items: _bantOptions,
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedBant = value);
                    },
                  ),
            const SizedBox(height: 14),
            Text('Yetki', style: AppText.label),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRol,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted),
                  style: AppText.label,
                  items: _roller
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(_rolLabel(r))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedRol = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            OnvoPrimaryButton(
              label: 'Kaydet',
              onPressed: () {
                if (_nameController.text.trim().isEmpty) return;
                Navigator.of(context).pop(
                  _PersonelEditResult(
                    adSoyad: _nameController.text.trim(),
                    birim: _selectedBirim,
                    bant: effectiveBant,
                    rol: _selectedRol,
                    email: _emailController.text.trim().isEmpty
                        ? null
                        : _emailController.text.trim(),
                    servisNo: _servisController.text.trim().isEmpty
                        ? null
                        : _servisController.text.trim(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            if (widget.personel.aktif) ...[
              if (_toggleAktifHata != null) ...[
                Text(_toggleAktifHata!, style: AppText.errorMsg),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: _isTogglingAktif ? null : _handleSilPersonel,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                label: Text(
                  _isTogglingAktif ? 'İşleniyor...' : 'Personeli Sil',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yeni personel ekleme alt sayfası — sicil no, ad soyad, birim, rol ve
/// geçici şifre alınıp backend'e (POST /personel) gönderilir. Bant
/// seçimi yok: proje kararınca personelin sabit bir bandı olmuyor,
/// sadece sabit bir birimi var (bant bilgisi her girişte Kayit'ta tutulur).
class _AddPersonelSheet extends StatefulWidget {
  const _AddPersonelSheet({required this.birimler});
  final List<BirimData> birimler;

  @override
  State<_AddPersonelSheet> createState() => _AddPersonelSheetState();
}

class _AddPersonelSheetState extends State<_AddPersonelSheet> {
  static const _rolOptions = ['calisan', 'bant_sefi', 'yonetici'];

  final _sicilController = TextEditingController();
  final _adController = TextEditingController();
  final _sifreController = TextEditingController();
  final _emailController = TextEditingController();
  final _servisController = TextEditingController();

  late String _selectedBirim;
  String _selectedRol = 'calisan';
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedBirim =
        widget.birimler.isNotEmpty ? widget.birimler.first.name : '';
  }

  @override
  void dispose() {
    _sicilController.dispose();
    _adController.dispose();
    _sifreController.dispose();
    _emailController.dispose();
    _servisController.dispose();
    super.dispose();
  }

  void _submit() {
    final sicil = _sicilController.text.trim();
    final ad = _adController.text.trim();
    final sifre = _sifreController.text.trim();
    final email = _emailController.text.trim();
    final servis = _servisController.text.trim();

    if (sicil.isEmpty || ad.isEmpty) {
      setState(() => _error = 'Sicil no ve ad soyad zorunlu.');
      return;
    }
    if (sifre.length < 8 || sifre.length > 16) {
      setState(() => _error = 'Şifre 8-16 karakter olmalı.');
      return;
    }

    Navigator.of(context).pop(
      _PersonelAddResult(
        sicilNo: sicil,
        adSoyad: ad,
        birim: _selectedBirim,
        rol: _selectedRol,
        sifre: sifre,
        email: email.isEmpty ? null : email,
        servisNo: servis.isEmpty ? null : servis,
      ),
    );
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
            Text('Yeni Personel Ekle',
                style: AppText.h1.copyWith(fontSize: 19)),
            const SizedBox(height: 18),
            Text('Sicil No', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
                controller: _sicilController, decoration: _fieldDecoration()),
            const SizedBox(height: 14),
            Text('Ad Soyad', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
                controller: _adController, decoration: _fieldDecoration()),
            const SizedBox(height: 14),
            Text('Birim', style: AppText.label),
            const SizedBox(height: 6),
            widget.birimler.isEmpty
                ? Text('Önce bir birim oluşturmalısınız', style: AppText.footer)
                : _dropdownField(
                    value: _selectedBirim,
                    items: widget.birimler.map((b) => b.name).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedBirim = value);
                      }
                    },
                  ),
            const SizedBox(height: 14),
            Text('Yetki', style: AppText.label),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRol,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted),
                  style: AppText.label,
                  items: _rolOptions
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(_rolLabel(r))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedRol = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Geçici Şifre', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
              controller: _sifreController,
              obscureText: true,
              decoration:
                  _fieldDecoration().copyWith(hintText: '8-16 karakter'),
            ),
            const SizedBox(height: 14),
            Text('E-posta (opsiyonel)', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
                controller: _emailController, decoration: _fieldDecoration()),
            const SizedBox(height: 14),
            Text('Servis No (opsiyonel)', style: AppText.label),
            const SizedBox(height: 6),
            TextField(
                controller: _servisController, decoration: _fieldDecoration()),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppText.errorMsg),
            ],
            const SizedBox(height: 22),
            OnvoPrimaryButton(label: 'Ekle', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}