import 'dart:ui';

// Light palette derived from the school's gold/brass brand colors.
//
// Error roles intentionally use the Material 3 baseline reds instead of the
// gold family: gold error banners read as warnings, and the yellow-on-dark
// combination the old palette produced failed contrast checks in dark mode.
const primaryLight = Color(0xFF695E32);
const onPrimaryLight = Color(0xFFFFFFFF);
const primaryContainerLight = Color(0xFFCFC08B);
const onPrimaryContainerLight = Color(0xFF3B310A);
const secondaryLight = Color(0xFF685E39);
const onSecondaryLight = Color(0xFFFFFFFF);
const secondaryContainerLight = Color(0xFFB7AB7F);
const onSecondaryContainerLight = Color(0xFF272002);
const tertiaryLight = Color(0xFF635E4A);
const onTertiaryLight = Color(0xFFFFFFFF);
const tertiaryContainerLight = Color(0xFFCDC6AD);
const onTertiaryContainerLight = Color(0xFF3A3624);
const errorLight = Color(0xFFBA1A1A);
const onErrorLight = Color(0xFFFFFFFF);
const errorContainerLight = Color(0xFFFFDAD6);
const onErrorContainerLight = Color(0xFF410002);
const backgroundLight = Color(0xFFFEF8F2);
const onBackgroundLight = Color(0xFF1D1B18);
const surfaceLight = Color(0xFFFDF8F6);
const onSurfaceLight = Color(0xFF1C1B1B);
const surfaceVariantLight = Color(0xFFE6E2D8);
const onSurfaceVariantLight = Color(0xFF48473F);
const outlineLight = Color(0xFF79776E);
const outlineVariantLight = Color(0xFFCAC6BC);
const scrimLight = Color(0xFF000000);
const inverseSurfaceLight = Color(0xFF31302F);
const inverseOnSurfaceLight = Color(0xFFF4F0EE);
const inversePrimaryLight = Color(0xFFD6C691);
const surfaceDimLight = Color(0xFFDDD9D7);
const surfaceBrightLight = Color(0xFFFDF8F6);
const surfaceContainerLowestLight = Color(0xFFFFFFFF);
const surfaceContainerLowLight = Color(0xFFF7F3F1);
const surfaceContainerLight = Color(0xFFF1EDEB);
const surfaceContainerHighLight = Color(0xFFEBE7E5);
const surfaceContainerHighestLight = Color(0xFFE6E2E0);

// Dark palette. Surfaces stay warm-neutral; the "on" colors are kept at high
// luminance so body text, captions and icons all clear WCAG AA (4.5:1) against
// every surface container they are painted on.
const primaryDark = Color(0xFFEADAA3);
const onPrimaryDark = Color(0xFF393008);
const primaryContainerDark = Color(0xFFC0B17D);
const onPrimaryContainerDark = Color(0xFF2E2501);
const secondaryDark = Color(0xFFD3C699);
const onSecondaryDark = Color(0xFF38300F);
const secondaryContainerDark = Color(0xFFA4986E);
const onSecondaryContainerDark = Color(0xFF080500);
const tertiaryDark = Color(0xFFEAE2C8);
const onTertiaryDark = Color(0xFF34311F);
const tertiaryContainerDark = Color(0xFFBFB89F);
const onTertiaryContainerDark = Color(0xFF2F2C1A);
const errorDark = Color(0xFFFFB4AB);
const onErrorDark = Color(0xFF690005);
const errorContainerDark = Color(0xFF93000A);
const onErrorContainerDark = Color(0xFFFFDAD6);
const backgroundDark = Color(0xFF151310);
const onBackgroundDark = Color(0xFFE7E2DB);
const surfaceDark = Color(0xFF141312);
const onSurfaceDark = Color(0xFFE6E2E0);
const surfaceVariantDark = Color(0xFF48473F);
const onSurfaceVariantDark = Color(0xFFCCC8BE);
const outlineDark = Color(0xFF9A9389);
const outlineVariantDark = Color(0xFF4A483F);
const scrimDark = Color(0xFF000000);
const inverseSurfaceDark = Color(0xFFE6E2E0);
const inverseOnSurfaceDark = Color(0xFF31302F);
const inversePrimaryDark = Color(0xFF695E32);
const surfaceDimDark = Color(0xFF141312);
const surfaceBrightDark = Color(0xFF3A3938);
const surfaceContainerLowestDark = Color(0xFF0F0E0D);
const surfaceContainerLowDark = Color(0xFF1C1B1B);
const surfaceContainerDark = Color(0xFF201F1F);
const surfaceContainerHighDark = Color(0xFF2B2A29);
const surfaceContainerHighestDark = Color(0xFF363433);
