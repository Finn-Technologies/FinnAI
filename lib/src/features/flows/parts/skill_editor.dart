part of '../flows_page.dart';

class _SkillDraft {
  const _SkillDraft({
    required this.name,
    required this.description,
    required this.instructions,
  });

  final String name;
  final String description;
  final String instructions;
}

class _SkillEditor extends StatefulWidget {
  const _SkillEditor({this.flow});
  final FinnFlow? flow;

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  late final _name = TextEditingController(text: widget.flow?.name ?? '');
  late final _description = TextEditingController(
    text: widget.flow?.description ?? '',
  );
  late final _instructions = TextEditingController(
    text: widget.flow?.instructions ?? '',
  );

  bool get _valid =>
      _name.text.trim().isNotEmpty && _instructions.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _instructions.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: FluxColors.canvasOf(context),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FluxRadius.sheet)),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FluxColors.lineOf(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.flow == null
                        ? L10n.of(context).flowsNewSkill
                        : L10n.of(context).flowsEditTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    L10n.of(context).flowsInstructionHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                  ),
                  const SizedBox(height: 18),
                  _EditorField(
                    key: const Key('flow-name-field'),
                    controller: _name,
                    label: L10n.of(context).flowsEditorName,
                    hint: L10n.of(context).flowsEditorNameHint,
                    maxLength: 60,
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    controller: _description,
                    label: L10n.of(context).flowsEditorDescription,
                    hint: L10n.of(context).flowsEditorDescriptionHint,
                    maxLength: 140,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    key: const Key('flow-instructions-field'),
                    controller: _instructions,
                    label: L10n.of(context).flowsEditorInstructions,
                    hint: L10n.of(context).flowsEditorInstructionsHint,
                    maxLength: 500,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const Key('save-flow-button'),
                      onPressed: _valid
                          ? () => Navigator.pop(
                                context,
                                _SkillDraft(
                                  name: _name.text,
                                  description: _description.text,
                                  instructions: _instructions.text,
                                ),
                              )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: FluxColors.inkOf(context),
                        foregroundColor: FluxColors.canvasOf(context),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(L10n.of(context).commonSaveFlow),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: FluxColors.mutedOf(context)),
          filled: true,
          fillColor: FluxColors.cardOf(context),
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.md),
            borderSide: BorderSide(color: FluxColors.lineOf(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FluxRadius.md),
            borderSide: BorderSide(color: FluxColors.inkOf(context)),
          ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FluxRadius.md)),
        ),
      );
}
