import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutasi_stok/app.dart';

void main() {
  testWidgets('Menampilkan identitas dan status aplikasi', (tester) async {
    await tester.pumpWidget(MutasiStokApp(checkHealth: () async {}));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Persediaan antar gudang'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('mutasi stock'), findsOneWidget);
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Backend dan MySQL terhubung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Layar kecil dengan teks besar tidak overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: WelcomePage(checkHealth: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
