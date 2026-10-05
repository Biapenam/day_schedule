import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Shared, quiet surface for both editor sections and settings groups.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.all(20),
    required this.child,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: context.colors.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

/// All pickers share focus, ripple, touch targets and selected semantics.
class AppChoiceButton extends StatelessWidget {
  const AppChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.semanticLabel,
  });
  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    label: semanticLabel,
    child: FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: selected
            ? context.colors.primary
            : context.colors.surfaceContainer,
        foregroundColor: selected
            ? context.colors.onPrimary
            : context.colors.textBody,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    ),
  );
}

class SheetHeading extends StatelessWidget {
  const SheetHeading({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: context.colors.primary, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?trailing,
      IconButton(
        tooltip: '关闭',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}
