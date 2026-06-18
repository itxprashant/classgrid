import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_controller.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palettes.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Color theme picker (light + dark palettes).
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final theme = context.watch<ThemeController>();

    return ScreenShell(
      eyebrow: 'Appearance',
      title: 'Color theme',
      subtitle: Text(
        'Pick a palette for the whole app. Your choice is saved on this device.',
        style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: T.space32),
        children: [
          _ThemeSection(
            label: 'Light',
            options: AppPalettes.lightThemes,
            selectedId: theme.currentId,
            onSelect: (id) => _selectTheme(context, theme, id),
          ),
          const SizedBox(height: T.space16),
          _ThemeSection(
            label: 'Dark',
            options: AppPalettes.darkThemes,
            selectedId: theme.currentId,
            onSelect: (id) => _selectTheme(context, theme, id),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTheme(
    BuildContext context,
    ThemeController controller,
    String id,
  ) async {
    if (id == controller.currentId) return;
    final label = AppPalettes.byId(id).label;
    await controller.select(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Theme set to $label')),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelect,
  });

  final String label;
  final List<ThemeOption> options;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(label),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: T.space12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final tileWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: tileWidth,
                      child: _ThemePreviewTile(
                        option: option,
                        selected: option.id == selectedId,
                        onTap: () => onSelect(option.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThemePreviewTile extends StatelessWidget {
  const _ThemePreviewTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final p = option.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.rLg),
        child: AnimatedContainer(
          duration: T.tBase,
          curve: T.easeOut,
          padding: const EdgeInsets.all(T.space12),
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(
              color: selected ? T.accent : T.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 72,
                padding: const EdgeInsets.all(T.space8),
                decoration: BoxDecoration(
                  color: p.paper,
                  borderRadius: BorderRadius.circular(T.r),
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 6,
                      width: 48,
                      decoration: BoxDecoration(
                        color: p.ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: p.lectureTint,
                              borderRadius: BorderRadius.circular(T.rSm),
                              border: Border.all(color: p.lectureEdge),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: p.tutorialTint,
                              borderRadius: BorderRadius.circular(T.rSm),
                              border: Border.all(color: p.tutorialEdge),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: p.labTint,
                              borderRadius: BorderRadius.circular(T.rSm),
                              border: Border.all(color: p.labEdge),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.accentTint,
                          borderRadius: BorderRadius.circular(T.rSm),
                          border: Border.all(color: p.accentEdge),
                        ),
                        child: Text(
                          'COL106',
                          style: AppText.mono(size: 8, color: p.accentInk),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: AppText.mono(
                        size: T.fs13,
                        weight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? T.accentInk : T.ink,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, size: 18, color: T.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
