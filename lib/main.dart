import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/api.dart';
import 'core/notifications.dart';
import 'core/motion.dart';
import 'core/theme.dart';
import 'core/workspace.dart';
import 'screens/create_enquiry_sheet.dart';
import 'screens/home_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/listings.dart';
import 'screens/login_screen.dart';
import 'screens/more_screen.dart';
import 'screens/thread_screen.dart';
import 'screens/trip_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/work_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nothing here may stop the app starting.
  //
  // These read stored preferences and register with the notification centre.
  // Any one of them can throw — a corrupt preferences file, a declined
  // permission, a platform channel that is not ready — and an exception before
  // runApp() terminates the process with no UI and no message. On a phone
  // launched from the Home Screen that looks exactly like a crash, because it is
  // one. A failed restore should cost a sign-in, never the whole app.
  try {
    await Api.instance.restore();
  } catch (error) {
    debugPrint('[startup] could not restore the session: $error');
  }
  try {
    await AppTheme.restore();
  } catch (error) {
    debugPrint('[startup] could not restore the theme: $error');
  }
  runApp(const MakutanoApp());

  // Deliberately NOT awaited before runApp().
  //
  // On iOS, initialize() carries requestAlertPermission, which puts up the
  // system permission dialog and does not return until it is answered. Awaiting
  // it here held the app on its launch screen — on a first run until the driver
  // tapped a button, and on every run for a platform-channel round trip. None of
  // it is needed to draw a frame, so it happens once the UI is on screen.
  // armAlerts() calls init() itself, and init() is idempotent via _ready.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await Notifications.instance.init();
    } catch (error) {
      debugPrint('[startup] notifications unavailable: $error');
    }
  });
}

/// Real push if this build has a Firebase project and the device can register;
/// polling if it cannot. Callers never have to know which one they got.
Future<void> armAlerts() async {
  final pushed = await Notifications.instance.connectPush();
  if (!pushed) Notifications.instance.startWatching();
}

class MakutanoApp extends StatefulWidget {
  const MakutanoApp({super.key});

  @override
  State<MakutanoApp> createState() => _MakutanoAppState();
}

class _MakutanoAppState extends State<MakutanoApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final StreamSubscription<String> _taps;

  @override
  void initState() {
    super.initState();
    _taps = Notifications.instance.onOpenConversation.listen(_openThread);
    if (Api.instance.signedIn) armAlerts();
  }

  @override
  void dispose() {
    _taps.cancel();
    super.dispose();
  }

  void _openThread(String conversationId) {
    _navigator.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => ThreadScreen(conversationId: conversationId)),
    );
  }

  void _afterSignIn() {
    armAlerts();
    _navigator.currentState?.pushReplacement(MaterialPageRoute<void>(builder: (_) => const Shell()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Makutano Connect',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigator,
        theme: buildTheme(brightness: Brightness.light),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: mode,
        home: Api.instance.signedIn ? const Shell() : LoginScreen(onSignedIn: _afterSignIn),
      ),
    );
  }
}

