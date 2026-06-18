import 'package:flutter/material.dart';

import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// A small tinted pill, used for slot/credit/code chips.
class Pill extends StatelessWidget {
  Pill(
    this.label, {
    super.key,
    this.tint,
    this.edge,
    this.ink,
    this.mono = true,
  });

  final String label;
  final Color? tint;
  final Color? edge;
  final Color? ink;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint ?? T.accentTint,
        border: Border.all(color: edge ?? T.accentEdge),
        borderRadius: BorderRadius.circular(T.rSm),
      ),
      child: Text(
        label,
        style: mono
            ? AppText.mono(size: T.fs12, color: ink ?? T.accentInk)
            : AppText.sans(size: T.fs12, color: ink ?? T.accentInk),
      ),
    );
  }
}

/// A dismissible status banner (ok/warn/err) matching the web oauthBanner.
class StatusBanner extends StatelessWidget {
  StatusBanner({
    super.key,
    required this.kind,
    required this.text,
    this.onClose,
  });

  final String kind;
  final String text;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    Color tint, edge, ink;
    switch (kind) {
      case 'ok':
        tint = T.successTint;
        edge = T.successEdge;
        ink = T.successInk;
        break;
      case 'err':
        tint = T.dangerTint;
        edge = T.dangerEdge;
        ink = T.danger;
        break;
      default:
        tint = T.tutorialTint;
        edge = T.tutorialEdge;
        ink = T.tutorialInk;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: edge),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppText.sans(size: T.fs13, color: ink))),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close, size: 16, color: ink),
            ),
        ],
      ),
    );
  }
}

