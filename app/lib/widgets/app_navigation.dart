import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shared page route with a subtle slide-up + fade transition.
PageRoute<R> appRoute<R>(Widget page) {
  return PageRouteBuilder<R>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (reduceMotion) return child;

      final curved = CurvedAnimation(parent: animation, curve: T.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: T.tSlow,
    reverseTransitionDuration: T.tBase,
  );
}

/// Push [page] using the shared route transition.
Future<R?> pushAppRoute<R>(BuildContext context, Widget page) {
  return Navigator.of(context).push<R>(appRoute<R>(page));
}
