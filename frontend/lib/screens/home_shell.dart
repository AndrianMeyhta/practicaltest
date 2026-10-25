import 'package:flutter/material.dart';

import '../services/inventory_api.dart';
import '../widgets/connection_status.dart';
import '../widgets/app_style.dart';
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
    backgroundColor: _page == 0 ? const Color(0xFFF1F4F2) : null,
    appBar: AppBar(
      title: Text(_titles[_page]),
      backgroundColor: forest,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    drawer: Drawer(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const ContainerHeader(),
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
            const _DashboardHeading(),
            const SizedBox(height: 16),
            DashboardSummary(key: ValueKey('summary$_revision'), api: _api),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                leading: const Icon(
                  Icons.warehouse_outlined,
                  color: Color(0xFF176B58),
                  size: 28,
                ),
                title: const Text(
                  'Lihat stok per gudang',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Cari barang dan cek jumlahnya'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryPage()),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Transaksi terbaru',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Maksimal 5 transaksi terakhir',
              style: TextStyle(color: Color(0xFF64756E), fontSize: 13),
            ),
            TransactionHistory(
              key: ValueKey('dashboard$_revision'),
              api: _api,
              compact: true,
            ),
          ],
          if (_page == 1) ...[
            const PageHeading(
              eyebrow: 'Transaksi / Stok',
              title: 'Catat perubahan stok',
              description: 'Pilih jenis transaksi yang ingin dibuat.',
            ),
            for (final kind in ['opening-stocks', 'transfers', 'adjustments'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: forest,
                      foregroundColor: leaf,
                      child: Icon(
                        kind == 'transfers'
                            ? Icons.swap_horiz
                            : kind == 'opening-stocks'
                            ? Icons.add_box_outlined
                            : Icons.tune,
                      ),
                    ),
                    title: Text(
                      transactionLabel(kind),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      kind == 'transfers'
                          ? 'Pindahkan barang ke gudang lain'
                          : kind == 'opening-stocks'
                          ? 'Catat saldo pertama barang'
                          : 'Tambah atau kurangi stok dengan alasan',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _transaction(kind),
                  ),
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
            const PageHeading(
              eyebrow: 'Data / Master',
              title: 'Barang & gudang',
              description: 'Atur data barang dan lokasi penyimpanan.',
            ),
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
                    subtitle: Text(
                      kind == 'items'
                          ? 'Kode, nama, satuan, dan status'
                          : 'Lokasi penyimpanan dan status',
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
            const PageHeading(
              eyebrow: 'Sistem / Pengaturan',
              title: 'Koneksi aplikasi',
              description: 'Periksa sambungan ke server dan database.',
            ),
            ConnectionStatus(checkHealth: widget.checkHealth),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Alamat server'),
                    SelectableText(_api.baseUrl),
                  ],
                ),
              ),
            ),
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

class ContainerHeader extends StatelessWidget {
  const ContainerHeader({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      24,
      24 + MediaQuery.paddingOf(context).top,
      24,
      24,
    ),
    color: forest,
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warehouse_outlined, size: 40, color: leaf),
        SizedBox(height: 16),
        Text(
          'INVENTORI / UPVC',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'INVENTORI / UPVC',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64756E),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Ringkasan stok',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: const Color(0xFF123F36),
        ),
      ),
    ],
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
  Widget build(BuildContext context) {
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(height: 12),
              const Text('Ringkasan stok belum bisa dimuat.'),
              const SizedBox(height: 4),
              Text(_error.toString()),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (_data == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat ringkasan stok...'),
            ],
          ),
        ),
      );
    }
    final units = _data!['units'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(16) > 24;
            final cards = [
              _DashboardMetric(
                label: 'Jenis barang aktif',
                value: '${_data!['items']}',
                icon: Icons.inventory_2_outlined,
              ),
              _DashboardMetric(
                label: 'Gudang aktif',
                value: '${_data!['warehouses']}',
                icon: Icons.warehouse_outlined,
              ),
            ];
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cards[0], const SizedBox(height: 8), cards[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF123F36),
            borderRadius: BorderRadius.circular(24),
            border: const Border(
              top: BorderSide(color: Color(0xFFB8D875), width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total stok semua gudang',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFD6E7DF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (units.isEmpty)
                const Text(
                  'Belum ada stok tercatat.',
                  style: TextStyle(color: Colors.white),
                )
              else
                Wrap(
                  spacing: 32,
                  runSpacing: 20,
                  children: [
                    for (final row in units)
                      Container(
                        padding: const EdgeInsets.only(left: 16),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Color(0xFFB8D875),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${row['quantity']}',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              TextSpan(
                                text: '\n${row['unit']}',
                                style: const TextStyle(
                                  color: Color(0xFFB8D875),
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF396156), height: 1),
              const SizedBox(height: 12),
              const Text(
                'Gabungan stok dari seluruh gudang',
                style: TextStyle(color: Color(0xFFC3DDD4), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    ),
  );
}
