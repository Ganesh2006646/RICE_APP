import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/settings_service.dart';
import '../main.dart';

/// Comprehensive Settings Screen
/// Supports: Language, Display, Mode, Theme, Order settings, Data & Safety, About
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

  // Settings state
  String _selectedLanguage = 'English';
  String _selectedFontSize = 'Medium';
  String _selectedMode = 'Simple Mode';
  String _selectedTheme = 'Light';
  int _defaultDueDays = 7;

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
    final prefs = await SharedPreferences.getInstance();
    final millEmail = await SettingsService.getMillEmail();
    final invoicePrefix = await SettingsService.getInvoicePrefix();

    setState(() {
      _millEmailController.text = millEmail;
      _invoicePrefixController.text = invoicePrefix;
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _selectedFontSize = prefs.getString('fontSize') ?? 'Medium';
      _selectedMode = prefs.getString('appMode') ?? 'Simple Mode';
      _selectedTheme = prefs.getString('theme') ?? 'Light';
      _defaultDueDays = prefs.getInt('defaultDueDays') ?? 7;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await SettingsService.setMillEmail(_millEmailController.text.trim());
    await SettingsService.setInvoicePrefix(
        _invoicePrefixController.text.trim());

    await prefs.setString('language', _selectedLanguage);
    await prefs.setString('fontSize', _selectedFontSize);
    await prefs.setString('appMode', _selectedMode);
    await prefs.setString('theme', _selectedTheme);
    await prefs.setInt('defaultDueDays', _defaultDueDays);

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

    // Delete all data
    await db.delete(db.orderItems).go();
    await db.delete(db.lorryShipments).go();
    await db.delete(db.payments).go();
    await db.delete(db.orders).go();
    await db.delete(db.customerPrices).go();
    await db.delete(db.customers).go();
    await db.delete(db.products).go();
    await db.delete(db.syncMeta).go();

    // Reset settings
    await SettingsService.resetAllSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

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
          if (_hasChanges)
            FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // SECTION 1: LANGUAGE & DISPLAY
                _buildSectionHeader('Language & Display'),
                _buildSettingsCard(
                  icon: Icons.language,
                  title: 'App Language',
                  children: [
                    _buildDropdown(
                      label: 'Language',
                      value: _selectedLanguage,
                      items: ['English', 'Telugu', 'Tamil', 'Hindi'],
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value!;
                          _markChanged();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Font Size',
                      value: _selectedFontSize,
                      items: ['Small', 'Medium', 'Large'],
                      onChanged: (value) {
                        setState(() {
                          _selectedFontSize = value!;
                          _markChanged();
                        });
                      },
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
                      label: 'App Mode',
                      value: _selectedMode,
                      items: ['Simple Mode', 'Advanced Mode'],
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value!;
                          _markChanged();
                        });
                      },
                      helperText: _selectedMode == 'Simple Mode'
                          ? 'Only essential buttons and screens'
                          : 'Shows analytics, export & sync options',
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Theme',
                      value: _selectedTheme,
                      items: ['Light', 'Dark'],
                      onChanged: (value) {
                        setState(() {
                          _selectedTheme = value!;
                          _markChanged();
                        });
                      },
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
                    _buildTextField(
                      label: 'Default Mill Email',
                      controller: _millEmailController,
                      hint: 'mill@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Default Payment Due Days',
                      value: _defaultDueDays.toString(),
                      items: ['7', '15', '30'],
                      onChanged: (value) {
                        setState(() {
                          _defaultDueDays = int.parse(value!);
                          _markChanged();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Invoice Prefix',
                      controller: _invoicePrefixController,
                      hint: 'RA-2024-',
                      helperText: 'Example: RA-2024-0001',
                    ),
                    const SizedBox(height: 16),
                    _buildReadOnlyField(
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
                          const SnackBar(
                            content: Text('Backup feature coming soon'),
                          ),
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
                            content: Text('Restore feature coming soon'),
                          ),
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
                      onPressed: _showResetConfirmation,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.error,
                      ),
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
                      Text(
                        'RiceAgent',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This app helps rice agents manage orders and payments easily.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.charcoal,
                        ),
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
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.email,
                              size: 16, color: AppTheme.primaryGreen),
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
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Part of Balaji Group of Industries',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Founded by Kotha Veerabhadra Rao & Kotha Narasimha Rao (Mohan Rao)\nContinued by Kotha Bhyarava Krishna, Kotha Sree Rama Krishna, Kotha Sudhir',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey,
                        ),
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => _markChanged(),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.grey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown({
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
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
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
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.grey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyField({
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
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.charcoal,
            ),
          ),
        ),
      ],
    );
  }
}