/// Home · Inbox · + · Trips · Work.
///
/// Five destinations chosen from what staff do all day, with creation in the middle
/// where a thumb reaches. Anything the workspace or the permissions cannot use is
/// not rendered at all — the tab simply does not exist for that person.
///
/// The account page is NOT one of them. It is the avatar in every header, and a
/// destination already one tap away does not need a second of five slots on a
/// phone — so for an operator the last slot carries the work feed instead, which
/// otherwise had no tab at all. Someone without trips still gets it as a tab,
/// because Work already owns the fourth slot for them and there is nothing else
/// to put in the fifth.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _inboxKey = GlobalKey<InboxScreenState>();
  final _workKey = GlobalKey<WorkScreenState>();
  final _tripsKey = GlobalKey<TripsScreenState>();

  /// Does the fourth tab show Trips or Work?
  ///
  /// For a tour operator the operational screen IS trips — that is the job the
  /// app exists for once a sale is closed. Everyone else keeps the work feed,
  /// and Work stays one tap from Home either way, so nothing is lost.
  bool get _tripsTab {
    final session = Api.instance.session;
    if (session == null) return false;
    final workspace = workspaceOf(session.workspace);
    final relevant = workspace == Workspace.bookings || workspace == Workspace.hybrid;
    return relevant && session.can('trips:read');
  }

  void _openTrip(String tripId) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => TripScreen(tripId: tripId)))
        .then((_) => _tripsKey.currentState?.load());
  }

  void _openThread(String conversationId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ThreadScreen(conversationId: conversationId))).then((_) {
      _inboxKey.currentState?.load();
      _homeKey.currentState?.load();
    });
  }

  void _openInbox({String filter = 'all'}) {
    setState(() => _tab = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _inboxKey.currentState?.applyFilter(filter));
  }

  /// The full shopfront, pushed rather than given a tab.
  ///
  /// Home already carries the listings an operator looks at daily; this is the
  /// rest of them, and it does not earn a permanent seat in a four-item nav.
  void _openListings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: appBackground(context),
            child: SafeArea(
              bottom: false,
              child: Builder(builder: (routeContext) => ListingsScreen(onBack: () => Navigator.of(routeContext).pop())),
            ),
          ),
        ),
      ),
    );
  }

  /// Which slot the work feed lives in — the fifth for an operator, the fourth
  /// for everyone else, because Trips takes the fourth when it is relevant.
  int get _workTab => _tripsTab ? 4 : 3;

  void _openWork({String? kind}) {
    setState(() => _tab = _workTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _workKey.currentState?.focusKind(kind);
      _workKey.currentState?.load();
    });
  }

  /// The account page, from the avatar in a header.
  ///
  /// A tab where there is a slot for one, a pushed screen where the work feed
  /// took it. Either way the avatar is the only way in, which is what freed the
  /// slot in the first place.
  void _openAccount() {
    if (!_tripsTab) {
      setState(() => _tab = 4);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: appBackground(context),
            child: SafeArea(
              bottom: false,
              child: Builder(
                builder: (routeContext) =>
                    MoreScreen(onSignedOut: _signedOut, onBack: () => Navigator.of(routeContext).pop()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _runAction(String key) {
    switch (key) {
      case 'enquiry':
        final noun = workspaceOf(Api.instance.session?.workspace ?? '') == Workspace.service ? 'request' : 'enquiry';
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => CreateEnquirySheet(noun: noun, onOpenThread: _openThread),
        ).then((_) {
          _homeKey.currentState?.load();
          _workKey.currentState?.load();
        });
      case 'order':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${Api.instance.baseUrl}/app/orders/new')));
      case 'inbox':
        _openInbox();
    }
  }

  void _openQuickCreate() {
    final session = Api.instance.session;
    if (session == null) return;
    final actions = quickActionsFor(session);
    if (actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account cannot create records')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => QuickCreateSheet(
        actions: actions,
        onPick: (key) {
          Navigator.pop(sheetContext);
          _runAction(key);
        },
      ),
    );
  }

  void _signedOut() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          onSignedIn: () {
            armAlerts();
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const Shell()));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // The gradient is the scaffold's own ground so it sits behind every tab and
      // behind the floating nav, rather than being repainted per screen.
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: appBackground(context),
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                key: _homeKey,
                onOpenThread: _openThread,
                onOpenInbox: _openInbox,
                onOpenWork: _openWork,
                onOpenListings: _openListings,
                onQuickAction: _runAction,
                onOpenAccount: _openAccount,
              ),
              InboxScreen(key: _inboxKey, onOpenThread: _openThread, onOpenAccount: _openAccount),
              const SizedBox.shrink(), // the centre button opens a sheet, never a page
              _tripsTab
                  ? TripsScreen(key: _tripsKey, onOpenTrip: _openTrip, onOpenAccount: _openAccount)
                  : WorkScreen(key: _workKey, onCreate: _runAction, onOpenAccount: _openAccount),
              _tripsTab
                  ? WorkScreen(key: _workKey, onCreate: _runAction, onOpenAccount: _openAccount)
                  : MoreScreen(onSignedOut: _signedOut),
            ],
          ),
        ),
      ),
      // A floating pill rather than a bar welded to the bottom edge: the content
      // runs under it, which is what makes the gradient ground visible at all.
      extendBody: true,
      // Deliberately not inside a SafeArea: the bar sits down in the curve of the
      // screen rather than above the home indicator, so the inset is the same
      // small gutter on all three sides and the shape reads as concentric with
      // the device corner. The indicator draws over the gutter below it, which is
      // what a system tab bar does too.
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(NavBar.gutter, 0, NavBar.gutter, NavBar.gutter),
        // The box is tall enough to hold the raised + as well as the pill. A
        // Stack does not receive taps outside its own bounds, so the lift has to
        // be real height rather than an overflow, or the button stops working
        // exactly where it looks most obviously tappable.
        child: SizedBox(
          height: NavBar.height + NavBar.fabLift,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: NavBar.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NavBar.radius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dark ? Brand.darkSurface.withValues(alpha: 0.82) : Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(NavBar.radius),
                        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.08) : Brand.line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.12),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      // The bar is a fixed height; its labels must not grow past
                      // what that can hold, or every tab clips.
                      child: ChromeText(
                        child: Row(
                          // Stretch, so each tab's tap target is the full height of
                          // the bar and not just the height of its icon and label.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NavItem(
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home_rounded,
                              label: 'Home',
                              selected: _tab == 0,
                              onTap: () => setState(() => _tab = 0),
                            ),
                            _NavItem(
                              icon: Icons.forum_outlined,
                              activeIcon: Icons.forum_rounded,
                              label: 'Inbox',
                              selected: _tab == 1,
                              onTap: () => _openInbox(),
                            ),
                            // The middle slot draws nothing — the + rides above the
                            // pill — but it still claims a fifth of the row, so the
                            // four labels stay evenly spaced either side of it and
                            // the button lands on the bar's true centre. It takes
                            // taps as well: the button's circle stops short of the
                            // bar's bottom edge, and a tap just under it obviously
                            // means "create" rather than nothing at all.
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openQuickCreate,
                                child: const SizedBox.expand(),
                              ),
                            ),
                            _NavItem(
                              icon: _tripsTab ? Icons.map_outlined : Icons.assignment_outlined,
                              activeIcon: _tripsTab ? Icons.map_rounded : Icons.assignment_rounded,
                              label: _tripsTab ? 'Trips' : 'Work',
                              selected: _tab == 3,
                              onTap: () {
                                if (!_tripsTab) return _openWork();
                                setState(() => _tab = 3);
                                WidgetsBinding.instance.addPostFrameCallback((_) => _tripsKey.currentState?.load());
                              },
                            ),
                            _NavItem(
                              icon: _tripsTab ? Icons.assignment_outlined : Icons.more_horiz_rounded,
                              activeIcon: _tripsTab ? Icons.assignment_rounded : Icons.more_horiz_rounded,
                              label: _tripsTab ? 'Work' : 'More',
                              selected: _tab == 4,
                              onTap: () {
                                if (_tripsTab) return _openWork();
                                setState(() => _tab = 4);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Creation is an action, not a destination — so it is not a tab at
              // all: a round button riding above the bar, in the one place
              // nothing else can be.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(child: _CreateButton(onTap: _openQuickCreate)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The raised +.
///
/// Round where the tabs are square, lifted where they are flat, and ringed in the
/// bar's own surface so it reads as sitting on top of the pill rather than being
/// punched through it.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blue = Tone.accent(context);
    final dark = Tone.isDark(context);

    return Semantics(
      label: 'New',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: NavBar.fabSize,
          height: NavBar.fabSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [blue, Color.lerp(blue, Colors.black, 0.24)!],
            ),
            border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.white, width: 3),
            boxShadow: [
              // The coloured glow is what makes it read as lifted rather than
              // merely large; the black shadow underneath keeps it legible on the
              // pale ground, where a blue glow alone disappears.
              BoxShadow(color: blue.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.45 : 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;

  /// Drawn under the icon, and the tab's semantics label.
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Tone.accent(context);
    final tint = selected ? accent : Tone.muted(context);

    // Equal flex across all five slots — the four tabs and the empty middle — is
    // what keeps the + on the true centre and the labels evenly spaced.
    return Expanded(
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Motion.quick,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? Tone.wash(context, accent) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(selected ? activeIcon : icon, size: 26, color: tint),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: Motion.quick,
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  letterSpacing: 0.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: tint,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
