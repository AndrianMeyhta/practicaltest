import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/services/health_api.dart';

void main() {
  test('Health memanggil URL konfigurasi dan membaca respons', () async {
    final api = HealthApi(
      baseUrl: 'http://localhost:3000/api/v1/',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/health');
        return http.Response(
          '{"data":{"status":"ok","database":"connected"}}',
          200,
        );
      }),
    );
    addTearDown(api.close);
    await api.check();
  });
  for (final status in [503, 404, 500, 200]) {
    test('Menolak respons gagal atau JSON tidak valid: $status', () async {
      final api = HealthApi(
        client: MockClient((_) async => http.Response('invalid', status)),
      );
      addTearDown(api.close);
      await expectLater(api.check(), throwsA(isA<ApiException>()));
    });
  }
  test('Timeout berakhir dengan pesan aman', () async {
    final api = HealthApi(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(api.close);
    await expectLater(api.check(), throwsA(isA<ApiException>()));
  });
  test('Koneksi gagal dipetakan ke error aplikasi', () async {
    final api = HealthApi(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(api.close);
    await expectLater(api.check(), throwsA(isA<ApiException>()));
  });
}
