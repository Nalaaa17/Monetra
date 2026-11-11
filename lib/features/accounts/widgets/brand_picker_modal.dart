import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/bank_brands.dart';
import '../../../core/utils/bank_logo_helper.dart';
import '../../../core/utils/color_helper.dart';

Future<BankBrand?> showBrandPickerModal(
  BuildContext context, {
  String? currentLogoKey,
}) {
  return showModalBottomSheet<BankBrand>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BrandPickerSheet(currentLogoKey: currentLogoKey),
  );
}

class _BrandPickerSheet extends StatefulWidget {
  final String? currentLogoKey;

  const _BrandPickerSheet({this.currentLogoKey});

  @override
  State<_BrandPickerSheet> createState() => _BrandPickerSheetState();
}

class _BrandPickerSheetState extends State<_BrandPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  BankBrandGroup? _selectedGroup; // null = Semua
  bool _onlyPopular = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BankBrand> get _filteredBrands {
    return BankBrands.all.where((brand) {
      if (_onlyPopular && !brand.isPopular) return false;
      if (_selectedGroup != null && brand.group != _selectedGroup) {
        return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      if (brand.displayName.toLowerCase().contains(q)) return true;
      if (brand.key.contains(q)) return true;
      return brand.aliases.any((a) => a.contains(q));
    }).toList();
  }

  String _groupLabel(BankBrandGroup group) {
    switch (group) {
      case BankBrandGroup.bank:
        return 'Bank Nasional & Umum';
      case BankBrandGroup.digital:
        return 'Bank Digital';
      case BankBrandGroup.ewallet:
        return 'E-Wallet / Dompet Digital';
      case BankBrandGroup.bpd:
        return 'Bank Daerah (BPD)';
      case BankBrandGroup.fintech:
        return 'Fintech & Layanan Pembayaran';
      case BankBrandGroup.cash:
        return 'Uang Tunai';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredBrands;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Bank & E-Wallet Indonesia',
                            style: AppTypography.headlineMedium.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tersedia ${BankBrands.all.length} nama bank nasional, digital, BPD & e-wallet',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
              ),

              // Search Box
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText:
                        'Cari nama bank atau e-wallet (misal: BCA, BNI, Jago, OVO, Jateng...)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurface
                        : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),

              // Filter Group Chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildFilterChip(
                      label: 'Semua',
                      selected: !_onlyPopular && _selectedGroup == null,
                      onTap: () => setState(() {
                        _onlyPopular = false;
                        _selectedGroup = null;
                      }),
                    ),
                    _buildFilterChip(
                      label: 'Populer',
                      selected: _onlyPopular,
                      onTap: () => setState(() {
                        _onlyPopular = true;
                        _selectedGroup = null;
                      }),
                    ),
                    _buildFilterChip(
                      label: 'Bank Nasional',
                      selected:
                          !_onlyPopular && _selectedGroup == BankBrandGroup.bank,
                      onTap: () => setState(() {
                        _onlyPopular = false;
                        _selectedGroup = BankBrandGroup.bank;
                      }),
                    ),
                    _buildFilterChip(
                      label: 'Bank Digital',
                      selected: !_onlyPopular &&
                          _selectedGroup == BankBrandGroup.digital,
                      onTap: () => setState(() {
                        _onlyPopular = false;
                        _selectedGroup = BankBrandGroup.digital;
                      }),
                    ),
                    _buildFilterChip(
                      label: 'E-Wallet',
                      selected: !_onlyPopular &&
                          _selectedGroup == BankBrandGroup.ewallet,
                      onTap: () => setState(() {
                        _onlyPopular = false;
                        _selectedGroup = BankBrandGroup.ewallet;
                      }),
                    ),
                    _buildFilterChip(
                      label: 'Bank Daerah (BPD)',
                      selected:
                          !_onlyPopular && _selectedGroup == BankBrandGroup.bpd,
                      onTap: () => setState(() {
                        _onlyPopular = false;
                        _selectedGroup = BankBrandGroup.bpd;
                      }),
                    ),
                    _buildFilterChip(
                      label: 'Fintech & Kartu',
                      selected: !_onlyPopular &&
                          _selectedGroup == BankBrandGroup.fintech,
                      onTap: () => setState(() {
                        _onlyPopular = false;
                        _selectedGroup = BankBrandGroup.fintech;
                      }),
                    ),
                    _buildFilterChip(
                      label: 'Tunai',
                      selected:
                          !_onlyPopular && _selectedGroup == BankBrandGroup.cash,
                      onTap: () => setState(() {
                        _onlyPopular = false;
                        _selectedGroup = BankBrandGroup.cash;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: Theme.of(context).dividerColor),

              // Clean Searchable List of Banks & E-Wallets
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 48,
                                  color: AppColors.textSecondaryOf(context)),
                              const SizedBox(height: 10),
                              Text(
                                'Nama "$_query" tidak ditemukan',
                                style: AppTypography.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Anda tetap bisa mengetik nama bebas di form — aplikasi akan otomatis membuatkan logo inisial.',
                                textAlign: TextAlign.center,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.6),
                        ),
                        itemBuilder: (context, index) {
                          final brand = filtered[index];
                          final isSelected = widget.currentLogoKey == brand.key;
                          final brandColor = ColorHelper.parseHex(
                            brand.colorHex,
                            fallback: const Color(0xFF0284C7),
                          );

                          return ListTile(
                            onTap: () => Navigator.pop(context, brand),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: isSelected,
                            selectedTileColor: AppColors.primary
                                .withValues(alpha: isDark ? 0.16 : 0.1),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            leading: BankLogoHelper.buildBrandBadge(
                              context: context,
                              brand: brand,
                              borderColor: brandColor,
                              size: 42,
                              borderRadius: 12,
                            ),
                            title: Text(
                              brand.displayName,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            subtitle: Text(
                              _groupLabel(brand.group),
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primaryDark)
                                : Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textSecondaryOf(context)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.black : null,
          ),
        ),
        selected: selected,
        selectedColor: AppColors.primary,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
