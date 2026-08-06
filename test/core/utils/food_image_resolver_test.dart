import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/core/utils/food_image_resolver.dart';

void main() {
  group('resolveImageKey', () {
    test('maps the biryani family to one shared photo', () {
      for (final name in [
        'Chicken Biryani',
        'Beef Biryani',
        'Mutton Biryani',
        'Biryani (large double plate)',
      ]) {
        expect(resolveImageKey(name), 'biryani', reason: name);
      }
    });

    test('is case insensitive and tolerates surrounding text', () {
      expect(resolveImageKey('CHICKEN KARAHI'), 'karahi');
      expect(resolveImageKey('  Zinger Burger  '), 'burger');
    });

    test('prefers the more specific rule when names overlap', () {
      // Each of these contains a keyword belonging to an earlier, more
      // generic rule — first-match ordering is what keeps them correct.
      expect(resolveImageKey('Bun Kebab'), 'bun_kebab');
      expect(resolveImageKey('Seekh Kebab'), 'kebab');
      expect(resolveImageKey('Halwa Puri (set)'), 'halwa_puri');
      expect(resolveImageKey('Sooji Halwa'), 'halwa');
      expect(resolveImageKey('Dahi Bhalay'), 'dahi_bhalay');
      expect(resolveImageKey('Dahi (plain yogurt)'), 'yogurt');
      expect(resolveImageKey('Chana Chaat'), 'chana');
      expect(resolveImageKey('Samosa Chaat'), 'samosa');
      expect(resolveImageKey('Fruit Chaat'), 'chaat');
      expect(resolveImageKey('Cake Rusk'), 'cake_rusk');
      expect(resolveImageKey('Cake Slice (bakery)'), 'cake');
      expect(resolveImageKey('Spring Rolls'), 'spring_roll');
      expect(resolveImageKey('Chicken Roll'), 'roll');
      expect(resolveImageKey('Karhi (yogurt curry)'), 'karhi');
      expect(resolveImageKey('Choco Milkshake'), 'milkshake');
    });

    test('covers the packaged snacks and drinks the catalog now carries', () {
      expect(resolveImageKey('Lays Masala Chips (small pack)'), 'chips');
      expect(resolveImageKey('Kurkure Masala Munch'), 'chips');
      expect(resolveImageKey('Nachos with Cheese Dip'), 'chips');
      expect(resolveImageKey('Coca-Cola (250ml can)'), 'cola');
      expect(resolveImageKey('Pepsi (500ml bottle)'), 'cola');
      expect(resolveImageKey('Mountain Dew (500ml bottle)'), 'cola');
      expect(resolveImageKey('Sting Energy Drink (500ml)'), 'energy_drink');
      expect(resolveImageKey('Red Bull (250ml can)'), 'energy_drink');
      expect(resolveImageKey('Sports Drink (500ml)'), 'energy_drink');
      expect(resolveImageKey('KitKat (4 finger)'), 'chocolate');
      expect(resolveImageKey('Oreo (3 biscuits)'), 'biscuit');
      expect(resolveImageKey('Chicken Wings (6 pieces)'), 'fried_chicken');
      expect(resolveImageKey('Chargha (quarter)'), 'fried_chicken');
      expect(resolveImageKey('Chicken Handi'), 'karahi');
      expect(resolveImageKey('Onion Rings'), 'fries');
      expect(resolveImageKey('Gelato'), 'ice_cream');
    });

    test('returns null rather than guessing', () {
      expect(resolveImageKey(null), isNull);
      expect(resolveImageKey(''), isNull);
      expect(resolveImageKey('   '), isNull);
      expect(resolveImageKey('Zorbulax Surprise'), isNull);
    });
  });

  group('bundled assets', () {
    test('every key the resolver can produce has a shipped photo', () async {
      final manifestFile = File('assets/food_images/manifest.json');
      expect(
        manifestFile.existsSync(),
        isTrue,
        reason: 'run: node tool/fetch_food_images.mjs',
      );

      final decoded =
          json.decode(await manifestFile.readAsString())
              as Map<String, dynamic>;
      final shipped = (decoded['keys'] as List<dynamic>).cast<String>().toSet();

      final missing = allImageKeys.difference(shipped);
      expect(
        missing,
        isEmpty,
        reason: 'resolver keys without a bundled photo: $missing',
      );
    });

    test('every manifest key has a real file and a credit entry', () async {
      final manifest =
          json.decode(
                await File('assets/food_images/manifest.json').readAsString(),
              )
              as Map<String, dynamic>;
      final credits =
          json.decode(
                await File('assets/food_images/credits.json').readAsString(),
              )
              as Map<String, dynamic>;

      for (final key in (manifest['keys'] as List<dynamic>).cast<String>()) {
        expect(
          File('assets/food_images/$key.webp').existsSync(),
          isTrue,
          reason: '$key.webp is listed in the manifest but missing on disk',
        );
        expect(
          credits.containsKey(key),
          isTrue,
          reason: '$key has no attribution entry — CC images must be credited',
        );
      }
    });

    test('every credit names a free license and an author', () async {
      final credits =
          json.decode(
                await File('assets/food_images/credits.json').readAsString(),
              )
              as Map<String, dynamic>;

      expect(credits, isNotEmpty);
      final freeLicense = RegExp(
        r'^(cc0|cc[ -]by|public domain|pd|no restrictions)',
        caseSensitive: false,
      );

      credits.forEach((key, value) {
        final entry = value as Map<String, dynamic>;
        final license = entry['license'] as String? ?? '';
        expect(
          freeLicense.hasMatch(license),
          isTrue,
          reason: '$key ships under a non-free license: "$license"',
        );
        expect(
          (entry['author'] as String? ?? '').trim(),
          isNotEmpty,
          reason: '$key has no author recorded',
        );
      });
    });
  });
}
