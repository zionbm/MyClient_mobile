import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api_client.dart';
import 'config/app_config.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/session_controller.dart';
import 'navigation/app_route_observer.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

class MyClientApp extends StatefulWidget {
  const MyClientApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<MyClientApp> createState() => _MyClientAppState();
}

class _MyClientAppState extends State<MyClientApp> {
  late final ApiClient _apiClient;
  late final PushNotificationService _pushNotifications;
  late final SessionController _sessionController;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(config: widget.config);
    _pushNotifications = PushNotificationService(apiClient: _apiClient);
    _sessionController = SessionController(
      apiClient: _apiClient,
      pushNotifications: _pushNotifications,
    );
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyClient',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      navigatorObservers: [appRouteObserver],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AuthGate(controller: _sessionController),
    );
  }
}
