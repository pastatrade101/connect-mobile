import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/primitives.dart';

/// The operator's shopfront, on their phone.
///
/// Makutano is a marketplace, and the thing an operator most wants to know when
/// they pick up their phone is whether their trips are actually up there and
/// whether anyone is asking about them. That was the one part of their business
/// the app could not show at all.
///
/// Read-only by design. Building a listing is a long, media-heavy job that
/// belongs in the portal on a real screen; what the phone owes an operator is
/// the STATE of the shopfront — what is live, what is stuck waiting for review,
/// what has been sent back — and the address of the page a traveller sees.
class Listing {
  Listing(this.raw);
  final Map<String, dynamic> raw;

  String get id => (raw['id'] ?? '').toString();
  String get title => (raw['title'] ?? 'Untitled trip').toString();
  String get status => (raw['status'] ?? '').toString();
  String get state => (raw['state'] ?? status).toString();
  String get tone => (raw['tone'] ?? 'quiet').toString();
  int get enquiries => (raw['enquiries'] as int?) ?? 0;
  int get days => (raw['durationDays'] as int?) ?? 0;
  int? get nights => raw['durationNights'] as int?;
  String? get country => _text(raw['country']);
  String? get groupType => _text(raw['groupType']);
  String? get style => _text(raw['style']);
  bool get featured => raw['featured'] == true;
  String? get heroUrl => (raw['hero'] as Map<String, dynamic>?)?['url']?.toString();
  String? get publicUrl => raw['publicUrl']?.toString();
  bool get isLive => status == 'PUBLISHED';

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// The chips under the title: length, then who it is for, then how it is
  /// travelled — capped at TWO so the row never wraps and every card in the
  /// strip is the same height.
  ///
  /// Only what the listing actually says. A tour with no group type falls
  /// through to its style rather than showing a gap, and there is no comfort
  /// tier in this catalogue, so nothing here claims one.
  List<(IconData, String)> get facts => [
    if (days > 0) (Icons.calendar_today_outlined, days == 1 ? '1 day' : '$days days'),
    if (groupType != null) (Icons.person_outline_rounded, groupType!),
    if (style != null) (Icons.landscape_outlined, style!),
  ].take(2).toList();

  /// Split so the card can set "From" and "per person" quietly around the number.
  ({String prefix, String amount, String suffix})? get priceParts {
    final value = double.tryParse((raw['priceFrom'] ?? '').toString());
    if (value == null || value <= 0) return null;
    final currency = (raw['currency'] ?? 'USD').toString();
    final money = NumberFormat('#,##0.##', 'en_US').format(value);
    return switch ((raw['pricingType'] ?? 'PER_PERSON').toString()) {
      'PER_GROUP' => (prefix: '', amount: '$currency $money', suffix: 'for the group'),
      'FROM' => (prefix: 'From', amount: '$currency $money', suffix: ''),
      _ => (prefix: 'From', amount: '$currency $money', suffix: 'per person'),
    };
  }

  /// "USD 2,950 per person", or nothing at all when no price is published.
  ///
  /// Never a bare zero: an unpriced listing is a thing to finish, not a free
  /// trip, and saying "USD 0" on the operator's own dashboard would be the
  /// first place that lie gets told.
  String? get price {
    final value = double.tryParse((raw['priceFrom'] ?? '').toString());
    if (value == null || value <= 0) return null;
    final currency = (raw['currency'] ?? 'USD').toString();
    final money = NumberFormat('#,##0.##', 'en_US').format(value);
    return switch ((raw['pricingType'] ?? 'PER_PERSON').toString()) {
      'PER_GROUP' => '$currency $money per group',
      'FROM' => 'From $currency $money',
      _ => '$currency $money per person',
    };
  }
}

Color _toneColour(BuildContext context, String tone) => switch (tone) {
  'live' => Tone.success(context),
  'action' => Tone.accent(context),
  'waiting' => Tone.warning(context),
  _ => Tone.muted(context),
};

/// The state of one listing, in the marketplace's own vocabulary.
class ListingState extends StatelessWidget {
  const ListingState({super.key, required this.listing, this.dense = false});
  final Listing listing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colour = _toneColour(context, listing.tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        Flexible(
          child: Text(
            listing.state,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colour, fontWeight: FontWeight.w700, fontSize: dense ? 12 : null),
          ),
        ),
      ],
    );
  }
}

