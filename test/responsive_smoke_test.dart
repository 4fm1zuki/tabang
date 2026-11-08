import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/models.dart';
import 'package:tabang/core/repository.dart';
import 'package:tabang/screens/admin/admin_overview.dart';
import 'package:tabang/screens/admin/admin_shell.dart';
import 'package:tabang/screens/donor/blood_bank_page.dart';
import 'package:tabang/screens/donor/discover_page.dart';
import 'package:tabang/screens/donor/donor_shell.dart';
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

    final book = find.text('Book appointment').first;
    await tester.ensureVisible(book);
    await tester.pumpAndSettle();
    await tester.tap(book);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Appointment with blood'),
      ),
      findsOneWidget,
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

    Badge messageBadge() => tester.widget<Badge>(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.byType(Badge),
          )
          .first,
    );

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

    // Slim rails are off in this host; the pin switch is enabled.
    expect(switchFor('Slim navigation rails').value, isFalse);
    expect(switchFor('Keep the sidebar pinned open').value, isTrue);

    await tester.tap(find.text('Slim navigation rails'));
    await tester.pumpAndSettle();
    expect(switchFor('Slim navigation rails').value, isTrue);

    // While slim rails are on the pin switch is disabled and explains why.
    final pinWhileSlim = switchFor('Keep the sidebar pinned open');
    expect(pinWhileSlim.value, isTrue);
    expect(pinWhileSlim.onChanged, isNull);
    expect(
      find.textContaining('Turn off slim navigation rails'),
      findsOneWidget,
    );

    await tester.tap(find.text('Slim navigation rails'));
    await tester.pumpAndSettle();
    expect(switchFor('Slim navigation rails').value, isFalse);

    await tester.tap(find.text('Keep the sidebar pinned open'));
    await tester.pumpAndSettle();
    expect(switchFor('Keep the sidebar pinned open').value, isFalse);
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
    return SettingsPage(
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
