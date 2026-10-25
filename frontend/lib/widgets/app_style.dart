import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const forest = Color(0xFF123F36);
const leaf = Color(0xFFB8D875);
const canvas = Color(0xFFF1F4F2);
const muted = Color(0xFF64756E);

ThemeData inventoryTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: forest).copyWith(
    primary: forest,
    onPrimary: Colors.white,
    secondary: leaf,
    onSecondary: forest,
    surface: Colors.white,
    outline: const Color(0xFFCDD9D2),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Color(0xFFCDD9D2)),
  );
  return base.copyWith(
    scaffoldBackgroundColor: canvas,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: forest,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: forest,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: forest,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: forest,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDFE7E2)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: const TextStyle(color: muted),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: forest, width: 2),
      ),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFCDD9D2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: leaf,
      foregroundColor: forest,
      elevation: 2,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFEAF1ED),
      side: BorderSide.none,
      labelStyle: const TextStyle(color: forest, fontWeight: FontWeight.w600),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: canvas),
    listTileTheme: const ListTileThemeData(
      iconColor: forest,
      selectedColor: forest,
      selectedTileColor: Color(0xFFE1ECD8),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFDFE7E2)),
    dialogTheme: DialogThemeData(
      backgroundColor: canvas,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: canvas),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
  });
  final String eyebrow, title;
  final String? description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(description!, style: const TextStyle(color: muted)),
        ],
      ],
    ),
  );
}

class StockPanel extends StatelessWidget {
  const StockPanel({
    super.key,
    required this.title,
    required this.value,
    this.caption,
    this.icon = Icons.layers_outlined,
  });
  final String title, value;
  final String? caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(24),
      border: const Border(top: BorderSide(color: leaf, width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: leaf, size: 26),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(color: Color(0xFFD6E7DF), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 12),
          Text(
            caption!,
            style: const TextStyle(color: Color(0xFFC3DDD4), fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: forest, fontWeight: FontWeight.w700),
    ),
  );
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: muted),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: muted)),
        ],
      ),
    ),
  );
}
