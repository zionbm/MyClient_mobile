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

    return AppConfig(
      environment: environment,
      coreBaseUrl: const String.fromEnvironment(
        'CORE_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
      authMode: const String.fromEnvironment('AUTH_MODE', defaultValue: 'mock'),
    );
  }

  final AppEnvironment environment;
  final String coreBaseUrl;
  final String authMode;

  bool get isMockAuth => authMode == 'mock';
}
