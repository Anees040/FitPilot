import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/application/providers/machine_scanner_provider.dart';
import 'package:fitpilot/application/providers/network_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';
import 'package:fitpilot/domain/entities/machine_scan.dart';
import 'package:fitpilot/features/exercises/presentation/machine_scanner_screen.dart';

MachineScan _scan(String id, String name, {Duration age = Duration.zero}) {
  return MachineScan(
    id: id,
    machineName: name,
    analysis: MachineAnalysis(
      isGymMachine: true,
      machineName: name,
      confidence: 0.9,
      primaryMuscles: const ['Back'],
      howToUse: const ['Sit down', 'Pull'],
    ),
    createdAt: DateTime.now().subtract(age),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  List<MachineScan> scans = const [],
  bool isOnline = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recentMachineScansProvider.overrideWith((ref) async => scans),
        isOnlineProvider.overrideWith((ref) => Stream.value(isOnline)),
      ],
      child: MaterialApp(
        theme: AppTheme.getDarkTheme(),
        home: const MachineScannerScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers the scan action and explains what it does', (tester) async {
    await _pump(tester);

    expect(find.text('Machine Scanner'), findsOneWidget);
    expect(find.text('Scan a machine'), findsOneWidget);
    expect(
      find.text('Point your camera at any gym machine to learn it'),
      findsOneWidget,
    );
  });

  testWidgets('an empty history explains itself instead of showing a blank list', (
    tester,
  ) async {
    await _pump(tester, scans: const []);

    expect(find.text('No scans yet'), findsOneWidget);
    expect(find.textContaining('saved here for later'), findsOneWidget);
  });

  testWidgets('saved scans are listed with their muscles and age', (tester) async {
    await _pump(
      tester,
      scans: [
        _scan('1', 'Lat Pulldown Machine'),
        _scan('2', 'Leg Press', age: const Duration(hours: 3)),
      ],
    );

    expect(find.text('Lat Pulldown Machine'), findsOneWidget);
    expect(find.text('Leg Press'), findsOneWidget);
    expect(find.text('2 saved'), findsOneWidget);
    expect(find.textContaining('3h ago'), findsOneWidget);
    expect(find.text('No scans yet'), findsNothing);
  });

  testWidgets('offline still shows saved scans and says why scanning is blocked', (
    tester,
  ) async {
    await _pump(
      tester,
      scans: [_scan('1', 'Lat Pulldown Machine')],
      isOnline: false,
    );

    // The whole point of this screen: history stays readable with no network.
    expect(find.text('Lat Pulldown Machine'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets('online shows the capability hint rather than an offline warning', (
    tester,
  ) async {
    await _pump(tester, isOnline: true);

    expect(find.textContaining("You're offline"), findsNothing);
    expect(find.textContaining('muscles worked'), findsOneWidget);
  });
}
