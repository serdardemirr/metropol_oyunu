import 'package:flutter/material.dart';

import '../models/pawn_token.dart';
import 'pawn_avatar.dart';

/// Sembol ve renk seçici. Odada başkasının kullandığı renk/semboller
/// soluk gösterilir ve seçilemez.
class PawnPicker extends StatelessWidget {
  const PawnPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.takenSymbols = const {},
    this.takenColors = const {},
  });

  final PawnToken value;
  final ValueChanged<PawnToken> onChanged;
  final Set<PawnSymbol> takenSymbols;
  final Set<PawnColor> takenColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              PawnAvatar(pawn: value, size: 84, selected: true),
              const SizedBox(height: 6),
              Text(value.label, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Sembol', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in PawnSymbol.values)
              _Choice(
                selected: s == value.symbol,
                disabled: takenSymbols.contains(s),
                label: s.label,
                onTap: () => onChanged(value.copyWith(symbol: s)),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: value.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: PawnSymbolIcon(symbol: s, size: 32),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Renk', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in PawnColor.values)
              _Choice(
                selected: c == value.tint,
                disabled: takenColors.contains(c),
                label: c.label,
                onTap: () => onChanged(value.copyWith(tint: c)),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.disabled,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final bool disabled;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: disabled ? '$label (başka oyuncuda)' : label,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: disabled ? 0.25 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
