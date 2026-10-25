import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutasi_stok/app.dart';

void main() {
  testWidgets('Menampilkan identitas dan status aplikasi', (tester) async {
    await tester.pumpWidget(const MutasiStokApp());
    expect(find.text('Mutasi Stok'), findsOneWidget);
    expect(find.text('Persediaan antar gudang'), findsOneWidget);
    expect(find.textContaining('belum tersedia'), findsOneWidget);
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
        home: const WelcomePage(),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
