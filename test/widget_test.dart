import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/main.dart';

void main() {
  testWidgets('GymTracker startet', (WidgetTester tester) async {
    await tester.pumpWidget(const GymTrackerApp());

    expect(find.text('Meine Übungen'), findsOneWidget);
  });
}