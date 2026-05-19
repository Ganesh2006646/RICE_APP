import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
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
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),

            const SizedBox(height: 24),

            // Premium Galaxy Trio
            _buildProductCard(
              context: context,
              ref: ref,
              title: 'premium_collection'.tr(ref),
              description: 'premium_desc'.tr(ref),
              imagePath: 'assets/images/galaxy_trio_premium.png',
              height: 250,
            ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),

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

            // Brand Advertisement Videos
            SafeText(
              'Brand Videos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            const SafeText(
              'Watch our brand advertisements',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grey,
              ),
            ),
            const SizedBox(height: 16),

            _buildVideoSection(context, ref),

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
                      Flexible(
                        child: Text(
                          'quality_assurance'.tr(ref),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade800,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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
            ).animate().fadeIn(duration: 600.ms, delay: 400.ms).scale(begin: const Offset(0.95, 0.95)),
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
        'name': 'galaxy_sona_blue'.tr(ref),
        'image': 'assets/images/galaxy_blue_sona.png',
        'description': 'sona_blue_desc'.tr(ref),
      },
      {
        'name': 'galaxy_sona_green'.tr(ref),
        'image': 'assets/images/galaxy_green_sona.png',
        'description': 'sona_green_desc'.tr(ref),
      },
      {
        'name': 'amaravathi'.tr(ref),
        'image': 'assets/images/amaravati.png',
        'description': 'hmt_desc'.tr(ref),
      },
      {
        'name': 'brown_rice'.tr(ref),
        'image': 'assets/images/brown_rice.png',
        'description': 'brown_rice_desc'.tr(ref),
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
          ).animate(delay: (index * 150).ms).fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutQuad),
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

  Widget _buildVideoSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final videos = <Map<String, String>>[
      {
        'title': 'Sri Balaji Rice Mill - Brand Ad 1',
        'videoId': '7Lf4R6Xi-KM',
        'url': 'https://youtu.be/7Lf4R6Xi-KM',
      },
      {
        'title': 'Sri Balaji Rice Mill - Brand Ad 2',
        'videoId': 'WBmw0Ec_Nlg',
        'url': 'https://youtu.be/WBmw0Ec_Nlg',
      },
      {
        'title': 'Sri Balaji Rice Mill - Brand Ad 3',
        'videoId': 'XpIEccDxaAY',
        'url': 'https://youtu.be/XpIEccDxaAY',
      },
    ];

    // Filter out entries with empty URLs
    final activeVideos = videos.where((v) => v['url']!.isNotEmpty).toList();

    if (activeVideos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.video_library_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Videos coming soon!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Brand advertisement videos will appear here',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms);
    }

    return Column(
      children: activeVideos.asMap().entries.map((entry) {
        final idx = entry.key;
        final video = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: idx < activeVideos.length - 1 ? 16 : 0),
          child: _buildVideoCard(context, video, theme)
              .animate(delay: (idx * 150).ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.05, curve: Curves.easeOutQuad),
        );
      }).toList(),
    );
  }

  Widget _buildVideoCard(
      BuildContext context, Map<String, String> video, ThemeData theme) {
    final videoId = video['videoId'] ?? '';
    final thumbnailUrl = videoId.isNotEmpty
        ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
        : '';

    return GestureDetector(
      onTap: () async {
        final url = video['url'] ?? '';
        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          boxShadow: theme.brightness == Brightness.light
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // YouTube Thumbnail with Play Button overlay
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Thumbnail or placeholder
                  thumbnailUrl.isNotEmpty
                      ? Image.network(
                          thumbnailUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 200,
                            color: Colors.red.shade50,
                            child: Icon(Icons.play_circle_outline,
                                size: 64, color: Colors.red.shade300),
                          ),
                        )
                      : Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.red.shade50,
                          child: Icon(Icons.play_circle_outline,
                              size: 64, color: Colors.red.shade300),
                        ),
                  // Dark overlay
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                  // Play button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade900.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 36, color: Colors.white),
                  ),
                  // YouTube branding
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_display,
                              size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'YouTube',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Video title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.play_circle_filled,
                      color: Colors.red.shade600, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      video['title'] ?? 'Brand Video',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.open_in_new,
                      size: 18, color: Colors.grey.shade500),
                ],
              ),
            ),
          ],
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
