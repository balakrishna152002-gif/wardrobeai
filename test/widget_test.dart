import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wardrobe_ai/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WardrobeAiApp());

    expect(find.text('WardrobeAI'), findsOneWidget);
    expect(find.byIcon(Icons.checkroom), findsOneWidget);
  });
}
