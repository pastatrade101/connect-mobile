import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/notifications.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/primitives.dart';

/// The things you need occasionally: account, alerts, and the configuration that
/// genuinely belongs on a bigger screen. Nothing appears here that this person's
/// permissions could not use.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.onSignedOut});
  final VoidCallback onSignedOut;

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
      Notifications.instance.startWatching();
    } else {
      Notifications.instance.stopWatching();
    }
    if (mounted) setState(() => _alerts = value);
  }

  @override
  Widget build(BuildContext context) {
    final session = Api.instance.session;
    if (_loading || session == null) return const Center(child: CircularProgressIndicator());

    // Portal-only destinations, each gated on the permission that governs it.
    final portalLinks = <({String label, String path, IconData icon, bool allowed})>[
      (label: 'Team', path: '/app/settings/team', icon: Icons.group_outlined, allowed: session.can('members:read')),
      (label: 'WhatsApp', path: '/app/whatsapp', icon: Icons.chat_outlined, allowed: session.can('whatsapp:read')),
      (
        label: 'Message templates',
        path: '/app/whatsapp/templates',
        icon: Icons.description_outlined,
        allowed: session.can('whatsapp:templates')
      ),
      (
        label: 'Integrations',
        path: '/app/developers',
        icon: Icons.code_rounded,
        allowed: session.can('api_keys:read')
      ),
      (
        label: 'Business settings',
        path: '/app/settings',
        icon: Icons.tune_rounded,
        allowed: session.can('tenant:read')
      ),
    ].where((l) => l.allowed).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        MobileHeader(title: 'More', subtitle: session.tenantName),

        GroupedList(
          children: [
            ListTile(
              minVerticalPadding: 14,
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: Brand.blueWash,
                child: Text(
                  initialsOf(session.userName),
                  style: const TextStyle(color: Brand.blue, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              title: Text(session.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
              subtitle: Text(session.userEmail, style: Theme.of(context).textTheme.bodySmall),
              trailing: StatusChip(label: _roleLabel(session.role)),
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
              title: const Text('New message alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'When a chat you hold gets a reply.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${Api.instance.baseUrl}${link.path}')),
                  ),
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
            icon: const Icon(Icons.logout_rounded, size: 18, color: Brand.danger),
            label: const Text('Sign out', style: TextStyle(color: Brand.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Brand.danger)),
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
