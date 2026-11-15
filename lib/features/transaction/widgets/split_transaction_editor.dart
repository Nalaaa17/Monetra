import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/color_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../data/models/category.dart';
import '../providers/transaction_form_provider.dart';

class SplitTransactionEditor extends StatefulWidget {
  final int totalAmount;
  final List<SplitCategoryItem> splitItems;
  final List<Category> categories;
  final VoidCallback onAddItem;
  final void Function(int index, SplitCategoryItem item) onUpdateItem;
  final void Function(int index) onRemoveItem;
  final VoidCallback onDisableSplit;

  const SplitTransactionEditor({
    super.key,
    required this.totalAmount,
    required this.splitItems,
    required this.categories,
    required this.onAddItem,
    required this.onUpdateItem,
    required this.onRemoveItem,
    required this.onDisableSplit,
  });

  @override
  State<SplitTransactionEditor> createState() => _SplitTransactionEditorState();
}

class _SplitTransactionEditorState extends State<SplitTransactionEditor> {
  int get _splitTotal =>
      widget.splitItems.fold(0, (sum, item) => sum + item.amount);
  int get _remaining => widget.totalAmount - _splitTotal;

  void _showCategoryPicker(
    BuildContext context,
    int index,
    SplitCategoryItem currentItem,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E222A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pilih Kategori untuk Pecahan #${index + 1}',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: widget.categories.length,
                    itemBuilder: (ctx, i) {
                      final cat = widget.categories[i];
                      final isSelected = cat.id == currentItem.categoryId;
                      final color = ColorHelper.parseHex(cat.colorHex);
                      final icon = IconHelper.getIcon(cat.iconCodePoint);

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onUpdateItem(
                            index,
                            currentItem.copyWith(
                              categoryId: cat.id,
                              categoryName: cat.name,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? color : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? Colors.white : color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? color
                                    : AppColors.textPrimaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAmountEditDialog(
    BuildContext context,
    int index,
    SplitCategoryItem currentItem,
  ) {
    final controller = TextEditingController(
      text: currentItem.amount > 0 ? currentItem.amount.toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nominal Pecahan #${index + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                border: OutlineInputBorder(),
              ),
            ),
            if (_remaining > 0) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final newAmt = currentItem.amount + _remaining;
                  controller.text = newAmt.toString();
                },
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: Text(
                  'Tambah Sisa Belanja (+${CurrencyFormatter.format(_remaining)})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
              final val = int.tryParse(raw) ?? 0;
              widget.onUpdateItem(
                index,
                currentItem.copyWith(amount: val),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  Category? _findCategory(int? id) {
    if (id == null) return null;
    try {
      return widget.categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;

    final isBalanced = widget.totalAmount > 0 && _splitTotal == widget.totalAmount;
    final isOver = _splitTotal > widget.totalAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBalanced
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : (isOver
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Judul Split Transaksi & Tombol Matikan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.call_split_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Split Transaksi (Pecah Kategori)',
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: widget.onDisableSplit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Batal Split',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Balance Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E222A)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Terbagi',
                        style: AppTypography.labelSmall.copyWith(fontSize: 10),
                      ),
                      Text(
                        CurrencyFormatter.format(_splitTotal),
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBalanced
                        ? const Color(0xFF059669).withValues(alpha: 0.12)
                        : (isOver
                            ? AppColors.danger.withValues(alpha: 0.12)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isBalanced
                        ? 'Pas ✓'
                        : (isOver
                            ? 'Kelebihan ${CurrencyFormatter.format(_splitTotal - widget.totalAmount)}'
                            : 'Kurang ${CurrencyFormatter.format(_remaining)}'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isBalanced
                          ? const Color(0xFF059669)
                          : (isOver ? AppColors.danger : const Color(0xFFF59E0B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Split Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.splitItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = widget.splitItems[index];
              final cat = _findCategory(item.categoryId);
              final catColor = cat != null
                  ? ColorHelper.parseHex(cat.colorHex)
                  : AppColors.primary;
              final catIcon = cat != null
                  ? IconHelper.getIcon(cat.iconCodePoint)
                  : Icons.category_rounded;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F29) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Item
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pecahan #${index + 1}',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        if (widget.splitItems.length > 2)
                          InkWell(
                            onTap: () => widget.onRemoveItem(index),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Category Selector + Amount Button
                    Row(
                      children: [
                        // Pilih Kategori
                        Expanded(
                          flex: 5,
                          child: InkWell(
                            onTap: () =>
                                _showCategoryPicker(context, index, item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: catColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(catIcon, size: 16, color: catColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      cat?.name ?? 'Pilih Kategori',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: catColor,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down,
                                      size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Edit Nominal
                        Expanded(
                          flex: 4,
                          child: InkWell(
                            onTap: () =>
                                _showAmountEditDialog(context, index, item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF262C36)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: dividerColor),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      CurrencyFormatter.format(item.amount),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.edit,
                                      size: 12, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Catatan Per Pecahan (misal: "Bahan Dapur", "Snack")
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.note,
                            onChanged: (val) {
                              widget.onUpdateItem(
                                index,
                                item.copyWith(note: val),
                              );
                            },
                            style: const TextStyle(fontSize: 11),
                            decoration: InputDecoration(
                              hintText: 'Keterangan pecahan (opsional)...',
                              hintStyle: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: dividerColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: dividerColor),
                              ),
                            ),
                          ),
                        ),
                        if (_remaining > 0) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              final newAmt = item.amount + _remaining;
                              widget.onUpdateItem(
                                index,
                                item.copyWith(amount: newAmt),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '+Isi Sisa',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Tombol Tambah Pecahan
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onAddItem,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Tambah Pecahan Kategori',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: dividerColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
