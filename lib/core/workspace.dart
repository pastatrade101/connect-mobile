import 'package:flutter/material.dart';

import 'api.dart';

/// What this business does, and therefore what the app offers.
///
/// The same rule the portal uses: relevance is not authorization. This decides what
/// a workspace *cares about*; the server still enforces every permission behind it,
/// and nothing here can grant access the session does not already have.
enum Workspace { bookings, orders, service, hybrid }

Workspace workspaceOf(String raw) => switch (raw) {
      'BOOKINGS' => Workspace.bookings,
      'ORDERS' => Workspace.orders,
      'SERVICE' => Workspace.service,
      _ => Workspace.hybrid,
    };

class QuickAction {
  const QuickAction({
    required this.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.primary = false,
  });

  final String key;
  final String label;
  final String hint;
  final IconData icon;
  final bool primary;
}

/// Quick-create, resolved from workspace × permission. A tour operator is never
/// offered "New order"; a shop is never offered "New enquiry".
List<QuickAction> quickActionsFor(Session session) {
  final workspace = workspaceOf(session.workspace);
  final actions = <QuickAction>[];

  final takesEnquiries = workspace != Workspace.orders;
  final takesOrders = workspace == Workspace.orders || workspace == Workspace.hybrid;

  if (takesEnquiries && session.can('booking_requests:write')) {
    actions.add(QuickAction(
      key: 'enquiry',
      label: workspace == Workspace.service ? 'New request' : 'New enquiry',
      hint: 'Log what a customer asked for',
      icon: Icons.bookmark_add_outlined,
      primary: true,
    ));
  }
  if (takesOrders && session.can('orders:write')) {
    actions.add(QuickAction(
      key: 'order',
      label: 'New order',
      hint: 'Record a customer order',
      icon: Icons.receipt_long_outlined,
      primary: actions.isEmpty,
    ));
  }
  if (session.can('conversations:read')) {
    actions.add(const QuickAction(
      key: 'inbox',
      label: 'Open inbox',
      hint: 'Answer a customer now',
      icon: Icons.forum_outlined,
    ));
  }
  return actions;
}

/// The lifecycle objects worth a tab on a phone, per workspace.
List<({String kind, String label})> workKindsFor(Session session) {
  final workspace = workspaceOf(session.workspace);
  final kinds = <({String kind, String label})>[];
  if (workspace != Workspace.orders) {
    if (session.can('booking_requests:read')) kinds.add((kind: 'enquiry', label: 'Enquiries'));
    if (session.can('quotations:read')) kinds.add((kind: 'quotation', label: 'Quotations'));
  }
  if (workspace == Workspace.bookings || workspace == Workspace.hybrid) {
    if (session.can('bookings:read')) kinds.add((kind: 'booking', label: 'Bookings'));
  }
  if (workspace == Workspace.orders || workspace == Workspace.hybrid) {
    if (session.can('orders:read')) kinds.add((kind: 'order', label: 'Orders'));
  }
  return kinds;
}

/// One line explaining how work reaches a business that has none yet.
String howWorkArrives(Workspace workspace) => switch (workspace) {
      Workspace.orders =>
        'Orders arrive from a shared order link, from WhatsApp, or you can write one down here.',
      Workspace.service => 'Requests arrive from your website and WhatsApp — or log one while you are on the phone.',
      _ => 'Enquiries arrive from your website and WhatsApp — or log one while the traveller is still talking.',
    };
