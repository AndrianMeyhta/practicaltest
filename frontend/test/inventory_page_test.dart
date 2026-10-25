import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/screens/inventory_page.dart';

void main() {
  testWidgets('Memuat gudang dan saldo UPVC dari API', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/warehouses')) {
        return http.Response(
          '{"data":[{"id":1,"name":"Gudang Utama"}],"meta":{"total":1}}',
          200,
        );
      }
      expect(request.url.queryParameters['warehouse_id'], '1');
      return http.Response(
        '{"data":[{"item_id":1,"code":"UPVC-KSN-PTH-6M","name":"Profil Kusen UPVC Putih 6 Meter","unit":"batang","quantity":25}],"meta":{"total":1}}',
        200,
      );
    });
    await tester.pumpWidget(MaterialApp(home: InventoryPage(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('25 batang'), findsOneWidget);
    expect(find.text('Profil Kusen UPVC Putih 6 Meter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Gagal memuat menampilkan retry', (tester) async {
    final client = MockClient((_) async => http.Response('{}', 503));
    await tester.pumpWidget(MaterialApp(home: InventoryPage(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
