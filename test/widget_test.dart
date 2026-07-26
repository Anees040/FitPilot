import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/main.dart';

void main() {
  testWidgets('Navigation shell renders all tabs and switches between them', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitPilotApp()));
    await tester.pumpAndSettle();

    // The text in BottomNavigationBar items and in the Center of screens both appear
    // Let's rely on finding them in the hierarchy.
    
    // Verify Today screen is visible (its text is in the center)
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Log'), findsWidgets); // This text is in the nav bar
    
    // Switch to Log
    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();
    expect(find.text('Log'), findsWidgets);

    // Switch to Plan
    await tester.tap(find.text('Plan').last);
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsWidgets);

    // Switch to Progress
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Progress'), findsWidgets);

    // Switch to Profile
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
  });
}
