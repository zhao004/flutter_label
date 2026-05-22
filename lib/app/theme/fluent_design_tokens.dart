import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

/// 应用级 Fluent 调色板，作为 `FluentThemeData.extensions` 的补充 token。
///
/// 设计意图：`fluent_ui` 已提供系统控件颜色，但项目还需要页面背景、玻璃卡片、
/// 预览画布和状态色等业务语义。把这些颜色挂在主题扩展上，避免继续在页面里
/// 固定浅色值，并让系统深浅色切换时自动同步。
@immutable
class FluentDesignPalette extends ThemeExtension<FluentDesignPalette> {
  const FluentDesignPalette({
    required this.appBackground,
    required this.titleBarBackground,
    required this.navigationBackground,
    required this.cardBackground,
    required this.cardHoverBackground,
    required this.fieldBackground,
    required this.selectedBackground,
    required this.previewBackground,
    required this.canvasBackground,
    required this.border,
    required this.fieldBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.warningBackground,
    required this.warningBorder,
    required this.warningText,
    required this.successGreen,
    required this.errorRed,
    required this.closeHover,
    required this.glassFill,
    required this.glassStrongFill,
    required this.shadow,
  });

  final Color appBackground;
  final Color titleBarBackground;
  final Color navigationBackground;
  final Color cardBackground;
  final Color cardHoverBackground;
  final Color fieldBackground;
  final Color selectedBackground;
  final Color previewBackground;
  final Color canvasBackground;
  final Color border;
  final Color fieldBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color warningBackground;
  final Color warningBorder;
  final Color warningText;
  final Color successGreen;
  final Color errorRed;
  final Color closeHover;
  final Color glassFill;
  final Color glassStrongFill;
  final Color shadow;

  static const light = FluentDesignPalette(
    appBackground: Color(0xFFF3F3F3),
    titleBarBackground: Color(0xEAFBFBFB),
    navigationBackground: Color(0xDDF7F7F7),
    cardBackground: Color(0xEFFFFFFF),
    cardHoverBackground: Color(0xFFFFFFFF),
    fieldBackground: Color(0xFFF8F8F8),
    selectedBackground: Color(0xFFEAF3FF),
    previewBackground: Color(0xFF1F1F1F),
    canvasBackground: Color(0xFF2B2B2B),
    border: Color(0xFFDADADA),
    fieldBorder: Color(0xFFD1D1D1),
    textPrimary: Color(0xFF202020),
    textSecondary: Color(0xFF616161),
    warningBackground: Color(0xFFFFF8E5),
    warningBorder: Color(0xFFE5C365),
    warningText: Color(0xFF6A4F00),
    successGreen: Color(0xFF0E7A0D),
    errorRed: Color(0xFFC42B1C),
    closeHover: Color(0xFFC42B1C),
    glassFill: Color(0xCCFFFFFF),
    glassStrongFill: Color(0xF7FFFFFF),
    shadow: Color(0x26000000),
  );

  static const dark = FluentDesignPalette(
    appBackground: Color(0xFF202020),
    titleBarBackground: Color(0xEA1F1F1F),
    navigationBackground: Color(0xDD252525),
    cardBackground: Color(0xE72B2B2B),
    cardHoverBackground: Color(0xFF323232),
    fieldBackground: Color(0xFF2D2D2D),
    selectedBackground: Color(0xFF123B5D),
    previewBackground: Color(0xFF171717),
    canvasBackground: Color(0xFF101010),
    border: Color(0xFF3A3A3A),
    fieldBorder: Color(0xFF4A4A4A),
    textPrimary: Color(0xFFF3F3F3),
    textSecondary: Color(0xFFC8C8C8),
    warningBackground: Color(0xFF433519),
    warningBorder: Color(0xFF9D7C24),
    warningText: Color(0xFFFFD56A),
    successGreen: Color(0xFF6CCB5F),
    errorRed: Color(0xFFFF8A80),
    closeHover: Color(0xFFC42B1C),
    glassFill: Color(0xB82C2C2C),
    glassStrongFill: Color(0xF2303030),
    shadow: Color(0x66000000),
  );

