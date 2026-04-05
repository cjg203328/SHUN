import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/config/theme.dart';
import 'package:sunliao/widgets/chat_delivery_status.dart';

const _retrySpec = ChatDeliveryStatusSpec(
  badgeLabel: '发送失败',
  badgeColor: AppColors.error,
  badgeIcon: Icons.error_outline,
  cardLabel: '发送失败',
  cardDetail: '点击重试后继续发送',
  cardColor: AppColors.error,
  cardIcon: Icons.error_outline,
  actionLabel: '立即重试',
  actionType: ChatDeliveryAction.retry,
);

const _successSpec = ChatDeliveryStatusSpec(
  badgeLabel: '已送达',
  badgeColor: AppColors.textSecondary,
  badgeIcon: Icons.done_rounded,
  cardLabel: '已送达',
  cardDetail: '消息已到达对方设备',
  cardColor: AppColors.textSecondary,
  cardIcon: Icons.done_rounded,
);

const _blockedSpec = ChatDeliveryStatusSpec(
  badgeLabel: '暂不可重试',
  badgeColor: AppColors.warning,
  badgeIcon: Icons.block_outlined,
  cardLabel: '暂不可重试',
  cardDetail: '当前不可重试，请确认会话状态',
  cardColor: AppColors.warning,
  cardIcon: Icons.block_outlined,
);

Widget _buildHost({
  required double width,
  ChatDeliveryStatusSpec spec = _retrySpec,
  VoidCallback? onActionTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: ChatDeliveryStatusCard(
            spec: spec,
            onActionTap: onActionTap ?? () {},
            animated: false,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'chat delivery status card should keep action on the right for regular width',
    (tester) async {
      await tester.pumpWidget(_buildHost(width: 300));

      final labelRect = tester.getRect(
        find.byKey(const ValueKey<String>(
            'chat-delivery-status-label:发送失败|发送失败|立即重试')),
      );
      final detailRect = tester.getRect(
        find.byKey(const ValueKey<String>(
            'chat-delivery-status-detail:发送失败|发送失败|立即重试')),
      );
      final actionRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('chat-delivery-status-action:retry'),
        ),
      );

      expect(detailRect.top, greaterThan(labelRect.bottom));
      expect(actionRect.top, lessThanOrEqualTo(detailRect.bottom));
      expect(actionRect.left, greaterThan(detailRect.left));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat delivery status card should stack action under detail for narrow width',
    (tester) async {
      await tester.pumpWidget(_buildHost(width: 220));

      final detailRect = tester.getRect(
        find.byKey(const ValueKey<String>(
            'chat-delivery-status-detail:发送失败|发送失败|立即重试')),
      );
      final actionRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('chat-delivery-status-action:retry'),
        ),
      );
      final cardRect = tester.getRect(find.byType(ChatDeliveryStatusCard));

      expect(actionRect.top, greaterThan(detailRect.bottom));
      expect(actionRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(actionRect.right, lessThanOrEqualTo(cardRect.right));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat delivery status card should keep success state compact without action chip',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          width: 220,
          spec: _successSpec,
          onActionTap: null,
        ),
      );

      final labelRect = tester.getRect(
        find.byKey(
            const ValueKey<String>('chat-delivery-status-label:已送达|已送达')),
      );
      final detailRect = tester.getRect(
        find.byKey(
            const ValueKey<String>('chat-delivery-status-detail:已送达|已送达')),
      );
      final cardRect = tester.getRect(find.byType(ChatDeliveryStatusCard));

      expect(detailRect.top, greaterThan(labelRect.bottom));
      expect(detailRect.right, lessThanOrEqualTo(cardRect.right));
      expect(
          find.byKey(const ValueKey<String>('chat-delivery-status-action:已送达')),
          findsNothing);
      expect(find.text('消息已到达对方设备'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat delivery status card should keep non-action failure state readable on narrow width',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          width: 220,
          spec: _blockedSpec,
          onActionTap: null,
        ),
      );

      final labelRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('chat-delivery-status-label:暂不可重试|暂不可重试'),
        ),
      );
      final detailRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('chat-delivery-status-detail:暂不可重试|暂不可重试'),
        ),
      );
      final cardRect = tester.getRect(find.byType(ChatDeliveryStatusCard));

      expect(detailRect.top, greaterThan(labelRect.bottom));
      expect(detailRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(detailRect.right, lessThanOrEqualTo(cardRect.right));
      expect(
        find.byKey(
          const ValueKey<String>('chat-delivery-status-action:暂不可重试'),
        ),
        findsNothing,
      );
      expect(find.text('当前不可重试，请确认会话状态'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat delivery status card should keep retry action tappable across widths',
    (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        _buildHost(
          width: 300,
          onActionTap: () => tapCount++,
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-delivery-status-action:retry'),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        _buildHost(
          width: 220,
          onActionTap: () => tapCount++,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-delivery-status-action:retry'),
        ),
      );
      await tester.pump();

      expect(tapCount, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
