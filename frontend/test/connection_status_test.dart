import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutasi_stok/services/health_api.dart';
import 'package:mutasi_stok/widgets/connection_status.dart';

void main() {
  testWidgets('Loading, gagal, lalu retry berhasil', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConnectionStatus(
            checkHealth: () {
              calls++;
              return calls == 1 ? pending.future : Future.value();
            },
          ),
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.completeError(const ApiException('Database belum tersedia.'));
    await tester.pumpAndSettle();
    expect(find.text('Database belum tersedia.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Backend dan MySQL terhubung.'), findsOneWidget);
    expect(calls, 2);
  });
}
