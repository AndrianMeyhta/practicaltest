import 'package:flutter/material.dart';

import 'widgets/connection_status.dart';

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
      ),
      home: WelcomePage(checkHealth: checkHealth),
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
              const SizedBox(height: 24),
              const Text(
                'Aplikasi sedang dalam tahap pengembangan. '
                'Fitur barang, gudang, dan mutasi belum tersedia.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
