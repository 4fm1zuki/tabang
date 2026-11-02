import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/repository.dart';
import 'package:tabang/screens/donor/discover_page.dart';
import 'package:tabang/screens/donor/find_donor_page.dart';
import 'package:tabang/theme.dart';
import 'package:tabang/widgets/common.dart';
import 'package:tabang/widgets/illustrations.dart';
import 'package:tabang/widgets/photo.dart';

void main() {
  final repo = TabangRepository.instance;

  setUp(repo.resetForTesting);

  testWidgets('discover shows quick actions above the full feed',
      (tester) async {
    final donor = repo.userById('USR-001')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: DiscoverPage(user: donor)),
      ),
    );

    // Single unified interface: obvious actions first, feed below.
    expect(find.text('Donate blood'), findsOneWidget);
    expect(find.text('Find donation sites'), findsOneWidget);
    expect(find.text('Quick guide'), findsOneWidget);
    expect(find.text('Featured updates'), findsOneWidget);
  });

  testWidgets('find donor map loads the real boundaries and stays tappable',
      (tester) async {
    final donor = repo.userById('USR-001')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: FindDonorPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    // The GeoJSON loaded: no error overlay, and the painter is mounted.
    expect(find.text('DIGOS CITY · 26 BARANGAYS'), findsOneWidget);
    expect(find.text('Barangay map unavailable'), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    // Taps must be handled by the raw listener without throwing, and repeated
    // taps must not wedge the page.
    final mapCentre = tester.getCenter(find.byType(InteractiveViewer));
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(mapCentre + Offset(i * 24.0, 0));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Available donors'), findsOneWidget);

    // The donor list collapses to a tap bar and comes back.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
  });

  testWidgets('find donor desktop layout keeps its overlays and controls',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final donor = repo.userById('USR-001')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.dark,
        home: Scaffold(body: FindDonorPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    // Wide layout: map left, donor pane right, with every overlay mounted.
    expect(find.text('ALL'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.text('AVAILABLE DONORS'), findsOneWidget);
    expect(find.textContaining('Available donors'), findsOneWidget);

    // The overlay controls must be tappable.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Tapping a barangay filters the donor list. The exact polygon under the
    // centre depends on the fitted bounds, so try a few points and require at
    // least one hit.
    final mapCentre = tester.getCenter(find.byType(InteractiveViewer));
    var selected = false;
    for (final offset in <Offset>[
      Offset.zero,
      const Offset(0, 120),
      const Offset(-90, -80),
      const Offset(60, 180),
    ]) {
      await tester.tapAt(mapCentre + offset);
      await tester.pumpAndSettle();
      if (find.textContaining('Available donors in').evaluate().isNotEmpty) {
        selected = true;
        break;
      }
    }
    expect(selected, isTrue, reason: 'a map tap should select a barangay');

    // The donor pane collapses to the right and expands again.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.textContaining('Available donors'), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.textContaining('Available donors'), findsOneWidget);
  });

  testWidgets('empty states render the vector illustration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(
          body: EmptyState(
            art: TabangArt.requests,
            title: 'Nothing here',
          ),
        ),
      ),
    );

    expect(find.byType(TabangIllustration), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('page header stacks actions so the title never gets squeezed',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: PageHeader(
            title: 'Discover',
            subtitle: 'Updates and drives across Digos City.',
            actions: [
              SizedBox(width: 240, height: 40, child: Container()),
            ],
          ),
        ),
      ),
    );

    final title = tester.getSize(find.text('Discover'));
    expect(title.height, lessThan(50));
    expect(find.text('Updates and drives across Digos City.'), findsOneWidget);
  });

  testWidgets('every content item ships a bundled photo asset',
      (tester) async {
    for (final item in repo.content) {
      expect(
        item.imageAsset,
        isNotNull,
        reason: '${item.id} should point at a bundled photo',
      );
      final data = await rootBundle.load(item.imageAsset!);
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '${item.imageAsset} is missing or empty',
      );
    }

    // Each card should still have its own photograph rather than repeating
    // one placeholder across the whole feed.
    final distinct = repo.content.map((c) => c.imageAsset).toSet();
    expect(distinct.length, greaterThanOrEqualTo(8));

    final icon = await rootBundle.load('assets/branding/app_icon.png');
    expect(icon.lengthInBytes, greaterThan(1000));
  });

  testWidgets('discover uses local photos in the hero, feed and article dialog',
      (tester) async {
    final donor = repo.userById('USR-001')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: DiscoverPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    // Hero, content cards and the two drive cards all use TabangPhoto.
    expect(find.byType(TabangPhoto), findsWidgets);

    await tester.ensureVisible(find.text('Read more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Photo: public-domain / CC0'), findsOneWidget);
    expect(find.byType(TabangPhoto), findsWidgets);
  });

  testWidgets('a missing photo renders the themed fallback, not an error box',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(
          body: SizedBox(
            width: 240,
            height: 140,
            child: TabangPhoto(
              'assets/images/not_bundled.jpg',
              fallbackIcon: Icons.bloodtype_outlined,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bloodtype_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
