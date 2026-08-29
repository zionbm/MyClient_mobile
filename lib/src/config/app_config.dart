enum AppEnvironment { local, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.coreBaseUrl,
    required this.authMode,
  });

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment('APP_ENV', defaultValue: 'local');
    final environment = switch (envName) {
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => AppEnvironment.local,
    };

    final config = AppConfig(
      environment: environment,
      coreBaseUrl: const String.fromEnvironment(
        'CORE_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
      authMode: const String.fromEnvironment('AUTH_MODE', defaultValue: 'mock'),
    );
    config.validate();
    return config;
  }

  final AppEnvironment environment;
  final String coreBaseUrl;
  final String authMode;

  bool get isMockAuth => authMode == 'mock';

  Uri get coreBaseUri => Uri.parse(coreBaseUrl);

  void validate() {
    final uri = coreBaseUri;
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(
        coreBaseUrl,
        'CORE_BASE_URL',
        'נדרשת כתובת שרת תקינה',
      );
    }
    if (authMode != 'mock' && authMode != 'firebase') {
      throw ArgumentError.value(authMode, 'AUTH_MODE', 'ערך auth לא נתמך');
    }
    if (environment == AppEnvironment.production) {
      if (uri.scheme != 'https') {
        throw ArgumentError.value(
          coreBaseUrl,
          'CORE_BASE_URL',
          'production מחייב HTTPS',
        );
      }
      if (isMockAuth) {
        throw ArgumentError.value(
          authMode,
          'AUTH_MODE',
          'production מחייב Firebase auth',
        );
      }
    }
  }
}
