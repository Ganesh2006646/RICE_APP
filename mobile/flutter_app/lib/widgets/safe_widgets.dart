import 'package:flutter/material.dart';

/// SafePage - Universal Layout Widget for Overflow-Free UI
///
/// RULES APPLIED:
/// 1. Always scrollable (SingleChildScrollView)
/// 2. SafeArea for notches/system UI
/// 3. Consistent padding
/// 4. No fixed heights that can overflow
///
/// USE THIS FOR ALL SCREENS
class SafePage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool safeTop;
  final bool safeBottom;
  final ScrollPhysics? physics;
  final Color? backgroundColor;

  const SafePage({
    super.key,
    required this.child,
    this.padding,
    this.safeTop = true,
    this.safeBottom = true,
    this.physics,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        top: safeTop,
        bottom: safeBottom,
        child: SingleChildScrollView(
          physics: physics ?? const AlwaysScrollableScrollPhysics(),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

/// SafeCard - Overflow-safe card with natural height
///
/// RULES APPLIED:
/// 1. No fixed height - grows with content
/// 2. mainAxisSize: MainAxisSize.min
/// 3. Proper padding
class SafeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double borderRadius;

  const SafeCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

/// SafeRow - Row that handles overflow gracefully
///
/// RULES APPLIED:
/// 1. Main content wrapped in Expanded/Flexible
/// 2. Text has ellipsis
/// 3. No fixed widths
/// 4. Trailing wrapped in Flexible to prevent right overflow
class SafeRow extends StatelessWidget {
  final Widget leading;
  final Widget? trailing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final int flexLeading;
  final int flexTrailing;

  const SafeRow({
    super.key,
    required this.leading,
    this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.flexLeading = 1,
    this.flexTrailing =
        0, // 0 means no flex (intrinsic size), >0 means flexible
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Flexible(flex: flexLeading, child: leading),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          flexTrailing > 0
              ? Flexible(flex: flexTrailing, child: trailing!)
              : Flexible(flex: 0, fit: FlexFit.loose, child: trailing!),
        ],
      ],
    );
  }
}

/// SafeText - Text widget that never overflows
///
/// RULES APPLIED:
/// 1. maxLines with ellipsis
/// 2. Respects system font scaling
/// 3. Soft wrap enabled
class SafeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;
  final TextOverflow overflow;

  const SafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: true,
    );
  }
}

/// SafeColumn - Column that prevents overflow
///
/// RULES APPLIED:
/// 1. mainAxisSize: MainAxisSize.min (shrink-wrap)
/// 2. Proper cross-axis alignment
class SafeColumn extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  const SafeColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children,
    );
  }
}

/// SafeWrap - Use instead of Row when items might overflow
///
/// RULES APPLIED:
/// 1. Auto-wraps to next line
/// 2. Consistent spacing
/// 3. Never overflows
class SafeWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  const SafeWrap({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      children: children,
    );
  }
}

/// SafeProgress - Progress bar that never overflows
///
/// RULES APPLIED:
/// 1. Uses Column, not Row
/// 2. Label above, value below
/// 3. No fixed widths
class SafeProgress extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color? color;
  final String? suffix;

  const SafeProgress({
    super.key,
    required this.label,
    required this.value,
    this.max = 100,
    this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final progress = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final displayValue = value.toStringAsFixed(2);
    final displayMax = max.toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color ?? Colors.green),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$displayValue / $displayMax ${suffix ?? ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// SafeListTile - ListTile that handles long text
///
/// RULES APPLIED:
/// 1. Title/subtitle have maxLines and ellipsis
/// 2. No fixed widths
/// 3. Proper padding
class SafeListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  const SafeListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: contentPadding,
    );
  }
}

/// SafeSnackBar - Prevents message stacking by clearing previous snackbars
class SafeSnackBar {
  static void show(BuildContext context, String message,
      {bool isError = false}) {
    // Clear any existing snackbars first to prevent stacking
    ScaffoldMessenger.of(context).clearSnackBars();

    // Show the new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// SafeBuilder - Ensures conditional UI never renders null/blank
///
/// RULES APPLIED:
/// 1. Always has a fallback (loading, error, or empty state)
/// 2. Handles null builder results gracefully
/// 3. Prevents black screen from null widget returns
///
/// USE THIS: For any conditional rendering that might return null
class SafeBuilder extends StatelessWidget {
  final Widget? Function() builder;
  final Widget fallback;

  const SafeBuilder({
    super.key,
    required this.builder,
    this.fallback = const Center(child: CircularProgressIndicator()),
  });

  @override
  Widget build(BuildContext context) {
    return builder() ?? fallback;
  }
}

/// NavigationGuard - Utility for safe navigation with state cleanup
///
/// Provides centralized navigation guards to prevent:
/// - Double pops
/// - Navigation from disposed contexts
/// - State leaks after cancel/discard
class NavigationGuard {
  /// Safely pop with mounted check
  static void safePop(BuildContext context, {VoidCallback? onBeforePop}) {
    if (context.mounted) {
      onBeforePop?.call();
      Navigator.pop(context);
    }
  }

  /// Safely pop with result and mounted check
  static void safePopWithResult<T>(BuildContext context, T result,
      {VoidCallback? onBeforePop}) {
    if (context.mounted) {
      onBeforePop?.call();
      Navigator.pop(context, result);
    }
  }

  /// Check if safe to navigate (context is mounted)
  static bool canNavigate(BuildContext context) {
    return context.mounted;
  }
}
