import 'package:flutter/material.dart';

import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Consistent bottom-sheet chrome: drag handle, serif title, scroll body,
/// optional sticky primary action.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.body,
    this.primaryAction,
    this.primaryLabel,
    this.onPrimary,
    this.primaryLoading = false,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });

  final String title;
  final Widget? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? primaryAction;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  static Future<R?> show<R>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool useDraggable = true,
    double initialChildSize = 0.85,
  }) {
    return showModalBottomSheet<R>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: (_) => useDraggable
          ? DraggableScrollableSheet(
              initialChildSize: initialChildSize,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, controller) {
                if (child is SheetScaffold) {
                  return SheetScaffold(
                    title: child.title,
                    subtitle: child.subtitle,
                    actions: child.actions,
                    body: child.body,
                    primaryAction: child.primaryAction,
                    primaryLabel: child.primaryLabel,
                    onPrimary: child.onPrimary,
                    primaryLoading: child.primaryLoading,
                    scrollController: controller,
                    padding: child.padding,
                  );
                }
                return child;
              },
            )
          : child,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: T.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: T.space8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: T.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(T.space16, T.space12, T.space8, T.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.serif(size: T.fs21, weight: FontWeight.w600, color: T.ink),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: T.space4),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: padding,
              children: [body],
            ),
          ),
          if (primaryAction != null || (primaryLabel != null && onPrimary != null))
            Padding(
              padding: EdgeInsets.fromLTRB(T.space16, T.space8, T.space16, T.space16 + bottomInset),
              child: primaryAction ??
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: primaryLoading ? null : onPrimary,
                      child: primaryLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: T.accentFg,
                              ),
                            )
                          : Text(primaryLabel!),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}
