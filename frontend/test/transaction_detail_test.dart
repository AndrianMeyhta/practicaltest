import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/screens/transaction_history.dart';
import 'package:mutasi_stok/services/inventory_api.dart';
import 'package:mutasi_stok/widgets/stock_movement.dart';

void main() {
  testWidgets(
    'Bukti dikelompokkan per gudang dengan warna dan rincian historis',
    (tester) async {
      final api = InventoryApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {
                'transfer_number': 'MUT-20261025-1',
                'created_at': '2026-10-25T01:00:00Z',
                'source_warehouse_name': 'Utama',
                'destination_warehouse_name': 'Cabang',
                'notes': 'Pengisian cabang',
                'items': [
                  {
                    'item_name': 'Profil',
                    'item_code': 'P',
                    'item_unit': 'batang',
                    'quantity': 10,
                    'source_stock_before': 25,
                    'source_stock_after': 15,
                    'destination_stock_before': 3,
                    'destination_stock_after': 13,
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: TransactionDetail(api: api, kind: 'transfers', id: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WarehouseMovementCard), findsNWidgets(2));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.north_east_rounded)).color,
        const Color(0xFFFF8A80),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.south_west_rounded)).color,
        const Color(0xFFB8D875),
      );
      expect(find.text('−10 batang'), findsOneWidget);
      expect(find.text('+10 batang'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('−10 batang')).style!.color,
        stockOutColor,
      );
      expect(
        tester.widget<Text>(find.text('+10 batang')).style!.color,
        stockInColor,
      );
      await tester.scrollUntilVisible(
        find.text('Rincian saldo saat transaksi'),
        200,
      );
      await tester.tap(find.text('Rincian saldo saat transaksi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Utama: 25 → 15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Baris pergerakan pada layar sempit dan teks besar tidak overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: WarehouseMovementCard(
                    warehouse: 'Gudang Utama Penyimpanan Profil',
                    incoming: true,
                    rows: [
                      StockMovementRow(
                        title: 'Profil Kusen UPVC Putih 6 Meter',
                        quantity: 1000000,
                        unit: 'batang',
                        incoming: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
