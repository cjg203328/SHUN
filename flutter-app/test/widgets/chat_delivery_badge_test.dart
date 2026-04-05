import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/config/theme.dart';
import 'package:sunliao/widgets/chat_delivery_status.dart';

Widget _buildHost({
  required bool animated,
  required bool emphasized,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: ChatDeliveryBadge(
          label: '发送失败',
          color: AppColors.error,
          icon: Icons.error_outline,
          animated: animated,
          emphasized: emphasized,
        ),
      ),
    ),
  );
}

Finder _badgeFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('badge:发送失败:'),
  );
}

void main() {
  testWidgets(
    'chat delivery badge should render static badge without AnimatedSwitcher when animation is disabled',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          animated: false,
          emphasized: false,
        ),
      );

      expect(find.byType(AnimatedSwitcher), findsNothing);
      expect(find.text('发送失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat delivery badge should add shadow when emphasized',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          animated: true,
          emphasized: true,
        ),
      );

      final container = tester.widget<Container>(_badgeFinder());
      final decoration = container.decoration! as BoxDecoration;

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect((decoration.border as Border).top.color.a, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat delivery badge should keep non-emphasized animated badge lightweight',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          animated: true,
          emphasized: false,
        ),
      );

      final container = tester.widget<Container>(_badgeFinder());
      final decoration = container.decoration! as BoxDecoration;

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(decoration.boxShadow, isNull);
      expect((decoration.border as Border).top.color.a, greaterThan(0));
      expect(find.text('发送失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat delivery badge should switch from lightweight to emphasized state cleanly',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          animated: true,
          emphasized: false,
        ),
      );

      var container = tester.widget<Container>(_badgeFinder());
      var decoration = container.decoration! as BoxDecoration;

      expect(decoration.boxShadow, isNull);

      await tester.pumpWidget(
        _buildHost(
          animated: true,
          emphasized: true,
        ),
      );
      await tester.pump();

      container = tester.widget<Container>(_badgeFinder());
      decoration = container.decoration! as BoxDecoration;

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect(find.text('发送失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
