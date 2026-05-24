import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resilimesh/main.dart';

void main() {
  testWidgets('Vanguard app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const VanguardApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
