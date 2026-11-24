import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  int _iconCodeForType(String type) {
    if (type == 'cash') return Icons.payments_rounded.codePoint;
    if (type == 'ewallet') return Icons.wallet_rounded.codePoint;
    return Icons.account_balance_rounded.codePoint;
  }

  Widget _buildTypeSegment(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.primary : AppColors.primaryDark;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? activeColor
                        : AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12.5,
                      color: isSelected
                          ? activeColor
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
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

    final popularBrands =
        BankBrands.all.where((b) => b.isPopular).take(10).toList();

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
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
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header Sheet (Clean & modern, no verbose subtitles)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Akun' : 'Tambah Akun',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 1. Quick Brand Selector Strip
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...popularBrands.map((brand) {
                        final isSelected = _selectedLogoKey == brand.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _applyBrandSelection(brand,
                                forceUpdateName: !isEditing),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                        .withValues(alpha: isDark ? 0.22 : 0.16)
                                    : AppColors.surfaceOf(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Theme.of(context)
                                          .dividerColor
                                          .withValues(alpha: 0.5),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BankLogoHelper.buildBrandBadge(
                                    context: context,
                                    brand: brand,
                                    size: 22,
                                    borderRadius: 6,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    brand.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark
                                              ? AppColors.primary
                                              : AppColors.primaryDark)
                                          : AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      // Tombol Cari Bank Lainnya
                      InkWell(
                        onTap: _openFullBrandPicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceOf(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Lainnya',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryOf(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Nama Akun
                Text('Nama Akun', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    hintText: 'Nama akun / dompet',
                    filled: true,
                    fillColor: AppColors.surfaceOf(context),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: _openFullBrandPicker,
                        child: BankLogoHelper.buildAccountBadge(
                          context: context,
                          accountName: previewName,
                          accountColor: previewColor,
                          logoKey: _selectedLogoKey,
                          size: 28,
                          borderRadius: 8,
                        ),
                      ),
                    ),
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
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama akun wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. Saldo Awal (Khusus Tambah Baru)
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
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. Tipe Akun (Full-width responsive segmented control)
                Text('Tipe Akun', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerOf(context)),
                  ),
                  child: Row(
                    children: [
                      _buildTypeSegment(
                          'bank', 'Bank', Icons.account_balance_rounded),
                      _buildTypeSegment(
                          'ewallet', 'E-Wallet', Icons.wallet_rounded),
                      _buildTypeSegment(
                          'cash', 'Tunai', Icons.payments_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Kelompok Dana (Full-width responsive segmented control)
                Text('Kelompok Dana', style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerOf(context)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedCategory = 'harian'),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedCategory == 'harian'
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                'Harian',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _selectedCategory == 'harian'
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedCategory == 'harian'
                                      ? (isDark
                                          ? AppColors.primary
                                          : AppColors.primaryDark)
                                      : AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedCategory = 'tabungan'),
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedCategory == 'tabungan'
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                'Tabungan',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _selectedCategory == 'tabungan'
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: _selectedCategory == 'tabungan'
                                      ? (isDark
                                          ? AppColors.primary
                                          : AppColors.primaryDark)
                                      : AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 5. Tombol Simpan
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1600),
            content: Text(isEditing
                ? 'Akun "$name" berhasil diperbarui!'
                : 'Akun "$name" berhasil ditambahkan!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 2000),
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
