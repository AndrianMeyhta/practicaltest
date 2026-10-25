import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
}

class HealthApi {
  HealthApi({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://10.0.2.2:3000/api/v1',
           );

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  Future<void> check() async {
    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/health',
      );
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ApiException('URL backend tidak valid.');
      }
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode == 503) {
        throw const ApiException(
          'Backend terhubung, tetapi database belum tersedia.',
        );
      }
      if (response.statusCode != 200) {
        throw ApiException('Pemeriksaan gagal (HTTP ${response.statusCode}).');
      }
      final body = jsonDecode(response.body);
      if (body is! Map ||
          body['data'] is! Map ||
          body['data']['status'] != 'ok' ||
          body['data']['database'] != 'connected') {
        throw const ApiException('Respons backend tidak sesuai.');
      }
    } on TimeoutException {
      throw const ApiException('Koneksi terlalu lama. Silakan coba lagi.');
    } on http.ClientException {
      throw const ApiException(
        'Backend tidak dapat dijangkau. Periksa koneksi dan alamat server.',
      );
    } on FormatException {
      throw const ApiException('Alamat atau respons backend tidak valid.');
    }
  }

  void close() => _client.close();
}
