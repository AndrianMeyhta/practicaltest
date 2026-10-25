import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/inventory_api.dart';
import 'masters_page.dart';

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
          '/stocks?warehouse_id=$_warehouse&page=$_page',
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
        Text(
          'Persediaan UPVC',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Profil utuh dan aksesori, tercatat per lokasi penyimpanan.',
        ),
        const SizedBox(height: 24),
        if (_warehouses.isNotEmpty)
          DropdownButtonFormField<int>(
            key: ValueKey(_warehouse),
            initialValue: _warehouse,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Gudang',
              border: OutlineInputBorder(),
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
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          Text(_error!),
          OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
        ] else ...[
          if (_stocks.isEmpty)
            const Text('Belum ada barang untuk ditampilkan.'),
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
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stock['name'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${stock['quantity']} ${stock['unit']}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
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
