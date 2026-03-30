import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/widgets/settings_media_management_preview_card.dart';

Widget _buildHost({required bool hasMedia}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SettingsMediaManagementPreviewCard(
          leading: const SizedBox(width: 40, height: 40),
          statusLabel: hasMedia ? 'status-synced' : 'status-default',
          statusKey: const Key('status'),
          badgeLabel: hasMedia ? 'badge-live' : 'badge-empty',
          badgeKey: const Key('badge'),
          hasMedia: hasMedia,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'settings media management preview card should render status and badge',
      (tester) async {
    await tester.pumpWidget(_buildHost(hasMedia: true));

    expect(find.byKey(const Key('status')), findsOneWidget);
    expect(find.byKey(const Key('badge')), findsOneWidget);
    expect(find.text('status-synced'), findsOneWidget);
    expect(find.text('badge-live'), findsOneWidget);
  });
}
