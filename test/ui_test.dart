import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/image_credits.dart';
import 'package:tabang/core/models.dart';
import 'package:tabang/core/repository.dart';
import 'package:tabang/screens/admin/admin_overview.dart';
import 'package:tabang/screens/admin/chat_moderation_page.dart';
import 'package:tabang/screens/admin/drive_management_page.dart';
import 'package:tabang/screens/admin/inventory_management.dart';
import 'package:tabang/screens/admin/operations_map_page.dart';
import 'package:tabang/screens/admin/operations_workspace_page.dart';
import 'package:tabang/screens/admin/user_management_page.dart';
import 'package:tabang/screens/donor/chat_page.dart';
import 'package:tabang/screens/donor/discover_page.dart';
import 'package:tabang/screens/donor/donor_hub_page.dart';
import 'package:tabang/screens/donor/find_donor_page.dart';
import 'package:tabang/screens/donor/requests_page.dart';
import 'package:tabang/screens/shared/about_help_page.dart';
import 'package:tabang/screens/shared/profile_page.dart';
import 'package:tabang/theme.dart';
import 'package:tabang/widgets/chapter_identity.dart';
import 'package:tabang/widgets/common.dart';
import 'package:tabang/widgets/digos_vector_map.dart';
import 'package:tabang/widgets/illustrations.dart';
import 'package:tabang/widgets/photo.dart';
import 'package:tabang/widgets/request_document_list.dart';

