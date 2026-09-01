import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/notifications.dart';
import '../main.dart' show armAlerts;
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/primitives.dart';
import '../widgets/skeleton.dart';

/// The things you need occasionally: account, alerts, and the configuration that
/// genuinely belongs on a bigger screen. Nothing appears here that this person's
/// permissions could not use.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.onSignedOut, this.onBack});
  final VoidCallback onSignedOut;

  /// Set when this arrives as a pushed screen rather than a tab.
  ///
  /// An operator reaches it from the avatar in the header, because the bottom
  /// bar has five slots and a destination already reachable in one tap is not
  /// worth one of them.
  final VoidCallback? onBack;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _alerts = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _alerts = prefs.getBool('notifications') ?? true;
      _loading = false;
    });
  }

  Future<void> _setAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    if (value) {
      await Notifications.instance.init();
      await armAlerts();
    } else {
      Notifications.instance.stopWatching();
    }
    if (mounted) setState(() => _alerts = value);
  }

  @override
  Widget build(BuildContext context) {
    final session = Api.instance.session;
    if (_loading || session == null) {
      return const Padding(padding: EdgeInsets.only(top: 16), child: SkeletonRows(rows: 6, disc: false));
    }

    // Portal-only destinations, each gated on the permission that governs it.
    final portalLinks = <({String label, String path, IconData icon, bool allowed})>[
      (label: 'Team', path: '/app/settings/team', icon: Icons.group_outlined, allowed: session.can('members:read')),
      (label: 'WhatsApp', path: '/app/whatsapp', icon: Icons.chat_outlined, allowed: session.can('whatsapp:read')),
      (
        label: 'Message templates',
        path: '/app/whatsapp/templates',
        icon: Icons.description_outlined,
        allowed: session.can('whatsapp:templates'),
      ),
      (label: 'Integrations', path: '/app/developers', icon: Icons.code_rounded, allowed: session.can('api_keys:read')),
      (
        label: 'Business settings',
        path: '/app/settings',
        icon: Icons.tune_rounded,
        allowed: session.can('tenant:read'),
      ),
    ].where((l) => l.allowed).toList();

    // Header outside the scroll view, so it stays put like Home's and Inbox's.
    return Column(
      children: [
        MobileHeader(title: 'More', subtitle: session.tenantName, onBack: widget.onBack),
        Expanded(
          child: ListView(
            // Clear the floating nav, raised + included.
            padding: const EdgeInsets.only(bottom: NavBar.clearance),
            children: [
              GroupedList(
                children: [
                  ListTile(
                    minVerticalPadding: 14,
                    leading: Avatar(
                      url: session.operatorLogoUrl,
                      initials: initialsOf(session.operatorName ?? session.tenantName),
                      radius: 22,
                    ),
                    title: Text(session.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                    subtitle: Text(session.userEmail, style: Theme.of(context).textTheme.bodySmall),
                    trailing: StatusChip(label: _roleLabel(session.role)),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const GroupLabel(text: 'Appearance'),
              GroupedList(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: ValueListenableBuilder<ThemeMode>(
                      valueListenable: AppTheme.mode,
                      builder: (context, mode, _) => SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.phone_iphone_rounded, size: 17),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode_rounded, size: 17),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode_rounded, size: 17),
                            ),
                          ],
                          selected: {mode},
                          showSelectedIcon: false,
                          onSelectionChanged: (next) => AppTheme.set(next.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: Tone.accent(context),
                            selectedForegroundColor: Colors.white,
                            side: BorderSide(color: Tone.line(context)),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const GroupLabel(text: 'Alerts'),
              GroupedList(
                children: [
                  SwitchListTile(
                    value: _alerts,
                    onChanged: _setAlerts,
                    title: const Text(
                      'New message alerts',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('When a chat you hold gets a reply.', style: Theme.of(context).textTheme.bodySmall),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const GroupLabel(text: 'Workspace'),
              GroupedList(
                children: [
                  _Row(label: 'Business', value: session.tenantName),
                  _Row(label: 'Works with', value: _workspaceLabel(workspaceOf(session.workspace))),
                  _Row(label: 'Server', value: Api.instance.baseUrl.replaceFirst(RegExp(r'^https?://'), '')),
                ],
              ),

              if (portalLinks.isNotEmpty) ...[
                const SizedBox(height: 18),
                const GroupLabel(text: 'Manage in the portal'),
                GroupedList(
                  children: [
                    for (final link in portalLinks)
                      ListTile(
                        minVerticalPadding: 12,
                        leading: Icon(link.icon, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
                        title: Text(link.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.north_east_rounded, size: 16),
                        onTap: () => ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('${Api.instance.baseUrl}${link.path}'))),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Text(
                    'Company configuration stays on the big screen, where there is room to read it before changing it.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: OutlinedButton.icon(
                  onPressed: _confirmSignOut,
                  icon: Icon(Icons.logout_rounded, size: 18, color: Tone.danger(context)),
                  label: Text('Sign out', style: TextStyle(color: Tone.danger(context))),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Tone.danger(context))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will stop receiving message alerts on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;
    Notifications.instance.stopWatching();
    await Api.instance.signOut();
    widget.onSignedOut();
  }

  static String _roleLabel(String role) => switch (role) {
    'OWNER' => 'Owner',
    'ADMIN' => 'Admin',
    'BOOKING_AGENT' => 'Manager',
    'SALES' => 'Agent',
    'VIEWER' => 'Viewer',
    _ => role,
  };

  static String _workspaceLabel(Workspace workspace) => switch (workspace) {
    Workspace.bookings => 'Bookings & enquiries',
    Workspace.orders => 'Customer orders',
    Workspace.service => 'Enquiries & quotations',
    Workspace.hybrid => 'Bookings and orders',
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
          ),
        ],
      ),
    );
  }
}
