import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../main.dart';
import '../providers/settings_provider.dart';
import '../services/translation_service.dart';
import '../services/backup_service.dart';
import '../widgets/safe_widgets.dart';
import '../screens/product_gallery_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Comprehensive Settings Screen
/// Settings changes now reflect immediately in the app
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: SafeText('settings'.tr(ref)),
      ),
      body: SafePage(
        padding: const EdgeInsets.all(16),
        child: SafeColumn(
          children: [
            // SECTION 1: LANGUAGE & DISPLAY
            _buildSectionHeader(context, 'language_display'.tr(ref)),
            _buildSettingsCard(
              context: context,
              icon: Icons.language,
              title: 'app_language'.tr(ref),
              children: [
                _buildDropdown(
                  context: context,
                  label: 'app_language'.tr(ref),
                  value: settings.language,
                  items: ['English', 'Telugu', 'Hindi', 'Tamil'],
                  onChanged: (value) => notifier.setLanguage(value!),
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  context: context,
                  label: 'font_size'.tr(ref),
                  value: settings.fontSize,
                  items: ['Small', 'Medium', 'Large'],
                  onChanged: (value) => notifier.setFontSize(value!),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const SizedBox(height: 24),

            // SECTION 3: ORDER & PAYMENT SETTINGS
            _buildSectionHeader(context, 'order_payment_settings'.tr(ref)),
            _buildSettingsCard(
              context: context,
              icon: Icons.receipt_long_outlined,
              title: 'business_settings'.tr(ref),
              children: [
                _buildEditableField(
                  context: context,
                  label: 'invoice_prefix'.tr(ref),
                  value: settings.invoicePrefix,
                  onChanged: (v) => notifier.setInvoicePrefix(v),
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  context: context,
                  label: 'currency_symbol'.tr(ref),
                  value: settings.currencySymbol,
                  items: ['₹', '\$', 'QR', 'KD', 'AED', 'SAR'],
                  onChanged: (v) {
                    if (v != null) notifier.setCurrencySymbol(v);
                  },
                  helperText: 'currency_symbol_desc'.tr(ref),
                ),
                const SizedBox(height: 16),
                _buildEditableField(
                  context: context,
                  label: 'mill_contact_phone'.tr(ref),
                  value: settings.millContactPhone,
                  onChanged: (value) => notifier.setMillContactPhone(value),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SECTION: STORAGE SETTINGS
            _buildSectionHeader(context, 'storage_settings'.tr(ref)),
            SafeCard(
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SafeColumn(
                  children: [
                    SafeRow(
                      leading: Row(
                        children: [
                          Icon(Icons.folder_outlined,
                              color: theme.primaryColor),
                          const SizedBox(width: 12),
                          SafeText('excel_settings'.tr(ref),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SafeText(
                      'excel_save_location'.tr(ref),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    // Unified "One Div" style picker
                    InkWell(
                      onTap: () => _pickExcelPath(context, ref),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.lightGrey),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_open,
                                color: theme.primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                settings.excelSavePath.isEmpty
                                    ? 'default_downloads'.tr(ref)
                                    : settings.excelSavePath,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: settings.excelSavePath.isEmpty
                                      ? AppTheme.grey
                                      : theme.textTheme.bodyMedium?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit,
                                size: 16, color: AppTheme.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SECTION 4: DATA & SAFETY
            _buildSectionHeader(context, 'data_safety'.tr(ref)),
            _buildSettingsCard(
              context: context,
              icon: Icons.backup_outlined,
              title: 'data_management'.tr(ref),
              children: [
                // Auto-Backup Toggle
                SafeCard(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(12),
                  child: SafeColumn(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.autorenew,
                            color: theme.primaryColor, size: 24),
                        title: Text(
                          'auto_backup_daily'.tr(ref),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'auto_backup_helper'.tr(ref),
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.grey),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        trailing: Switch(
                          value: settings.autoBackupEnabled,
                          onChanged: (value) =>
                              notifier.setAutoBackupEnabled(value),
                          activeTrackColor: theme.primaryColor.withAlpha(128),
                          activeThumbColor: theme.primaryColor,
                        ),
                      ),
                      // Show last backup time
                      FutureBuilder<DateTime?>(
                        future: BackupService.getLastAutoBackupTime(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final lastBackup = snapshot.data!;
                            final formattedTime =
                                '${lastBackup.day}/${lastBackup.month}/${lastBackup.year} ${lastBackup.hour}:${lastBackup.minute.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SafeText(
                                '${'last_backup'.tr(ref)}: $formattedTime',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.grey),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await BackupService.backupDatabase();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result != null
                              ? 'backup_success'.tr(ref)
                              : 'backup_failed'.tr(ref)),
                          backgroundColor: result != null
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.backup),
                  label: Text('backup_data'.tr(ref)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: theme.primaryColor),
                    foregroundColor: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('restore_data'.tr(ref)),
                        content: Text('restore_warning'.tr(ref)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('cancel'.tr(ref)),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('restore'.tr(ref)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      final result = await BackupService.restoreDatabase();
                      if (context.mounted) {
                        if (result) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('restore_success'.tr(ref)),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                          // Prompt to restart app
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              title: Text('restart_required'.tr(ref)),
                              content: Text('restart_message'.tr(ref)),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.of(context)
                                      .popUntil((route) => route.isFirst),
                                  child: Text('ok'.tr(ref)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('restore_failed'.tr(ref)),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.restore),
                  label: Text('restore_data'.tr(ref)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: theme.primaryColor),
                    foregroundColor: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                SafeText(
                  'danger_zone'.tr(ref),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showResetConfirmation(context, ref),
                  icon: const Icon(Icons.delete_forever),
                  label: Text('reset_app'.tr(ref)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                SafeText(
                  'reset_warning'.tr(ref),
                  style: const TextStyle(fontSize: 12, color: AppTheme.error),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // SECTION 5: ABOUT & SUPPORT
            _buildSectionHeader(context, 'about_support'.tr(ref)),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.1)),
              ),
              child: SafeColumn(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/sri_balaji_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.business,
                          size: 50,
                          color: theme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeText(
                    'RiceAgent Pro',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SafeText(
                    'app_version'.tr(ref),
                    style: const TextStyle(fontSize: 14, color: AppTheme.grey),
                  ),
                  const SizedBox(height: 16),
                  SafeText(
                    'app_desc'.tr(ref),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Link to Product Gallery
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProductGalleryScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.collections_outlined,
                              size: 20, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          SafeText(
                            'view_products'.tr(ref),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              size: 12, color: theme.primaryColor),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SafeText(
                    'mill_full_name'.tr(ref),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SafeText(
                    'mill_history'.tr(ref),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SafeText(
                    'mill_address'.tr(ref),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey),
                  ),
                  const SizedBox(height: 16),
                  SafeRow(
                    mainAxisAlignment: MainAxisAlignment.center,
                    leading: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email, size: 16, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        SafeText(
                          'sbbrrm@gmail.com',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SafeText(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGrey.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeRow(
            leading: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                SafeText(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? helperText,
  }) {
    return SafeColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeText(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          key: ValueKey(value),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          SafeText(
            helperText,
            style: const TextStyle(fontSize: 12, color: AppTheme.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildEditableField({
    required BuildContext context,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return SafeColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeText(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickExcelPath(BuildContext context, WidgetRef ref) async {
    try {
      if (Platform.isAndroid) {
        // Robust Permission Check
        var status = await Permission.manageExternalStorage.status;

        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }

        if (!status.isGranted) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('permission_required'.tr(ref)),
                content: const Text(
                    'To save files in custom folders, this app needs "All Files Access".\n\nPlease grant this permission in the next screen (App Settings).',
                    style: TextStyle(fontSize: 14)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel'.tr(ref))),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: Text('open_settings'.tr(ref)),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // Quick verification
        final testFile = File('$selectedDirectory/test_write.txt');
        try {
          // Try writing
          await testFile.writeAsString('test');
          await testFile.delete();

          ref
              .read(settingsProvider.notifier)
              .setExcelSavePath(selectedDirectory);
        } catch (e) {
          if (context.mounted) {
            _showError(context,
                'Write failed: Permission denied for this specific folder.\nTry "Internal Storage" root or standard "Downloads".');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showPathInputDialog(
            context, ref, ref.read(settingsProvider).excelSavePath);
      }
    }
  }

  void _showPathInputDialog(
      BuildContext context, WidgetRef ref, String? currentPath) {
    final controller = TextEditingController(text: currentPath ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('enter_path'.tr(ref)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('manual_path_helper'.tr(ref),
                style: const TextStyle(fontSize: 13, color: AppTheme.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '/storage/emulated/0/Download',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr(ref))),
          FilledButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setExcelSavePath(controller.text);
              Navigator.pop(context);
            },
            child: Text('save'.tr(ref)),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) {
      SafeSnackBar.show(context, message, isError: true);
    }
  }

  Future<void> _showResetConfirmation(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: SafeRow(
          leading: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
              const SizedBox(width: 12),
              SafeText('reset_confirm_title'.tr(ref)),
            ],
          ),
        ),
        content: SafeText(
          'reset_confirm_body'.tr(ref),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr(ref)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('reset_app'.tr(ref)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = ref.read(databaseProvider);
        await db.delete(db.payments).go();
        await db.delete(db.lorryShipments).go();
        await db.delete(db.orderItems).go();
        await db.delete(db.orders).go();
        await db.delete(db.customerPrices).go();
        await db.delete(db.syncMeta).go();
        await db.delete(db.customers).go();
        await db.delete(db.products).go();

        ref.read(settingsProvider.notifier).resetAll();

        if (context.mounted) {
          SafeSnackBar.show(context, 'deleted_success'.tr(ref), isError: true);
        }
      } catch (e) {
        if (context.mounted) {
          SafeSnackBar.show(context, '${'failed_to_delete'.tr(ref)}: $e',
              isError: true);
        }
      }
    }
  }
}
