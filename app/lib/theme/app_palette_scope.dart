import 'package:flutter/widgets.dart';

import '../state/theme_controller.dart';

/// Binds [BuildContext] to [ThemeController] so widgets rebuild when the palette
/// changes. Most screens use [T] getters rather than [Theme.of], so they must
/// depend on this (or watch [ThemeController] directly) to pick up live theme edits.
class AppPaletteScope extends InheritedNotifier<ThemeController> {
  const AppPaletteScope({
    super.key,
    required ThemeController super.notifier,
    required super.child,
  });

  static ThemeController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppPaletteScope>();
    assert(scope != null, 'AppPaletteScope not found above $context');
    return scope!.notifier!;
  }
}