/// One listing as it appears on the home strip.
///
/// Built to read the way the marketplace's own tour card reads, because that is
/// what an operator is checking: the photograph first, then the trip, where it
/// goes, what shape it is, and the price it is being sold at. The state pill
/// over the image is the one thing a traveller's card does not have and this one
/// must — a listing that is not live is the most important thing on the card.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});
  final Listing listing;
  final VoidCallback onTap;

  /// Fixed, so a strip of cards has one baseline whatever the titles do.
  ///
  /// Measured against the tallest thing a card can hold rather than the listing
  /// that happened to be on screen: a two-line title, a place, and one row of
  /// fact chips.
  static const height = 316.0;
  static const width = 218.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final price = listing.priceParts;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Tone.surface(context),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Tone.line(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Cover(listing: listing),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.title,
                          // Two lines, then ellipsis. A long safari title will
                          // run to four otherwise, and the card is for
                          // recognising a trip, not reading its full name.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(height: 1.3, fontSize: 14.5),
                        ),
                        if (listing.country != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: 13, color: Tone.muted(context)),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  listing.country!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Still a Wrap rather than a Row: two chips fit at this
                        // width in every case seen so far, but a long group-type
                        // label wrapping is better than one clipped mid-word.
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [for (final (icon, label) in listing.facts) _Chip(icon: icon, label: label)],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: Tone.line(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (price == null)
                              Text('No price yet', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600))
                            else ...[
                              if (price.prefix.isNotEmpty)
                                Text(price.prefix, style: text.bodySmall?.copyWith(fontSize: 11.5)),
                              Text(
                                price.amount,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium?.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700),
                              ),
                              if (price.suffix.isNotEmpty)
                                Text(price.suffix, style: text.bodySmall?.copyWith(fontSize: 11.5)),
                            ],
                          ],
                        ),
                      ),
                      // Decoration, not a second control: the whole card is the
                      // tap target, so this points at where a tap already goes.
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Tone.accent(context), width: 1.4),
                        ),
                        child: Icon(Icons.arrow_forward_rounded, size: 18, color: Tone.accent(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photograph, with the two things that have to sit on top of it.
class _Cover extends StatelessWidget {
  const _Cover({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (listing.heroUrl == null)
            Container(
              color: Tone.accentWash(context),
              child: Icon(Icons.photo_camera_outlined, color: Tone.accent(context), size: 22),
            )
          else
            Image.network(
              listing.heroUrl!,
              fit: BoxFit.cover,
              // A listing with a broken image is still a listing; it must not
              // take the card down with it.
              errorBuilder: (_, _, _) => Container(color: Tone.accentWash(context)),
            ),
          Positioned(left: 8, top: 8, child: _StatePill(listing: listing)),
          // Only when it is true. An outlined heart on every card would be a
          // control that does nothing on a screen about the operator's OWN
          // listings — this mark means the marketplace is featuring the trip.
          if (listing.featured)
            const Positioned(
              right: 8,
              top: 8,
              child: Tooltip(
                message: 'Featured on Makutano Journeys',
                child: _Glass(child: Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC65C))),
              ),
            ),
        ],
      ),
    );
  }
}

