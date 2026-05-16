import 'package:flutter/material.dart';
import '../services/crash_reporting_service.dart';

/// ErrorBoundary - Global error handler widget for uncaught exceptions
///
/// Wraps the app to catch any uncaught errors and show a friendly
/// error screen instead of crashing.
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
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      CrashReportingService.reportError(
        details.exception,
        details.stack,
        context: 'ErrorBoundary',
      );
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
    if (_retryCount >= _maxRetries) return;
    setState(() {
      _retryCount++;
      _errorDetails = null;
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _errorDetails != null) {
      return widget.errorBuilder?.call(_errorDetails!) ??
          _buildDefaultErrorScreen();
    }
    return widget.child;
  }

  Widget _buildDefaultErrorScreen() {
    final canRetry = _retryCount < _maxRetries;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F6F0),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Icon ──────────────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 40,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────────────────────
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2E1B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The app hit an unexpected error.\nYour data is safe.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7B6B),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // ── Error detail card ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDE5DD)),
                    ),
                    child: Text(
                      _errorDetails?.exceptionAsString() ??
                          'Unknown error occurred.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5C3317),
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Action ────────────────────────────────────────────
                  if (canRetry)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _resetError,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                            'Try Again (${_maxRetries - _retryCount} left)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCC02)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFF57C00), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please restart the app. If the error persists, go to Settings → Backup to recover your data.',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFFF57C00)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'RiceAgent · ${_retryCount > 0 ? 'Retry #$_retryCount' : 'First occurrence'}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GlobalErrorHandler - Static utility for setting up global error handling
class GlobalErrorHandler {
  static bool _initialized = false;
  static bool _handling = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterError.onError = (FlutterErrorDetails details) {
      if (_handling) return;
      _handling = true;
      try {
        debugPrint('[GlobalErrorHandler] Flutter Error: ${details.exception}');
        FlutterError.dumpErrorToConsole(details);
      } finally {
        _handling = false;
      }
    };
  }

  static void logError(dynamic error, StackTrace? stackTrace) {
    debugPrint('[GlobalErrorHandler] Error: $error');
    if (stackTrace != null) {
      debugPrint('[GlobalErrorHandler] Stack: $stackTrace');
    }
  }
}
