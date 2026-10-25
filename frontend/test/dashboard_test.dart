import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/screens/home_shell.dart';
import 'package:mutasi_stok/services/inventory_api.dart';

Map<String, dynamic> summary({bool empty = false}) => {
  'data': {
    'items': empty ? 0 : 12,
    'warehouses': empty ? 0 : 3,
    'units': empty
        ? []
        : [
            {'quantity': 120, 'unit': 'batang'},
            {'quantity': 45, 'unit': 'pcs'},
          ],
  },
};

void main() {
  testWidgets('Ringkasan hanya menampilkan jumlah jenis barang dan gudang', (
    tester,
  ) async {
    final api = InventoryApi(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/dashboard');
        return http.Response(jsonEncode(summary()), 200);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardSummary(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jenis barang aktif'), findsOneWidget);
    expect(find.text('Gudang aktif'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Total stok semua gudang'), findsNothing);
    expect(find.text('Gabungan stok dari seluruh gudang'), findsNothing);
    expect(find.text('120\nbatang'), findsNothing);
    expect(find.text('45\npcs'), findsNothing);
    expect(find.text('165'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menampilkan loading, gagal, lalu mencoba ulang', (tester) async {
    final response = Completer<http.Response>();
    var calls = 0;
    final api = InventoryApi(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return response.future;
        return http.Response(jsonEncode(summary()), 200);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardSummary(api: api)),
      ),
    );
    expect(find.text('Memuat ringkasan stok...'), findsOneWidget);
    response.complete(http.Response('{}', 503));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan stok belum bisa dimuat.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Data kosong tidak ditampilkan sebagai data gagal', (
    tester,
  ) async {
    final api = InventoryApi(
      client: MockClient(
        (_) async => http.Response(jsonEncode(summary(empty: true)), 200),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardSummary(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Total stok semua gudang'), findsNothing);
    expect(find.text('Coba lagi'), findsNothing);
  });

  testWidgets('Dashboard sempit dan teks besar tetap terbaca', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = InventoryApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/dashboard')) {
          return http.Response(jsonEncode(summary()), 200);
        }
        expect(request.url.queryParameters['limit'], '5');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 1,
                'kind': 'adjustments',
                'number': 'ADJ-20261025-001',
                'location': 'Gudang Utama Penyimpanan Profil',
                'created_at': '2026-10-25T01:00:00Z',
                'item_count': 2,
                'notes': '',
              },
            ],
            'meta': {'total': 1},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: HomeShell(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Lihat rincian'), 200);
    expect(find.text('Penyesuaian stok'), findsOneWidget);
    expect(find.text('2 jenis barang'), findsOneWidget);
    expect(find.text('Aktivitas terbaru'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
