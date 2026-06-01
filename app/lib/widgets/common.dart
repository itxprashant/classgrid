import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// A small tinted pill, used for slot/credit/code chips.
class Pill extends StatelessWidget {
  const Pill(
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
  const StatusBanner({
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
  const EmptyState({super.key, required this.message, this.icon, this.action});

  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
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

/// Choice chip with readable label on both selected (dark) and unselected (tint) states.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: AppText.mono(
          size: T.fs12,
          color: selected ? T.accentFg : T.accentInk,
        ),
      ),
      selected: selected,
      selectedColor: T.accent,
      backgroundColor: T.accentTint,
      side: BorderSide(color: T.accentEdge),
      checkmarkColor: T.accentFg,
      labelStyle: AppText.mono(
        size: T.fs12,
        color: selected ? T.accentFg : T.accentInk,
      ),
      onSelected: onSelected,
    );
  }
}

/// An editorial page header: eyebrow + serif title + optional subtitle.
class PageHeader extends StatelessWidget {
  const PageHeader({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                Text(title, style: AppText.serif(size: T.fs26)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
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
