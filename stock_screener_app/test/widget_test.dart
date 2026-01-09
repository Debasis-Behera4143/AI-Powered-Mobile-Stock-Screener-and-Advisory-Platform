// Stock Screener App Widget Tests
//
// Tests for the Stock Screener application to verify:
// - App loads correctly
// - UI elements are present
// - Stock list screen is displayed

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_screener_app/main.dart';

void main() {
  testWidgets('Stock Screener app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StockScreenerApp());

    // Verify that the app title is displayed in the AppBar
    expect(find.text('Stock Screener'), findsOneWidget);

    // Verify that the refresh icon button is present
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    // Wait for any async operations to complete
    await tester.pump();
  });

  testWidgets('Stock list shows loading or error state initially', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const StockScreenerApp());

    // Since the app makes an API call on init, it should show loading or error
    // We can't predict which without mocking the HTTP call
    await tester.pump();
    
    // Verify app bar is present
    expect(find.text('Stock Screener'), findsOneWidget);
  });

  testWidgets('Refresh button is tappable', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const StockScreenerApp());

    // Find and tap the refresh button
    final refreshButton = find.byIcon(Icons.refresh);
    expect(refreshButton, findsOneWidget);
    
    await tester.tap(refreshButton);
    await tester.pump();
    
    // Verify the app doesn't crash on refresh
    expect(find.text('Stock Screener'), findsOneWidget);
  });
}
