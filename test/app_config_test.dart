import 'package:dev_mobile/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production requires HTTPS and Firebase authentication', () {
    final insecure = AppConfig(
      environment: AppEnvironment.production,
      coreBaseUrl: 'http://core.example.com',
      authMode: 'firebase',
    );
    final mock = AppConfig(
      environment: AppEnvironment.production,
      coreBaseUrl: 'https://core.example.com',
      authMode: 'mock',
    );

    expect(insecure.validate, throwsArgumentError);
    expect(mock.validate, throwsArgumentError);
  });

  test('local mock configuration permits an HTTP development server', () {
    const config = AppConfig(
      environment: AppEnvironment.local,
      coreBaseUrl: 'http://10.0.2.2:3000',
      authMode: 'mock',
    );

    expect(config.validate, returnsNormally);
  });
}
