import 'package:finn_ai/src/inference/bonsai_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Safety System Prompt Template Verification', () {
    test(
      'Direct answer mode prompt template includes full safety system prompt',
      () {
        final inference = BonsaiInference.instance;
        final rendered = inference.renderPromptForTest(
          prompt: 'How do I write a Python function?',
          router: false,
        );

        expect(rendered, contains('<|im_start|>system\n'));
        expect(
          rendered,
          contains('You are Finn AI, an on-device AI assistant.'),
        );
        expect(rendered, contains('Do not provide content that facilitates:'));
        expect(
          rendered,
          contains('sexual exploitation or sexual content involving minors'),
        );
        expect(rendered, contains('suicide or self-harm methods'));
        expect(rendered, contains('malware, destructive cyber abuse'));
        expect(rendered, contains('<|im_end|>'));
        expect(rendered, contains('How do I write a Python function?'));
      },
    );

    test(
      'Router mode prompt template includes BOTH safety prompt and router instructions',
      () {
        final inference = BonsaiInference.instance;
        final rendered = inference.renderPromptForTest(
          prompt: 'Solve 2 + 2',
          router: true,
        );

        expect(rendered, contains('<|im_start|>system\n'));
        expect(
          rendered,
          contains('You are Finn AI, an on-device AI assistant.'),
        );
        expect(
          rendered,
          contains('sexual exploitation or sexual content involving minors'),
        );
        expect(rendered, contains('You are Finn AI\'s private routing layer.'));
        expect(rendered, contains('<|im_end|>'));
      },
    );
  });
}
