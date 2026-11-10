import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/presentation/widgets/common.dart';

void main() {
  testWidgets('SeverityBadge renders its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SeverityBadge(level: AlertLevel.danger)),
        ),
      ),
    );
    expect(find.text('DANGER'), findsOneWidget);
  });

  testWidgets('StatCard renders label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Active alerts',
            value: '12',
            icon: Icons.crisis_alert,
          ),
        ),
      ),
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Active alerts'), findsOneWidget);
  });

  testWidgets('EmptyState renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.shield_outlined,
            title: 'No alerts',
            subtitle: 'All clear',
          ),
        ),
      ),
    );
    expect(find.text('No alerts'), findsOneWidget);
    expect(find.text('All clear'), findsOneWidget);
  });

  testWidgets('OfflineBanner is hidden when not visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfflineBanner(visible: false))),
    );
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.textContaining('Offline'), findsNothing);
  });
}
