import 'package:finn_ai/src/engine/eval/evaluation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Italian ricotta and strawberry cake fixture meets semantic criteria',
    () {
      const response = '''
Torta dolce di ricotta e fragole

Ingredienti per 8 porzioni
- 500 g di ricotta
- 300 g di fragole
- 180 g di zucchero
- 3 uova
- 200 g di farina

Preparazione
1. Mescola ricotta, zucchero e uova, quindi incorpora la farina.
2. Aggiungi metà delle fragole e versa in una tortiera.
3. Cuoci in forno a 175 °C per 45 minuti.
4. Lascia raffreddare e completa con le fragole rimaste.
''';

      final result = assessRicottaStrawberryCake(response);
      expect(result.passed, isTrue, reason: result.toJson().toString());
    },
  );

  test('reported malformed and truncated recipe fails quality gates', () {
    const response = '''
Ingredienti:
- torta ricotta
- olio all'aglio
- pomodoro
- salato

1. Mescola gli ingredienti e poi
''';

    final result = assessRicottaStrawberryCake(response);
    expect(result.passed, isFalse);
    expect(result.complete, isFalse);
    expect(result.requestedIngredients, isFalse);
    expect(result.noUnrelatedIngredients, isFalse);
    expect(result.doesNotListDishAsIngredient, isFalse);
  });

  test('cautious laptop RAM guidance passes structural acceptance', () {
    const response = '''
Upgradeability depends on the manufacturer and exact model number. Check the
manufacturer specifications or service manual before buying parts or opening
the laptop. RAM may be soldered, socketed as a SODIMM, or use a combination of
both, so I cannot infer capacity or slot count without the model. Power off and
disconnect the charger and internal battery where the service manual permits.
Use electrostatic precautions before touching components.
''';
    final result = assessLaptopRamGuidance(response);
    expect(result.passed, isTrue, reason: result.toJson().toString());
  });

  test('invented universal laptop slot guidance fails acceptance', () {
    const response =
        'All laptops have two slots: Main RAM and a differently sized slot.';
    final result = assessLaptopRamGuidance(response);
    expect(result.passed, isFalse);
    expect(result.avoidsInventedDetails, isFalse);
  });

  test('accurate Bridgetown routing answer passes screenshot regression', () {
    const response = '''
Bridgetown is a Ruby-powered progressive site generator. Its server uses Roda
for routing. Projects can define Roda API routes, opt into server-side
rendering (SSR), and use the bridgetown-routes plugin for dynamic file-based
routes. Rake may run build tasks, but it is not Bridgetown's routing system.
''';
    final result = assessBridgetownRouting(response);
    expect(result.passed, isTrue, reason: result.toJson().toString());
  });

  test('reported Bridgetown and Rake hallucination fails quality gate', () {
    const response =
        'Bridgetown uses Rake as its routing system and has no built-in routing.';
    final result = assessBridgetownRouting(response);
    expect(result.passed, isFalse);
    expect(result.identifiesRoda, isFalse);
    expect(result.avoidsRakeConflation, isFalse);
  });

  test('species-aware ant death explanation passes screenshot regression', () {
    const response = '''
The mechanism varies by species. In some ants, post-mortem changes increase
fatty-acid cues such as oleic or linoleic acid; workers detect these cues and
perform necrophoresis, carrying the corpse away. Other species respond quickly
to the disappearance of chemical signals associated with life, so there is no
single delay that applies to all ants.
''';
    final result = assessAntNecrophoresis(response);
    expect(result.passed, isTrue, reason: result.toJson().toString());
  });

  test('universal unique-scent ant claim fails quality gate', () {
    const response =
        'When an ant dies, it emits a unique scent that tells ants it is dead.';
    final result = assessAntNecrophoresis(response);
    expect(result.passed, isFalse);
    expect(result.avoidsUniversalEmissionClaim, isFalse);
  });
}
