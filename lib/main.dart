import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api.dart';
import 'core/notifications.dart';
import 'core/theme.dart';
import 'core/workspace.dart';
import 'screens/create_enquiry_sheet.dart';
import 'screens/home_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/login_screen.dart';
import 'screens/more_screen.dart';
import 'screens/thread_screen.dart';
import 'screens/work_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.restore();
  await Notifications.instance.init();
  runApp(const MakutanoApp());
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
    return MaterialApp(
      title: 'Makutano Connect',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      theme: buildTheme(brightness: Brightness.light),
      darkTheme: buildTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: Api.instance.signedIn ? const Shell() : LoginScreen(onSignedIn: _afterSignIn),
    );
  }
}

/// Home · Inbox · + · Work · More.
///
/// Five destinations chosen from what staff do all day, with creation in the middle
/// where a thumb reaches. Anything the workspace or the permissions cannot use is
/// not rendered at all — the tab simply does not exist for that person.
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

  void _openWork({String? kind}) {
    setState(() => _tab = 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _workKey.currentState?.focusKind(kind);
      _workKey.currentState?.load();
    });
  }

  void _runAction(String key) {
    switch (key) {
      case 'enquiry':
        final noun = workspaceOf(Api.instance.session?.workspace ?? '') == Workspace.service
            ? 'request'
            : 'enquiry';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${Api.instance.baseUrl}/app/orders/new')));
      case 'inbox':
        _openInbox();
    }
  }

  void _openQuickCreate() {
    final session = Api.instance.session;
    if (session == null) return;
    final actions = quickActionsFor(session);
    if (actions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your account cannot create records')));
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
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            HomeScreen(
              key: _homeKey,
              onOpenThread: _openThread,
              onOpenInbox: _openInbox,
              onOpenWork: _openWork,
              onQuickAction: _runAction,
              onOpenAccount: () => setState(() => _tab = 4),
            ),
            InboxScreen(key: _inboxKey, onOpenThread: _openThread),
            const SizedBox.shrink(), // the centre button opens a sheet, never a page
            WorkScreen(key: _workKey, onCreate: _runAction),
            MoreScreen(onSignedOut: _signedOut),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: dark ? Brand.darkSurface : Brand.surface,
          border: Border(top: BorderSide(color: dark ? Brand.darkLine : Brand.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
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
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _openQuickCreate,
                      child: Container(
                        width: 50,
                        height: 40,
                        decoration: BoxDecoration(color: Brand.blue, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  label: 'Work',
                  selected: _tab == 3,
                  onTap: () => _openWork(),
                ),
                _NavItem(
                  icon: Icons.more_horiz_rounded,
                  activeIcon: Icons.more_horiz_rounded,
                  label: 'More',
                  selected: _tab == 4,
                  onTap: () => setState(() => _tab = 4),
                ),
              ],
            ),
          ),
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
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 22, color: selected ? Brand.blue : muted),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Brand.blue : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