/// Flutter decodes JPEG, PNG and WebP. A download named `.jpg` whose bytes are
/// actually AVIF (or HEIC) is not an error the loader reports: it silently draws
/// the fallback icon, so bundled photography is checked by signature here.
bool _isDecodableImage(ByteData data) {
  final b = data.buffer.asUint8List();
  if (b.length < 12) return false;
  final jpeg = b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
  final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
  final webp =
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50;
  return jpeg || png || webp;
}

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
    expect(find.text('Find a donor'), findsOneWidget);
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

    // Repeated taps must not wedge the page, and a tap selects a barangay
    // immediately (no double-tap recognizer holding the gesture).
    final mapCentre = tester.getCenter(find.byType(DigosVectorMap));
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(mapCentre);
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const ValueKey('clearDonorBarangayFilter')),
      findsOneWidget,
    );

    // Clear the filter so the rest of the test describes the whole directory.
    await tester.tap(find.byKey(const ValueKey('clearDonorBarangayFilter')));
    await tester.pumpAndSettle();

    expect(find.text('Available donors'), findsOneWidget);

    // The scale bar is tied to the live camera, not a cached zoom: its label
    // and the number of pixels drawn must describe the same ground distance.
    final map = tester.widget<DigosVectorMap>(find.byType(DigosVectorMap));
    final scale = mapScaleBarScale(
      zoom: map.controller.camera.zoom,
      latitude: map.controller.camera.center.latitude,
    );
    final scaleLabel = tester.widget<Text>(
      find.byKey(const ValueKey('mapScaleBarLabel')),
    );
    expect(scaleLabel.data, scale.label);
    final scaleLine = tester.widget<Container>(
      find.byKey(const ValueKey('mapScaleBarLine')),
    );
    expect(
      scaleLine.constraints?.maxWidth,
      closeTo(scale.width, 0.01),
      reason: 'the drawn ruler must match its label',
    );
    expect(find.textContaining('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.textContaining('HOT style'), findsNothing);

    // The old four-mode dropdown and the header switches are gone. A draggable
    // divider now sits between the map and the directory.
    expect(find.byKey(const ValueKey('findDonorMapModeMenu')), findsNothing);
    expect(find.byKey(const ValueKey('hideDonorMapButton')), findsNothing);
    expect(find.byKey(const ValueKey('showDonorMapButton')), findsNothing);
    expect(find.byKey(const ValueKey('collapseDonorListButton')), findsNothing);
    final splitHandle = find.byKey(const ValueKey('mapSplitHandle'));
    expect(splitHandle, findsOneWidget);
    final halfHeight = tester.getSize(find.byType(DigosVectorMap)).height;

    // Pull the divider down: the map grows to the full page and the donor
    // panel becomes the compact restore bubble over it.
    await tester.drag(splitHandle, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(DigosVectorMap), findsOneWidget);
    // The donor pane is hidden, so only the restore bubble names the list.
    expect(find.textContaining('Available donors'), findsNothing);
    expect(find.text('Show donor list'), findsOneWidget);
    await tester.tap(find.byTooltip('Show donor list'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Available donors'), findsOneWidget);
    expect(find.text('Show donor list'), findsNothing);

    // Pull it up: the directory fills the page and the map steps aside.
    await tester.drag(splitHandle, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(DigosVectorMap), findsNothing);
    expect(find.textContaining('Available donors'), findsOneWidget);

    // Pull it back down to the middle: the default half split returns.
    await tester.drag(splitHandle, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(DigosVectorMap), findsOneWidget);
    expect(find.textContaining('Available donors'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DigosVectorMap)).height,
      closeTo(halfHeight, 1),
    );
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

    // The vertical divider collapses the donor pane to the map-only restore
    // bar and expands it again.
    await tester.drag(
      find.byKey(const ValueKey('mapSplitHandle')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Show donor list'), findsOneWidget);
    await tester.tap(find.byTooltip('Show donor list'));
    await tester.pumpAndSettle();
    expect(find.text('Show donor list'), findsNothing);
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

  testWidgets('Home quick action "Find a drive" always reaches the drive rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final donor = repo.userById('USR-001')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: DiscoverPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    // Only the Explore and Blood Drives categories mount the rail, so from the
    // Stories view the button used to return without doing anything visible.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Stories'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming blood drives'), findsNothing);

    await tester.tap(find.text('Find a drive'));
    await tester.pumpAndSettle();
    expect(
      find.text('Upcoming blood drives'),
      findsOneWidget,
      reason: 'Find a drive must switch to a view that carries the rail',
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
      expect(
        _isDecodableImage(data),
        isTrue,
        reason: '${item.imageAsset} is not a JPEG/PNG/WebP file',
      );
    }

    // Each card should still have its own photograph rather than repeating
    // one placeholder across the whole feed.
    final distinct = repo.content.map((c) => c.imageAsset).toSet();
    expect(distinct.length, greaterThanOrEqualTo(8));

    // Every seeded drive ships its own photograph from the Blood Drives
    // folder, and each one resolves to a credit entry.
    final drivePhotos = <String>{};
    for (final drive in repo.drives) {
      final photo = drive.photoAsset;
      expect(photo, isNotNull, reason: '${drive.id} should have a photo');
      final data = await rootBundle.load(photo!);
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '$photo is missing or empty',
      );
      expect(
        _isDecodableImage(data),
        isTrue,
        reason: '$photo is not a JPEG/PNG/WebP file',
      );
      expect(
        creditForAsset(photo),
        isNotNull,
        reason: '$photo has no credit entry',
      );
      drivePhotos.add(photo);
    }
    expect(drivePhotos.length, repo.drives.length);

    // Every bundled content image resolves to its own credit entry.
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

  testWidgets('staff operations map reuses the community map chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
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

    // Same map surface as Find Donor: title card, blood-type chips, zoom and
    // fit stack, donor-style side panel with the draggable divider.
    expect(find.byType(DigosVectorMap), findsOneWidget);
    expect(find.text('Digos City Barangay Map'), findsOneWidget);
    expect(find.text('ALL'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
    expect(find.text('Open requests'), findsOneWidget);
    // Staff open on the amber request-workload ramp, with a legend switch to
    // the community donor-density ramp. The switch itself names the layers,
    // so the legend card carries no second title repeating it.
    expect(find.text('None open'), findsOneWidget);
    expect(find.text('No available donors'), findsNothing);
    expect(find.byKey(const ValueKey('mapSplitHandle')), findsOneWidget);
    // "Requests" is both the queue tab and the legend's layer switch; the
    // second panel tab is the donor directory, not the registrations queue
    // (that queue lives on the Users page).
    expect(find.text('Requests'), findsWidgets);
    expect(find.text('Donors'), findsWidgets);
    expect(find.text('Registrations'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('operationsHeatDonors')));
    await tester.pumpAndSettle();
    expect(find.text('No available donors'), findsOneWidget);
    expect(find.text('None open'), findsNothing);
    // Switching to the donor heat also brings the donor list forward.
    expect(find.text('Donors'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('operationsHeatRequests')));
    await tester.pumpAndSettle();
    expect(find.text('None open'), findsOneWidget);

    // The old staff-only chrome is gone: no page header, inventory shortcut,
    // size menu, layer toggle or "city-wide queue" section.
    expect(find.text('Operations map'), findsNothing);
    expect(find.text('Inventory queue'), findsNothing);
    expect(find.text('City-wide queue'), findsNothing);
    expect(find.byKey(const ValueKey('mapSizeMenu')), findsNothing);

    // The blood-type chips filter the request panel, like the donor map. The
    // donor list also carries "O+" chips, so target the filter row (built first).
    await tester.tap(find.text('O+').first);
    await tester.pumpAndSettle();
    expect(find.text('Open requests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone operations map uses the draggable split handle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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

    expect(find.byType(DigosVectorMap), findsOneWidget);
    expect(find.byKey(const ValueKey('mapSplitHandle')), findsOneWidget);
    expect(find.byKey(const ValueKey('hideOperationsMapButton')), findsNothing);
    expect(find.byKey(const ValueKey('showOperationsMapButton')), findsNothing);
    expect(
      find.byKey(const ValueKey('collapseOperationsListButton')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('mapSizeMenu')), findsNothing);

    // Pull the divider down: the map keeps the page, and the request list
    // becomes the compact restore bubble over the map.
    await tester.drag(
      find.byKey(const ValueKey('mapSplitHandle')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DigosVectorMap), findsOneWidget);
    // The request pane is collapsed to its restore bubble.
    expect(find.text('Open requests'), findsNothing);
    expect(find.text('Show request list'), findsOneWidget);
    await tester.tap(find.byTooltip('Show request list'));
    await tester.pumpAndSettle();
    expect(find.text('Open requests'), findsOneWidget);
    expect(find.text('Show request list'), findsNothing);

    // Pull it up: the list fills the page and the map steps aside.
    await tester.drag(
      find.byKey(const ValueKey('mapSplitHandle')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DigosVectorMap), findsNothing);
    expect(find.byKey(const ValueKey('mapSplitHandle')), findsOneWidget);

    // Pull it back down to restore the half split.
    await tester.drag(
      find.byKey(const ValueKey('mapSplitHandle')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DigosVectorMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blood-type balance pills say more or short, not +N', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(body: AdminOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    final labelled = repo
        .bloodTypeStats()
        .where((stat) => stat.balance != 0)
        .toList();
    expect(labelled, isNotEmpty);
    for (final stat in labelled) {
      final label = stat.balance > 0
          ? '${stat.balance} more'
          : '${stat.balance.abs()} short';
      expect(
        find.text(label),
        findsWidgets,
        reason: '${stat.bloodType.label} must explain its balance',
      );
    }

    // The old pill was a bare "+12"/"-3" with no unit or direction.
    expect(find.textContaining(RegExp(r'^\+\d+$')), findsNothing);
    expect(
      find.textContaining('The pill is the balance'),
      findsOneWidget,
      reason: 'the card explains donations minus requests',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory exposes add-stock and the booked-slot queue', (
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

    await tester.tap(find.textContaining('Booked slots'));
    await tester.pumpAndSettle();
    // Seeded REQ-011 is still awaiting review, so its slot and the verify
    // action are reachable: the row opens the details, which carry the action.
    expect(find.text('Awaiting verification'), findsWidgets);
    await tester.tap(find.textContaining('Awaiting verification').first);
    await tester.pumpAndSettle();
    expect(find.text('Verify and open'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Request cards stay compact, so the requester and attachments move into
    // the details dialog behind a tap on the card.
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.byType(RequestDocumentList), findsNothing);
    await tester.tap(find.textContaining('Patient ').first);
    await tester.pumpAndSettle();
    expect(find.byType(RequestDocumentList), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The removed-units ledger keeps a removal visible and offers a restore.
    final removed = repo.units.first;
    expect(repo.removeBloodUnit(removed.barcode, actorId: staff.id), isTrue);
    await tester.tap(find.textContaining('Removed units'));
    await tester.pumpAndSettle();
    expect(find.text('Restore to stock'), findsWidgets);
    expect(find.textContaining(removed.barcode), findsWidgets);
    await tester.tap(find.text('Restore to stock').first);
    await tester.pumpAndSettle();
    expect(repo.units.any((u) => u.barcode == removed.barcode), isTrue);
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

  testWidgets('operations workspace moves between map and inventory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: OperationsWorkspacePage(user: staff)),
      ),
    );
    await tester.pumpAndSettle();

    // One Operations destination with a top segmented control at every width;
    // there is no desktop-only inner sidebar.
    expect(find.byKey(const ValueKey('operationsSidebar')), findsNothing);
    expect(find.text('Open requests'), findsOneWidget);
    expect(find.byType(DigosVectorMap), findsOneWidget);

    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Add unit'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Open requests'), findsOneWidget);

    // Opening a request from the map lands on the Requests tab, not the units
    // list, with that request's card focused.
    final openInRequests = find.text('Open in Requests').first;
    await tester.ensureVisible(openInRequests);
    await tester.pumpAndSettle();
    await tester.tap(openInRequests);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cards show the essentials'), findsOneWidget);
    // The jump target is outlined, then the outline clears so it cannot stay
    // stuck on the first request the map opened.
    bool hasHighlightedCard() => tester
        .widgetList<SurfaceCard>(find.byType(SurfaceCard))
        .any((card) => card.highlighted);
    expect(hasHighlightedCard(), isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(hasHighlightedCard(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff chat can start a new conversation from search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: ChatPage(user: staff, allowNewConversation: true)),
      ),
    );
    await tester.pumpAndSettle();

    // The staff room is listed for staff with its staff-only marker (the
    // auto-opened header repeats the name, hence findsWidgets).
    expect(find.text('Staff room'), findsWidgets);
    expect(find.text('Staff only'), findsWidgets);

    await tester.tap(find.byTooltip('New conversation'));
    await tester.pumpAndSettle();
    expect(find.text('New conversation'), findsWidgets);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Juan',
    );
    await tester.pumpAndSettle();

    final donorTile = find.byKey(const ValueKey('newConversation-USR-001'));
    expect(donorTile, findsOneWidget);
    await tester.tap(donorTile);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Write a message'), findsOneWidget);
    // Staff can choose the chapter identity or their own account; the safe
    // default is the chapter.
    expect(find.text('Sending as the PRC chapter identity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff user record opens details and the donation window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    final before = repo.userById('USR-001')!.totalDonations;

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: UserManagementPage(currentUser: staff)),
      ),
    );
    await tester.pumpAndSettle();

    // Search on a fragment so the field's own text does not also match the
    // list row's full name.
    await tester.enterText(find.byType(TextField).first, 'Dela');
    await tester.pumpAndSettle();

    final name = find.text('Juan Dela Cruz');
    expect(name, findsOneWidget);
    await tester.tap(name);
    await tester.pumpAndSettle();

    // Contact details stay in the staff/admin-only record dialog.
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('juan.delacruz@tabang.app'), findsOneWidget);
    expect(
      find.textContaining('visible to chapter staff and administrators only'),
      findsOneWidget,
    );

    final donationWindow = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Donation window'),
    );
    await tester.ensureVisible(donationWindow);
    await tester.pumpAndSettle();
    await tester.tap(donationWindow);
    await tester.pumpAndSettle();
    expect(find.text('Donation window · JuanDC'), findsOneWidget);

    await tester.tap(find.text('Update window'));
    await tester.pumpAndSettle();

    expect(repo.userById('USR-001')!.totalDonations, before);
    expect(find.text('Donation window updated for JuanDC.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff can remove a warning from an account record', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    // Seeded warned account with two warnings.
    expect(repo.userById('USR-003')!.warningCount, 2);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: UserManagementPage(currentUser: staff)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Rogel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rogelio Bautista'));
    await tester.pumpAndSettle();

    // The record lists the warnings and offers a per-warning remove control.
    expect(find.textContaining('Moderation warnings'), findsOneWidget);
    final removeButton = find.widgetWithText(TextButton, 'Remove');
    expect(removeButton, findsWidgets);
    await tester.ensureVisible(removeButton.first);
    await tester.pumpAndSettle();
    await tester.tap(removeButton.first);
    await tester.pumpAndSettle();

    expect(repo.userById('USR-003')!.warningCount, 1);
    expect(repo.warningsFor('USR-003'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile carries the account standing history', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final warned = repo.userById('USR-003')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: ProfilePage(user: warned)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account standing'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('What you can do now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('donor hub locks a staff-restricted donation type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Seeded demo account: limited to red cells and plasma.
    final juan = repo.userById('USR-001')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: DonorHubPage(user: juan)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Chapter staff have limited this account'),
      findsOneWidget,
    );
    final locked = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, BloodComponent.wholeBlood.label),
    );
    expect(
      locked.onSelected,
      isNull,
      reason: 'a restricted type cannot be ticked',
    );
    final open = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, BloodComponent.packedRbc.label),
    );
    expect(open.onSelected, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('about references group the stories and learn articles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(body: AboutHelpPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('References'), findsOneWidget);
    expect(find.text('Stories'), findsWidgets);
    expect(find.text('Learn & Prepare'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('community map request cards hand off to the Requests tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var opened = 0;
    String? openedId;
    final donor = repo.userById('USR-001')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: FindDonorPage(
            user: donor,
            onOpenRequests: (id) {
              opened++;
              openedId = id;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch the side panel to its Requests tab.
    final panelTab = find
        .descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('Requests'),
        )
        .first;
    await tester.ensureVisible(panelTab);
    await tester.pumpAndSettle();
    await tester.tap(panelTab);
    await tester.pumpAndSettle();

    expect(find.text('Open in Requests'), findsWidgets);
    final openButton = find.text('Open in Requests').first;
    await tester.ensureVisible(openButton);
    await tester.pumpAndSettle();
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    expect(opened, 1);
    // The hand-off names the specific request so the Requests tab can scroll
    // to it, instead of dropping the user at the top of the list.
    expect(openedId, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request cards open details and show one filter guide', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final donor = repo.userById('USR-001')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: RequestsPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    // Urgency and state now share one guide beside the filter row instead of
    // two tips stacked above it.
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byTooltip('Request options'), findsNothing);

    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('Urgency & request states'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // The whole card opens the full record; there is no three-dot menu.
    final card = find.ancestor(
      of: find.text('Patient 205'),
      matching: find.byType(SurfaceCard),
    );
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Request ID'), findsOneWidget);
    expect(find.text('REQ-007'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('map hand-off focuses a request that is not the viewer own', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Maria is a recipient. The community map lists every request, so the
    // hand-off must land on one she did not post instead of dropping her at
    // the top of a Mine-only list. REQ-007 is critical, which also proves the
    // outline is the locator and not a permanent critical-urgency border.
    final recipient = repo.userById('USR-009')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(
          body: RequestsPage(
            user: recipient,
            focusRequestId: 'REQ-007',
            focusRequestToken: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Patient 205'),
      matching: find.byType(SurfaceCard),
    );
    expect(card, findsOneWidget);
    expect(tester.widget<SurfaceCard>(card).highlighted, isTrue);

    // The outline is a locator, not a permanent state: it clears after the
    // user has had time to see where they landed.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.widget<SurfaceCard>(card).highlighted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request queues lead with critical and then urgent', (
    tester,
  ) async {
    // Same urgency bands on both sides of the app, oldest request first within
    // a band.
    final community = repo.communityRequests;
    final urgencyRank = {
      for (final (i, urgency) in const [
        RequestUrgency.critical,
        RequestUrgency.urgent,
        RequestUrgency.routine,
      ].indexed)
        urgency: i,
    };
    for (var i = 1; i < community.length; i++) {
      final previous = community[i - 1];
      final current = community[i];
      final byUrgency = urgencyRank[previous.urgency]!.compareTo(
        urgencyRank[current.urgency]!,
      );
      expect(byUrgency, lessThanOrEqualTo(0));
      if (byUrgency == 0) {
        expect(
          previous.createdAt.isAfter(current.createdAt),
          isFalse,
          reason: 'older requests come first inside an urgency band',
        );
      }
    }
  });

  testWidgets('report rows offer warning and suspend, not dismiss', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: ChatModerationPage(currentUser: staff)),
      ),
    );
    await tester.pumpAndSettle();

    final reportsButton = find.textContaining('User reports').first;
    await tester.ensureVisible(reportsButton);
    await tester.pumpAndSettle();
    await tester.tap(reportsButton);
    await tester.pumpAndSettle();

    // The seeded report is on Rogel, so both moderation actions are present.
    expect(find.text('Issue warning'), findsWidgets);
    expect(find.text('Suspend'), findsWidgets);
    expect(find.text('Dismiss'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drive form pins the venue and auto-detects the barangay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: DriveManagementPage(currentUser: staff)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add drive').first);
    await tester.pumpAndSettle();

    expect(find.text('Pin the venue on the map'), findsOneWidget);
    await tester.tap(find.text('Pin the venue on the map'));
    await tester.pumpAndSettle();
    expect(find.text('Pin the drive venue'), findsOneWidget);
    expect(find.text('No location pinned yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('community requests board filters by lifecycle state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final donor = repo.userById('USR-001')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: RequestsPage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Any state'), findsOneWidget);
    // Lifecycle filter is a dropdown now; open it and pick a value.
    await tester.tap(find.text('Any state'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RequestStatus.pendingReview.label).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory tabs each carry filters', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
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

    // Units tab: blood type + status.
    expect(find.text('Blood type'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Blood type'), findsOneWidget);
    expect(find.text('Urgency'), findsOneWidget);
    expect(find.text('All urgencies'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);

    // The urgency filter is a real dropdown; pick Critical and make sure the
    // picker closes and applies without changing tab.
    await tester.tap(find.text('All urgencies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(RequestUrgency.critical.label).last);
    await tester.pumpAndSettle();
    expect(find.text('All urgencies'), findsNothing);
    expect(find.text('Requests'), findsWidgets);

    await tester.tap(find.text('Booked slots'));
    await tester.pumpAndSettle();
    expect(find.text('Slot state'), findsOneWidget);

    await tester.tap(find.text('Removed units'));
    await tester.pumpAndSettle();
    expect(find.text('Ledger state'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booked slots can be filtered to fulfilled and reopened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    final target = repo.scheduledRequests.firstWhere(
      (r) => r.canBeFulfilled,
      orElse: () => throw StateError('no fulfillable seeded slot'),
    );
    expect(repo.markRequestFulfilled(target.id, actorId: staff.id), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: InventoryManagementPage(currentUser: staff)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Booked slots'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All slots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fulfilled').last);
    await tester.pumpAndSettle();

    expect(find.text('Reopen (undo fulfilled)'), findsWidgets);
    await tester.tap(find.text('Reopen (undo fulfilled)').first);
    await tester.pumpAndSettle();

    expect(
      repo.requests.firstWhere((r) => r.id == target.id).status,
      isNot(RequestStatus.fulfilled),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a confirmed slot with no donor yet still offers an action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final staff = repo.userById('USR-010')!;
    // A donor-network request that is open (no donor chosen) still needs an
    // action on its booked-slot card, not a dead "Slot confirmed" pill.
    final open = repo.scheduledRequests.firstWhere(
      (r) => r.status == RequestStatus.open && !r.canBeFulfilled,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: InventoryManagementPage(currentUser: staff)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Booked slots'));
    await tester.pumpAndSettle();

    expect(find.text('Slot confirmed'), findsWidgets);
    expect(find.text('Awaiting donor'), findsWidgets);
    expect(open.canBeFulfilled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each role in the permissions card is its own dropdown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final admin = repo.userById('USR-011')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: AdminOverviewPage(user: admin)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Roles & permissions'), findsOneWidget);
    expect(find.text('Voluntary Donor'), findsWidgets);
    expect(find.text('Recipient / Patient Representative'), findsWidgets);
    // The signed-in role starts open; the others start collapsed so the card
    // stays scannable.
    expect(
      find.text('Appear in the donor directory while available'),
      findsNothing,
    );

    // Expanding one role must not expand the others or collapse the card.
    await tester.tap(find.text('Voluntary Donor').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Appear in the donor directory while available'),
      findsOneWidget,
    );
    expect(find.text('Recipient / Patient Representative'), findsWidgets);
    expect(
      find.text('Create and manage all accounts, including staff'),
      findsOneWidget,
    );

    // It is a dropdown: a second tap closes only that role again.
    await tester.tap(find.text('Voluntary Donor').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Appear in the donor directory while available'),
      findsNothing,
    );
    expect(
      find.text('Create and manage all accounts, including staff'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatar picker keeps staff and community sets apart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool showsAsset(String asset) => tester
        .widgetList<Image>(find.byType(Image))
        .any(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName == asset,
        );

    final staff = repo.userById('USR-010')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: ProfilePage(user: staff)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change avatar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('separate set'), findsOneWidget);
    expect(showsAsset('assets/images/avatars/avatar_037.png'), isTrue);
    expect(showsAsset('assets/images/avatars/avatar_001.png'), isFalse);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final donor = repo.userById('USR-001')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: ProfilePage(user: donor)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change avatar'));
    await tester.pumpAndSettle();
    expect(showsAsset('assets/images/avatars/avatar_001.png'), isTrue);
    expect(showsAsset('assets/images/avatars/avatar_037.png'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chapter mark ships the bundled Red Cross emblem', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(body: Center(child: ChapterMark(size: 48))),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/branding/prc_logo.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('readiness score shows targets and explains them on demand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(body: AdminOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('READINESS SCORE'), findsOneWidget);
    expect(find.text('of 100% max'), findsOneWidget);
    // The old "Live"/"Simulated data" chips were removed as noise.
    expect(find.text('Live'), findsNothing);
    expect(find.text('SIMULATED DATA'), findsNothing);

    // Every bar names the count against its target instead of a bare
    // percentage, and the KPI footnotes repeat the same denominator.
    expect(find.textContaining('of 32 units'), findsWidgets);
    expect(find.textContaining('of 20 donors'), findsWidgets);
    expect(find.textContaining('of 60 target'), findsWidgets);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('How the readiness score works'), findsOneWidget);
    expect(
      find.textContaining('planning target set by this chapter'),
      findsOneWidget,
    );
    expect(find.textContaining('30% of score'), findsOneWidget);
    expect(find.textContaining('Target: 0 open requests'), findsOneWidget);
    // The viewer here has no admin account, so targets stay read-only.
    expect(find.text('Set targets'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only an admin can set the readiness targets', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final admin = repo.userById('USR-011')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: AdminOverviewPage(user: admin)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set targets'));
    await tester.pumpAndSettle();
    expect(find.text('Set readiness targets'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));

    // The dialog edits denominators, not the score itself.
    await tester.enterText(fields.at(0), '40');
    await tester.enterText(fields.at(1), '25');
    await tester.enterText(fields.at(2), '10');
    await tester.enterText(fields.at(3), '80');
    await tester.tap(find.text('Save targets'));
    await tester.pumpAndSettle();

    expect(repo.readinessTargets.unitTarget, 40);
    expect(repo.readinessTargets.donorTarget, 25);
    expect(repo.readinessTargets.requestPressureCap, 10);
    expect(repo.readinessTargets.communityTarget, 80);
    expect(find.textContaining('of 40 units'), findsWidgets);
    expect(find.textContaining('of 25 donors'), findsWidgets);
    expect(find.textContaining('of 80 target'), findsWidgets);
    expect(
      repo.activityLog.any(
        (event) =>
            event.kind == ActivityKind.readinessTargets &&
            event.summary.contains('Updated readiness targets'),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview lists recent transfusions and account changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: const Scaffold(body: AdminOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent transfusions & account changes'), findsOneWidget);
    expect(
      find.textContaining('Recorded a packed RBC donation'),
      findsOneWidget,
    );
    expect(find.textContaining('Changed their profile photo'), findsOneWidget);

    await tester.ensureVisible(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(find.text('Chapter activity'), findsOneWidget);
    await tester.tap(find.text('Transfusions'));
    await tester.pumpAndSettle();
    // The Overview card stays behind the dialog, so the filter is checked
    // inside the dialog itself.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Changed their profile photo'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
