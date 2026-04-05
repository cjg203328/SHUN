import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/widgets/notification_permission_notice_card.dart';

Widget _buildHost({
  required bool compact,
  double? width,
  String? secondaryActionLabel,
  VoidCallback? onSecondaryActionPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width ?? (compact ? 320 : 360),
          child: NotificationPermissionNoticeCard(
            description: 'desc-line',
            actionLabel: 'primary-action',
            actionKey: const Key('primary-action'),
            onActionPressed: () {},
            compact: compact,
            secondaryActionLabel: secondaryActionLabel,
            secondaryActionKey: secondaryActionLabel == null
                ? null
                : const Key('secondary-action'),
            onSecondaryActionPressed: onSecondaryActionPressed,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'notification permission notice card should stack title badge description and actions in compact mode',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          compact: true,
          secondaryActionLabel: 'secondary-action',
          onSecondaryActionPressed: () {},
        ),
      );

      final titleRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-title')),
      );
      final badgeRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-badge')),
      );
      final descriptionRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-description')),
      );
      final descriptionText = tester.widget<Text>(
        find.byKey(const Key('notification-permission-notice-description')),
      );
      final primaryRect =
          tester.getRect(find.byKey(const Key('primary-action')));
      final secondaryRect =
          tester.getRect(find.byKey(const Key('secondary-action')));

      expect(badgeRect.top, greaterThan(titleRect.bottom));
      expect(descriptionRect.top, greaterThan(badgeRect.bottom));
      expect(primaryRect.top, greaterThan(descriptionRect.bottom));
      expect(secondaryRect.top, greaterThan(primaryRect.bottom));
      expect(descriptionText.maxLines, 2);
      expect(descriptionText.overflow, TextOverflow.ellipsis);
      expect(primaryRect.height, 34);
      expect(secondaryRect.height, 34);
      expect(find.text('primary-action'), findsOneWidget);
      expect(find.text('secondary-action'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification permission notice card should keep compact dual-action layout visible on narrow width',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          compact: true,
          width: 280,
          secondaryActionLabel: 'secondary-action',
          onSecondaryActionPressed: () {},
        ),
      );

      final cardRect =
          tester.getRect(find.byType(NotificationPermissionNoticeCard));
      final primaryRect =
          tester.getRect(find.byKey(const Key('primary-action')));
      final secondaryRect =
          tester.getRect(find.byKey(const Key('secondary-action')));

      expect(primaryRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(primaryRect.right, lessThanOrEqualTo(cardRect.right));
      expect(secondaryRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(secondaryRect.right, lessThanOrEqualTo(cardRect.right));
      expect(primaryRect.bottom, lessThan(secondaryRect.top));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification permission notice card should keep compact single-action layout readable',
    (tester) async {
      await tester.pumpWidget(_buildHost(compact: true));

      final titleRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-title')),
      );
      final badgeRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-badge')),
      );
      final descriptionRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-description')),
      );
      final descriptionText = tester.widget<Text>(
        find.byKey(const Key('notification-permission-notice-description')),
      );
      final primaryRect =
          tester.getRect(find.byKey(const Key('primary-action')));

      expect(badgeRect.top, greaterThan(titleRect.bottom));
      expect(descriptionRect.top, greaterThan(badgeRect.bottom));
      expect(primaryRect.top, greaterThan(descriptionRect.bottom));
      expect(descriptionText.maxLines, 2);
      expect(descriptionText.overflow, TextOverflow.ellipsis);
      expect(primaryRect.height, 34);
      expect(find.byKey(const Key('secondary-action')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification permission notice card should keep title and badge aligned in regular mode',
    (tester) async {
      await tester.pumpWidget(_buildHost(compact: false));

      final titleRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-title')),
      );
      final badgeRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-badge')),
      );
      final descriptionRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-description')),
      );
      final descriptionText = tester.widget<Text>(
        find.byKey(const Key('notification-permission-notice-description')),
      );
      final primaryRect =
          tester.getRect(find.byKey(const Key('primary-action')));

      expect(badgeRect.top, lessThan(titleRect.bottom));
      expect(descriptionRect.top, greaterThan(titleRect.bottom));
      expect(primaryRect.top, greaterThan(descriptionRect.bottom));
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, TextOverflow.visible);
      expect(primaryRect.height, 38);
      expect(find.byKey(const Key('secondary-action')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification permission notice card should keep regular dual-action layout side by side',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          compact: false,
          secondaryActionLabel: 'secondary-action',
          onSecondaryActionPressed: () {},
        ),
      );

      final titleRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-title')),
      );
      final badgeRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-badge')),
      );
      final descriptionRect = tester.getRect(
        find.byKey(const Key('notification-permission-notice-description')),
      );
      final primaryRect =
          tester.getRect(find.byKey(const Key('primary-action')));
      final secondaryRect =
          tester.getRect(find.byKey(const Key('secondary-action')));

      expect(badgeRect.top, lessThan(titleRect.bottom));
      expect(descriptionRect.top, greaterThan(titleRect.bottom));
      expect(primaryRect.top, greaterThan(descriptionRect.bottom));
      expect(secondaryRect.top, greaterThan(descriptionRect.bottom));
      expect(
        (primaryRect.top - secondaryRect.top).abs(),
        lessThanOrEqualTo(1),
      );
      expect(primaryRect.right, lessThan(secondaryRect.left));
      expect(primaryRect.height, 38);
      expect(secondaryRect.height, 38);
      expect(tester.takeException(), isNull);
    },
  );
}
