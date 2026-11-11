import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/bank_brands.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../data/models/account.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../home/providers/home_providers.dart';
import 'brand_picker_modal.dart';

void showAccountFormModal(
  BuildContext context,
  WidgetRef ref, {
  AccountWithBalance? existing,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AccountFormSheet(existing: existing),
  );
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  final AccountWithBalance? existing;

  const _AccountFormSheet({this.existing});

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  late String _selectedType;
  late String _selectedCategory;
  late String _selectedColor;
  String? _selectedLogoKey;
  String? _lastAutoFilledName;
  bool _isSubmitting = false;

  bool get isEditing => widget.existing != null;

  static const String _defaultNeutralAccent = '0xFF00D09E';

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    if (item != null) {
      _nameController = TextEditingController(text: item.name);
      _balanceController =
          TextEditingController(text: item.account.initialBalance.toString());
      _selectedType = item.type;
      _selectedCategory = item.account.category;
      _selectedColor = item.colorHex;
      _selectedLogoKey = item.logoKey;
    } else {
      _nameController = TextEditingController();
      _balanceController = TextEditingController(text: '0');
      _selectedType = 'bank';
      _selectedCategory = 'harian';
      _selectedColor = _defaultNeutralAccent;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _applyBrandSelection(BankBrand brand, {bool forceUpdateName = false}) {
    setState(() {
      _selectedLogoKey = brand.key;
      _selectedType = brand.accountType;
      _selectedColor = brand.colorHex;

      final currentText = _nameController.text.trim();
      if (forceUpdateName ||
          (!isEditing &&
              (currentText.isEmpty || currentText == _lastAutoFilledName))) {
        _nameController.text = brand.displayName;
        _lastAutoFilledName = brand.displayName;
      }
    });
  }

  void _onNameChanged(String value) {
    if (_selectedLogoKey == null) {
      final detected = BankLogoHelper.resolveBrand(value);
      if (detected != null) {
        setState(() {
          _selectedType = detected.accountType;
          _selectedColor = detected.colorHex;
        });
        return;
      } else {
        setState(() {
          _selectedColor = _defaultNeutralAccent;
        });
        return;
      }
    }
    setState(() {});
  }

  List<BankBrand> _getAutocompleteSuggestions(String rawInput) {
    final q = rawInput.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final exactBrand = BankBrands.resolve(
      logoKey: _selectedLogoKey,
      accountName: rawInput,
    );
    // Jika input sudah sama persis dengan merk terpilih, sembunyikan saran
    if (exactBrand != null &&
        exactBrand.displayName.toLowerCase() == q &&
        _selectedLogoKey == exactBrand.key) {
      return const [];
    }

    return BankBrands.all
        .where((b) =>
            b.displayName.toLowerCase().contains(q) ||
            b.key.contains(q) ||
            b.aliases.any((a) => a.contains(q)))
        .take(5)
        .toList();
  }

  int _iconCodeForType(String type) {
    if (type == 'cash') return Icons.payments_rounded.codePoint;
    if (type == 'ewallet') return Icons.wallet_rounded.codePoint;
    return Icons.account_balance_rounded.codePoint;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewColor = ColorHelper.parseHex(_selectedColor);
    final previewName = _nameController.text.trim().isEmpty
        ? 'Akun Baru'
        : _nameController.text.trim();

    final selectedBrand = BankBrands.findByKey(_selectedLogoKey) ??
        BankLogoHelper.resolveBrand(_nameController.text);
    final popularBrands =
        BankBrands.all.where((b) => b.isPopular).take(18).toList();
    final suggestions = _getAutocompleteSuggestions(_nameController.text);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Sheet
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit "${widget.existing!.name}"'
                                : 'Tambah Dompet / Rekening',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Pilih bank / e-wallet Indonesia yang tersedia',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // 1. Pemilih Utama: Pilih Bank / E-Wallet Indonesia (Dropdown Picker)
                Text(
                  'Pilih Bank / E-Wallet Indonesia',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _openFullBrandPicker,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        BankLogoHelper.buildAccountBadge(
                          context: context,
                          accountName: previewName,
                          accountColor: previewColor,
                          logoKey: _selectedLogoKey,
                          size: 36,
                          borderRadius: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedBrand != null
                                    ? selectedBrand.displayName
                                    : 'Cari Bank atau E-Wallet Indonesia...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selectedBrand != null
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: selectedBrand != null
                                      ? AppColors.textPrimaryOf(context)
                                      : AppColors.textSecondaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Tersedia ${BankBrands.all.length} bank nasional, digital, BPD & e-wallet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Strip Cepat Bank & E-Wallet Populer
                SizedBox(
                  height: 74,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: popularBrands.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final brand = popularBrands[index];
                      final isSelected = _selectedLogoKey == brand.key ||
                          (_selectedLogoKey == null &&
                              selectedBrand?.key == brand.key);
                      final bColor = ColorHelper.parseHex(brand.colorHex);

                      return InkWell(
                        onTap: () => _applyBrandSelection(
                          brand,
                          forceUpdateName: !isEditing,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 68,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                    .withValues(alpha: isDark ? 0.22 : 0.14)
                                : (isDark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFF9FAFB)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Theme.of(context).dividerColor,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              BankLogoHelper.buildBrandBadge(
                                context: context,
                                brand: brand,
                                borderColor: bColor,
                                size: 34,
                                borderRadius: 9,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                brand.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Nama Akun / Dompet + Saran Otomatis Saat Mengetik
                Text(
                  'Nama Akun / Dompet (Bisa Disesuaikan)',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    hintText: 'Contoh: BCA, Bank Mandiri, OVO, ShopeePay...',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8),
                      child: BankLogoHelper.buildAccountBadge(
                        context: context,
                        accountName: previewName,
                        accountColor: previewColor,
                        logoKey: _selectedLogoKey,
                        size: 30,
                        borderRadius: 8,
                      ),
                    ),
                    suffixIcon: _nameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            tooltip: 'Bersihkan & reset auto',
                            onPressed: () {
                              setState(() {
                                _nameController.clear();
                                _selectedLogoKey = null;
                                _lastAutoFilledName = null;
                                _selectedColor = _defaultNeutralAccent;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama akun wajib diisi';
                    }
                    return null;
                  },
                ),

                // Saran nama bank / e-wallet otomatis saat user mengetik
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: suggestions.map((brand) {
                      final bColor = ColorHelper.parseHex(brand.colorHex);
                      return ActionChip(
                        avatar: BankLogoHelper.buildBrandBadge(
                          context: context,
                          brand: brand,
                          borderColor: bColor,
                          size: 20,
                          borderRadius: 6,
                        ),
                        label: Text(
                          brand.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _applyBrandSelection(brand, forceUpdateName: true),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),

                // 3. Saldo Awal (Khusus Tambah Baru)
                if (!isEditing) ...[
                  Text('Saldo Awal (Rp)', style: AppTypography.labelSmall),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. Kelompok Dana (Uang Harian vs Tabungan)
                Text('Kelompok Dana', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'harian',
                        icon: Icon(Icons.bolt_rounded, size: 16),
                        label: Text('Uang Harian', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 'tabungan',
                        icon: Icon(Icons.savings_rounded, size: 16),
                        label: Text('Tabungan', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {_selectedCategory},
                    onSelectionChanged: (val) {
                      setState(() => _selectedCategory = val.first);
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Tipe Akun
                Text('Tipe Akun', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'bank',
                        icon: Icon(Icons.account_balance_rounded, size: 15),
                        label: Text('Bank', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 'ewallet',
                        icon: Icon(Icons.wallet_rounded, size: 15),
                        label: Text('E-Wallet', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 'cash',
                        icon: Icon(Icons.payments_rounded, size: 15),
                        label: Text('Cash', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (val) {
                      setState(() => _selectedType = val.first);
                    },
                  ),
                ),
                const SizedBox(height: 22),

                // 6. Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            isEditing ? 'Simpan Perubahan' : 'Simpan Akun',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFullBrandPicker() async {
    final picked = await showBrandPickerModal(
      context,
      currentLogoKey: _selectedLogoKey,
    );
    if (picked != null && mounted) {
      _applyBrandSelection(picked, forceUpdateName: !isEditing);
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final repo = ref.read(accountRepositoryProvider);
      final iconCode = _iconCodeForType(_selectedType);

      if (isEditing) {
        final updated = widget.existing!.account.copyWith(
          name: name,
          type: _selectedType,
          category: _selectedCategory,
          colorHex: _selectedColor,
          iconCodePoint: iconCode,
          logoKey: _selectedLogoKey,
          clearLogoKey: _selectedLogoKey == null,
        );
        await repo.updateAccount(updated);
      } else {
        final initBal = int.tryParse(
                _balanceController.text.replaceAll('.', '').replaceAll(',', '')) ??
            0;
        await repo.insertAccount(
          Account(
            name: name,
            type: _selectedType,
            category: _selectedCategory,
            colorHex: _selectedColor,
            iconCodePoint: iconCode,
            initialBalance: initBal,
            logoKey: _selectedLogoKey,
            createdAt: DateTime.now(),
          ),
        );
      }

      ref.read(homeRefreshTriggerProvider.notifier).state++;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Akun "$name" berhasil diperbarui!'
                : 'Akun "$name" berhasil ditambahkan!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan akun: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
