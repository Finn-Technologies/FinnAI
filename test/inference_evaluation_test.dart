import 'package:finn_ai/src/inference/evaluation.dart';
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
}
