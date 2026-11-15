import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/bank_brands.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
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

  Widget _buildTypeSegment(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewColor = ColorHelper.parseHex(_selectedColor);
    final previewName = _nameController.text.trim().isEmpty
        ? 'Nama Akun'
        : _nameController.text.trim();

    final selectedBrand = BankBrands.findByKey(_selectedLogoKey) ??
        BankLogoHelper.resolveBrand(_nameController.text);
    final popularBrands =
        BankBrands.all.where((b) => b.isPopular).take(12).toList();

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header Sheet
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit ${widget.existing!.name}'
                                : 'Tambah Akun Baru',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? 'Perbarui data dompet atau rekening'
                                : 'Hubungkan rekening bank, e-wallet, atau tunai',
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
                const SizedBox(height: 14),

                // 1. HERO LIVE PREVIEW CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161A23) : const Color(0xFF1E2430),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          BankLogoHelper.buildAccountBadge(
                            context: context,
                            accountName: previewName,
                            accountColor: previewColor,
                            logoKey: _selectedLogoKey,
                            size: 38,
                            borderRadius: 10,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_selectedCategory == 'tabungan'
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF34D399))
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedCategory == 'tabungan'
                                      ? Icons.savings_rounded
                                      : Icons.bolt_rounded,
                                  size: 13,
                                  color: _selectedCategory == 'tabungan'
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF34D399),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedCategory == 'tabungan'
                                      ? 'Tabungan'
                                      : 'Uang Harian',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedCategory == 'tabungan'
                                        ? const Color(0xFF38BDF8)
                                        : const Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        previewName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            !isEditing
                                ? CurrencyFormatter.format(int.tryParse(
                                        _balanceController.text
                                            .replaceAll('.', '')
                                            .replaceAll(',', '')) ??
                                    0)
                                : 'Saldo Terkelola Aktif',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _selectedType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Pilih Bank / Brand
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
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedBrand != null
                                    ? selectedBrand.displayName
                                    : 'Cari Bank atau E-Wallet Indonesia...',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selectedBrand != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: selectedBrand != null
                                      ? AppColors.textPrimaryOf(context)
                                      : AppColors.textSecondaryOf(context),
                                ),
                              ),
                              Text(
                                'Tersedia ${BankBrands.all.length} bank nasional, digital, BPD & e-wallet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_right_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Popular Brand Strip
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: popularBrands.map((brand) {
                      final isSelected = _selectedLogoKey == brand.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _applyBrandSelection(brand,
                              forceUpdateName: !isEditing),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                      .withValues(alpha: isDark ? 0.22 : 0.16)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.6),
                                width: isSelected ? 1.6 : 1,
                              ),
                            ),
                            child: BankLogoHelper.buildBrandBadge(
                              context: context,
                              brand: brand,
                              size: 32,
                              borderRadius: 8,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Nama Akun / Dompet
                Text('Nama Akun / Dompet', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    hintText: 'Contoh: BCA Tabungan, GoPay Utama, Dompet Saku',
                    filled: true,
                    fillColor: AppColors.surfaceOf(context),
                    suffixIcon: _nameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
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
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama akun wajib diisi';
                    }
                    return null;
                  },
                ),
                // Saran Auto-complete Bank / Dompet
                Builder(
                  builder: (context) {
                    final suggestions =
                        _getAutocompleteSuggestions(_nameController.text);
                    if (suggestions.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestions.map((b) {
                          return ActionChip(
                            avatar: BankLogoHelper.buildBrandBadge(
                              context: context,
                              brand: b,
                              size: 18,
                              borderRadius: 4,
                            ),
                            label: Text(b.displayName),
                            onPressed: () =>
                                _applyBrandSelection(b, forceUpdateName: true),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 4. Saldo Awal (Khusus Tambah Baru)
                if (!isEditing) ...[
                  Text('Saldo Awal (Rp)', style: AppTypography.labelSmall),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      filled: true,
                      fillColor: AppColors.surfaceOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 5. Kelompok Dana (Segmented Bar)
                Text('Kelompok Dana', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.dividerOf(context)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = 'harian'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedCategory == 'harian'
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 16,
                                    color: _selectedCategory == 'harian'
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Uang Harian',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: _selectedCategory == 'harian'
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 12,
                                      color: _selectedCategory == 'harian'
                                          ? AppColors.primaryDark
                                          : AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = 'tabungan'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedCategory == 'tabungan'
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.savings_rounded,
                                    size: 16,
                                    color: _selectedCategory == 'tabungan'
                                        ? AppColors.primaryDark
                                        : AppColors.textSecondaryOf(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tabungan',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: _selectedCategory == 'tabungan'
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 12,
                                      color: _selectedCategory == 'tabungan'
                                          ? AppColors.primaryDark
                                          : AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Tipe Akun (Segmented Bar)
                Text('Tipe Akun', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.dividerOf(context)),
                  ),
                  child: Row(
                    children: [
                      _buildTypeSegment(
                          'bank', 'Bank', Icons.account_balance_rounded),
                      _buildTypeSegment(
                          'ewallet', 'E-Wallet', Icons.wallet_rounded),
                      _buildTypeSegment(
                          'cash', 'Cash', Icons.payments_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 7. Tombol Simpan
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
