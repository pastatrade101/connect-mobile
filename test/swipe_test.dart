import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makutano_connect/widgets/swipe_to_delete.dart';

void main() {
  Widget host({bool enabled = true, VoidCallback? onDelete}) => MaterialApp(
    home: Scaffold(
      body: SwipeToDelete(
        enabled: enabled,
        onDelete: onDelete ?? () {},
        // A transparent row, exactly as WorkRow is: GroupedList paints the card,
        // not the row. This is the condition that made the first version wrong.
        child: const SizedBox(height: 60, width: double.infinity, child: Text('A booking')),
      ),
    ),
  );

  testWidgets('shows nothing but the row until it is swiped', (tester) async {
    // The red sat behind every row at rest, showing through the transparent
    // child. On a list of ten that read as ten red stripes.
    await tester.pumpWidget(host());
    expect(find.text('A booking'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('reveals delete on a left swipe, and calls it once tapped', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(host(onDelete: () => deleted++));

    await tester.drag(find.text('A booking'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);

    // Revealing is not deleting: it takes a second, deliberate tap.
    expect(deleted, 0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('a right swipe reveals nothing', (tester) async {
    await tester.pumpWidget(host());
    await tester.drag(find.text('A booking'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('is inert where deletion is not offered', (tester) async {
    await tester.pumpWidget(host(enabled: false));
    await tester.drag(find.text('A booking'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
  });
}
