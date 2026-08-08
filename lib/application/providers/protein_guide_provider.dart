import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One entry in the budget protein guide.
///
/// Static bundled content, not a database table: it is reference material that
/// ships with the app and never changes per user.
class ProteinFood extends Equatable {
  final String id;
  final String name;

  /// Grams of protein per 100 g.
  final double proteinPer100g;

  /// Kcal per 100 g — shown so a cheap protein that is also very calorie-dense
  /// (peanuts) cannot be mistaken for a free win.
  final int kcalPer100g;

  /// 1 = cheapest, 2 = cheap, 3 = worth it.
  final int tier;

  /// True when the figure is for the dry weight, which is several times more
  /// concentrated than the cooked weight. Marked clearly because getting this
  /// wrong is the most common way to overcount protein.
  final bool isDry;

  final String how;
  final String? caution;

  /// Visual identifier shown in the guide. Emoji rather than a bundled image:
  /// no licensing, no APK weight, and it renders offline on every platform.
  final String glyph;

  const ProteinFood({
    required this.id,
    required this.name,
    required this.proteinPer100g,
    required this.kcalPer100g,
    required this.tier,
    required this.isDry,
    required this.how,
    this.caution,
    this.glyph = '🍽',
  });

  factory ProteinFood.fromJson(Map<String, dynamic> json) => ProteinFood(
    id: json['id'] as String,
    name: json['name'] as String,
    proteinPer100g: (json['protein'] as num).toDouble(),
    kcalPer100g: (json['kcal'] as num).toInt(),
    tier: (json['tier'] as num).toInt(),
    isDry: json['dry'] == true,
    how: json['how'] as String,
    caution: json['caution'] as String?,
    glyph: json['glyph'] as String? ?? '🍽',
  );

  @override
  List<Object?> get props => [id];
}

/// Loads the guide from the bundled asset. Cached by Riverpod, so the file is
/// parsed once per session and the screen opens instantly offline.
final proteinGuideProvider = FutureProvider<List<ProteinFood>>((ref) async {
  final raw = await rootBundle.loadString('assets/seed/protein_guide.json');
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final items = decoded['items'] as List<dynamic>;
  return items
      .cast<Map<String, dynamic>>()
      .map(ProteinFood.fromJson)
      .toList();
});
