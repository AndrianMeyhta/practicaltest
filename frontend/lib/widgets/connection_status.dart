import 'package:flutter/material.dart';

import '../services/health_api.dart';

class ConnectionStatus extends StatefulWidget {
  const ConnectionStatus({super.key, this.checkHealth});
  final Future<void> Function()? checkHealth;

  @override
  State<ConnectionStatus> createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends State<ConnectionStatus> {
  late final HealthApi _api;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = HealthApi();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await (widget.checkHealth ?? _api.check)();
    } on ApiException catch (error) {
      if (mounted) _error = error.message;
    } catch (_) {
      if (mounted) _error = 'Koneksi gagal diperiksa. Silakan coba lagi.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koneksi sistem',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Memeriksa backend dan database...'),
            ] else ...[
              Icon(
                _error == null
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
              ),
              const SizedBox(height: 8),
              Text(_error ?? 'Backend dan MySQL terhubung.'),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _check,
              icon: const Icon(Icons.refresh),
              label: Text(_error == null ? 'Periksa ulang' : 'Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
