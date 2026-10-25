import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mutasi_stok/models/master.dart';
import 'package:mutasi_stok/screens/master_editor.dart';
import 'package:mutasi_stok/screens/masters_page.dart';
import 'package:mutasi_stok/services/inventory_api.dart';

void main() {
  testWidgets('Form validasi, loading, error field dan isian tetap tersimpan', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final api = InventoryApi(
      client: MockClient((request) {
        expect(jsonDecode(request.body)['code'], 'ABC');
        return pending.future;
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MasterEditor(api: api, kind: 'items'),
      ),
    );
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Isi 1–30 karakter setelah trim.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'abc');
    await tester.enterText(find.byType(TextFormField).at(1), 'Barang uji');
    await tester.enterText(find.byType(TextFormField).at(2), 'pcs');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete(
      http.Response(
        jsonEncode({
          'error': {
            'message': 'Kode sudah digunakan.',
            'details': [
              {'field': 'code', 'message': 'Gunakan kode lain.'},
            ],
          },
        }),
        409,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gunakan kode lain.'), findsOneWidget);
    expect(find.text('Barang uji'), findsOneWidget);
  });

  testWidgets('Retry daftar lalu create, edit dan hapus memuat ulang API', (
    tester,
  ) async {
    var failed = true;
    final rows = <Map<String, dynamic>>[];
    final api = InventoryApi(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          if (failed) {
            failed = false;
            return http.Response('{"error":{"message":"Gagal"}}', 503);
          }
          return http.Response(
            jsonEncode({
              'data': rows,
              'meta': {'total': rows.length},
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          rows.add({
            'id': 1,
            ...jsonDecode(request.body) as Map<String, dynamic>,
          });
        }
        if (request.method == 'PATCH') {
          rows[0].addAll(jsonDecode(request.body) as Map<String, dynamic>);
        }
        if (request.method == 'DELETE') {
          rows.clear();
          return http.Response('', 204);
        }
        return http.Response(
          '{"data":{}}',
          request.method == 'POST' ? 201 : 200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MastersPage(kind: 'warehouses', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'GD-UJI');
    await tester.enterText(find.byType(TextFormField).at(1), 'Gudang Uji');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Gudang Uji'), findsOneWidget);
    await tester.tap(find.text('Gudang Uji'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).readOnly,
      isTrue,
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Gudang Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gudang Baru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus bersyarat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(rows, isEmpty);
    expect(find.text('Belum ada data yang sesuai.'), findsOneWidget);
  });

  testWidgets('Editor layar kecil dan teks besar dapat digulir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = InventoryApi();
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: MasterEditor(
          api: api,
          kind: 'items',
          master: const Master(
            id: 1,
            code: 'UPVC',
            name: 'Profil panjang',
            active: true,
            unit: 'batang',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'Timeout tulis dianggap belum diketahui dan tidak retry otomatis',
    () async {
      var calls = 0;
      final api = InventoryApi(
        timeout: const Duration(milliseconds: 5),
        client: MockClient((_) {
          calls++;
          return Completer<http.Response>().future;
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.save('items', {}),
        throwsA(
          isA<InventoryApiException>().having(
            (e) => e.uncertain,
            'uncertain',
            true,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
}
