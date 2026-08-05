enum NutritionBasis { per100g, per100ml, perServing, perPiece, unknown }

class ParsedField<T> {
  final T value;
  final double confidence; // 0.0 to 1.0

  ParsedField(this.value, this.confidence);

  @override
  String toString() => '$value ($confidence)';
}

class NutritionLabelResult {
  final ParsedField<int>? kcal;
  final ParsedField<NutritionBasis>? basis;
  final ParsedField<double>? servingSizeGrams;
  final ParsedField<double>? servingsPerPack;
  final String? subtitle;

  NutritionLabelResult({
    this.kcal,
    this.basis,
    this.servingSizeGrams,
    this.servingsPerPack,
    this.subtitle,
  });
}

class NutritionLabelParser {
  NutritionLabelResult parse(String text) {
    final normalized = text.toLowerCase().replaceAll('\r', '\n');

    ParsedField<int>? parsedKcal;
    ParsedField<NutritionBasis>? parsedBasis;
    ParsedField<double>? parsedServingSize;
    ParsedField<double>? parsedServings;
    String? subtitle;

    // 1. Kcal / Energy
    final kcalMatch = RegExp(
      r'(?<!\d)(\d+(?:[.,]\d+)?)[ \t]*(?:kcal|kilocalories)\b',
    ).firstMatch(normalized);
    
    if (kcalMatch != null) {
      final val = _parseDouble(kcalMatch.group(1)!);
      if (val != null) {
        parsedKcal = ParsedField<int>(val.round(), 0.9);
      }
    } else {
      final kjMatch = RegExp(
        r'(?<!\d)(\d+(?:[.,]\d+)?)[ \t]*(?:kj|kilojoules)\b',
      ).firstMatch(normalized);
      if (kjMatch != null) {
        final val = _parseDouble(kjMatch.group(1)!);
        if (val != null) {
          parsedKcal = ParsedField<int>((val / 4.184).round(), 0.8);
        }
      } else {
        final fallbackMatch = RegExp(
          r'(?:energy|calories|calori|tawanai|hararay)[ \t\n]*[:=-]?[ \t\n]*(\d+(?:[.,]\d+)?)',
        ).firstMatch(normalized);
        if (fallbackMatch != null) {
          final val = _parseDouble(fallbackMatch.group(1)!);
          if (val != null) {
            parsedKcal = ParsedField<int>(val.round(), 0.5);
          }
        }
      }
    }

    // 2. Basis
    bool has100g = RegExp(r'(?:per|fi|har)\s*100\s*g').hasMatch(normalized) || RegExp(r'(?:per|fi|har)\s*100\s*ml').hasMatch(normalized);
    bool hasPiece = RegExp(r'(?:per\s*piece|fi\s*dana|fi\s*adad)').hasMatch(normalized);
    bool hasServing = RegExp(r'(?:per\s*serving|fi\s*hissa|har\s*hissa|per\s*portion)').hasMatch(normalized);

    if (hasPiece) {
      parsedBasis = ParsedField(NutritionBasis.perPiece, 0.9);
      if (has100g) subtitle = "Preferred per-piece over per-100g";
    } else if (hasServing) {
      parsedBasis = ParsedField(NutritionBasis.perServing, 0.9);
      if (has100g) subtitle = "Preferred per-serving over per-100g";
    } else if (has100g) {
      if (RegExp(r'(?:per|fi|har)\s*100\s*g').hasMatch(normalized)) {
        parsedBasis = ParsedField(NutritionBasis.per100g, 0.9);
      } else {
        parsedBasis = ParsedField(NutritionBasis.per100ml, 0.9);
      }
    }

    // 3. Serving Size
    final servingMatch = RegExp(
      r'(?:serving size|serving|portion|hissa)[ \t\n]*[:=-]?[ \t\n]*(\d+(?:[.,]\d+)?)[ \t]*(g|ml)\b',
    ).firstMatch(normalized);
    if (servingMatch != null) {
      final val = _parseDouble(servingMatch.group(1)!);
      if (val != null) {
        parsedServingSize = ParsedField(val, 0.9);
      }
    }

    // 4. Servings Per Pack
    final packMatch = RegExp(
      r'(?:servings per container|servings per pack|servings|kul hissay)[ \t\n]*[:=-]?[ \t\n]*(\d+(?:[.,]\d+)?)',
    ).firstMatch(normalized);
    if (packMatch != null) {
      final val = _parseDouble(packMatch.group(1)!);
      if (val != null) {
        parsedServings = ParsedField(val, 0.8);
      }
    }

    return NutritionLabelResult(
      kcal: parsedKcal,
      basis: parsedBasis,
      servingSizeGrams: parsedServingSize,
      servingsPerPack: parsedServings,
      subtitle: subtitle,
    );
  }

  double? _parseDouble(String s) {
    return double.tryParse(s.replaceAll(',', '.'));
  }
}
