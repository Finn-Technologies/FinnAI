part of '../flows_page.dart';

class _SkillsSummary extends StatelessWidget {
  const _SkillsSummary({required this.active, required this.total});

  final int active;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FluxColors.cardOf(context),
          borderRadius: BorderRadius.circular(FluxRadius.sheet),
          border: Border.all(color: FluxColors.lineOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FluxColors.surfaceOf(context),
              ),
              child: Center(child: FluxIcon(icon: FluxIcons.flows, size: 23)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active == 0
                        ? L10n.of(context).flowsNoneActive
                        : L10n.of(context).flowsActiveCount(active),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    L10n.of(context).flowsSubtitle(total),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: FluxColors.mutedOf(context),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FluxColors.mutedOf(context),
                  height: 1.35,
                ),
          ),
        ],
      );
}

class _EmptyCustomSkills extends StatelessWidget {
  const _EmptyCustomSkills();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          color: FluxColors.surfaceOf(context).withValues(alpha: .65),
          borderRadius: BorderRadius.circular(FluxRadius.card),
          border: Border.all(color: FluxColors.lineOf(context)),
        ),
        child: Text(
          L10n.of(context).flowsNoSkills,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: FluxColors.mutedOf(context)),
        ),
      );
}
