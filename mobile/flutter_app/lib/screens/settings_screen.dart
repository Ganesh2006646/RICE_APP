import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../services/settings_service.dart';
import '../main.dart';

/// Settings screen for app configuration
/// Matches the provided mockup design exactly
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _millEmailController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _millEmailController.dispose();
    _invoicePrefixController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final millEmail = await SettingsService.getMillEmail();
    final invoicePrefix = await SettingsService.getInvoicePrefix();

    setState(() {
      _millEmailController.text = millEmail;
      _invoicePrefixController.text = invoicePrefix;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await SettingsService.setMillEmail(_millEmailController.text.trim());
    await SettingsService.setInvoicePrefix(
        _invoicePrefixController.text.trim());

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Settings saved successfully'),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showResetConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 12),
            Text('Reset All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all customers, products, and orders. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _resetAllData();
    }
  }

  Future<void> _resetAllData() async {
    final db = ref.read(databaseProvider);

    // Delete all data from all tables
    await db.delete(db.orderItems).go();
    await db.delete(db.orders).go();
    await db.delete(db.customerPrices).go();
    await db.delete(db.customers).go();
    await db.delete(db.products).go();
    await db.delete(db.syncMeta).go();

    // Reset settings
    await SettingsService.resetAllSettings();
    await _loadSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.white),
              SizedBox(width: 12),
              Text('All data has been reset'),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          FilledButton.icon(
            onPressed: _hasChanges ? _saveSettings : null,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save Settings'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  _hasChanges ? AppTheme.primaryGreen : AppTheme.grey,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure application preferences.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.darkGrey,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Email Settings Card
                  _buildSettingsCard(
                    icon: Icons.email_outlined,
                    title: 'Email Settings',
                    children: [
                      _buildTextField(
                        label: 'Default Mill Email',
                        controller: _millEmailController,
                        hint: 'mill@example.com',
                        keyboardType: TextInputType.emailAddress,
                        helperText:
                            'This email will be pre-filled when sending order sheets.',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Invoice Settings Card
                  _buildSettingsCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Invoice Settings',
                    children: [
                      _buildTextField(
                        label: 'Invoice Prefix',
                        controller: _invoicePrefixController,
                        hint: 'RA-2024-',
                        helperText:
                            'Prefix for order numbers (e.g., RA-2024-0001)',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Danger Zone Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorLight,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppTheme.error.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.delete_forever, color: AppTheme.error),
                            const SizedBox(width: 12),
                            Text(
                              'Danger Zone',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showResetConfirmation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reset All Application Data'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Warning: This will delete all customers, products, and orders.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.error,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // About Section
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Sri Balaji Rice Mill',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Owner: Kankatala Narayana Murthy',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.grey,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Professional Rice Mill Management',
                          style:
                              TextStyle(color: AppTheme.darkGrey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightGrey),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryGreen),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.charcoal,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppTheme.lightGrey,
          ),
          onChanged: (_) => _markChanged(),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.grey,
                ),
          ),
        ],
      ],
    );
  }
}
