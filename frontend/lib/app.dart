import 'package:flutter/material.dart';

import 'widgets/connection_status.dart';
import 'widgets/app_style.dart';
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
      theme: inventoryTheme(),
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
              const PageHeading(
                eyebrow: 'Inventori / UPVC',
                title: 'Kelola stok gudang',
                description: 'Stok profil dan aksesori UPVC di setiap gudang.',
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