/// "● Live", legible over any photograph.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    // Fixed dark glass rather than theme colours: this sits on a photograph, and
    // a photograph is neither light mode nor dark mode.
    final dot = switch (listing.tone) {
      'live' => const Color(0xFF4ADE80),
      'action' => const Color(0xFFFF9A62),
      'waiting' => const Color(0xFFFFC65C),
      _ => const Color(0xFFCFCAC2),
    };
    return _Glass(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            listing.state,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xCC1C1A16), borderRadius: BorderRadius.circular(20)),
    child: child,
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: Tone.panel(context),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: Tone.line(context)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.5, color: Tone.muted(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// The home strip: cards that snap, with dots underneath.
///
/// A PageView rather than a free-scrolling list, because a card this tall wants
/// to settle somewhere rather than stop halfway. The viewport fraction leaves
/// the next card peeking, which is what tells a reader there is more to the
/// right without a scrollbar.
class ListingStrip extends StatefulWidget {
  const ListingStrip({super.key, required this.listings});
  final List<Listing> listings;

  @override
  State<ListingStrip> createState() => _ListingStripState();
}

class _ListingStripState extends State<ListingStrip> {
  PageController? _pages;
  double? _builtFor;
  int _page = 0;

  /// One card plus a glimpse of the next, whatever the screen is.
  ///
  /// Derived from the card's own width rather than fixed: a hard-coded fraction
  /// shows a sliver of the next card on a small phone and half of it on a large
  /// one, so the peek — the only thing telling a reader there is more to the
  /// right — is exactly the size it was designed to be on one device and wrong
  /// everywhere else.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.of(context).size.width;
    if (_builtFor == width) return;
    _builtFor = width;
    _pages?.dispose();
    _pages = PageController(initialPage: _page, viewportFraction: ((ListingCard.width + 10) / width).clamp(0.35, 0.95));
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.listings.length > 1;
    return Column(
      children: [
        SizedBox(
          height: ListingCard.height,
          child: PageView.builder(
            controller: _pages!,
            padEnds: false,
            itemCount: widget.listings.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(left: i == 0 ? 14 : 5, right: 5),
              child: ListingCard(listing: widget.listings[i], onTap: () => showListing(context, widget.listings[i])),
            ),
          ),
        ),
        if (many) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Capped: twenty dots is not an indicator, it is a texture.
              for (var i = 0; i < widget.listings.length.clamp(0, 8); i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? Tone.accent(context) : Tone.line(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// What the phone can honestly say about one listing, and where to go for the rest.
Future<void> showListing(BuildContext context, Listing listing) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) {
    final text = Theme.of(sheetContext).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (listing.heroUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    listing.heroUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: Tone.accentWash(sheetContext)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(listing.title, style: text.titleLarge),
            const SizedBox(height: 8),
            ListingState(listing: listing),
            const SizedBox(height: 14),
            _fact(sheetContext, 'Price', listing.price ?? 'Not set yet'),
            if (listing.days > 0) _fact(sheetContext, 'Length', '${listing.days} days'),
            _fact(sheetContext, 'Enquiries', listing.enquiries == 0 ? 'None yet' : '${listing.enquiries}'),
            if (listing.publicUrl != null) ...[
              const SizedBox(height: 14),
              Text('Traveller sees it here', style: text.bodySmall),
              const SizedBox(height: 4),
              // Selectable rather than a link: the app has no browser of its own,
              // and a tap that does nothing is worse than text you can copy.
              SelectableText(
                listing.publicUrl!,
                style: text.bodySmall?.copyWith(color: Tone.accent(sheetContext), fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Editing a listing — photos, itinerary, pricing — happens in Connect on a bigger screen.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  },
);

Widget _fact(BuildContext context, String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    children: [
      SizedBox(width: 92, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      Expanded(
        child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
    ],
  ),
);

/// Every listing, when the strip on Home is not enough.
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  List<Listing> _items = const [];
  Map<String, dynamic> _summary = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.tours();
      if (!mounted) return;
      setState(() {
        _items = ((data['items'] as List?) ?? const []).cast<Map<String, dynamic>>().map(Listing.new).toList();
        _summary = (data['summary'] as Map<String, dynamic>?) ?? const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load your listings.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MobileHeader(
          title: 'Your listings',
          subtitle: summaryLine(_summary) ?? 'On Makutano Journeys',
          onBack: widget.onBack,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: TeachingEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load your listings',
                      body: _error!,
                      actionLabel: 'Try again',
                      onAction: _load,
                    ),
                  )
                : _items.isEmpty
                ? const Center(
                    child: TeachingEmptyState(
                      icon: Icons.map_outlined,
                      title: 'Nothing listed yet',
                      body:
                          'Trips you publish on Makutano Journeys appear here. Building one happens in Connect, on a bigger screen.',
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, NavBar.clearance),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ListingRow(listing: _items[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tone.surface(context),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showListing(context, listing),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Tone.line(context)),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 78,
                  height: 62,
                  child: listing.heroUrl == null
                      ? Container(
                          color: Tone.accentWash(context),
                          child: Icon(Icons.photo_camera_outlined, size: 18, color: Tone.accent(context)),
                        )
                      : Image.network(
                          listing.heroUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: Tone.accentWash(context)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                    const SizedBox(height: 5),
                    ListingState(listing: listing, dense: true),
                    const SizedBox(height: 3),
                    Text(
                      [
                        listing.price ?? 'No price yet',
                        if (listing.enquiries > 0)
                          '${listing.enquiries} ${listing.enquiries == 1 ? 'enquiry' : 'enquiries'}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Tone.muted(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "3 live · 1 waiting for review · 2 need you" — only the parts that are true.
String? summaryLine(Map<String, dynamic> summary) {
  final live = (summary['live'] as int?) ?? 0;
  final waiting = (summary['waiting'] as int?) ?? 0;
  final needsYou = (summary['needsYou'] as int?) ?? 0;
  final bits = [
    if (live > 0) '$live live',
    if (waiting > 0) '$waiting waiting for review',
    if (needsYou > 0) '$needsYou ${needsYou == 1 ? 'needs' : 'need'} you',
  ];
  return bits.isEmpty ? null : bits.join(' · ');
}
