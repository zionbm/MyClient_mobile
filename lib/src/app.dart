import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'config/app_config.dart';
import 'core/state/data_invalidator.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/session_controller.dart';
import 'navigation/app_navigator.dart';
import 'navigation/linked_entity_navigation.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

class MyClientApp extends ConsumerStatefulWidget {
  const MyClientApp({super.key, required this.config});

  final AppConfig config;

  @override
  ConsumerState<MyClientApp> createState() => _MyClientAppState();
}

class _MyClientAppState extends ConsumerState<MyClientApp> {
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
      dataInvalidator: ref.read(dataInvalidatorProvider),
    );
    _pushNotifications.onOpenNotification =
        ({required type, required id, title}) async {
          final context = appNavigatorKey.currentContext;
          if (context == null) return;
          await openLinkedEntity(
            context: context,
            controller: _sessionController,
            type: type,
            id: id,
            title: title,
          );
        };
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
      navigatorKey: appNavigatorKey,
      theme: buildAppTheme(),
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
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
