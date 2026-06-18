import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/instructor_ref.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class InstructorLinks extends StatelessWidget {
  const InstructorLinks({
    super.key,
    required this.instructors,
    this.onTap,
    this.style,
    this.linkColor,
  });

  final List<InstructorRef> instructors;
  final void Function(String email, String name)? onTap;
  final TextStyle? style;
  final Color? linkColor;

  @override
  Widget build(BuildContext context) {
    if (instructors.isEmpty) return const SizedBox.shrink();

    final base = style ?? AppText.sans(size: T.fs13, color: T.ink2);
    final linkInk = linkColor ?? T.accentInk;
    final spans = <InlineSpan>[];

    for (var i = 0; i < instructors.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: ' · ', style: base.copyWith(color: T.ink3)));
      }
      final inst = instructors[i];
      final email = inst.email;
      if (email != null && onTap != null) {
        spans.add(
          TextSpan(
            text: inst.name.isNotEmpty ? inst.name : email,
            style: base.copyWith(color: linkInk, fontWeight: FontWeight.w500),
            recognizer: TapGestureRecognizer()..onTap = () => onTap!(email, inst.name),
          ),
        );
      } else {
        spans.add(TextSpan(text: inst.name, style: base));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}
