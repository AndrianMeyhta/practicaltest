import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/master.dart';
import '../services/inventory_api.dart';
import 'transaction_history.dart';
import '../widgets/app_style.dart';
import '../widgets/stock_movement.dart';

class TransactionLine {
  Master? item;
  final quantity = TextEditingController(text: '1');
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key, required this.kind, required this.api});
  final String kind;
  final InventoryApi api;
  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _lines = [TransactionLine()];
  List<Master> _warehouses = [], _items = [];
  int? _source, _destination;
  String _direction = 'IN';
  bool _loading = true, _busy = false, _uncertain = false;
  String? _error, _key, _previewFingerprint;
  Map<String, dynamic>? _preview, _attempt;
  Map<int, int> _balances = {};
  bool _stockLoading = false;
  String? _stockError;
  int _stockGeneration = 0;
  bool get _transfer => widget.kind == 'transfers';
  bool get _adjustment => widget.kind == 'adjustments';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final line in _lines) {
      line.quantity.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Future<List<Master>> all(String kind) async {
        final rows = <Master>[];
        for (var page = 1; ; page++) {
          final result = await widget.api.masters(
            kind,
            page: page,
            active: true,
          );
          rows.addAll(result.rows);
          if (rows.length >= result.total) return rows;
        }
      }

      final result = await Future.wait([all('warehouses'), all('items')]);
      if (mounted) {
        setState(() {
          _warehouses = result[0];
          _items = result[1];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() => setState(() {
    _preview = null;
    _previewFingerprint = null;
    _key = null;
    _error = null;
  });
  Future<void> _loadBalances() async {
    _changed();
    final source = _source;
    final generation = ++_stockGeneration;
    setState(() {
      _balances = {};
      _stockError = null;
      _stockLoading = source != null;
    });
    if (source == null) return;
    try {
      final balances = await widget.api.warehouseBalances(source);
      if (mounted && generation == _stockGeneration) {
        setState(() => _balances = balances);
      }
    } catch (_) {
      if (mounted && generation == _stockGeneration) {
        setState(() => _stockError = 'Stok gagal dimuat.');
      }
    } finally {
      if (mounted && generation == _stockGeneration) {
        setState(() => _stockLoading = false);
      }
    }
  }

  Widget _quantityRow(TransactionLine line) {
    final quantity = _balances[line.item?.id];
    final colors = Theme.of(context).colorScheme;
    final stock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Stok tersedia', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        if (_source == null || line.item == null)
          const Text('Pilih gudang dan barang', style: TextStyle(fontSize: 12))
        else if (_stockLoading)
          const Text('Memuat stok…')
        else if (_stockError != null || quantity == null)
          TextButton(
            onPressed: _busy || _uncertain ? null : _loadBalances,
            child: const Text('Muat ulang stok'),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: quantity > 0 ? colors.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: quantity > 0 ? colors.primary : colors.outlineVariant,
              ),
            ),
            child: Text(
              '$quantity ${line.item!.unit}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: quantity > 0 ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
      ],
    );
    final input = TextFormField(
      controller: line.quantity,
      enabled: !_busy && !_uncertain,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Jumlah', errorMaxLines: 3),
      onChanged: (_) => _changed(),
      validator: (v) {
        final n = int.tryParse(v?.trim() ?? '');
        if (n == null || n < 1 || n > 1000000) {
          return 'Isi integer 1–1.000.000.';
        }
        if ((_transfer || (_adjustment && _direction == 'OUT')) &&
            quantity != null &&
            n > quantity) {
          return 'Melebihi stok tersedia.';
        }
        return null;
      },
    );
    final remove = _transfer && _lines.length > 1
        ? IconButton(
            tooltip: 'Hapus barang ${_lines.indexOf(line) + 1}',
            onPressed: _busy || _uncertain
                ? null
                : () {
                    _lines.remove(line);
                    _changed();
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => line.quantity.dispose(),
                    );
                  },
            icon: const Icon(Icons.delete_outline),
          )
        : const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(14) > 22) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stock,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: input),
                  remove,
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: stock),
            const SizedBox(width: 12),
            Expanded(child: input),
            remove,
          ],
        );
      },
    );
  }

  Map<String, dynamic> _payload() => {
    if (_transfer) ...{
      'source_warehouse_id': _source,
      'destination_warehouse_id': _destination,
      'items': _lines
          .map(
            (line) => {
              'item_id': line.item?.id,
              'quantity': int.tryParse(line.quantity.text.trim()),
            },
          )
          .toList(),
    } else ...{
      'warehouse_id': _source,
      'item_id': _lines.first.item?.id,
      'quantity': int.tryParse(_lines.first.quantity.text.trim()),
    },
    if (_adjustment) 'direction': _direction,
    'notes': _notes.text.trim(),
  };
  Future<void> _inspect() async {
    if (!_form.currentState!.validate()) return;
    if (_lines.map((line) => line.item?.id).toSet().length != _lines.length ||
        (_transfer && _source == _destination)) {
      setState(
        () => _error = 'Gudang harus berbeda dan barang tidak boleh duplikat.',
      );
      return;
    }
    final body = _payload();
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final result = await widget.api.request(
        'POST',
        '/${widget.kind}/preview',
        body: body,
      );
      if (mounted) {
        setState(() {
          _preview = result['data'] as Map<String, dynamic>;
          _previewFingerprint = jsonEncode(body);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _newKey() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_uncertain) {
      if (_preview == null || _previewFingerprint != jsonEncode(_payload())) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Simpan transaksi?'),
          content: const Text(
            'Periksa preview dan keterangan. Dokumen berhasil tidak dapat diubah atau dihapus. Saldo akan diperiksa ulang oleh server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      _attempt = _payload();
      _key ??= _newKey();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.request(
        'POST',
        '/${widget.kind}',
        body: _attempt,
        idempotencyKey: _key,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _uncertain = false;
      });
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetail(
            api: widget.api,
            kind: widget.kind,
            id: (result['data'] as Map)['id'] as int,
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on InventoryApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _uncertain = error.uncertain;
          if (!_uncertain) {
            _preview = null;
            _key = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _warehouse(String label, int? value, ValueChanged<int?> changed) =>
      DropdownButtonFormField<int>(
        key: ValueKey('$label:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: _warehouses
            .where(
              (w) =>
                  !_transfer ||
                  w.id != (label == 'Gudang tujuan' ? _source : _destination),
            )
            .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
            .toList(),
        validator: (v) => v == null ? 'Pilih gudang.' : null,
        onChanged: _busy || _uncertain
            ? null
            : (v) {
                changed(v);
                _changed();
              },
      );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_uncertain,
    child: Scaffold(
      appBar: AppBar(title: Text(transactionLabel(widget.kind))),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading || _busy || _uncertain ? null : _inspect,
                  child: const Text('Preview stok'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      _loading || _busy || (!_uncertain && _preview == null)
                      ? null
                      : _save,
                  child: Text(
                    _busy
                        ? 'Memproses…'
                        : _uncertain
                        ? 'Coba ulang'
                        : 'Konfirmasi',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    PageHeading(
                      eyebrow: 'Transaksi / Baru',
                      title: _transfer
                          ? 'Transfer stok'
                          : _adjustment
                          ? 'Penyesuaian stok'
                          : 'Stok awal',
                      description: _transfer
                          ? 'Pilih gudang asal, tujuan, dan barang yang dipindahkan.'
                          : _adjustment
                          ? 'Pilih perubahan stok dan tulis alasannya.'
                          : 'Catat jumlah pertama barang di gudang.',
                    ),
                    const SectionLabel('Lokasi & jenis transaksi'),
                    if (_warehouses.isEmpty || _items.isEmpty) ...[
                      const Text('Barang dan gudang aktif diperlukan.'),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Muat ulang master'),
                      ),
                    ],
                    _warehouse(_transfer ? 'Gudang asal' : 'Gudang', _source, (
                      v,
                    ) {
                      _source = v;
                      _loadBalances();
                    }),
                    const SizedBox(height: 16),
                    if (_transfer && _warehouses.length < 2)
                      const Text(
                        'Transfer membutuhkan minimal dua gudang aktif.',
                      ),
                    if (_transfer) ...[
                      _warehouse(
                        'Gudang tujuan',
                        _destination,
                        (v) => _destination = v,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_adjustment) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _direction,
                        decoration: const InputDecoration(
                          labelText: 'Jenis penyesuaian',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'IN',
                            child: Text('Tambah stok'),
                          ),
                          DropdownMenuItem(
                            value: 'OUT',
                            child: Text('Kurangi stok'),
                          ),
                        ],
                        onChanged: _busy || _uncertain
                            ? null
                            : (v) {
                                _direction = v!;
                                _changed();
                              },
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SectionLabel('Barang & jumlah'),
                    for (final line in _lines)
                      Padding(
                        key: ObjectKey(line),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                DropdownButtonFormField<int>(
                                  key: ObjectKey(line),
                                  isExpanded: true,
                                  initialValue: line.item?.id,
                                  decoration: const InputDecoration(
                                    labelText: 'Barang',
                                  ),
                                  items: _items
                                      .where(
                                        (i) => !_lines.any(
                                          (other) =>
                                              other != line &&
                                              other.item?.id == i.id,
                                        ),
                                      )
                                      .map(
                                        (i) => DropdownMenuItem(
                                          value: i.id,
                                          child: Text('${i.name} (${i.unit})'),
                                        ),
                                      )
                                      .toList(),
                                  validator: (v) =>
                                      v == null ? 'Pilih barang.' : null,
                                  onChanged: _busy || _uncertain
                                      ? null
                                      : (v) {
                                          line.item = _items.firstWhere(
                                            (i) => i.id == v,
                                          );
                                          _changed();
                                        },
                                ),
                                const SizedBox(height: 12),
                                _quantityRow(line),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_transfer)
                      OutlinedButton.icon(
                        onPressed: _busy || _uncertain || _lines.length >= 50
                            ? null
                            : () {
                                _lines.add(TransactionLine());
                                _changed();
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah barang'),
                      ),
                    const SizedBox(height: 16),
                    const SectionLabel('Catatan transaksi'),
                    TextFormField(
                      controller: _notes,
                      enabled: !_busy && !_uncertain,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: _adjustment
                            ? 'Keterangan wajib'
                            : 'Catatan (opsional)',
                      ),
                      onChanged: (_) => _changed(),
                      validator: (v) =>
                          (v ?? '').trim().runes.length > 500 ||
                              (_adjustment && (v ?? '').trim().isEmpty)
                          ? 'Isi maksimal 500 karakter. Alasan penyesuaian wajib diisi.'
                          : null,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_preview != null) ...[
                      const SizedBox(height: 16),
                      const SectionLabel('Pratinjau perubahan stok'),
                      ItemStockPreview(
                        changes: (_preview!['changes'] as List)
                            .cast<Map<String, dynamic>>(),
                      ),
                    ],
                    if (_uncertain)
                      SelectableText(
                        'Hasil belum diketahui. Jangan membuat transaksi baru. Coba ulang dengan key yang sama: $_key',
                      ),
                  ],
                ),
              ),
      ),
    ),
  );
}