/// A centered empty / status message.
class EmptyState extends StatelessWidget {
  EmptyState({super.key, required this.message, this.icon, this.action});

  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final children = <Widget>[];
    if (icon != null) {
      children.add(Icon(icon, size: 36, color: T.ink4));
      children.add(const SizedBox(height: 12));
    }
    children.add(Text(
      message,
      textAlign: TextAlign.center,
      style: AppText.sans(size: T.fs14, color: T.ink3),
    ));
    if (action != null) {
      children.add(const SizedBox(height: 16));
      children.add(action!);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Selected-state colors for a filter chip or segment.
class AppFilterPalette {
  const AppFilterPalette({required this.fill, required this.ink});

  final Color fill;
  final Color ink;

  static AppFilterPalette get accent =>
      AppFilterPalette(fill: T.accent, ink: T.accentFg);
  static AppFilterPalette get lecture =>
      AppFilterPalette(fill: T.lectureInk, ink: T.lectureTint);
  static AppFilterPalette get tutorial =>
      AppFilterPalette(fill: T.tutorialInk, ink: T.tutorialTint);
  static AppFilterPalette get lab =>
      AppFilterPalette(fill: T.labInk, ink: T.labTint);
}

/// One option in [AppSegmentedFilters].
class AppFilterSegment<V> {
  const AppFilterSegment({
    required this.value,
    required this.label,
    this.icon,
    this.palette,
  });

  final V value;
  final String label;
  final IconData? icon;
  final AppFilterPalette? palette;
}

/// Pressable filter chip for Wrap layouts (dept filters, schedule pickers).
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.palette,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final AppFilterPalette? palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final active = palette ?? AppFilterPalette.accent;
    final fill = selected ? active.fill : T.surface;
    final ink = selected ? active.ink : T.ink2;
    final border = selected ? active.fill.withValues(alpha: 0.35) : T.line;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.rLg),
        splashColor: active.fill.withValues(alpha: 0.12),
        highlightColor: active.fill.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: border, width: selected ? 1.25 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: active.fill.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: T.shadowCard,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 14 : 15, color: ink),
                SizedBox(width: compact ? 5 : 6),
              ],
              Text(
                label,
                style: AppText.mono(
                  size: compact ? T.fs12 : T.fs13,
                  color: ink,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connected pill bar for mutually exclusive filters (session kind, view mode).
class AppSegmentedFilters<V> extends StatelessWidget {
  const AppSegmentedFilters({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppFilterSegment<V>> segments;
  final V selected;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: T.surfaceSunk,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.line),
        boxShadow: [
          BoxShadow(
            color: T.shadowCard,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(child: _SegmentButton(
                segment: segments[i],
                selected: segments[i].value == selected,
                onTap: () => onChanged(segments[i].value),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentButton<V> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final AppFilterSegment<V> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final active = segment.palette ?? AppFilterPalette.accent;
    final fill = selected ? active.fill : Colors.transparent;
    final ink = selected ? active.ink : T.ink3;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        splashColor: active.fill.withValues(alpha: 0.14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: active.fill.withValues(alpha: 0.32),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: 15, color: ink),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(
                    size: T.fs12,
                    color: ink,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choice chip with readable label on both selected and unselected states.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.palette,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;
  final AppFilterPalette? palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppFilterChip(
      label: label,
      selected: selected,
      onTap: () => onSelected(!selected),
      icon: icon,
      palette: palette,
      compact: compact,
    );
  }
}

/// An editorial page header: eyebrow + serif title + optional subtitle.
///
/// Do not use `const PageHeader(...)` at call sites; it reads live [T] tokens.
class PageHeader extends StatelessWidget {
  PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.space16, T.space16, T.space16, T.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(),
                    style: AppText.mono(
                        size: T.fs12, color: T.ink3, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppText.serif(
                    size: T.fs26,
                    weight: FontWeight.w500,
                    color: T.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: T.space4),
                  subtitle!,
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Screen shell: transparent AppBar (back only) + [PageHeader] body pattern.
class ScreenShell extends StatelessWidget {
  const ScreenShell({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.actions,
    required this.body,
    this.floatingActionButton,
  });

  final String eyebrow;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Scaffold(
      backgroundColor: T.paper,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: Material(
        color: T.paper,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              eyebrow: eyebrow,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Raised surface card matching design-system panels.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(T.space12),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.rLg),
        boxShadow: [
          BoxShadow(
            color: T.shadowCard,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.rLg),
        child: card,
      ),
    );
  }
}

/// Mono eyebrow section label (APPEARANCE, SELECTED COURSES, etc.).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.padding});

  final String label;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space8),
      child: Text(
        label.toUpperCase(),
        style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2),
      ),
    );
  }
}

/// Settings-style navigation row inside a grouped card.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Semantics(
      button: true,
      label: subtitle != null ? '$title, $subtitle' : title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: T.space12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: T.accentInk),
                  const SizedBox(width: T.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppText.mono(size: T.fs12, color: T.ink3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing ?? Icon(Icons.chevron_right, size: 20, color: T.ink4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grouped settings section with [SectionHeader] + bordered card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(label),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: T.space16),
          child: Container(
            decoration: BoxDecoration(
              color: T.surface,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.rLg),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: T.line),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Confirm a destructive action. Returns true if confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Remove',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppText.serif(size: T.fs18, color: T.ink)),
      content: Text(message, style: AppText.sans(color: T.ink2)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: T.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Search field with clear button and optional debounce handled by caller.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onClear,
    this.textInputAction = TextInputAction.search,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.search, size: 20, color: T.ink3),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 18, color: T.ink3),
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                      onChanged?.call('');
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Status banner with optional retry action.
class StatusBannerWithRetry extends StatelessWidget {
  StatusBannerWithRetry({
    super.key,
    required this.kind,
    required this.text,
    this.onClose,
    this.onRetry,
  });

  final String kind;
  final String text;
  final VoidCallback? onClose;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    Color tint, edge, ink;
    switch (kind) {
      case 'ok':
        tint = T.successTint;
        edge = T.successEdge;
        ink = T.successInk;
        break;
      case 'err':
        tint = T.dangerTint;
        edge = T.dangerEdge;
        ink = T.danger;
        break;
      default:
        tint = T.tutorialTint;
        edge = T.tutorialEdge;
        ink = T.tutorialInk;
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: T.space16, vertical: T.space8),
      padding: const EdgeInsets.fromLTRB(T.space12, 10, T.space8, 10),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: edge),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppText.sans(size: T.fs13, color: ink))),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Retry'),
            ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close, size: 16, color: ink),
            ),
        ],
      ),
    );
  }
}
