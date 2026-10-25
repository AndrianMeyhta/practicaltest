import 'package:flutter/material.dart';

import 'widgets/connection_status.dart';
import 'screens/inventory_page.dart';
import 'screens/masters_page.dart';
import 'screens/home_shell.dart';

class MutasiStokApp extends StatelessWidget {
  const MutasiStokApp({super.key, this.checkHealth});
  final Future<void> Function()? checkHealth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mutasi Stok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B58)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FB),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x12176B58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE4EBE7)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: HomeShell(checkHealth: checkHealth),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.checkHealth});
  final Future<void> Function()? checkHealth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mutasi Stok')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warehouse_outlined, size: 48),
              const SizedBox(height: 24),
              Text(
                'Persediaan antar gudang',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text('Pengelolaan stok profil dan aksesori UPVC.'),
              const SizedBox(height: 24),
              ConnectionStatus(checkHealth: checkHealth),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const InventoryPage(),
                  ),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Lihat stok gudang'),
              ),
              const SizedBox(height: 24),
              for (final kind in ['items', 'warehouses'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MastersPage(kind: kind),
                      ),
                    ),
                    icon: Icon(
                      kind == 'items'
                          ? Icons.inventory_2_outlined
                          : Icons.warehouse_outlined,
                    ),
                    label: Text(
                      kind == 'items' ? 'Master barang' : 'Master gudang',
                    ),
                  ),
                ),
              const Text(
                'Aplikasi sedang dalam tahap pengembangan. '
                'Transaksi mutasi belum tersedia.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
