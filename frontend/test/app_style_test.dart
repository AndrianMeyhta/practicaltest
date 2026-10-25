import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/screens/inventory_page.dart';
import 'package:mutasi_stok/screens/masters_page.dart';
import 'package:mutasi_stok/screens/master_editor.dart';
import 'package:mutasi_stok/screens/stock_card_page.dart';
import 'package:mutasi_stok/screens/transaction_form.dart';
import 'package:mutasi_stok/screens/transaction_history.dart';
import 'package:mutasi_stok/services/inventory_api.dart';
import 'package:mutasi_stok/widgets/app_style.dart';
import 'package:mutasi_stok/widgets/connection_status.dart';

http.Response response(Object data) => http.Response(jsonEncode(data), 200);

void main() {
  test('Tema memakai palet dashboard pada seluruh komponen utama', () {
    final theme = inventoryTheme();
    expect(theme.scaffoldBackgroundColor, canvas);
    expect(theme.appBarTheme.backgroundColor, forest);
    expect(theme.appBarTheme.foregroundColor, Colors.white);
    expect(theme.colorScheme.secondary, leaf);
    expect(theme.cardTheme.color, Colors.white);
  });

  testWidgets(
    'Semua halaman bertema dapat digulir pada layar kecil dan teks besar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/stocks')) {
          return response({
            'data': [
              {
                'item_id': 1,
                'code': 'UPVC-P',
                'name': 'Profil Kusen UPVC Putih 6 Meter',
                'unit': 'batang',
                'quantity': 25,
              },
            ],
            'meta': {'total': 1},
          });
        }
        if (path.endsWith('/stock-card')) {
          return response({
            'balance': 25,
            'data': [],
            'meta': {'total': 0},
          });
        }
        if (path.endsWith('/history')) {
          return response({
            'data': [],
            'meta': {'total': 0},
          });
        }
        if (path.endsWith('/opening-stocks/1')) {
          return response({
            'data': {
              'opening_number': 'AWL-20261025-1',
              'created_at': '2026-10-25T01:00:00Z',
              'warehouse_name': 'Gudang Utama',
              'item_name': 'Profil Kusen UPVC',
              'item_code': 'UPVC-P',
              'item_unit': 'batang',
              'quantity': 25,
              'balance_before': 0,
              'balance_after': 25,
              'notes': '',
            },
          });
        }
        final items = path.endsWith('/items');
        return response({
          'data': [
            {
              'id': 1,
              'code': items ? 'UPVC-P' : 'GD-U',
              'name': items
                  ? 'Profil Kusen UPVC Putih 6 Meter'
                  : 'Gudang Utama',
              if (items) 'unit': 'batang',
              'is_active': true,
            },
          ],
          'meta': {'total': 1},
        });
      });
      final api = InventoryApi(client: client);
      addTearDown(api.close);
      final pages = <Widget>[
        InventoryPage(client: client),
        MastersPage(kind: 'items', api: api),
        MastersPage(kind: 'warehouses', api: api),
        MasterEditor(kind: 'items', api: api),
        StockCardPage(
          api: api,
          warehouseId: 1,
          itemId: 1,
          title: 'Profil Kusen UPVC (batang)',
        ),
        for (final kind in ['opening-stocks', 'transfers', 'adjustments'])
          TransactionForm(kind: kind, api: api),
        TransactionDetail(api: api, kind: 'opening-stocks', id: 1),
        Scaffold(
          body: SingleChildScrollView(
            child: ConnectionStatus(checkHealth: () async {}),
          ),
        ),
      ];
      for (var i = 0; i < pages.length; i++) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(i),
            theme: inventoryTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: pages[i],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Halaman ${pages[i].runtimeType}',
        );
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          for (var scroll = 0; scroll < 4; scroll++) {
            await tester.drag(scrollable.first, const Offset(0, -400));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Gulir halaman ${pages[i].runtimeType}',
            );
          }
        }
      }
    },
  );
}
