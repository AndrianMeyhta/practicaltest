import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/inventory_api.dart';
import '../widgets/app_style.dart';
import 'masters_page.dart';
import 'stock_card_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, this.client});
  final http.Client? client;
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final InventoryApi _api;
  List<Map<String, dynamic>> _warehouses = [], _stocks = [];
  int? _warehouse;
  int _page = 1, _total = 0;
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _api = InventoryApi(client: widget.client);
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse(path);
    return _api.request('GET', uri.path, query: uri.queryParameters);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _stocks = [];
    });
    try {
      {
        var page = 1;
        final warehouses = <Map<String, dynamic>>[];
        while (true) {
          final response = await _get('/warehouses?page=$page&limit=100');
          warehouses.addAll(
            (response['data'] as List).cast<Map<String, dynamic>>(),
          );
          if (warehouses.length >= response['meta']['total']) break;
          page++;
        }
        _warehouses = warehouses;
        if (!_warehouses.any((w) => w['id'] == _warehouse)) {
          _warehouse = _warehouses.isEmpty
              ? null
              : _warehouses.first['id'] as int;
          _page = 1;
        }
      }
      if (_warehouse != null) {
        final response = await _get(
          '/stocks?warehouse_id=$_warehouse&page=$_page&search=${Uri.encodeQueryComponent(_search)}',
        );
        _stocks = (response['data'] as List).cast<Map<String, dynamic>>();
        _total = response['meta']['total'] as int;
      }
    } catch (_) {
      _error = 'Tidak dapat memuat stok. Periksa koneksi lalu coba lagi.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Stok gudang'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Kelola master',
          onSelected: (kind) async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => MastersPage(kind: kind)),
            );
            if (mounted) await _load();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'items', child: Text('Master barang')),
            PopupMenuItem(value: 'warehouses', child: Text('Master gudang')),
          ],
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeading(
          eyebrow: 'Inventori / Gudang',
          title: 'Stok per gudang',
          description: 'Pilih gudang untuk melihat jumlah stok barang.',
        ),
        if (_warehouses.isNotEmpty)
          DropdownButtonFormField<int>(
            key: ValueKey(_warehouse),
            initialValue: _warehouse,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Gudang',
              prefixIcon: Icon(Icons.warehouse_outlined),
            ),
            items: _warehouses
                .map(
                  (w) => DropdownMenuItem(
                    value: w['id'] as int,
                    child: Text(w['name'] as String),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) {
                    _warehouse = value;
                    _page = 1;
                    _load();
                  },
          ),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Cari kode atau nama',
            suffixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) {
            _search = value.trim();
            _page = 1;
            _load();
          },
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          Text(_error!),
          OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
        ] else ...[
          if (_stocks.isEmpty)
            const StatusMessage(
              text: 'Belum ada barang untuk ditampilkan.',
              icon: Icons.inventory_2_outlined,
            ),
          if (_stocks.isNotEmpty) ...[
            StockPanel(
              title: 'Gudang terpilih',
              value:
                  _warehouses.firstWhere((w) => w['id'] == _warehouse)['name']
                      as String,
              caption: '$_total jenis barang sesuai pencarian',
              icon: Icons.warehouse_outlined,
            ),
            const SectionLabel('Daftar stok barang'),
          ],
          for (final stock in _stocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock['code'] as String,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: muted, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stock['name'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: forest,
                          borderRadius: BorderRadius.circular(16),
                          border: const Border(
                            left: BorderSide(color: leaf, width: 3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stok tersedia',
                              style: TextStyle(
                                color: Color(0xFFC3DDD4),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${stock['quantity']} ${stock['unit']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StockCardPage(
                              api: _api,
                              warehouseId: _warehouse!,
                              itemId: stock['item_id'] as int,
                              title: '${stock['name']} (${stock['unit']})',
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('Kartu stok'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _page > 1
                    ? () {
                        _page--;
                        _load();
                      }
                    : null,
                child: const Text('Sebelumnya'),
              ),
              Text('Halaman $_page'),
              OutlinedButton(
                onPressed: _page * 20 < _total
                    ? () {
                        _page++;
                        _load();
                      }
                    : null,
                child: const Text('Berikutnya'),
              ),
              TextButton(onPressed: _load, child: const Text('Muat ulang')),
            ],
          ),
        ],
      ],
    ),
  );
}
