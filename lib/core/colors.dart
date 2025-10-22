import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ThemeModeType { automatic, light, dark }

ThemeData getAppTheme(BuildContext context, ThemeModeType themeModeType) {
  // check system theme
  final brightness = MediaQuery.of(context).platformBrightness;
  final isDarkMode = brightness == Brightness.dark;

  final isDarkTheme =
      themeModeType == ThemeModeType.dark ||
      (themeModeType == ThemeModeType.automatic && isDarkMode);

  SystemChrome.setSystemUIOverlayStyle(getSystemUiOverlayStyle(isDarkTheme));

  return ThemeData(
    scaffoldBackgroundColor:
        isDarkTheme ? AppColors.backgroundD : AppColors.backgroundD,
    brightness: isDarkTheme ? Brightness.dark : Brightness.light,
    checkboxTheme: CheckboxThemeData(
      // fillColor: WidgetStateProperty.all(AppColors.secondaryD),
      // fillColor: WidgetStateProperty.all(AppColors.secondaryD),
      // checkColor: WidgetStateProperty.all(AppColors.textD),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.secondaryD),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.secondaryD,
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: getSystemUiOverlayStyle(isDarkTheme),
      backgroundColor:
          isDarkTheme ? AppColors.backgroundD : AppColors.backgroundD,
      iconTheme: IconThemeData(
        color: isDarkTheme ? Colors.white : Colors.black54,
      ),
    ),
    useMaterial3: false,
    extensions: <ThemeExtension<dynamic>>[
      AppColors(
        backgroundDarkness: AppColors.backgroundD,
        secondaryDarkness: AppColors.secondaryD,
        greenDarkness: AppColors.greenD,
        redDarkness: AppColors.red,
      ),
    ],
  );
}

class AppColors extends ThemeExtension<AppColors> {
  static const Color backgroundD = Color(0xff1e1e1e);
  static const Color terminalD = Color.fromARGB(255, 21, 21, 21);
  static const Color secondaryD = Color(0xff007acc);
  static const Color greenD = Color(0xffabc32f);
  static const Color textD = Color.fromARGB(255, 152, 152, 160);
  static const Color red = Color.fromARGB(255, 255, 69, 32);

  final Color backgroundDarkness;
  final Color secondaryDarkness;
  final Color greenDarkness;
  final Color redDarkness;

  AppColors({
    required this.backgroundDarkness,
    required this.secondaryDarkness,
    required this.greenDarkness,
    required this.redDarkness,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? backgroundDarkness,
    Color? secondaryDarkness,
    Color? greenDarkness,
    Color? redDarkness,
  }) {
    return AppColors(
      backgroundDarkness: backgroundDarkness ?? this.backgroundDarkness,
      secondaryDarkness: secondaryDarkness ?? this.secondaryDarkness,
      greenDarkness: greenDarkness ?? this.greenDarkness,
      redDarkness: redDarkness ?? this.redDarkness,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(
    covariant ThemeExtension<AppColors>? other,
    double t,
  ) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      backgroundDarkness:
          Color.lerp(backgroundDarkness, other.backgroundDarkness, t) ??
          backgroundDarkness,
      secondaryDarkness:
          Color.lerp(backgroundDarkness, other.backgroundDarkness, t) ??
          backgroundDarkness,
      greenDarkness:
          Color.lerp(greenDarkness, other.greenDarkness, t) ?? greenDarkness,
      redDarkness: Color.lerp(redDarkness, other.redDarkness, t) ?? redDarkness,
    );
  }
}

AppColors colors(BuildContext context) =>
    Theme.of(context).extension<AppColors>()!;

SystemUiOverlayStyle getSystemUiOverlayStyle(bool isDarkTheme) {
  if (Platform.isIOS) {
    return SystemUiOverlayStyle(
      statusBarColor:
          isDarkTheme ? AppColors.backgroundD : AppColors.backgroundD,
      statusBarIconBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
      statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
    );
  } else {
    return SystemUiOverlayStyle(
      statusBarColor:
          !isDarkTheme ? AppColors.backgroundD : AppColors.backgroundD,
      statusBarIconBrightness:
          !isDarkTheme ? Brightness.dark : Brightness.light,
      statusBarBrightness: !isDarkTheme ? Brightness.dark : Brightness.light,
    );
  }
}
