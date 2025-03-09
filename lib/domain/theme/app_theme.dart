import 'package:flutter/material.dart';

// Colores base
const Color darkRed = Color(0xFF8B0000); // Rojo oscuro
const Color lightRed = Color(0xFFFF0000); // Rojo claro
const Color offWhite = Color(0xFFF5F5F5); // Blanco hueso para modo claro
const Color darkGrey = Color(0xFF121212); // Gris oscuro para modo oscuro
const Color textLight = Colors.black; // Texto en modo claro
const Color textDark = Colors.white; // Texto en modo oscuro

// Constante para los bordes redondeados
const double inputBorderRadius = 12.0; // Bordes redondeados para inputs
const double searchBarBorderRadius = 50.0; // Bordes para barras de búsqueda

// Tema claro
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: lightRed,
  scaffoldBackgroundColor: offWhite,
  appBarTheme: AppBarTheme(
    backgroundColor: darkRed,
    elevation: 0,
    titleTextStyle: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 20,
      color: textDark,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: darkRed,
    selectedItemColor: textDark,
    unselectedItemColor: textDark.withOpacity(0.6),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: textLight),
    bodyMedium: TextStyle(color: textLight),
    headlineLarge: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 24,
      color: textLight,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      borderSide: BorderSide(color: textLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      borderSide: BorderSide(color: lightRed, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      borderSide: BorderSide(color: textLight.withOpacity(0.5)),
    ),
    labelStyle: const TextStyle(color: textLight),
    hintStyle: TextStyle(color: textLight.withOpacity(0.7)),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      ),
    ),
  ),
);

// Tema oscuro
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: lightRed,
  scaffoldBackgroundColor: darkGrey,
  appBarTheme: AppBarTheme(
    backgroundColor: darkRed,
    elevation: 0,
    titleTextStyle: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 20,
      color: textDark,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: darkRed,
    selectedItemColor: textDark,
    unselectedItemColor: textDark.withOpacity(0.6),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: textDark),
    bodyMedium: TextStyle(color: textDark),
    headlineLarge: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 24,
      color: textDark,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.black.withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      borderSide: BorderSide(color: textDark),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      borderSide: BorderSide(color: lightRed, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      borderSide: BorderSide(color: textDark.withOpacity(0.5)),
    ),
    labelStyle: const TextStyle(color: textDark),
    hintStyle: TextStyle(color: textDark.withOpacity(0.7)),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
      ),
    ),
  ),
);

// Clase para manejar el tema
class AppTheme {
  static ThemeData get light => lightTheme;
  static ThemeData get dark => darkTheme;
  static double get inputRadius => inputBorderRadius;
  static double get searchBarRadius => searchBarBorderRadius;
}
