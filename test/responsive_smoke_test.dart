import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/models.dart';
import 'package:tabang/core/repository.dart';
import 'package:tabang/screens/admin/admin_overview.dart';
import 'package:tabang/screens/admin/admin_shell.dart';
import 'package:tabang/screens/admin/inventory_management.dart';
import 'package:tabang/screens/auth/login_screen.dart';
import 'package:tabang/screens/donor/blood_bank_page.dart';
import 'package:tabang/screens/donor/discover_page.dart';
import 'package:tabang/screens/donor/donor_shell.dart';
import 'package:tabang/screens/donor/find_donor_page.dart';
import 'package:tabang/screens/shared/settings_page.dart';
import 'package:tabang/theme.dart';

/// Narrow-screen smoke tests for the three densest surfaces.
///
/// These do not try to reproduce a full device; they pin the logical viewport
/// to a small phone and fail on the RenderFlex overflow that a desktop-first
/// layout would otherwise hide until release.
void main() {
  final repo = TabangRepository.instance;

  setUp(repo.resetForTesting);

  Future<void> usePhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(Widget child) {
    return MaterialApp(
      theme: TabangTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('login form scrolls on a phone without a stray scrollbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: LoginScreen(
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // One slim, transient rail — not the persistent Material scrollbar that
    // used to sit down the edge of the phone-sized window.
    expect(find.byKey(const ValueKey('loginScrollbar')), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    final scrollbar = tester.widget<Scrollbar>(
      find.byKey(const ValueKey('loginScrollbar')),
    );
    expect(scrollbar.thickness, 4);
    expect(scrollbar.interactive, isFalse);

    // The form still scrolls all the way to the demo accounts.
    await tester.drag(
      find.byKey(const ValueKey('loginScrollView')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('DEMO ACCOUNTS'), findsOneWidget);

    await tester.ensureVisible(find.text('juan.delacruz@tabang.app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('juan.delacruz@tabang.app'));
    await tester.pumpAndSettle();
    // Tapping the demo row fills the email field (the row label stays put, so
    // the text itself now appears twice).
    final email = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(email.controller.text, 'juan.delacruz@tabang.app');
  });

  testWidgets('home rails and cards fit a 360 px phone', (tester) async {
    await usePhone(tester);
    final user = repo.userById('USR-038')!;

    await tester.pumpWidget(host(DiscoverPage(user: user)));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blood bank table, selection bar and dialog fit a phone', (
    tester,
  ) async {
    await usePhone(tester);
    final user = repo.userById('USR-038')!;

    await tester.pumpWidget(host(BloodBankPage(user: user)));
    await tester.pumpAndSettle();

    expect(find.text('Blood Bank'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The table is horizontally scrollable, but its checkbox column stays
    // reachable so a phone user can still select a unit.
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(find.text('1 unit selected'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final request = find.text('Request blood').first;
    await tester.ensureVisible(request);
    await tester.pumpAndSettle();
    await tester.tap(request);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Post a blood request'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // Scheduling regression: picking Saturday must rebuild the Time list to
    // the published half-day hours (8–11), not keep a weekday hour that the
    // selected day does not offer.
    final dayDropdown = find.byType(DropdownButton<DateTime>);
    await tester.ensureVisible(dayDropdown);
    await tester.pumpAndSettle();
    await tester.tap(dayDropdown);
    await tester.pumpAndSettle();
    // "Sat," only matches the menu labels ("Sat, Nov 14"); the schedule blurb
    // uses "Sat 8–11" and must not be tapped.
    await tester.tap(find.textContaining('Sat,').first);
    await tester.pumpAndSettle();

    final timeDropdown = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    );
    final saturday = repo
        .bloodBankSlots(days: 14)
        .where((slot) => slot.weekday == DateTime.saturday)
        .first;
    expect(
      timeDropdown.items!.map((item) => item.value).toList(),
      TabangRepository.bloodBankSaturdayHours,
    );
    expect(timeDropdown.value, saturday.hour);
    expect(tester.takeException(), isNull);
  });

  testWidgets('find donor map switch and list fit a 360 px phone', (
    tester,
  ) async {
    await usePhone(tester);
    final donor = repo.userById('USR-001')!;
    await tester.pumpWidget(host(FindDonorPage(user: donor)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The blood-type row is wider than a phone; a visible scrollbar is the
    // only cue that more chips sit off-screen.
    expect(find.byKey(const ValueKey('mapChipScrollbar')), findsOneWidget);

    // The split handle belongs to the map/list boundary, not the Donors tab:
    // it stays available on Facilities and Drives too.
    final splitHandle = find.byKey(const ValueKey('mapSplitHandle'));
    final donationTabs = find.byType(SegmentedButton<int>);
    await tester.tap(
      find.descendant(of: donationTabs, matching: find.text('Facilities')),
    );
    await tester.pumpAndSettle();
    expect(splitHandle, findsOneWidget);
    await tester.tap(
      find.descendant(of: donationTabs, matching: find.text('Drives')),
    );
    await tester.pumpAndSettle();
    expect(splitHandle, findsOneWidget);
    await tester.tap(
      find.descendant(of: donationTabs, matching: find.text('Donors')),
    );
    await tester.pumpAndSettle();

    // Pull the divider down: map-only with a "Show donor list" bubble.
    await tester.drag(splitHandle, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Show donor list'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tapping the bubble restores the half split.
    await tester.tap(find.byTooltip('Show donor list'));
    await tester.pumpAndSettle();
    expect(find.text('Show donor list'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory booked slots fit a 360 px phone', (tester) async {
    await usePhone(tester);
    final staff = repo.userById('USR-010')!;

    await tester.pumpWidget(host(InventoryManagementPage(currentUser: staff)));
    await tester.pumpAndSettle();

    final booked = find.textContaining('Booked slots');
    await tester.ensureVisible(booked);
    await tester.pumpAndSettle();
    await tester.tap(booked);
    await tester.pumpAndSettle();

    expect(find.text('Awaiting verification'), findsWidgets);
    expect(find.text('Verify slot'), findsWidgets);
    expect(tester.takeException(), isNull);

    // The restyled request queue and the removed-units ledger fit too. The
    // tab row sits above the queue, so scroll it back into view first.
    final requestsTab = find.text('Requests');
    await tester.ensureVisible(requestsTab);
    await tester.pumpAndSettle();
    await tester.tap(requestsTab);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final removedTab = find.textContaining('Removed units');
    await tester.ensureVisible(removedTab);
    await tester.pumpAndSettle();
    await tester.tap(removedTab);
    await tester.pumpAndSettle();
    expect(
      find.text('No removed units'),
      findsOneWidget,
      reason: 'a fresh session has no ledger removals',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics hierarchy fits a 360 px phone', (tester) async {
    await usePhone(tester);

    await tester.pumpWidget(host(const AdminOverviewPage()));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed sidebar keeps its icons centred in the rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: DonorShell(
          user: repo.userById('USR-001')!,
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pinned by default at desktop width; unpin to reach the icon-only rail.
    await tester.tap(find.byTooltip('Unpin sidebar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // The rail item and its icon must share a centre. The old build kept the
    // selection accent bar in the collapsed layout, which pushed the icon (and
    // the pill) off-centre. Blood Bank is used because the selected
    // destination renders its filled icon variant.
    final itemRect = tester.getRect(find.byTooltip('Blood Bank'));
    final iconRect = tester.getRect(find.byIcon(Icons.inventory_2_outlined));
    expect((iconRect.center.dx - itemRect.center.dx).abs(), lessThan(1.5));
    expect((iconRect.center.dy - itemRect.center.dy).abs(), lessThan(1.5));
    expect(itemRect.width, lessThan(80));
    expect(tester.takeException(), isNull);

    // Collapsing the rail used to remove the only pin control with it, so an
    // unpinned rail could never be pinned open again. The compact pin stays
    // reachable under the logo.
    expect(find.byTooltip('Pin sidebar'), findsOneWidget);
    await tester.tap(find.byTooltip('Pin sidebar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.byTooltip('Unpin sidebar'), findsOneWidget);
    // The branded header only renders once the rail has slid back open.
    expect(find.text('Digos City'), findsOneWidget);
    expect(find.byTooltip('Pin sidebar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin rail can be pinned open again from the collapsed state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: AdminShell(
          user: repo.userById('USR-011')!,
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Unpin sidebar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byTooltip('Pin sidebar'), findsOneWidget);

    await tester.tap(find.byTooltip('Pin sidebar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byTooltip('Unpin sidebar'), findsOneWidget);
    expect(find.text('Chapter console'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff phone bar fits now that Moderation moved into Users', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: AdminShell(
          user: repo.userById('USR-011')!,
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Four destinations fit a phone, so the bar needs no scroll indicator; the
    // moderation queue is reached from inside Users instead.
    expect(find.byKey(const ValueKey('adminPhoneNavScrollbar')), findsNothing);
    expect(find.text('Users'), findsWidgets);
    expect(find.text('Moderation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slim rails setting hides the bottom-bar labels', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(
      host(
        DonorShell(
          user: repo.userById('USR-001')!,
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
          compactNav: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
    // Icons stay; the names under them disappear.
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.home),
      ),
      findsOneWidget,
    );
    // The label widget stays in the tree (Material keeps it for semantics)
    // but is faded to zero, so the name is not visible under the icon.
    final labelFade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text('Home'),
            ),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(labelFade.opacity.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('message badge clears when the conversation is read', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(
      host(
        DonorShell(
          user: repo.userById('USR-001')!,
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Other destinations now carry unlabeled "new activity" dots, so pick the
    // navigation badge that actually carries the message count label.
    Badge messageBadge() => tester
        .widgetList<Badge>(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byType(Badge),
          ),
        )
        .firstWhere((badge) => badge.label != null);

    expect(repo.unreadMessageCountFor('USR-001'), 2);
    expect(messageBadge().isLabelVisible, isTrue);

    // Reading a conversation notifies the repository; the shell listens so the
    // rail and bottom-bar badge clear without a tab switch.
    repo.markThreadRead('ROOM-101', 'USR-001');
    await tester.pumpAndSettle();

    expect(messageBadge().isLabelVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone bottom bar hides while scrolling and returns on scroll up',
    (tester) async {
      await usePhone(tester);
      await tester.pumpWidget(
        host(
          DonorShell(
            user: repo.userById('USR-001')!,
            themeMode: ThemeMode.light,
            onThemeModeChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The six destinations need more than 360 px, so the bar scrolls and
      // carries a scrollbar at its top edge.
      expect(
        find.byKey(const ValueKey('donorPhoneNavScrollbar')),
        findsOneWidget,
      );

      double barHeight() => tester
          .getSize(find.byKey(const ValueKey('phoneNavigationBar')))
          .height;
      expect(barHeight(), 80);

      final feed = find
          .descendant(
            of: find.byType(DiscoverPage),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;

      await tester.drag(feed, const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(barHeight(), 0, reason: 'scrolling toward the end hides the bar');

      await tester.drag(feed, const Offset(0, 140));
      await tester.pumpAndSettle();
      expect(barHeight(), 80, reason: 'scrolling back up restores the bar');

      // Fling to the very end. Once the page cannot scroll further down the
      // bar must pin itself instead of leaving the user without navigation.
      await tester.fling(feed, const Offset(0, -6000), 6000);
      await tester.pumpAndSettle();
      expect(
        barHeight(),
        80,
        reason: 'the bar returns at the bottom of the list',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pinning the phone bar keeps it visible on long swipes', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(
      host(
        DonorShell(
          user: repo.userById('USR-001')!,
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    double barHeight() =>
        tester.getSize(find.byKey(const ValueKey('phoneNavigationBar'))).height;

    final feed = find
        .descendant(
          of: find.byType(DiscoverPage),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    // The pin moved off the header and into the account menu.
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin bottom bar'));
    await tester.pumpAndSettle();

    await tester.drag(feed, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(
      barHeight(),
      80,
      reason: 'a pinned bar ignores the swipe-up hide gesture',
    );

    // Unpin, return to the top, and confirm the normal auto-hide is back.
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin bottom bar'));
    await tester.pumpAndSettle();

    await tester.drag(feed, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.drag(feed, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(barHeight(), 0, reason: 'without the pin the bar hides again');
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switches update immediately', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: Scaffold(body: _SettingsHost(user: repo.userById('USR-001')!)),
      ),
    );
    await tester.pumpAndSettle();

    Switch switchFor(String label) {
      final row = find
          .ancestor(of: find.text(label), matching: find.byType(Row))
          .first;
      return tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
    }

    // The rail pin lives in the sidebar; Settings only carries the slim
    // switch, so there is no disabled control to click on.
    expect(switchFor('Slim navigation rails').value, isFalse);
    expect(find.text('Keep the sidebar pinned open'), findsNothing);
    expect(find.text('slim=off pin=on'), findsOneWidget);

    await tester.tap(find.text('Slim navigation rails'));
    await tester.pumpAndSettle();
    expect(switchFor('Slim navigation rails').value, isTrue);
    // Enabling slim rails unpins the sidebar so the two controls agree.
    expect(find.text('slim=on pin=off'), findsOneWidget);

    await tester.tap(find.text('Slim navigation rails'));
    await tester.pumpAndSettle();
    expect(switchFor('Slim navigation rails').value, isFalse);
    // The rail stays unpinned until the sidebar pin is used.
    expect(find.text('slim=off pin=off'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar pin reopens the rail from slim mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TabangTheme.light,
        home: _ShellHost(user: repo.userById('USR-001')!),
      ),
    );
    await tester.pumpAndSettle();

    // Slim rails on, sidebar unpinned: icon-only rail, pin still reachable.
    expect(find.byTooltip('Pin sidebar'), findsOneWidget);
    expect(find.text('Digos City'), findsNothing);

    await tester.tap(find.byTooltip('Pin sidebar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // Pinning exits slim, so the rail slides open with its labels.
    expect(find.text('Digos City'), findsOneWidget);
    expect(find.byTooltip('Unpin sidebar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Minimal owner for the settings preference props, mirroring how the root
/// app and the shells share them.
class _SettingsHost extends StatefulWidget {
  const _SettingsHost({required this.user});

  final AppUser user;

  @override
  State<_SettingsHost> createState() => _SettingsHostState();
}

class _SettingsHostState extends State<_SettingsHost> {
  ThemeMode theme = ThemeMode.light;
  bool compactNav = false;
  bool railPinned = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'slim=${compactNav ? 'on' : 'off'} pin=${railPinned ? 'on' : 'off'}',
        ),
        Expanded(
          child: SettingsPage(
            user: widget.user,
            themeMode: theme,
            onThemeModeChanged: (value) => setState(() => theme = value),
            compactNav: compactNav,
            onCompactNavChanged: (value) => setState(() => compactNav = value),
            railPinned: railPinned,
            onRailPinnedChanged: (value) => setState(() => railPinned = value),
          ),
        ),
      ],
    );
  }
}

/// Root-like owner for a real shell, so the sidebar pin can be exercised the
/// way the app wires it: compactNav and railPinned shared with one owner.
class _ShellHost extends StatefulWidget {
  const _ShellHost({required this.user});

  final AppUser user;

  @override
  State<_ShellHost> createState() => _ShellHostState();
}

class _ShellHostState extends State<_ShellHost> {
  ThemeMode theme = ThemeMode.light;
  bool compactNav = true;
  bool railPinned = false;

  @override
  Widget build(BuildContext context) {
    return DonorShell(
      user: widget.user,
      themeMode: theme,
      onThemeModeChanged: (value) => setState(() => theme = value),
      compactNav: compactNav,
      onCompactNavChanged: (value) => setState(() => compactNav = value),
      railPinned: railPinned,
      onRailPinnedChanged: (value) => setState(() => railPinned = value),
    );
  }
}
