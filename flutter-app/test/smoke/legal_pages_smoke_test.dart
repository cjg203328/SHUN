import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunliao/content/app_legal_content.dart';
import 'package:sunliao/screens/about_screen.dart';
import 'package:sunliao/screens/legal_document_screen.dart';

void main() {
  testWidgets('about screen should stay scrollable on compact size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('about-screen-list')), findsOneWidget);
    expect(find.byKey(const Key('about-hero-card')), findsOneWidget);

    final heroFinder = find.byKey(
      const Key('about-hero-card'),
      skipOffstage: false,
    );
    final beforeOffset = tester.getTopLeft(heroFinder).dy;

    await tester.fling(
      find.byKey(const Key('about-screen-list')),
      const Offset(0, -480),
      1000,
    );
    await tester.pumpAndSettle();

    final afterOffset = tester.getTopLeft(heroFinder).dy;
    expect(afterOffset, lessThan(beforeOffset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('legal document screen should stay scrollable on compact size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(
          documentType: LegalDocumentType.safetyTips,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('legal-document-scroll-view')), findsOneWidget);
    expect(find.byKey(const Key('legal-document-card')), findsOneWidget);

    final cardFinder = find.byKey(
      const Key('legal-document-card'),
      skipOffstage: false,
    );
    final beforeOffset = tester.getTopLeft(cardFinder).dy;

    await tester.fling(
      find.byKey(const Key('legal-document-scroll-view')),
      const Offset(0, -1200),
      1200,
    );
    await tester.pumpAndSettle();

    final afterOffset = tester.getTopLeft(cardFinder).dy;
    expect(afterOffset, lessThan(beforeOffset));
    expect(tester.takeException(), isNull);
  });
}
