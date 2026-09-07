/// The four rules that decide what a child is charged.
///
/// They live out here, as plain functions, for one reason: every one of them has
/// already been got wrong once inside a widget, where nothing could see it. The
/// adult box used to mirror into the child box unconditionally — correct while
/// no tour published a child price, and a way to overwrite a real published rate
/// the moment one did. An empty child box used to be sent as "0.00", which is a
/// free holiday nobody decided to give, and which satisfies the server's own
/// guard so nothing downstream catches it.
///
/// A rule that costs money when it is wrong should be readable without a
/// simulator, and provable without one. See test/quotation_rules_test.dart.
library;

/// What the operator typed, in the shape the server will accept.
///
/// People type "1,200" and "1 200" on a phone; the server takes digits and at
/// most two decimals. Normalising here means a thousands separator is a
/// formatting habit rather than a rejected quotation. Empty means "they have
/// not said", which is deliberately different from zero.
String normaliseAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[,\s]'), '').trim();
  final value = double.tryParse(cleaned);
  return value == null ? '' : value.toStringAsFixed(2);
}

/// Children are on the quotation and nobody has said what they pay.
///
/// A deliberately free child is TYPED as 0 and passes this; an empty box does
/// not. That distinction is the whole point — "0" is a decision and "" is an
/// omission, and only one of them should be allowed to reach a traveller.
///
/// A whole-group price has no separate child line, so there is nothing to need.
bool childRateNeeded({required int children, required bool perGroup, required String childRate}) =>
    children > 0 && !perGroup && childRate.isEmpty;

/// Should typing in the adult box carry the same figure into the child box?
///
/// Only while nothing better is known. A rate that came out of the tour's own
/// price book IS something better: mirroring over it quotes the child at the
/// adult rate, which is the exact fault the pre-filled sheet was built to fix.
bool childFollowsAdult({required bool childPriceEdited, required bool childFromPricing}) =>
    !childPriceEdited && !childFromPricing;

/// Has the party moved away from the one the recommendation was calculated for?
///
/// The band is a function of party size and the server resolved it from the
/// ENQUIRY's numbers. Once the operator corrects those, a panel still reading
/// "3-4 travellers" above a counter reading 6 is not merely stale, it is a
/// statement contradicted by the screen it is printed on.
bool recommendationIsStale({
  required int adults,
  required int children,
  required int forAdults,
  required int forChildren,
}) => adults != forAdults || children != forChildren;

/// The child price to put in the payload, or null when there is none to send.
///
/// The server refuses a party with children and no child price, so a whole-group
/// quotation still has to send something — there the figure is unused, because
/// the group total already covers everyone. Everywhere else the operator's own
/// value goes up untouched, and [childRateNeeded] is what stops it being empty.
String? childPriceForPayload({required int children, required bool perGroup, required String childRate}) {
  if (children <= 0) return null;
  if (perGroup) return '0.00';
  return childRate;
}
