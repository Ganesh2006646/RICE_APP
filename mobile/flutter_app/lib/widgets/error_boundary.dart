import 'package:flutter/material.dart';

/// ErrorBoundary - Global error handler widget for uncaught exceptions
///
/// Wraps the app to catch any uncaught errors and show a friendly
/// error screen instead of crashing.
///
/// USAGE:
/// In main.dart, wrap your app:
/// ```dart
/// ErrorBoundary(
///   child: const RiceAgentApp(),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Capture Flutter framework errors - use addPostFrameCallback to avoid
    // setState during build phase
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Schedule setState for next frame to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _errorDetails = details;
            _hasError = true;
          });
        }
      });
    };
  }

  void _resetError() {
    setState(() {
      _errorDetails = null;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _errorDetails != null) {
      return widget.errorBuilder?.call(_errorDetails!) ??
          _buildDefaultErrorScreen(_errorDetails!);
    }
    return widget.child;
  }

  Widget _buildDefaultErrorScreen(FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Error Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error Title
                    const Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Error Message
                    Text(
                      'The app encountered an unexpected error.\nTap the button below to try again.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Retry Button
                    FilledButton.icon(
                      onPressed: _resetError,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Technical Details (collapsed by default)
                    ExpansionTile(
                      title: Text(
                        'Technical Details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            details.exceptionAsString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Color(0xFF333333),
                            ),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GlobalErrorHandler - Static utility for setting up global error handling
///
/// Call this in main() before runApp() to catch all errors
class GlobalErrorHandler {
  static bool _initialized = false;
  static final void Function(FlutterErrorDetails)? _originalHandler =
      FlutterError.onError;

  /// Initialize global error handling
  /// Must be called before runApp()
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Note: ErrorBoundary will override this, which is fine
    // This serves as a fallback for errors before ErrorBoundary mounts
    FlutterError.onError = (FlutterErrorDetails details) {
      // Call original handler if exists
      _originalHandler?.call(details);
      FlutterError.presentError(details);
      debugPrint('[GlobalErrorHandler] Flutter Error: ${details.exception}');
    };
  }

  /// Log an error manually
  static void logError(dynamic error, StackTrace? stackTrace) {
    debugPrint('[GlobalErrorHandler] Error: $error');
    if (stackTrace != null) {
      debugPrint('[GlobalErrorHandler] Stack: $stackTrace');
    }
  }
}
