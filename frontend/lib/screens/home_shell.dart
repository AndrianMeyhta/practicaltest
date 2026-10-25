import 'package:flutter/material.dart';

import '../services/inventory_api.dart';
import '../widgets/connection_status.dart';
import 'inventory_page.dart';
import 'masters_page.dart';
import 'transaction_form.dart';
import 'transaction_history.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.checkHealth, this.api});
  final Future<void> Function()? checkHealth;
  final InventoryApi? api;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final InventoryApi _api;
  int _page = 0, _revision = 0;
  static const _titles = ['Dashboard', 'Mutasi', 'Master', 'Pengaturan'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.swap_horiz,
    Icons.inventory_2_outlined,
    Icons.settings_outlined,
  ];
  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InventoryApi();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _transaction(String kind) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionForm(kind: kind, api: _api),
      ),
    );
    if (mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[_page])),
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'mutasi stock',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
            for (var i = 0; i < _titles.length; i++)
              ListTile(
                leading: Icon(_icons[i]),
                title: Text(_titles[i]),
                selected: _page == i,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _page = i;
                    _revision++;
                  });
                },
              ),
          ],
        ),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_page == 0) ...[
            Text(
              'Persediaan antar gudang',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Profil utuh dan aksesori UPVC, tercatat di setiap lokasi.',
            ),
            const SizedBox(height: 20),
            DashboardSummary(key: ValueKey('summary$_revision'), api: _api),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const InventoryPage()),
              ),
              icon: const Icon(Icons.warehouse_outlined),
              label: const Text('Lihat stok gudang'),
            ),
            const SizedBox(height: 24),
            Text(
              'Aktivitas terbaru',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TransactionHistory(
              key: ValueKey('dashboard$_revision'),
              api: _api,
              compact: true,
            ),
          ],
          if (_page == 1) ...[
            for (final kind in ['opening-stocks', 'transfers', 'adjustments'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () => _transaction(kind),
                  icon: const Icon(Icons.add),
                  label: Text(transactionLabel(kind)),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Riwayat transaksi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TransactionHistory(key: ValueKey('history$_revision'), api: _api),
          ],
          if (_page == 2) ...[
            Text(
              'Kelola master',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            for (final kind in ['items', 'warehouses'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      kind == 'items'
                          ? Icons.inventory_2_outlined
                          : Icons.warehouse_outlined,
                    ),
                    title: Text(
                      kind == 'items' ? 'Master barang' : 'Master gudang',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MastersPage(kind: kind, api: _api),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (_page == 3) ...[
            Text(
              'Koneksi sistem',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ConnectionStatus(checkHealth: widget.checkHealth),
            const SizedBox(height: 16),
            SelectableText('Alamat API: ${_api.baseUrl}'),
            const SizedBox(height: 8),
            const Text(
              'Pemeriksaan database dilakukan melalui backend. Aplikasi ini untuk demo lokal tanpa login.',
            ),
          ],
        ],
      ),
    ),
  );
}

class DashboardSummary extends StatefulWidget {
  const DashboardSummary({super.key, required this.api});
  final InventoryApi api;
  @override
  State<DashboardSummary> createState() => _DashboardSummaryState();
}

class _DashboardSummaryState extends State<DashboardSummary> {
  Map<String, dynamic>? _data;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final response = await widget.api.request('GET', '/dashboard');
      if (mounted) {
        setState(() => _data = response['data'] as Map<String, dynamic>);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(_error.toString()),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ] else if (_data == null)
            const CircularProgressIndicator()
          else ...[
            Text(
              '${_data!['items']} barang aktif • ${_data!['warehouses']} gudang aktif',
            ),
            const SizedBox(height: 12),
            for (final row in _data!['units'] as List)
              Text(
                '${row['quantity']} ${row['unit']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
          ],
        ],
      ),
    ),
  );
}
