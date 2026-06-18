import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/reports_api.dart';
import '../core/feedback.dart';
import '../state/auth_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/sheet_scaffold.dart';

/// Report shared UGC (events, policy, room markings).
class ReportContentSheet extends StatefulWidget {
  const ReportContentSheet({
    super.key,
    required this.targetKind,
    required this.targetId,
    required this.contextLabel,
    this.pageContext,
    this.label,
  });

  final String targetKind;
  final String targetId;
  final String contextLabel;
  final String? pageContext;
  final String? label;

  static Future<void> show(
    BuildContext context, {
    required String targetKind,
    required String targetId,
    required String contextLabel,
    String? pageContext,
    String? label,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      child: ReportContentSheet(
        targetKind: targetKind,
        targetId: targetId,
        contextLabel: contextLabel,
        pageContext: pageContext,
        label: label,
      ),
    );
  }

  @override
  State<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<ReportContentSheet> {
  String? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<ReportsApi>().submit(
        targetKind: widget.targetKind,
        targetId: widget.targetId,
        reason: _reason!,
        details: _detailsController.text.trim(),
        pageContext: widget.pageContext,
        label: widget.label,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = reportErrorMessage(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = reportErrorMessage(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return SheetScaffold(
        title: 'Report this',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatusBanner(kind: 'warn', text: reportErrorMessage('not_authenticated')),
            const SizedBox(height: T.space12),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await auth.startBrowserLogin();
              },
              child: const Text('Log in'),
            ),
          ],
        ),
      );
    }

    if (_done) {
      return SheetScaffold(
        title: 'Report this',
        body: StatusBanner(
          kind: 'ok',
          text: 'Thanks. We will review your report.',
        ),
        primaryLabel: 'Done',
        onPrimary: () => Navigator.pop(context),
      );
    }

    return SheetScaffold(
      title: 'Report this',
      subtitle: Text(
        widget.contextLabel,
        style: AppText.mono(size: T.fs13, color: T.ink2),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reason', style: AppText.sans(size: T.fs13, color: T.ink3)),
          const SizedBox(height: T.space8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in reportReasons)
                GestureDetector(
                  onTap: _submitting ? null : () => setState(() => _reason = r.id),
                  child: Pill(
                    r.label,
                    tint: _reason == r.id ? T.accentTint : T.paper2,
                    edge: _reason == r.id ? T.accentEdge : T.line,
                    ink: _reason == r.id ? T.accentInk : T.ink2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: T.space16),
          Text('Details (optional)', style: AppText.sans(size: T.fs13, color: T.ink3)),
          const SizedBox(height: T.space4),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            maxLength: reportMaxDetailsLen,
            enabled: !_submitting,
            decoration: const InputDecoration(hintText: 'What looks wrong?'),
          ),
          if (_error != null) ...[
            const SizedBox(height: T.space12),
            StatusBanner(kind: 'err', text: _error!),
          ],
        ],
      ),
      primaryLabel: _submitting ? 'Sending…' : 'Submit report',
      primaryLoading: _submitting,
      onPrimary: _reason == null || _submitting ? null : _submit,
    );
  }
}
