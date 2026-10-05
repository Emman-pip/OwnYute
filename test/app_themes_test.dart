import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_yute/core/app_controller.dart';
import 'package:own_yute/core/app_themes.dart';

void main() {
  test('dark blue palette uses blue accents and dark surfaces', () {
    final theme = AppThemes.dark(AppThemeChoice.darkBlue);

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xff8cc8ff));
    expect(theme.scaffoldBackgroundColor, const Color(0xff0b141d));
  });

  test('dark pink palette uses pink accents and dark surfaces', () {
    final theme = AppThemes.dark(AppThemeChoice.darkPink);

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xffff9bc2));
    expect(theme.scaffoldBackgroundColor, const Color(0xff190f15));
  });
}
