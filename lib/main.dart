import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/device_provider.dart';
import 'screens/server_workspace_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0078D4);
    final baseTextTheme = GoogleFonts.manropeTextTheme();

    return ChangeNotifierProvider(
      create: (_) => DeviceProvider(),
      child: MaterialApp(
        title: 'Linux Device Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
            surface: const Color(0xFFFFFFFF),
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF3F3F3),
          textTheme: baseTextTheme,
          fontFamily: 'Segoe UI',
          fontFamilyFallback: const ['Manrope', 'Inter', 'Roboto'],
          visualDensity: VisualDensity.compact,
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFF3F3F3),
            foregroundColor: const Color(0xFF101828),
            elevation: 1,
            titleTextStyle: baseTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF101828),
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          dividerTheme: DividerThemeData(
            color: Colors.grey.shade200,
            thickness: 1,
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.white,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: seed,
            unselectedItemColor: Color(0xFF64748B),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: seed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: seed, width: 1.5),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
            surface: const Color(0xFF0F172A),
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0B1220),
          textTheme: baseTextTheme.apply(
            bodyColor: const Color(0xFFE2E8F0),
            displayColor: const Color(0xFFE2E8F0),
          ),
          fontFamily: 'Segoe UI',
          fontFamilyFallback: const ['Manrope', 'Inter', 'Roboto'],
          visualDensity: VisualDensity.compact,
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF0B1220),
            foregroundColor: const Color(0xFFE2E8F0),
            elevation: 0,
            titleTextStyle: baseTextTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE2E8F0),
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF0F172A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          dividerTheme: DividerThemeData(
            color: Colors.white.withValues(alpha: 0.08),
            thickness: 1,
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: const Color(0xFF0F172A),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: const Color(0xFF111827),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: seed,
            unselectedItemColor: Color(0xFF94A3B8),
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: seed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: seed, width: 1.5),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const ServerWorkspaceScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
