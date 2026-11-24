import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/services/backup_service.dart';
import '../../home/providers/home_providers.dart';
import '../../../shared/widgets/app_dialog.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  BackupStats? _stats;
  List<File> _backupFiles = [];
  bool _isLoading = true;
  bool _autoBackupEnabled = true;
  String? _lastAutoBackupDate;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    setState(() => _isLoading = true);
    final stats = await BackupService.getCurrentStats();
    final files = await BackupService.listBackupFiles();
    final autoEnabled = await BackupService.isAutoBackupEnabled();
    final lastAutoDate = await BackupService.getLastAutoBackupDate();
    if (mounted) {
      setState(() {
        _stats = stats;
        _backupFiles = files;
        _autoBackupEnabled = autoEnabled;
        _lastAutoBackupDate = lastAutoDate;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cadangan & Pemulihan Data',
          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBackupInfo,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // 1. Kartu Ringkasan Data
                  _buildDataSummaryCard(),
                  const SizedBox(height: 20),

                  // 2. Tombol Aksi Cadangkan Sekarang
                  _buildBackupActionCard(),
                  const SizedBox(height: 24),

                  // 3. Daftar File Cadangan Lokal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('File Cadangan di HP', style: AppTypography.titleLarge),
                      Text(
                        '${_backupFiles.length} file',
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_backupFiles.isEmpty)
                    _buildEmptyBackupFilesState()
                  else
                    ..._backupFiles.map((file) => _buildBackupFileTile(file)),

                  const SizedBox(height: 24),

                  // 4. Opsi Cadangan Teks / Ekspor Manual
                  _buildManualTextRestoreCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildDataSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined,
                        size: 20, color: Color(0xFF059669)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Data Finansial Monetra',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/logo.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF059669)),
                SizedBox(width: 6),
                Text(
                  '100% Offline & Tersimpan di HP Anda',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 24, color: Theme.of(context).dividerColor),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildStatItem('Transaksi', '${_stats?.transactionsCount ?? 0}'),
              _buildStatItem('Rutin', '${_stats?.recurringCount ?? 0}'),
              _buildStatItem('Akun', '${_stats?.accountsCount ?? 0}'),
              _buildStatItem('Kategori', '${_stats?.categoriesCount ?? 0}'),
              _buildStatItem('Transfer', '${_stats?.transfersCount ?? 0}'),
              _buildStatItem('Target', '${_stats?.goalsCount ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headlineMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.labelSmall),
      ],
    );
  }

  Widget _buildBackupActionCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsedAutoDate = _lastAutoBackupDate != null
        ? DateTime.tryParse(_lastAutoBackupDate!)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2415) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload_outlined,
                  color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cadangan Baru',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Simpan seluruh transaksi ke file JSON di memori HP.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _handleCreateBackup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.save_alt_rounded, size: 20),
              label: const Text(
                'Cadangkan Sekarang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Divider(height: 22, color: Theme.of(context).dividerColor),
          SwitchListTile(
            value: _autoBackupEnabled,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primaryDark,
            title: const Text(
              'Auto-Backup Harian Otomatis',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              parsedAutoDate != null
                  ? 'Terakhir otomatis: ${DateFormatter.formatShort(parsedAutoDate)}'
                  : 'Otomatis membuat cadangan maksimal 1x/hari saat aplikasi dibuka',
              style: const TextStyle(fontSize: 11.5),
            ),
            onChanged: (val) async {
              await BackupService.setAutoBackupEnabled(val);
              if (val) {
                await BackupService.runDailyAutoBackupIfNeeded();
              }
              await _loadBackupInfo();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBackupFilesState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded,
                size: 36, color: AppColors.textSecondaryOf(context)),
            const SizedBox(height: 8),
            Text(
              'Belum ada file cadangan yang dibuat',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupFileTile(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final lastModified = file.lastModifiedSync();
    final fileSizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);
    final isAuto = BackupService.isAutoBackupFile(file);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Icon(
                isAuto
                    ? Icons.schedule_rounded
                    : Icons.description_outlined,
                color: AppColors.primaryDark,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isAuto
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF059669))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isAuto ? 'Otomatis' : 'Manual',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAuto
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.formatFull(lastModified)} • $fileSizeKb KB',
                  style: AppTypography.labelSmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondaryOf(context)),
            onSelected: (val) {
              if (val == 'restore') {
                _handleRestoreFile(file);
              } else if (val == 'copy') {
                _handleCopyFileContent(file);
              } else if (val == 'delete') {
                _handleDeleteFile(file);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore_rounded, color: Color(0xFF059669), size: 18),
                    SizedBox(width: 8),
                    Text('Pulihkan (Restore)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Salin Teks JSON'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger, size: 18),
                    SizedBox(width: 8),
                    Text('Hapus File', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualTextRestoreCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code_rounded, color: AppColors.textPrimaryOf(context), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Pulihkan dari Teks JSON',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Jika Anda menyalin teks JSON dari HP lain atau catatan eksternal, Anda bisa menempelkannya langsung di sini.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showPasteRestoreDialog,
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            label: const Text('Tempel & Pulihkan Data'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCreateBackup() async {
    try {
      final file = await BackupService.createBackupFile();
      await _loadBackupInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1800),
            content: Text('Cadangan tersimpan: ${file.path.split(Platform.pathSeparator).last}'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 2000),
            content: Text('Gagal membuat cadangan: $e'),
          ),
        );
      }
    }
  }

  void _handleRestoreFile(File file) async {
    final confirm = await AppDialog.confirm(
      context,
      type: AppDialogType.warning,
      icon: Icons.restore_rounded,
      title: 'Pulihkan Data?',
      message:
          'Data catatan saat ini akan digantikan dengan data dari file cadangan ini. Lanjutkan?',
      confirmLabel: 'Pulihkan Sekarang',
      cancelLabel: 'Batal',
      isDestructive: false,
    );

    if (confirm == true) {
      final success = await BackupService.restoreFromFile(file);
      if (success) {
        ref.read(homeRefreshTriggerProvider.notifier).state++;
        await _loadBackupInfo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil dipulihkan 100%!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memulihkan data dari file cadangan.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  void _handleCopyFileContent(File file) async {
    final content = await file.readAsString();
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1600),
          content: Text('Teks JSON berhasil disalin ke clipboard!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleDeleteFile(File file) async {
    await BackupService.deleteBackupFile(file);
    await _loadBackupInfo();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1600),
          content: Text('File cadangan dihapus'),
        ),
      );
    }
  }

  void _showPasteRestoreDialog() {
    final textController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tempel Teks JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tempelkan teks JSON cadangan Monetra di bawah ini:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: '{\n  "app": "Monetra",\n  ...\n}',
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;

              final success = await BackupService.restoreFromJsonString(text);
              if (success) {
                ref.read(homeRefreshTriggerProvider.notifier).state++;
                await _loadBackupInfo();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data berhasil dipulihkan dari teks!'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
              } else {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Format teks JSON tidak valid.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Pulihkan Data'),
          ),
        ],
      ),
    ).whenComplete(textController.dispose);
  }
}
