import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/master.dart';

class InventoryApiException implements Exception {
  const InventoryApiException(
    this.message, {
    this.fields = const {},
    this.requestId,
    this.uncertain = false,
  });
  final String message;
  final Map<String, String> fields;
  final String? requestId;
  final bool uncertain;
  @override
  String toString() =>
      requestId == null ? message : '$message\nID permintaan: $requestId';
}

class InventoryApi {
  InventoryApi({
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
  void close() => _client.close();

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final writing = method != 'GET';
    try {
      final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path')
          .replace(queryParameters: query);
      final request = http.Request(method, uri)
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        });
      if (body != null) request.body = jsonEncode(body);
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      if (response.statusCode == 204) return {};
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = json['error'] as Map<String, dynamic>?;
        final fields = <String, String>{};
        for (final detail in (error?['details'] as List? ?? [])) {
          if (detail is Map &&
              detail['field'] is String &&
              detail['message'] is String) {
            fields[detail['field'] as String] = detail['message'] as String;
          }
        }
        throw InventoryApiException(
          error?['message'] as String? ?? 'Permintaan gagal.',
          fields: fields,
          requestId: error?['request_id'] as String?,
          uncertain:
              writing &&
              response.statusCode >= 500 &&
              error?['code'] != 'TRANSACTION_RETRY_REQUIRED',
        );
      }
      return json;
    } on InventoryApiException {
      rethrow;
    } catch (_) {
      throw InventoryApiException(
        writing
            ? 'Hasil penyimpanan belum diketahui. Periksa daftar terbaru sebelum mengirim ulang.'
            : 'Data tidak dapat dimuat. Periksa koneksi lalu coba lagi.',
        uncertain: writing,
      );
    }
  }

  Future<MasterPageData> masters(
    String kind, {
    int page = 1,
    String search = '',
    bool? active,
  }) async {
    final result = await request(
      'GET',
      '/$kind',
      query: {
        'page': '$page',
        'limit': '20',
        if (kind == 'items') 'search': search,
        if (active != null) 'active': '$active',
      },
    );
    return MasterPageData(
      (result['data'] as List)
          .map((row) => Master.fromJson(row as Map<String, dynamic>))
          .toList(),
      (result['meta'] as Map)['total'] as int,
    );
  }

  Future<void> save(String kind, Map<String, dynamic> body, {int? id}) async {
    await request(
      id == null ? 'POST' : 'PATCH',
      '/$kind${id == null ? '' : '/$id'}',
      body: body,
    );
  }

  Future<void> remove(String kind, int id) async {
    await request('DELETE', '/$kind/$id');
  }

  Future<Map<int, int>> warehouseBalances(int warehouseId) async {
    final balances = <int, int>{};
    for (var page = 1; ; page++) {
      final result = await request(
        'GET',
        '/stocks',
        query: {
          'warehouse_id': '$warehouseId',
          'page': '$page',
          'limit': '100',
        },
      );
      final rows = result['data'] as List;
      for (final row in rows) {
        balances[row['item_id'] as int] = row['quantity'] as int;
      }
      if (page * 100 >= (result['meta'] as Map)['total']) return balances;
      if (rows.isEmpty) {
        throw const InventoryApiException(
          'Daftar saldo tidak lengkap. Muat ulang stok.',
        );
      }
    }
  }
}
