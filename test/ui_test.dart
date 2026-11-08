import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/image_credits.dart';
import 'package:tabang/core/repository.dart';
import 'package:tabang/screens/admin/inventory_management.dart';
import 'package:tabang/screens/admin/operations_map_page.dart';
import 'package:tabang/screens/donor/discover_page.dart';
import 'package:tabang/screens/donor/donor_hub_page.dart';
import 'package:tabang/screens/donor/find_donor_page.dart';
import 'package:tabang/theme.dart';
import 'package:tabang/widgets/common.dart';
import 'package:tabang/widgets/digos_vector_map.dart';
import 'package:tabang/widgets/illustrations.dart';
import 'package:tabang/widgets/photo.dart';

void main() {
  final repo = TabangRepository.instance;

  setUp(() {
    repo.resetForTesting();
    // Widget tests must not attempt OpenStreetMap tile requests.
    DigosVectorMap.tilesEnabled = false;
  });

  testWidgets('discover shows quick actions above the full feed', (
    tester,
  ) async {
    final donor = repo.userById('USR-001')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: DiscoverPage(user: donor)),
      ),
    );

    // Single unified interface: hero, then the two primary actions, then the
    // organised feed. The old four-button + summary stack is gone.
    expect(find.text('View blood requests'), findsOneWidget);
    expect(find.text('Find donors near you'), findsOneWidget);
    expect(find.text('Find a drive'), findsOneWidget);
    expect(find.text('Upcoming blood drives'), findsOneWidget);
    expect(find.text('Announcements & stories'), findsOneWidget);
  });

  testWidgets('find donor map loads the real boundaries and stays tappable', (
    tester,
  ) async {
    // Phone layout: the map stacks above the collapsible donor list.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final donor = repo.userById('USR-001')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: FindDonorPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    // The vector map is mounted. The title card is desktop-only and the old
    // eyebrow/"2D VECTOR MAP" chrome is gone.
    expect(find.byType(DigosVectorMap), findsOneWidget);
    expect(find.text('Digos City Barangay Map'), findsNothing);
    expect(find.text('2D VECTOR MAP'), findsNothing);
    expect(find.text('ALL'), findsOneWidget);

    // Repeated taps must not wedge the page.
    final mapCentre = tester.getCenter(find.byType(DigosVectorMap));
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(mapCentre + Offset(i * 24.0, 0));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Available donors'), findsOneWidget);

    // The donor list collapses to a tap bar and comes back.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    expect(find.text('Show list'), findsOneWidget);
    await tester.tap(find.text('Show list'));
    await tester.pumpAndSettle();
    expect(find.text('Show list'), findsNothing);
    expect(find.textContaining('Available donors'), findsOneWidget);
  });

  testWidgets('find donor desktop layout keeps its overlays and controls', (
    tester,
  ) async {
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
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
    // The legend keeps the donor-density key. The boundary / pin layer rows
    // were removed: the map already shows them, and they made the panel read
    // as a layers menu.
    expect(find.text('DONOR DENSITY'), findsOneWidget);
    expect(find.text('Digos City boundary'), findsNothing);
    expect(find.textContaining('Available donors'), findsOneWidget);

    // The overlay controls must be tappable.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Tapping a barangay filters the donor list. The exact polygon under the
    // centre depends on the fitted bounds, so try a few points and require at
    // least one hit.
    final mapCentre = tester.getCenter(find.byType(DigosVectorMap));
    var selected = false;
    for (final offset in <Offset>[
      Offset.zero,
      const Offset(0, 120),
      const Offset(-90, -80),
      const Offset(60, 180),
    ]) {
      await tester.tapAt(mapCentre + offset);
      await tester.pumpAndSettle();
      // A tap that lands on a drive pin opens the drives sheet instead of
      // selecting the barangay; dismiss it and try the next point.
      if (find.textContaining('Blood drives ·').evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        continue;
      }
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

  testWidgets('find donor map style follows the active theme', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final donor = repo.userById('USR-001')!;

    // Dark app theme (system dark): the map opens dark, so the style button
    // offers to switch back to light.
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.dark,
        home: Scaffold(body: FindDonorPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    // A live theme change re-syncs the map when the user has not overridden.
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: FindDonorPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    // The style button still pins a per-visit override.
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets('empty states render the vector illustration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(
          body: EmptyState(art: TabangArt.requests, title: 'Nothing here'),
        ),
      ),
    );

    expect(find.byType(TabangIllustration), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('page header stacks actions so the title never gets squeezed', (
    tester,
  ) async {
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
            actions: [SizedBox(width: 240, height: 40, child: Container())],
          ),
        ),
      ),
    );

    final title = tester.getSize(find.text('Discover'));
    expect(title.height, lessThan(50));
    // Headers are one compact line now: the description is exposed as a
    // hover/label tooltip instead of a second grey paragraph.
    expect(
      find.byTooltip('Updates and drives across Digos City.'),
      findsOneWidget,
    );
  });

  testWidgets('every content item ships a bundled photo asset', (tester) async {
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

    // Every bundled image resolves to its own credit entry.
    final credited = distinct.where((asset) => creditForAsset(asset) != null);
    expect(credited.length, distinct.length);

    final icon = await rootBundle.load('assets/branding/app_icon.png');
    expect(icon.lengthInBytes, greaterThan(1000));
  });

  testWidgets(
    'discover uses local photos in the hero, feed and article dialog',
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
      // The feed itself carries no credit text any more — attribution lives in
      // the details dialog that opens when a card is tapped.
      expect(find.byType(PhotoCredit), findsNothing);

      await tester.ensureVisible(find.text('Read the story'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read the story'));
      await tester.pumpAndSettle();
      expect(find.byType(TabangPhoto), findsWidgets);
      expect(find.byType(PhotoCredit), findsOneWidget);

      // Tapping the chip opens the licence and the source link. Asset paths are
      // deliberately not shown to users.
      await tester.tap(find.byType(PhotoCredit));
      await tester.pumpAndSettle();
      expect(find.text('Photo credit'), findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(find.textContaining('assets/images'), findsNothing);
    },
  );

  testWidgets('a missing photo renders the themed fallback, not an error box', (
    tester,
  ) async {
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

  testWidgets('staff operations map renders the request layer', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: OperationsMapPage(user: staff)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operations map'), findsOneWidget);
    expect(find.text('OPEN REQUESTS'), findsOneWidget);
    expect(find.text('Inventory queue'), findsOneWidget);
    expect(find.byType(DigosVectorMap), findsOneWidget);

    // The legend switch gives staff the same donor-density heatmap that the
    // community map uses, and swaps the legend with it.
    await tester.tap(find.text('Donor density'));
    await tester.pumpAndSettle();
    expect(find.text('DONOR DENSITY'), findsOneWidget);
    expect(find.text('No available donors'), findsOneWidget);
    expect(find.text('OPEN REQUESTS'), findsNothing);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN REQUESTS'), findsOneWidget);
    expect(find.text('DONOR DENSITY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory exposes add-stock and the appointment queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: InventoryManagementPage(currentUser: staff)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add unit'), findsOneWidget);

    await tester.tap(find.textContaining('Appointments'));
    await tester.pumpAndSettle();
    // Seeded APT-001 starts pending, so the confirm control is reachable.
    expect(find.text('Confirm'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('donor hub shows the away notice and can activate again', (
    tester,
  ) async {
    // A tall viewport keeps every hub card built so the availability notice
    // is in the tree without scrolling a lazy list.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final away = repo.userById('USR-039')!;

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: DonorHubPage(user: away)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("I'm active"), findsOneWidget);
    expect(find.textContaining('marks donors away'), findsOneWidget);

    await tester.tap(find.text("I'm active"));
    await tester.pumpAndSettle();
    expect(find.textContaining('marks donors away'), findsNothing);
    expect(
      find.text('You are visible to compatible recipients.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
