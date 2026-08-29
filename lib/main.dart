import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/config/app_config.dart';
import 'src/core/observability/app_error_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorReporter.initialize();
  final config = AppConfig.fromEnvironment();
  if (!config.isMockAuth) {
    await Firebase.initializeApp();
  }
  runApp(ProviderScope(child: MyClientApp(config: config)));
}
