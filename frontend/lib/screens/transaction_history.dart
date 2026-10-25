import 'package:flutter/material.dart';

import '../services/inventory_api.dart';
import '../widgets/stock_movement.dart';
import '../widgets/app_style.dart';

String transactionLabel(String kind) => switch (kind) {
  'transfers' => 'Transfer antar gudang',
  'opening-stocks' => 'Stok awal',
  _ => 'Penyesuaian stok',
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
  final _search = TextEditingController();
  DateTimeRange? _dates;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
          if (_dates != null) 'from': _dates!.start.toUtc().toIso8601String(),
          if (_dates != null)
            'until': DateTime(
              _dates!.end.year,
              _dates!.end.month,
              _dates!.end.day + 1,
            ).toUtc().toIso8601String(),
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
      if (!widget.compact) ...[
        TextField(
          controller: _search,
          enabled: !_loading,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: 'Cari nomor transaksi',
            counterText: '',
            suffixIcon: IconButton(
              tooltip: 'Cari',
              onPressed: _loading
                  ? null
                  : () {
                      _page = 1;
                      _load();
                    },
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: (_) {
            _page = 1;
            _load();
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                _dates == null
                    ? 'Filter tanggal'
                    : '${_dates!.start.day}/${_dates!.start.month}/${_dates!.start.year} – ${_dates!.end.day}/${_dates!.end.month}/${_dates!.end.year}',
              ),
              onPressed: _loading
                  ? null
                  : () async {
                      final dates = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _dates,
                      );
                      if (dates != null && mounted) {
                        _dates = dates;
                        _page = 1;
                        _load();
                      }
                    },
            ),
            if (_dates != null)
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        _dates = null;
                        _page = 1;
                        _load();
                      },
                child: const Text('Hapus tanggal'),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (!widget.compact)
        DropdownButtonFormField<String>(
          isExpanded: true,
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
        if (_rows.isEmpty)
          if (widget.compact)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined),
                    SizedBox(height: 12),
                    Text('Belum ada transaksi.'),
                    SizedBox(height: 4),
                    Text('Transaksi yang sudah disimpan akan muncul di sini.'),
                  ],
                ),
              ),
            )
          else
            const Text('Belum ada transaksi.'),
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: _DashboardTransaction(
                row: row,
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
          if (!widget.compact) Text('Halaman $_page • $_total dokumen'),
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

class _DashboardTransaction extends StatelessWidget {
  const _DashboardTransaction({required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = row['kind'] as String;
    final label = kind == 'adjustments'
        ? 'Penyesuaian stok'
        : transactionLabel(kind);
    final icon = switch (kind) {
      'transfers' => Icons.swap_horiz,
      'opening-stocks' => Icons.add_box_outlined,
      _ => Icons.tune,
    };
    final notes = (row['notes'] as String? ?? '').trim();
    final accent = kind == 'transfers'
        ? const Color(0xFF245BA8)
        : kind == 'opening-stocks'
        ? const Color(0xFF176B58)
        : const Color(0xFF9B641A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${row['number']}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${row['location']}',
              style: const TextStyle(color: Color(0xFF44564E)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(
                  localTransactionTime(row['created_at']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64756E),
                  ),
                ),
                Text(
                  '${row['item_count'] ?? 1} jenis barang',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64756E),
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[const SizedBox(height: 12), Text(notes)],
            const SizedBox(height: 10),
            const Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Lihat rincian'),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
            StockPanel(
              title: transactionLabel(widget.kind),
              value:
                  '${_data!['transfer_number'] ?? _data!['opening_number'] ?? _data!['adjustment_number']}',
              caption: localTransactionTime(_data!['created_at']),
              icon: Icons.receipt_long_outlined,
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.check_circle_outline, color: stockInColor),
                label: Text('Selesai'),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.kind == 'transfers')
              for (final incoming in [false, true])
                WarehouseMovementCard(
                  warehouse:
                      _data![incoming
                              ? 'destination_warehouse_name'
                              : 'source_warehouse_name']
                          as String,
                  incoming: incoming,
                  label: incoming
                      ? 'Gudang tujuan • Stok masuk'
                      : 'Gudang asal • Stok keluar',
                  rows: [
                    for (final item in _data!['items'] as List)
                      StockMovementRow(
                        title: item['item_name'] as String,
                        subtitle: item['item_code'] as String,
                        quantity: item['quantity'] as int,
                        unit: item['item_unit'] as String,
                        incoming: incoming,
                      ),
                  ],
                )
            else
              WarehouseMovementCard(
                warehouse: _data!['warehouse_name'] as String,
                incoming: _data!['direction'] != 'OUT',
                rows: [
                  StockMovementRow(
                    title: _data!['item_name'] as String,
                    subtitle: _data!['item_code'] as String,
                    quantity: _data!['quantity'] as int,
                    unit: _data!['item_unit'] as String,
                    incoming: _data!['direction'] != 'OUT',
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text('Keterangan', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              (_data!['notes'] as String? ?? '').isEmpty
                  ? 'Tidak ada catatan.'
                  : _data!['notes'] as String,
            ),
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                title: const Text('Rincian saldo saat transaksi'),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  if (widget.kind == 'transfers')
                    for (final item in _data!['items'] as List)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${item['item_name']} (${item['item_unit']})\n${_data!['source_warehouse_name']}: ${item['source_stock_before']} → ${item['source_stock_after']}\n${_data!['destination_warehouse_name']}: ${item['destination_stock_before']} → ${item['destination_stock_after']}',
                          ),
                        ),
                      )
                  else
                    Text(
                      '${_data!['balance_before'] ?? '—'} → ${_data!['balance_after'] ?? '—'} ${_data!['item_unit']}',
                    ),
                  const Text(
                    'Saldo historis saat pencatatan, bukan saldo terkini.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Dokumen ini tidak dapat diubah atau dihapus.'),
          ],
        ],
      ),
    ),
  );
}
