import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../main.dart';
import '../providers/settings_provider.dart';

/// Comprehensive Settings Screen
/// Settings changes now reflect immediately in the app
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SECTION 1: LANGUAGE & DISPLAY
          _buildSectionHeader('Language & Display'),
          _buildSettingsCard(
            icon: Icons.language,
            title: 'App Language',
            children: [
              _buildDropdown(
                context: context,
                label: 'Language',
                value: settings.language,
                items: ['English', 'Telugu', 'Tamil', 'Hindi'],
                onChanged: (value) => notifier.setLanguage(value!),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                context: context,
                label: 'Font Size',
                value: settings.fontSize,
                items: ['Small', 'Medium', 'Large'],
                onChanged: (value) => notifier.setFontSize(value!),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SECTION 2: MODE & THEME
          _buildSectionHeader('Mode & Theme'),
          _buildSettingsCard(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            children: [
              _buildDropdown(
                context: context,
                label: 'App Mode',
                value: settings.appMode,
                items: ['Simple Mode', 'Advanced Mode'],
                onChanged: (value) => notifier.setAppMode(value!),
                helperText: settings.appMode == 'Simple Mode'
                    ? 'Only essential buttons and screens'
                    : 'Shows analytics, export & sync options',
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                context: context,
                label: 'Theme',
                value: settings.theme,
                items: ['Light', 'Dark'],
                onChanged: (value) => notifier.setTheme(value!),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SECTION 3: ORDER & PAYMENT SETTINGS
          _buildSectionHeader('Order & Payment Settings'),
          _buildSettingsCard(
            icon: Icons.receipt_long_outlined,
            title: 'Business Settings',
            children: [
              _buildDropdown(
                context: context,
                label: 'Default Payment Due Days',
                value: settings.defaultDueDays.toString(),
                items: ['7', '15', '30'],
                onChanged: (value) =>
                    notifier.setDefaultDueDays(int.parse(value!)),
              ),
              const SizedBox(height: 16),
              _buildReadOnlyField(
                context: context,
                label: 'Currency Symbol',
                value: '₹ (Indian Rupee)',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // SECTION 4: DATA & SAFETY
          _buildSectionHeader('Data & Safety'),
          _buildSettingsCard(
            icon: Icons.backup_outlined,
            title: 'Data Management',
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup feature coming soon')),
                  );
                },
                icon: const Icon(Icons.backup),
                label: const Text('Backup Data'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Restore feature coming soon')),
                  );
                },
                icon: const Icon(Icons.restore),
                label: const Text('Restore Data'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showResetConfirmation(context, ref),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Reset App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Warning: This will delete all customers, products, and orders.',
                style: TextStyle(fontSize: 12, color: AppTheme.error),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // SECTION 5: ABOUT & SUPPORT
          _buildSectionHeader('About & Support'),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.paleGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/sri_balaji_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RiceAgent',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 14, color: AppTheme.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app helps rice agents manage orders and payments easily.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Sri Balaji Boiled and Raw Rice Mill',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Established 1998 • 45+ Years of Excellence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jaggampeta, East Godavari\nAndhra Pradesh, India',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.grey),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email, size: 16, color: AppTheme.primaryGreen),
                    SizedBox(width: 8),
                    Text(
                      'sbbrrm@gmail.com',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.charcoal,
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
        color: Colors.white,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
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

  Widget _buildDropdown({
    required BuildContext context,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.lightGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(fontSize: 12, color: AppTheme.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyField({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, color: AppTheme.charcoal),
          ),
        ),
      ],
    );
  }

  Future<void> _showResetConfirmation(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 12),
            Text('Reset App?'),
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.delete(db.orderItems).go();
      await db.delete(db.orders).go();
      await db.delete(db.customerPrices).go();
      await db.delete(db.customers).go();
      await db.delete(db.products).go();

      ref.read(settingsProvider.notifier).resetAll();

      if (context.mounted) {
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
          ),
        );
      }
    }
  }
}
