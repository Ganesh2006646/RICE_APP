import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../services/translation_service.dart';
import '../widgets/safe_widgets.dart';

/// Product Gallery Screen - Showcases Sri Balaji Rice Mill Products
/// Displays official product packaging and branding
class ProductGalleryScreen extends ConsumerWidget {
  const ProductGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: SafeText('our_products'.tr(ref)),
      ),
      body: SafePage(
        padding: const EdgeInsets.all(16),
        child: SafeColumn(
          children: [
            // Header
            SafeText(
              'mill_name'.tr(ref),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            SafeText(
              'premium_rice'.tr(ref),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Product Lineup Banner
            _buildProductCard(
              context: context,
              ref: ref,
              title: 'complete_range'.tr(ref),
              description: 'lineup_desc'.tr(ref),
              imagePath: 'assets/images/product_lineup_full.png',
              height: 200,
            ),

            const SizedBox(height: 24),

            // Premium Galaxy Trio
            _buildProductCard(
              context: context,
              ref: ref,
              title: 'premium_collection'.tr(ref),
              description: 'premium_desc'.tr(ref),
              imagePath: 'assets/images/galaxy_trio_premium.png',
              height: 250,
            ),

            const SizedBox(height: 24),

            // Individual Products
            SafeText(
              'featured_products'.tr(ref),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            _buildProductGrid(context, ref),

            const SizedBox(height: 32),

            // Quality Assurance
            // Quality Assurance - Premium Design
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.shade50,
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, size: 32, color: Colors.teal),
                      const SizedBox(width: 12),
                      Text(
                        'quality_assurance'.tr(ref),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildQualityBadge(
                        context,
                        icon: Icons.security,
                        label: 'fssai_certified'.tr(ref),
                        color: Colors.green,
                      ),
                      _buildQualityBadge(
                        context,
                        icon: Icons.precision_manufacturing,
                        label: 'japan_technology'.tr(ref),
                        color: Colors.blue,
                      ),
                      _buildQualityBadge(
                        context,
                        icon: Icons.diamond_outlined,
                        label: 'premium_rice'.tr(ref),
                        color: Colors.purple,
                      ),
                      _buildQualityBadge(
                        context,
                        icon: Icons.flag,
                        label: 'product_of_india'.tr(ref),
                        color: Colors.orange,
                      ),
                    ],
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

  Widget _buildProductCard({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String description,
    required String imagePath,
    required double height,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: theme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: SafeColumn(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.asset(
              imagePath,
              height: height,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: height,
                color: theme.primaryColor.withValues(alpha: 0.05),
                child: const Icon(Icons.image, size: 48, color: AppTheme.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SafeColumn(
              children: [
                SafeText(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                SafeText(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final products = [
      {
        'name': 'galaxy_sona'.tr(ref),
        'image': 'assets/images/galaxy_sona_rice.png',
        'description': 'common_rice_desc'.tr(ref),
      },
      {
        'name': 'raw_non_basmati'.tr(ref),
        'image': 'assets/images/galaxy_hmt_jeera_yellow.png',
        'description': 'common_rice_desc'.tr(ref),
      },
      {
        'name': 'parboiled_rice'.tr(ref),
        'image': 'assets/images/hmt_jeera_rice.png',
        'description': 'common_rice_desc'.tr(ref),
      },
      {
        'name': 'broken_rice'.tr(ref),
        'image': 'assets/images/brown_rice.png',
        'description': 'common_rice_desc'.tr(ref),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () {
            _showProductDetail(context, product, ref);
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: SafeColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.asset(
                      product['image']!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.primaryColor.withValues(alpha: 0.05),
                        child: const Icon(Icons.image,
                            size: 24, color: AppTheme.grey),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SafeColumn(
                    children: [
                      SafeText(
                        product['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      SafeText(
                        product['description']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductDetail(
      BuildContext context, Map<String, String> product, WidgetRef ref) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.asset(
                        product['image']!,
                        height: 350,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 350,
                          color: theme.primaryColor.withValues(alpha: 0.05),
                          child: const Icon(Icons.image,
                              size: 64, color: AppTheme.grey),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SafeColumn(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SafeText(
                        product['name']!,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      SafeText(
                        product['description']!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SafeText(
                        'mill_full_name'.tr(ref),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
