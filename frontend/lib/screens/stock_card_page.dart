import 'package:flutter/material.dart';

import '../services/inventory_api.dart';
import '../widgets/app_style.dart';
import 'transaction_history.dart';
import '../widgets/stock_movement.dart';

class StockCardPage extends StatefulWidget {
  const StockCardPage({
    super.key,
    required this.api,
    required this.warehouseId,
    required this.itemId,
    required this.title,
  });
  final InventoryApi api;
  final int warehouseId, itemId;
  final String title;
  @override
  State<StockCardPage> createState() => _StockCardPageState();
}

class _StockCardPageState extends State<StockCardPage> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _loading = true;
  int _page = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.request(
        'GET',
        '/stock-card',
        query: {
          'warehouse_id': '${widget.warehouseId}',
          'item_id': '${widget.itemId}',
          'page': '$_page',
        },
      );
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kartu stok')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PageHeading(
            eyebrow: 'Inventori / Kartu stok',
            title: widget.title,
            description: 'Riwayat stok masuk dan keluar di gudang ini.',
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(_error.toString()),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ] else ...[
            StockPanel(
              title: 'Saldo terkini',
              value: '${_data!['balance']}',
              caption: 'Satuan mengikuti barang yang dipilih',
            ),
            const SectionLabel('Pergerakan stok'),
            if ((_data!['data'] as List).isEmpty)
              const StatusMessage(
                text: 'Belum ada pergerakan.',
                icon: Icons.history,
              ),
            for (final row in _data!['data'] as List)
              Card(
                child: ListTile(
                  leading: Icon(
                    (row['quantity_in'] as int) > 0
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: (row['quantity_in'] as int) > 0
                        ? stockInColor
                        : stockOutColor,
                  ),
                  title: Text(switch (row['movement_type']) {
                    'OPENING' => 'Stok awal',
                    'TRANSFER_IN' => 'Mutasi masuk',
                    'TRANSFER_OUT' => 'Mutasi keluar',
                    'ADJUSTMENT_IN' => 'Penyesuaian masuk',
                    _ => 'Penyesuaian keluar',
                  }, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${localTransactionTime(row['created_at'])}\n${row['document_number'] ?? ''}\nMasuk ${row['quantity_in']} • Keluar ${row['quantity_out']}\nSaldo ${row['balance_before']} → ${row['balance_after']}',
                  ),
                  onTap: () {
                    final kind = row['opening_stock_id'] != null
                        ? 'opening-stocks'
                        : row['adjustment_id'] != null
                        ? 'adjustments'
                        : 'transfers';
                    final id =
                        row['opening_stock_id'] ??
                        row['adjustment_id'] ??
                        row['transfer_id'];
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionDetail(
                          api: widget.api,
                          kind: kind,
                          id: id as int,
                        ),
                      ),
                    );
                  },
                ),
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Sebelumnya',
                  onPressed: _page > 1
                      ? () {
                          _page--;
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Halaman $_page'),
                IconButton(
                  tooltip: 'Muat ulang',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Berikutnya',
                  onPressed:
                      _page * 20 < ((_data!['meta'] as Map)['total'] as int)
                      ? () {
                          _page++;
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