  @override
  FluentDesignPalette copyWith({
    Color? appBackground,
    Color? titleBarBackground,
    Color? navigationBackground,
    Color? cardBackground,
    Color? cardHoverBackground,
    Color? fieldBackground,
    Color? selectedBackground,
    Color? previewBackground,
    Color? canvasBackground,
    Color? border,
    Color? fieldBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? warningBackground,
    Color? warningBorder,
    Color? warningText,
    Color? successGreen,
    Color? errorRed,
    Color? closeHover,
    Color? glassFill,
    Color? glassStrongFill,
    Color? shadow,
  }) {
    return FluentDesignPalette(
      appBackground: appBackground ?? this.appBackground,
      titleBarBackground: titleBarBackground ?? this.titleBarBackground,
      navigationBackground: navigationBackground ?? this.navigationBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      cardHoverBackground: cardHoverBackground ?? this.cardHoverBackground,
      fieldBackground: fieldBackground ?? this.fieldBackground,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      previewBackground: previewBackground ?? this.previewBackground,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      border: border ?? this.border,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      warningBackground: warningBackground ?? this.warningBackground,
      warningBorder: warningBorder ?? this.warningBorder,
      warningText: warningText ?? this.warningText,
      successGreen: successGreen ?? this.successGreen,
      errorRed: errorRed ?? this.errorRed,
      closeHover: closeHover ?? this.closeHover,
      glassFill: glassFill ?? this.glassFill,
      glassStrongFill: glassStrongFill ?? this.glassStrongFill,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  FluentDesignPalette lerp(
    covariant ThemeExtension<FluentDesignPalette>? other,
    double t,
  ) {
    if (other is! FluentDesignPalette) {
      return this;
    }
    return FluentDesignPalette(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      titleBarBackground: Color.lerp(
        titleBarBackground,
        other.titleBarBackground,
        t,
      )!,
      navigationBackground: Color.lerp(
        navigationBackground,
        other.navigationBackground,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardHoverBackground: Color.lerp(
        cardHoverBackground,
        other.cardHoverBackground,
        t,
      )!,
      fieldBackground: Color.lerp(fieldBackground, other.fieldBackground, t)!,
      selectedBackground: Color.lerp(
        selectedBackground,
        other.selectedBackground,
        t,
      )!,
      previewBackground: Color.lerp(
        previewBackground,
        other.previewBackground,
        t,
      )!,
      canvasBackground: Color.lerp(
        canvasBackground,
        other.canvasBackground,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      fieldBorder: Color.lerp(fieldBorder, other.fieldBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      warningBackground: Color.lerp(
        warningBackground,
        other.warningBackground,
        t,
      )!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      successGreen: Color.lerp(successGreen, other.successGreen, t)!,
      errorRed: Color.lerp(errorRed, other.errorRed, t)!,
      closeHover: Color.lerp(closeHover, other.closeHover, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassStrongFill: Color.lerp(glassStrongFill, other.glassStrongFill, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Fluent 设计 token 入口，同时提供少量静态值给未完成迁移的旧页面兜底。
abstract final class FluentDesignTokens {
  static const Color primaryBlue = Color(0xFF005FB8);
  static const Color appBackground = Color(0xFFF3F3F3);
  static const Color titleBarBackground = Color(0xFFFBFBFB);
  static const Color navigationBackground = Color(0xFFF7F7F7);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color fieldBackground = Color(0xFFF8F8F8);
  static const Color selectedBackground = Color(0xFFEAF3FF);
  static const Color previewBackground = Color(0xFF1F1F1F);
  static const Color canvasBackground = Color(0xFF2B2B2B);
  static const Color border = Color(0xFFDADADA);
  static const Color fieldBorder = Color(0xFFD1D1D1);
  static const Color textPrimary = Color(0xFF202020);
  static const Color textSecondary = Color(0xFF616161);
  static const Color warningBackground = Color(0xFFFFF8E5);
  static const Color warningBorder = Color(0xFFE5C365);
  static const Color warningText = Color(0xFF6A4F00);
  static const Color successGreen = Color(0xFF0E7A0D);
  static const Color errorRed = Color(0xFFC42B1C);
  static const Color closeHover = Color(0xFFC42B1C);

  static const double titleBarHeight = 48;
  static const double navigationWidth = 260;
  static const double pageGap = 14;
  static const double cardRadius = 12;
  static const double controlRadius = 7;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(28, 22, 28, 24);
  static const EdgeInsets navigationPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 10,
  );

  static AccentColor get accentColor => primaryBlue.toAccentColor(
    darkestFactor: 0.36,
    darkerFactor: 0.24,
    darkFactor: 0.10,
    lightFactor: 0.22,
    lighterFactor: 0.38,
    lightestFactor: 0.48,
  );

  static FluentDesignPalette of(BuildContext context) {
    return FluentTheme.of(context).extension<FluentDesignPalette>() ??
        FluentDesignPalette.light;
  }

  static FluentThemeData lightTheme() => _fluentTheme(
    brightness: Brightness.light,
    palette: FluentDesignPalette.light,
  );

  static FluentThemeData darkTheme() => _fluentTheme(
    brightness: Brightness.dark,
    palette: FluentDesignPalette.dark,
  );

  static FluentThemeData _fluentTheme({
    required Brightness brightness,
    required FluentDesignPalette palette,
  }) {
    return FluentThemeData(
      brightness: brightness,
      accentColor: accentColor,
      activeColor: Colors.white,
      inactiveColor: palette.textPrimary,
      inactiveBackgroundColor: palette.fieldBackground,
      scaffoldBackgroundColor: palette.appBackground,
      acrylicBackgroundColor: palette.glassFill,
      micaBackgroundColor: palette.appBackground,
      cardColor: palette.cardBackground,
      menuColor: palette.cardBackground,
      shadowColor: palette.shadow,
      selectionColor: palette.selectedBackground,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
      extensions: [palette],
    );
  }

  /// 给尚未完全替换的 Material 控件提供一致的 Fluent 兼容层。
  ///
  /// 迁移策略是根应用先切 `FluentApp`，随后逐页替换可见 Material 控件；在过渡期
  /// Material 控件仍可能存在，因此这里集中定义它们的色彩、输入框和按钮状态，避免
  /// 回退到 Flutter 默认紫色/方形外观。
  static material.ThemeData materialTheme({
    Brightness brightness = Brightness.light,
  }) {
    final palette = brightness == Brightness.dark
        ? FluentDesignPalette.dark
        : FluentDesignPalette.light;
    final colorScheme = material.ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: brightness,
      surface: palette.cardBackground,
    );
    return material.ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      scaffoldBackgroundColor: palette.appBackground,
      colorScheme: colorScheme.copyWith(
        primary: primaryBlue,
        onPrimary: material.Colors.white,
        surface: palette.cardBackground,
        onSurface: palette.textPrimary,
        surfaceContainerHighest: palette.fieldBackground,
        outline: palette.fieldBorder,
        outlineVariant: palette.border,
        error: palette.errorRed,
      ),
      dividerColor: palette.border,
      textTheme: material.TextTheme(
        headlineMedium: material.TextStyle(
          color: palette.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: material.TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: material.TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: material.TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
        ),
        bodySmall: material.TextStyle(
          color: palette.textSecondary,
          fontSize: 12,
        ),
      ),
      filledButtonTheme: material.FilledButtonThemeData(
        style: material.FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: material.Colors.white,
          disabledBackgroundColor: palette.fieldBorder,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(0, 38),
          elevation: 1,
          shadowColor: palette.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: material.OutlinedButtonThemeData(
        style: material.OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(0, 38),
          side: BorderSide(color: palette.fieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      textButtonTheme: material.TextButtonThemeData(
        style: material.TextButton.styleFrom(
          foregroundColor: primaryBlue,
          disabledForegroundColor: palette.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      inputDecorationTheme: material.InputDecorationTheme(
        filled: true,
        fillColor: palette.fieldBackground,
        labelStyle: material.TextStyle(color: palette.textSecondary),
        hintStyle: material.TextStyle(color: palette.textSecondary),
        border: material.OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: palette.fieldBorder),
        ),
        enabledBorder: material.OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: palette.fieldBorder),
        ),
        focusedBorder: material.OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: primaryBlue, width: 1.4),
        ),
      ),
    );
  }

  static Widget materialCompatibilityBuilder(
    BuildContext context,
    Widget? child,
  ) {
    final brightness = FluentTheme.of(context).brightness;
    return material.Theme(
      data: materialTheme(brightness: brightness),
      child: material.Material(
        type: material.MaterialType.transparency,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
