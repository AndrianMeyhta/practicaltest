import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/screens/transaction_form.dart';
import 'package:mutasi_stok/services/inventory_api.dart';

void main() {
  testWidgets('Gudang berbeda, saldo tersedia, barang unik dan ikon hapus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = InventoryApi(
      client: MockClient((request) async {
        final path = request.url.path;
        final rows = path.endsWith('/stocks')
            ? [
                {'item_id': 1, 'quantity': 25},
                {'item_id': 2, 'quantity': 0},
              ]
            : path.endsWith('/warehouses')
            ? [
                {'id': 1, 'code': 'A', 'name': 'Utama', 'is_active': true},
                {'id': 2, 'code': 'B', 'name': 'Cabang', 'is_active': true},
              ]
            : [
                {
                  'id': 1,
                  'code': 'P',
                  'name': 'Profil',
                  'unit': 'batang',
                  'is_active': true,
                },
                {
                  'id': 2,
                  'code': 'E',
                  'name': 'Engsel',
                  'unit': 'pcs',
                  'is_active': true,
                },
              ];
        return http.Response(
          jsonEncode({
            'data': rows,
            'meta': {'total': rows.length},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionForm(kind: 'transfers', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utama').last);
    await tester.pumpAndSettle();
    final destination = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>).at(1),
    );
    // Periksa pilihan melalui dropdown turunannya, bukan hanya validasi submit.
    final dropdown = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: find.byWidget(destination),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    expect(dropdown.items!.map((i) => i.value), [2]);
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil (batang)').last);
    await tester.pumpAndSettle();
    expect(find.text('25 batang'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.text('Tambah barang'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Engsel (pcs)').last);
    await tester.pumpAndSettle();
    expect(find.text('0 pcs'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus barang 1'));
    await tester.pumpAndSettle();
    expect(find.text('0 pcs'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
