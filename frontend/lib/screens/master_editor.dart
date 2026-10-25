import 'package:flutter/material.dart';

import '../models/master.dart';
import '../services/inventory_api.dart';
import '../widgets/app_style.dart';

class MasterEditor extends StatefulWidget {
  const MasterEditor({
    super.key,
    required this.api,
    required this.kind,
    this.master,
  });
  final InventoryApi api;
  final String kind;
  final Master? master;
  @override
  State<MasterEditor> createState() => _MasterEditorState();
}

class _MasterEditorState extends State<MasterEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code, _name, _unit;
  bool _active = true, _busy = false, _uncertain = false;
  InventoryApiException? _error;
  bool get _items => widget.kind == 'items';

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.master?.code ?? '');
    _name = TextEditingController(text: widget.master?.name ?? '');
    _unit = TextEditingController(text: widget.master?.unit ?? '');
    _active = widget.master?.active ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _save({bool remove = false}) async {
    if (_busy || _uncertain) return;
    if (!remove && !_form.currentState!.validate()) return;
    if (remove &&
        !await _confirm(
          'Hapus master?',
          'Hanya master tanpa histori dan tanpa stok yang dapat dihapus. Tindakan ini tidak dapat dibatalkan.',
        )) {
      return;
    }
    if (!remove &&
        widget.master?.active == true &&
        !_active &&
        !await _confirm(
          'Nonaktifkan master?',
          'Master hanya dapat dinonaktifkan jika seluruh saldo nol. Histori tetap tersimpan.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (remove) {
        await widget.api.remove(widget.kind, widget.master!.id);
      } else {
        await widget.api.save(widget.kind, {
          if (widget.master == null) 'code': _code.text.trim().toUpperCase(),
          'name': _name.text.trim(),
          'is_active': _active,
          if (_items && widget.master == null) 'unit': _unit.text.trim(),
        }, id: widget.master?.id);
      }
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context, true);
      }
    } on InventoryApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _uncertain = error.uncertain;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value, int max) {
    final size = (value ?? '').trim().runes.length;
    return size < 1 || size > max ? 'Isi 1–$max karakter setelah trim.' : null;
  }

  Widget _field(
    String label,
    String key,
    TextEditingController controller,
    int max, {
    bool immutable = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      readOnly: immutable,
      enabled: !_busy,
      decoration: InputDecoration(
        labelText: label,
        filled: immutable,
        fillColor: immutable ? const Color(0xFFDEE3E1) : null,
        suffixIcon: immutable ? const Icon(Icons.lock_outline) : null,
        errorText: _error?.fields[key],
        helperText: immutable ? 'Tidak dapat diubah setelah dibuat.' : null,
      ),
      validator: (value) {
        final required = _required(value, max);
        if (required != null) return required;
        if (key == 'code' &&
            !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value!.trim())) {
          return 'Gunakan huruf ASCII, angka, _ atau -.';
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.master == null ? 'Tambah' : 'Ubah'} ${_items ? 'barang' : 'gudang'}',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PageHeading(
                eyebrow: 'Data / ${_items ? 'Barang' : 'Gudang'}',
                title: widget.master == null ? 'Data baru' : 'Ubah data',
                description: widget.master == null
                    ? 'Lengkapi informasi sebelum menyimpan.'
                    : 'Kode${_items ? ' dan satuan' : ''} tetap; nama dan status dapat diubah.',
              ),
              _field(
                'Kode',
                'code',
                _code,
                30,
                immutable: widget.master != null,
              ),
              _field('Nama', 'name', _name, 100),
              if (_items)
                _field(
                  'Satuan',
                  'unit',
                  _unit,
                  20,
                  immutable: widget.master != null,
                ),
              Card(
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(_active ? 'Aktif' : 'Nonaktif'),
                  subtitle: const Text(
                    'Penonaktifan hanya jika seluruh saldo nol.',
                  ),
                  value: _active,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _active = value),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_uncertain) ...[
                const Text(
                  'Jangan kirim ulang sebelum memeriksa data terbaru. Isian tetap tersedia selama halaman ini terbuka.',
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Kembali dan periksa daftar'),
                ),
              ],
              FilledButton(
                onPressed: _busy || _uncertain ? null : _save,
                child: Text(_busy ? 'Memproses…' : 'Simpan'),
              ),
              if (widget.master != null)
                TextButton(
                  onPressed: _busy || _uncertain
                      ? null
                      : () => _save(remove: true),
                  child: const Text('Hapus bersyarat'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
