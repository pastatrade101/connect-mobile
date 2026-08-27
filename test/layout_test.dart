// Home's rows have to survive a 375pt phone with long, real content in them.
//
// A widget test is the honest way to check this: Flutter reports an overflow as a
// test failure, so "it fits" is a fact rather than a look at one screenshot.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makutano_connect/core/theme.dart';
import 'package:makutano_connect/widgets/primitives.dart';

const widths = <double>[375, 390, 430]; // iPhone SE · iPhone 14 · Pro Max

Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(brightness: Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in widths) {
    group('${width.toInt()}pt', () {
      testWidgets('an attention row carries a long reason and a big count', (tester) async {
        await pumpAt(
          tester,
          width,
          GroupedList(
            children: [
              AttentionRow(
                item: const {
                  'key': 'payments_reported',
                  'title': 'Payment needs verification',
                  'detail': '12 customers',
                  'label': "12 customers say they've paid",
                  'count': 128,
                  'urgency': 'critical',
                  'scope': 'mine',
                },
                onTap: () {},
              ),
              AttentionRow(
                item: const {
                  'key': 'quotes_waiting',
                  'title': 'Waiting for the customer to answer a quotation we sent',
                  'detail': '3 quotations',
                  'count': 3,
                  'urgency': 'normal',
                  'scope': 'business',
                },
                onTap: () {},
              ),
            ],
          ),
        );
        expect(find.text('128'), findsOneWidget);
        expect(find.text('12 customers'), findsOneWidget);
      });

      testWidgets('a continue row carries a long customer name and money', (tester) async {
        await pumpAt(
          tester,
          width,
          GroupedList(
            children: [
              ContinueRow(
                item: const {
                  'customer': 'Kilimanjaro Expeditions & Safari Company Limited',
                  'state': 'Booking · Customer says they’ve paid',
                  'detail': 'TZS 12,450,000 outstanding',
                  'kind': 'booking',
                  'conversationId': 'x',
                },
                onTap: () {},
              ),
              ContinueRow(
                item: const {
                  'customer': '+255629142552',
                  'state': 'New WhatsApp conversation',
                  'detail': 'No enquiry yet',
                  'kind': 'conversation',
                },
                onTap: () {},
              ),
            ],
          ),
        );
        expect(find.textContaining('TZS 12,450,000'), findsOneWidget);
      });

      testWidgets('today’s card holds three stats and a big amount', (tester) async {
        await pumpAt(
          tester,
          width,
          const TodayCard(
            currency: 'TZS',
            tiles: [
              {'label': 'New chats today', 'value': '128', 'kind': 'count'},
              {'label': 'Enquiries today', 'value': '64', 'kind': 'count'},
              {'label': 'Received today', 'value': '12450000.00', 'kind': 'money'},
            ],
          ),
        );
        expect(find.text('Chats'), findsOneWidget);
        expect(find.text('TZS'), findsOneWidget);
        // Whole units, grouped — never a bare "12450000.00".
        expect(find.text('12,450,000'), findsOneWidget);
      });

      testWidgets('the header fits a greeting, a bell and an avatar on one row', (tester) async {
        await pumpAt(
          tester,
          width,
          MobileHeader(
            title: 'Good afternoon, Emmanuel',
            subtitle: 'Kilimanjaro Expeditions & Safari Company · 4 for you',
            initials: 'EM',
            alerts: 128,
            onAlerts: () {},
          ),
        );
        expect(find.text('EM'), findsOneWidget);
        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('the whole header stays under 60pt tall', (tester) async {
        await pumpAt(
          tester,
          width,
          MobileHeader(
            title: 'Good afternoon, Emmanuel',
            subtitle: 'Kilimanjaro Expeditions & Safari Company · 4 for you',
            initials: 'EM',
            alerts: 3,
            onAlerts: () {},
          ),
        );
        // Two lines of text plus the controls. Anything taller and the first thing
        // that needs doing drops below the fold on a small phone.
        expect(tester.getSize(find.byType(MobileHeader)).height, lessThan(60));
      });
    });
  }
}
