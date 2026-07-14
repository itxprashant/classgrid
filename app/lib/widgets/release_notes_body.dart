import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Renders release notes markdown (Keep a Changelog sections from the API).
class ReleaseNotesBody extends StatelessWidget {
  const ReleaseNotesBody({
    super.key,
    required this.notes,
    this.selectable = true,
  });

  final String notes;
  final bool selectable;

  static MarkdownStyleSheet _styleSheet() {
    final body = AppText.sans(size: T.fs13, color: T.ink2, height: 1.42);
    return MarkdownStyleSheet(
      p: body,
      pPadding: const EdgeInsets.only(bottom: T.space8),
      h3: AppText.sans(size: T.fs13, weight: FontWeight.w600, color: T.ink),
      h3Padding: const EdgeInsets.only(top: T.space8, bottom: T.space4),
      h2: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink),
      h2Padding: const EdgeInsets.only(top: T.space8, bottom: T.space4),
      strong: AppText.sans(
        size: T.fs13,
        weight: FontWeight.w600,
        color: T.ink,
        height: 1.42,
      ),
      em: body.copyWith(fontStyle: FontStyle.italic),
      a: AppText.sans(size: T.fs13, color: T.accentInk, height: 1.42).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: T.accentEdge,
      ),
      listBullet: body,
      listIndent: 24,
      blockSpacing: T.space8,
      blockquote: body.copyWith(color: T.ink3),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: T.space12),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: T.lineStrong, width: 3)),
      ),
      code: AppText.mono(size: T.fs12, color: T.ink),
      codeblockDecoration: BoxDecoration(
        color: T.paper2,
        borderRadius: BorderRadius.circular(T.rSm),
        border: Border.all(color: T.line),
      ),
      codeblockPadding: const EdgeInsets.all(T.space12),
    );
  }

  Future<void> _openLink(String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final trimmed = notes.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return MarkdownBody(
      data: trimmed,
      selectable: selectable,
      shrinkWrap: true,
      styleSheet: _styleSheet(),
      onTapLink: (text, href, title) => _openLink(href),
    );
  }
}
