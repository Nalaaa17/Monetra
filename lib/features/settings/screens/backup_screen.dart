import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/services/backup_service.dart';
import '../../home/providers/home_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  BackupStats? _stats;
  List<File> _backupFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    setState(() => _isLoading = true);
    final stats = await BackupService.getCurrentStats();
    final files = await BackupService.listBackupFiles();
    if (mounted) {
      setState(() {
        _stats = stats;
        _backupFiles = files;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
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
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.shield_outlined,
                      size: 20, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Text(
                    'Data Finansial Monetra',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Image.asset(
                'assets/images/logo.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Seluruh data Monetra tersimpan 100% lokal offline di memori HP Anda. Buat cadangan secara berkala agar catatan harian tidak hilang saat ganti perangkat atau update.',
            style: AppTypography.bodyMedium,
          ),
          const Divider(height: 24, color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Transaksi', '${_stats?.transactionsCount ?? 0}'),
              _buildStatItem('Akun', '${_stats?.accountsCount ?? 0}'),
              _buildStatItem('Kategori', '${_stats?.categoriesCount ?? 0}'),
              _buildStatItem('Transfer', '${_stats?.transfersCount ?? 0}'),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
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
              Text(
                'Buat Cadangan Baru (File JSON)',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Simpan seluruh transaksi, dompet, dan histori ke file JSON aman di folder Dokumen HP.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
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
                'Cadangkan Data Sekarang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBackupFilesState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded,
                size: 36, color: AppColors.textSecondary),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.description_outlined,
                color: AppColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
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
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.code_rounded, color: AppColors.textPrimary, size: 20),
              SizedBox(width: 8),
              Text(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cadangan tersimpan: ${file.path.split(Platform.pathSeparator).last}'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat cadangan: $e')),
        );
      }
    }
  }

  void _handleRestoreFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Data?'),
        content: const Text(
          'Data catatan saat ini akan digantikan dengan data dari file cadangan ini. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('Pulihkan Sekarang'),
          ),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File cadangan dihapus')),
      );
    }
  }

  void _showPasteRestoreDialog() {
    final textController = TextEditingController();

    showDialog(
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
                  fillColor: const Color(0xFFF9FAFB),
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
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
    );
  }
}
