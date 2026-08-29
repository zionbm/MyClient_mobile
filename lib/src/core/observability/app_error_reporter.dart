import 'package:flutter/foundation.dart';

/// Central non-PII error boundary. Replace [report] with a Crashlytics/Sentry
/// adapter once production credentials are available.
class AppErrorReporter {
  static void initialize() {
    FlutterError.onError = (details) {
      report(details.exception, details.stack, source: 'flutter');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, source: 'platform');
      return true;
    };
  }

  static void report(
    Object error,
    StackTrace? stack, {
    required String source,
  }) {
    if (kDebugMode) {
      debugPrint('App error [$source]: ${error.runtimeType}');
      if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 12);
    }
  }
}
