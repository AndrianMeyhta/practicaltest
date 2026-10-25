import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutasi_stok/widgets/stock_movement.dart';

void main() {
  testWidgets('Preview mengelompokkan barang dan mendahulukan gudang keluar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemStockPreview(
            changes: [
              {
                'item_id': 1,
                'item_name': 'Engsel',
                'warehouse_name': 'Tujuan',
                'quantity_in': 10,
                'quantity_out': 0,
                'unit': 'pcs',
              },
              {
                'item_id': 1,
                'item_name': 'Engsel',
                'warehouse_name': 'Asal',
                'quantity_in': 0,
                'quantity_out': 10,
                'unit': 'pcs',
              },
            ],
          ),
        ),
      ),
    );
    expect(find.text('Engsel'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Asal')).dy,
      lessThan(tester.getTopLeft(find.text('Tujuan')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
