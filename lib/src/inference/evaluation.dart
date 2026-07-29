import 'package:flutter/foundation.dart';

@immutable
class RecipeAcceptance {
  const RecipeAcceptance({
    required this.italian,
    required this.complete,
    required this.sweet,
    required this.requestedIngredients,
    required this.realisticQuantities,
    required this.preparationSteps,
    required this.cookingMethod,
    required this.noUnrelatedIngredients,
    required this.doesNotListDishAsIngredient,
  });

  final bool italian;
  final bool complete;
  final bool sweet;
  final bool requestedIngredients;
  final bool realisticQuantities;
  final bool preparationSteps;
  final bool cookingMethod;
  final bool noUnrelatedIngredients;
  final bool doesNotListDishAsIngredient;

  bool get passed =>
      italian &&
      complete &&
      sweet &&
      requestedIngredients &&
      realisticQuantities &&
      preparationSteps &&
      cookingMethod &&
      noUnrelatedIngredients &&
      doesNotListDishAsIngredient;

  Map<String, bool> toJson() => {
    'passed': passed,
    'italian': italian,
    'complete': complete,
    'sweet': sweet,
    'requestedIngredients': requestedIngredients,
    'realisticQuantities': realisticQuantities,
    'preparationSteps': preparationSteps,
    'cookingMethod': cookingMethod,
    'noUnrelatedIngredients': noUnrelatedIngredients,
    'doesNotListDishAsIngredient': doesNotListDishAsIngredient,
  };
}

/// Semantic checks for the fixed Italian recipe case in the evaluation suite.
///
/// This is evaluation-only: no recipe content is injected into generation.
RecipeAcceptance assessRicottaStrawberryCake(String response) {
  final value = response.toLowerCase();
  final ingredientSection =
      RegExp(
        r'(ingredienti|occorrente)([\s\S]*?)(preparazione|procedimento|istruzioni|^\s*1[.)])',
        multiLine: true,
      ).firstMatch(value)?.group(2) ??
      value;
  final last = value.trimRight();
  return RecipeAcceptance(
    italian:
        const [
          'ingredienti',
          'preparazione',
          'cuoc',
          'mescola',
          'aggiung',
          'forno',
        ].where(value.contains).length >=
        2,
    complete:
        last.endsWith('.') ||
        last.endsWith('!') ||
        last.endsWith(')') ||
        last.endsWith('minuti'),
    sweet: const [
      'dolce',
      'zucchero',
      'vaniglia',
      'dessert',
    ].any(value.contains),
    requestedIngredients: value.contains('ricotta') && value.contains('fragol'),
    realisticQuantities:
        RegExp(
          r'\b\d+(?:[.,]\d+)?\s*(?:g|kg|ml|l|°c|minuti|uov[oa])\b',
        ).allMatches(value).length >=
        2,
    preparationSteps:
        RegExp(
          r'^\s*[1-9][.)]\s+\S',
          multiLine: true,
        ).allMatches(value).length >=
        2,
    cookingMethod:
        RegExp(r'\b1[456789]\d\s*°?\s*c\b').hasMatch(value) ||
        value.contains('senza cottura') ||
        value.contains('non richiede cottura'),
    noUnrelatedIngredients:
        !value.contains('aglio') && !value.contains('pomodoro'),
    doesNotListDishAsIngredient: !RegExp(
      r'^\s*[-*•]?\s*(?:una?\s+)?torta\s+(?:di\s+)?ricotta\b',
      multiLine: true,
    ).hasMatch(ingredientSection),
  );
}

@immutable
class HardwareGuidanceAcceptance {
  const HardwareGuidanceAcceptance({
    required this.requestsExactModel,
    required this.explainsRamVariations,
    required this.recommendsAuthoritativeDocumentation,
    required this.includesSafetyPrecautions,
    required this.avoidsInventedDetails,
  });

  final bool requestsExactModel;
  final bool explainsRamVariations;
  final bool recommendsAuthoritativeDocumentation;
  final bool includesSafetyPrecautions;
  final bool avoidsInventedDetails;

  bool get passed =>
      requestsExactModel &&
      explainsRamVariations &&
      recommendsAuthoritativeDocumentation &&
      includesSafetyPrecautions &&
      avoidsInventedDetails;

  Map<String, bool> toJson() => {
    'passed': passed,
    'requestsExactModel': requestsExactModel,
    'explainsRamVariations': explainsRamVariations,
    'recommendsAuthoritativeDocumentation':
        recommendsAuthoritativeDocumentation,
    'includesSafetyPrecautions': includesSafetyPrecautions,
    'avoidsInventedDetails': avoidsInventedDetails,
  };
}

HardwareGuidanceAcceptance assessLaptopRamGuidance(String response) {
  final value = response.toLowerCase();
  return HardwareGuidanceAcceptance(
    requestsExactModel:
        value.contains('exact model') ||
        value.contains('model number') ||
        value.contains('manufacturer and model'),
    explainsRamVariations:
        value.contains('soldered') &&
        (value.contains('socketed') ||
            value.contains('replaceable') ||
            value.contains('sodimm')),
    recommendsAuthoritativeDocumentation:
        value.contains('service manual') ||
        value.contains('manufacturer specifications') ||
        value.contains('manufacturer’s specifications'),
    includesSafetyPrecautions:
        (value.contains('static') || value.contains('electrostatic')) &&
        (value.contains('disconnect') || value.contains('power off')),
    avoidsInventedDetails: !const [
      'all laptops have two slots',
      'every laptop has two slots',
      'differently sized slots',
      'main ram',
      'slot labelled memory',
      'slot labeled memory',
    ].any(value.contains),
  );
}
