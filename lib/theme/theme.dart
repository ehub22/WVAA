import 'package:flutter/material.dart';
import 'package:westview_app/theme/colors.dart';

final _lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: primaryLight,
  onPrimary: onPrimaryLight,
  primaryContainer: primaryContainerLight,
  onPrimaryContainer: onPrimaryContainerLight,
  secondary: secondaryLight,
  onSecondary: onSecondaryLight,
  secondaryContainer: secondaryContainerLight,
  onSecondaryContainer: onSecondaryContainerLight,
  tertiary: tertiaryLight,
  onTertiary: onTertiaryLight,
  error: errorLight,
  onError: onErrorLight,
  surfaceContainer: backgroundLight,
  surface: surfaceLight,
  onSurface: onSurfaceLight,
  surfaceContainerHighest: surfaceVariantLight,
  onSurfaceVariant: onSurfaceVariantLight,
  outline: outlineLight,
  shadow: Colors.black,
  inverseSurface: inverseSurfaceLight,
  onInverseSurface: inverseOnSurfaceLight,
  inversePrimary: inversePrimaryLight,
);

final _darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: primaryDark,
  onPrimary: onPrimaryDark,
  primaryContainer: primaryContainerDark,
  onPrimaryContainer: onPrimaryContainerDark,
  secondary: secondaryDark,
  onSecondary: onSecondaryDark,
  secondaryContainer: secondaryContainerDark,
  onSecondaryContainer: onSecondaryContainerDark,
  tertiary: tertiaryDark,
  onTertiary: onTertiaryDark,
  error: errorDark,
  onError: onErrorDark,
  surfaceContainer: backgroundDark,
  surface: surfaceDark,
  onSurface: onSurfaceDark,
  surfaceContainerHighest: surfaceVariantDark,
  onSurfaceVariant: onSurfaceVariantDark,
  outline: outlineDark,
  shadow: Colors.black,
  inverseSurface: inverseSurfaceDark,
  onInverseSurface: inverseOnSurfaceDark,
  inversePrimary: inversePrimaryDark,
);

final _baseTextTheme = Typography.material2018().black.apply(
      bodyColor: null,
      displayColor: null,
    );

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  colorScheme: _lightColorScheme,
  scaffoldBackgroundColor: backgroundLight,
  canvasColor: surfaceLight,
  cardColor: surfaceContainerLight,
  dividerColor: outlineLight,
  appBarTheme: AppBarTheme(
    backgroundColor: primaryContainerLight,
    elevation: 0,
    foregroundColor: onPrimaryContainerLight,
    iconTheme: IconThemeData(color: onPrimaryContainerLight),
    toolbarTextStyle: _baseTextTheme.bodyMedium?.copyWith(color: onPrimaryContainerLight),
    titleTextStyle: _baseTextTheme.titleLarge?.copyWith(color: onPrimaryContainerLight),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryLight,
      foregroundColor: onPrimaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryLight,
      side: BorderSide(color: outlineLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: primaryLight),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: secondaryLight,
    foregroundColor: onSecondaryLight,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surfaceContainerLowLight,
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: outlineVariantLight),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: primaryLight, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    labelStyle: TextStyle(color: onSurfaceVariantLight),
    hintStyle: TextStyle(color: onSurfaceVariantLight.withValues()),
  ),
  iconTheme: IconThemeData(color: onBackgroundLight),
  textTheme: _baseTextTheme.apply(bodyColor: onBackgroundLight, displayColor: onBackgroundLight),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: surfaceContainerLowLight,
    selectedItemColor: primaryLight,
    unselectedItemColor: onSurfaceVariantLight,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: _darkColorScheme,
  scaffoldBackgroundColor: backgroundDark,
  canvasColor: surfaceDark,
  cardColor: surfaceContainerDark,
  dividerColor: outlineDark,
  appBarTheme: AppBarTheme(
    backgroundColor: primaryContainerDark,
    elevation: 0,
    foregroundColor: onPrimaryContainerDark,
    iconTheme: IconThemeData(color: onPrimaryContainerDark),
    toolbarTextStyle: _baseTextTheme.bodyMedium?.copyWith(color: onPrimaryContainerDark),
    titleTextStyle: _baseTextTheme.titleLarge?.copyWith(color: onPrimaryContainerDark),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryDark,
      foregroundColor: onPrimaryDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryDark,
      side: BorderSide(color: outlineDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: primaryDark),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: secondaryDark,
    foregroundColor: onSecondaryDark,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surfaceContainerLowDark,
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: outlineVariantDark),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: primaryDark, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    labelStyle: TextStyle(color: onSurfaceVariantDark),
    hintStyle: TextStyle(color: onSurfaceVariantDark.withValues()),
  ),
  iconTheme: IconThemeData(color: onBackgroundDark),
  textTheme: _baseTextTheme.apply(bodyColor: onBackgroundDark, displayColor: onBackgroundDark),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: surfaceContainerLowDark,
    selectedItemColor: primaryDark,
    unselectedItemColor: onSurfaceVariantDark,
  ),
);
