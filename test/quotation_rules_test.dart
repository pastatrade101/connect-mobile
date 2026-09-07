// The rules that decide what a child is charged.
//
// Each of these tests names a way the quotation sheet has actually gone wrong,
// or was one edit away from going wrong, on a screen where being wrong sends a
// real traveller a real number.
import 'package:flutter_test/flutter_test.dart';
import 'package:makutano_connect/core/quotation_rules.dart';

void main() {
  group('normaliseAmount', () {
    test('takes the separators people type on a phone', () {
      expect(normaliseAmount('1,200'), '1200.00');
      expect(normaliseAmount('1 200'), '1200.00');
      expect(normaliseAmount('3930.00'), '3930.00');
      expect(normaliseAmount(' 2,950.5 '), '2950.50');
    });

    test('empty is not zero — an omission is not a decision', () {
      expect(normaliseAmount(''), '');
      expect(normaliseAmount('   '), '');
      expect(normaliseAmount('abc'), '');
      expect(normaliseAmount('0'), '0.00');
    });
  });

  group('childRateNeeded', () {
    test('an empty box with children on the quotation blocks the send', () {
      expect(childRateNeeded(children: 1, perGroup: false, childRate: ''), isTrue);
    });

    test('a typed zero is a decision and passes', () {
      // The operator meant it: this child travels free. That must be allowed,
      // and must not be reachable by leaving the box alone.
      expect(childRateNeeded(children: 1, perGroup: false, childRate: '0.00'), isFalse);
    });

    test('no children, nothing needed', () {
      expect(childRateNeeded(children: 0, perGroup: false, childRate: ''), isFalse);
    });

    test('a whole-group price has no separate child line to fill', () {
      expect(childRateNeeded(children: 2, perGroup: true, childRate: ''), isFalse);
    });
  });

  group('childFollowsAdult', () {
    test('follows while nothing better is known', () {
      // The historic case: no tour published a child price, so mirroring the
      // adult figure was the least wrong guess available.
      expect(childFollowsAdult(childPriceEdited: false, childFromPricing: false), isTrue);
    });

    test('stops once the operator has set the child rate apart', () {
      expect(childFollowsAdult(childPriceEdited: true, childFromPricing: false), isFalse);
    });

    test('never overwrites a rate that came from the tour price book', () {
      // THE BLOCKER. A published child rate is a fact, and the adult box
      // dragging it upward quotes the child at the adult rate — the exact
      // fault the pre-filled sheet exists to prevent.
      expect(childFollowsAdult(childPriceEdited: false, childFromPricing: true), isFalse);
    });
  });

  group('recommendationIsStale', () {
    test('fresh while the party is the one that was priced', () {
      expect(recommendationIsStale(adults: 2, children: 2, forAdults: 2, forChildren: 2), isFalse);
    });

    test('stale the moment either counter moves', () {
      // A band reading "3-4 travellers" above a counter reading 6 is not merely
      // out of date, it is contradicted by the screen it is printed on.
      expect(recommendationIsStale(adults: 6, children: 0, forAdults: 3, forChildren: 0), isTrue);
      expect(recommendationIsStale(adults: 2, children: 1, forAdults: 2, forChildren: 0), isTrue);
    });
  });

  group('childPriceForPayload', () {
    test('sends nothing when there are no children', () {
      expect(childPriceForPayload(children: 0, perGroup: false, childRate: ''), isNull);
    });

    test('never substitutes a zero for an empty box', () {
      // THE SECOND BLOCKER. The old code sent "0.00" here, which quotes the
      // child free AND satisfies the server's own guard, so nothing catches it.
      // childRateNeeded is what keeps this from ever being reached empty.
      expect(childPriceForPayload(children: 1, perGroup: false, childRate: ''), '');
    });

    test('sends the operator figure untouched', () {
      expect(childPriceForPayload(children: 2, perGroup: false, childRate: '2950.00'), '2950.00');
      expect(childPriceForPayload(children: 1, perGroup: false, childRate: '0.00'), '0.00');
    });

    test('a whole-group quotation still satisfies the server, with an unused figure', () {
      // The server refuses a party with children and no child price; on a group
      // price the number is not used because the group total covers everyone.
      expect(childPriceForPayload(children: 3, perGroup: true, childRate: ''), '0.00');
    });
  });

  group('the two blockers, end to end', () {
    test('an adult edit leaves a published child rate standing', () {
      // Enquiry: 2 adults + 1 child. Tour publishes adult 3930 / child 2950.
      var childBox = '2950.00';
      const childFromPricing = true;
      var childEdited = false;
      // The operator retypes the adult figure for this party.
      for (final keystroke in ['4', '40', '400', '4000']) {
        if (childFollowsAdult(childPriceEdited: childEdited, childFromPricing: childFromPricing)) {
          childBox = keystroke;
        }
      }
      expect(childBox, '2950.00', reason: 'the tour price book must survive an adult edit');
      expect(childEdited, isFalse);
    });

    test('adding a child to a childless enquiry cannot ship a free child', () {
      // Server sent childPrice null and childRateMissing false, because the
      // ENQUIRY had no children. The operator then adds one.
      const childFromPricing = false;
      final childBox = normaliseAmount('');
      expect(
        childRateNeeded(children: 1, perGroup: false, childRate: childBox),
        isTrue,
        reason: 'send must be blocked until the rate is named',
      );
      expect(
        childFollowsAdult(childPriceEdited: false, childFromPricing: childFromPricing),
        isTrue,
        reason: 'and the adult box may still fill it, since nothing better is known',
      );
    });
  });
}
