import 'dart:async';

import 'package:flutter/material.dart';

import '../models/master.dart';
import '../services/inventory_api.dart';
import 'master_editor.dart';

class MastersPage extends StatefulWidget {
  const MastersPage({super.key, required this.kind, this.api});
  final String kind;
  final InventoryApi? api;
  @override
  State<MastersPage> createState() => _MastersPageState();
}

class _MastersPageState extends State<MastersPage> {
  late final InventoryApi _api;
  MasterPageData? _data;
  Object? _error;
  bool _loading = true;
  int _page = 1, _generation = 0;
  String _search = '';
  bool? _active;
  Timer? _debounce;
  bool get _items => widget.kind == 'items';
  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InventoryApi();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.masters(
        widget.kind,
        page: _page,
        search: _search,
        active: _active,
      );
      if (!mounted || generation != _generation) return;
      if (_page > 1 && data.rows.isEmpty) {
        _page--;
        await _load();
        return;
      }
      setState(() => _data = data);
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([Master? master]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MasterEditor(api: _api, kind: widget.kind, master: master),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_items ? 'Master barang' : 'Master gudang')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Tambah'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (_items)
            TextField(
              decoration: const InputDecoration(
                labelText: 'Cari kode atau nama',
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _generation++;
                setState(() => _loading = true);
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _search = value.trim();
                  _page = 1;
                  _load();
                });
              },
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: 'all',
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Semua')),
              DropdownMenuItem(value: 'true', child: Text('Aktif')),
              DropdownMenuItem(value: 'false', child: Text('Nonaktif')),
            ],
            onChanged: (value) {
              _active = value == 'all' ? null : value == 'true';
              _page = 1;
              _load();
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(_error.toString()),
            OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
          ] else ...[
            if (_data!.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada data yang sesuai.'),
              ),
            for (final master in _data!.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      child: Icon(
                        _items
                            ? Icons.inventory_2_outlined
                            : Icons.warehouse_outlined,
                      ),
                    ),
                    title: Text(master.name),
                    subtitle: Text(
                      '${master.code} • ${master.unit ?? 'Gudang'} • ${master.active ? 'Aktif' : 'Nonaktif'}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(master),
                  ),
                ),
              ),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Halaman sebelumnya',
                onPressed: _loading || _page == 1
                    ? null
                    : () {
                        _page--;
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Hal. $_page • ${_data?.total ?? 0} data'),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Halaman berikutnya',
                onPressed: _loading || _page * 20 >= (_data?.total ?? 0)
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
      ),
    ),
  );
}
