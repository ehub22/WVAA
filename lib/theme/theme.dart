import 'package:flutter/material.dart';

import 'colors.dart';

/// Full Material 3 color schemes. Every role is provided explicitly (including
/// the surface-container hierarchy and error containers) so all M3 components —
/// NavigationBar, SegmentedButton, Cards, SnackBars, bottom sheets — resolve
/// brand tokens instead of falling back to the baseline purple palette.
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
  tertiaryContainer: tertiaryContainerLight,
  onTertiaryContainer: onTertiaryContainerLight,
  error: errorLight,
  onError: onErrorLight,
  errorContainer: errorContainerLight,
  onErrorContainer: onErrorContainerLight,
  surface: surfaceLight,
  onSurface: onSurfaceLight,
  surfaceDim: surfaceDimLight,
  surfaceBright: surfaceBrightLight,
  surfaceContainerLowest: surfaceContainerLowestLight,
  surfaceContainerLow: surfaceContainerLowLight,
  surfaceContainer: surfaceContainerLight,
  surfaceContainerHigh: surfaceContainerHighLight,
  surfaceContainerHighest: surfaceContainerHighestLight,
  onSurfaceVariant: onSurfaceVariantLight,
  outline: outlineLight,
  outlineVariant: outlineVariantLight,
  shadow: Colors.black,
  scrim: scrimLight,
  inverseSurface: inverseSurfaceLight,
  onInverseSurface: inverseOnSurfaceLight,
  inversePrimary: inversePrimaryLight,
  surfaceTint: primaryLight,
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
  tertiaryContainer: tertiaryContainerDark,
  onTertiaryContainer: onTertiaryContainerDark,
  error: errorDark,
  onError: onErrorDark,
  errorContainer: errorContainerDark,
  onErrorContainer: onErrorContainerDark,
  surface: surfaceDark,
  onSurface: onSurfaceDark,
  surfaceDim: surfaceDimDark,
  surfaceBright: surfaceBrightDark,
  surfaceContainerLowest: surfaceContainerLowestDark,
  surfaceContainerLow: surfaceContainerLowDark,
  surfaceContainer: surfaceContainerDark,
  surfaceContainerHigh: surfaceContainerHighDark,
  surfaceContainerHighest: surfaceContainerHighestDark,
  onSurfaceVariant: onSurfaceVariantDark,
  outline: outlineDark,
  outlineVariant: outlineVariantDark,
  shadow: Colors.black,
  scrim: scrimDark,
  inverseSurface: inverseSurfaceDark,
  onInverseSurface: inverseOnSurfaceDark,
  inversePrimary: inversePrimaryDark,
  surfaceTint: primaryDark,
);

TextTheme _textTheme(Color bodyColor) {
  return Typography.material2021().black.apply(
        bodyColor: bodyColor,
        displayColor: bodyColor,
      );
}

ThemeData _baseTheme({
  required Brightness brightness,
  required ColorScheme colorScheme,
  required Color scaffoldBackground,
  required Color bodyColor,
  required Color primary,
  required Color onPrimaryContainer,
  required Color primaryContainer,
  required Color outlineVariant,
  required Color surfaceContainerLow,
}) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    canvasColor: colorScheme.surface,
    cardColor: colorScheme.surfaceContainerLow,
    dividerColor: colorScheme.outlineVariant,
    // Everything gets a comfortable tap target: this is the default, stated
    // explicitly so a future tweak cannot silently shrink touch areas.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: primaryContainer,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: onPrimaryContainer,
      iconTheme: IconThemeData(color: onPrimaryContainer),
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceContainerLow,
      indicatorColor: colorScheme.secondaryContainer,
      elevation: 0,
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: colorScheme.outline),
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(64, 48),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.secondaryContainer,
      foregroundColor: colorScheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainerLow,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      actionTextColor: colorScheme.inversePrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    iconTheme: IconThemeData(color: colorScheme.onSurface),
    textTheme: _textTheme(bodyColor),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceContainerLow,
      selectedItemColor: primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
    ),
  );
}

final ThemeData lightTheme = _baseTheme(
  brightness: Brightness.light,
  colorScheme: _lightColorScheme,
  scaffoldBackground: backgroundLight,
  bodyColor: onBackgroundLight,
  primary: primaryLight,
  onPrimaryContainer: onPrimaryContainerLight,
  primaryContainer: primaryContainerLight,
  outlineVariant: outlineVariantLight,
  surfaceContainerLow: surfaceContainerLowLight,
);

final ThemeData darkTheme = _baseTheme(
  brightness: Brightness.dark,
  colorScheme: _darkColorScheme,
  scaffoldBackground: backgroundDark,
  bodyColor: onBackgroundDark,
  primary: primaryDark,
  onPrimaryContainer: onPrimaryContainerDark,
  primaryContainer: primaryContainerDark,
  outlineVariant: outlineVariantDark,
  surfaceContainerLow: surfaceContainerLowDark,
);
