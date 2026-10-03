import 'package:flutter/material.dart';

import 'package:finn_ai/l10n/l10n_helper.dart';
import 'package:finn_ai/src/shared/theme/flux_theme.dart';
import 'package:finn_ai/src/shared/widgets/finn_page.dart';

class CodeAboutPage extends StatelessWidget {
  const CodeAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return FinnPage(
      title: l10n.appBrandFinnAICode,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            l10n.codeAboutBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FluxColors.secondaryInkOf(context),
                ),
          ),
        ),
        FinnCaption(l10n.codeSandboxNote),
      ],
    );
  }
}
