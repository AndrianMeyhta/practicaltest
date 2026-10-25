import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/screens/transaction_form.dart';
import 'package:mutasi_stok/services/inventory_api.dart';

void main() {
  testWidgets(
    'Balancing wajib alasan, preview dan invalidasi saat jumlah berubah',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var previews = 0;
      final api = InventoryApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/preview')) {
            previews++;
            expect(jsonDecode(request.body)['notes'], 'Reject');
            return http.Response(
              jsonEncode({
                'data': {
                  'changes': [
                    {
                      'item_name': 'Engsel',
                      'warehouse_name': 'Utama',
                      'unit': 'pcs',
                      'balance_before': 10,
                      'balance_after': 11,
                      'quantity_in': 1,
                      'quantity_out': 0,
                    },
                  ],
                },
              }),
              200,
            );
          }
          final item = request.url.path.endsWith('/items');
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 1,
                  'code': item ? 'ENG' : 'GD',
                  'name': item ? 'Engsel' : 'Utama',
                  if (item) 'unit': 'pcs',
                  'is_active': true,
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
          home: TransactionForm(kind: 'adjustments', api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Utama').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engsel (pcs)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Periksa preview stok'));
      await tester.tap(find.text('Periksa preview stok'));
      await tester.pumpAndSettle();
      expect(previews, 0);
      await tester.enterText(find.byType(TextFormField).last, 'Reject');
      await tester.ensureVisible(find.text('Periksa preview stok'));
      await tester.tap(find.text('Periksa preview stok'));
      await tester.pumpAndSettle();
      expect(previews, 1);
      await tester.ensureVisible(find.byType(FilledButton));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.enterText(find.byType(TextFormField).first, '2');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
