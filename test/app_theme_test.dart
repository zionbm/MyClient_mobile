import 'package:dev_mobile/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 uses the permanent dark product palette', () {
    final theme = buildAppTheme();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.onPrimary, AppColors.onPrimary);
    expect(theme.appBarTheme.backgroundColor, AppColors.surface);
    expect(theme.bottomSheetTheme.backgroundColor, AppColors.background);
  });

  test('shared surfaces and controls follow the V2 palette', () {
    final theme = buildAppTheme();

    expect(theme.cardTheme.color, AppColors.surface);
    expect(theme.inputDecorationTheme.fillColor, AppColors.surfaceRaised);
    expect(theme.navigationBarTheme.backgroundColor, AppColors.surface);
    expect(theme.popupMenuTheme.color, AppColors.surfaceRaised);
  });
}
