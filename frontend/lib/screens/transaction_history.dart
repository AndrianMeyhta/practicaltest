import 'package:flutter/material.dart';

import '../services/inventory_api.dart';

String transactionLabel(String kind) => switch (kind) {
  'transfers' => 'Transfer antar gudang',
  'opening-stocks' => 'Stok awal',
  _ => 'Balancing',
};

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({
    super.key,
    required this.api,
    this.compact = false,
  });
  final InventoryApi api;
  final bool compact;
  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  List<dynamic> _rows = [];
  int _page = 1, _total = 0;
  String _kind = '';
  Object? _error;
  bool _loading = true;
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
      final result = await widget.api.request(
        'GET',
        '/history',
        query: {
          'page': '$_page',
          'limit': widget.compact ? '5' : '20',
          if (_kind.isNotEmpty) 'kind': _kind,
        },
      );
      if (mounted) {
        setState(() {
          _rows = result['data'] as List;
          _total = (result['meta'] as Map)['total'] as int;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.compact)
        DropdownButtonFormField<String>(
          initialValue: '',
          decoration: const InputDecoration(labelText: 'Jenis transaksi'),
          items: ['', 'opening-stocks', 'transfers', 'adjustments']
              .map(
                (k) => DropdownMenuItem(
                  value: k,
                  child: Text(
                    k.isEmpty ? 'Semua transaksi' : transactionLabel(k),
                  ),
                ),
              )
              .toList(),
          onChanged: _loading
              ? null
              : (v) {
                  _kind = v!;
                  _page = 1;
                  _load();
                },
        ),
      const SizedBox(height: 12),
      if (_loading)
        const Center(child: CircularProgressIndicator())
      else if (_error != null) ...[
        Text(_error.toString()),
        OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
      ] else ...[
        if (_rows.isEmpty) const Text('Belum ada transaksi.'),
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                title: Text(
                  '${row['number']} • ${transactionLabel(row['kind'] as String)}',
                ),
                subtitle: Text(
                  '${row['location']}\n${row['created_at']}\n${row['notes']}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetail(
                      api: widget.api,
                      kind: row['kind'] as String,
                      id: row['id'] as int,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!widget.compact)
            IconButton(
              tooltip: 'Sebelumnya',
              onPressed: _loading || _page == 1
                  ? null
                  : () {
                      _page--;
                      _load();
                    },
              icon: const Icon(Icons.chevron_left),
            ),
          Text(
            widget.compact
                ? 'Aktivitas terbaru'
                : 'Halaman $_page • $_total dokumen',
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (!widget.compact)
            IconButton(
              tooltip: 'Berikutnya',
              onPressed: _loading || _page * 20 >= _total
                  ? null
                  : () {
                      _page++;
                      _load();
                    },
              icon: const Icon(Icons.chevron_right),
            ),
        ],
      ),
    ],
  );
}

class TransactionDetail extends StatefulWidget {
  const TransactionDetail({
    super.key,
    required this.api,
    required this.kind,
    required this.id,
  });
  final InventoryApi api;
  final String kind;
  final int id;
  @override
  State<TransactionDetail> createState() => _TransactionDetailState();
}

class _TransactionDetailState extends State<TransactionDetail> {
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
      final result = await widget.api.request(
        'GET',
        '/${widget.kind}/${widget.id}',
      );
      if (mounted) {
        setState(() => _data = result['data'] as Map<String, dynamic>);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bukti transaksi')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) ...[
            Text(_error.toString()),
            OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
          ] else if (_data == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(
              '${_data!['transfer_number'] ?? _data!['opening_number'] ?? _data!['adjustment_number']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(transactionLabel(widget.kind)),
            Text('Tercatat: ${_data!['created_at']}'),
            Text(
              '${_data!['warehouse_name'] ?? '${_data!['source_warehouse_name']} → ${_data!['destination_warehouse_name']}'}',
            ),
            const SizedBox(height: 16),
            if (widget.kind == 'transfers')
              for (final item in _data!['items'] as List)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${item['item_code']} • ${item['item_name']}\n${item['quantity']} ${item['item_unit']}\nAsal: ${item['source_stock_before']} → ${item['source_stock_after']}\nTujuan: ${item['destination_stock_before']} → ${item['destination_stock_after']}',
                    ),
                  ),
                )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_data!['item_code']} • ${_data!['item_name']}\n${_data!['direction'] == 'OUT' ? 'Keluar' : 'Masuk'} ${_data!['quantity']} ${_data!['item_unit']}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('Keterangan: ${_data!['notes']}'),
            const SizedBox(height: 16),
            const Text('Dokumen ini tidak dapat diubah atau dihapus.'),
          ],
        ],
      ),
    ),
  );
}
