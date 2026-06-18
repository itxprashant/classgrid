import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/feedback_api.dart';
import '../core/feedback.dart';
import '../state/auth_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Feature feedback form — opened from drawer or About.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _category = 'feature';
  final _messageController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (!isFeedbackSubmittable(message)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<FeedbackApi>().submit(
        message: message,
        category: _category,
        pageContext: 'feedback',
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
        _error = feedbackErrorMessage(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = feedbackErrorMessage(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final auth = context.watch<AuthProvider>();

    return ScreenShell(
      eyebrow: 'Help improve ClassGrid',
      title: 'Suggest a feature',
      subtitle: Text(
        'Tell us what would make planning your semester easier. We read every submission when prioritizing the roadmap.',
        style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: T.space32),
        children: [
          if (_done)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: T.space16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBanner(kind: 'ok', text: 'Thanks. We will review your suggestion.'),
                    const SizedBox(height: T.space12),
                    Text(
                      'Feature ideas help us prioritize what to build next.',
                      style: AppText.sans(size: T.fs14, color: T.ink3, height: 1.45),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: T.space16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Category', style: AppText.sans(size: T.fs13, color: T.ink3)),
                    const SizedBox(height: T.space4),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (final c in feedbackCategories)
                          DropdownMenuItem(value: c.id, child: Text(c.label)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) {
                              if (v != null) setState(() => _category = v);
                            },
                    ),
                    const SizedBox(height: T.space16),
                    Text('Your idea', style: AppText.sans(size: T.fs13, color: T.ink3)),
                    const SizedBox(height: T.space4),
                    TextField(
                      controller: _messageController,
                      maxLines: 6,
                      maxLength: feedbackMaxMessageLen,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        hintText: 'Describe the feature or improvement you would like to see.',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (!auth.isLoggedIn) ...[
                      const SizedBox(height: T.space4),
                      Text(
                        'Signed in? We can reach you if we have questions.',
                        style: AppText.sans(size: T.fs13, color: T.ink3),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: T.space12),
                      StatusBanner(kind: 'err', text: _error!),
                    ],
                    const SizedBox(height: T.space16),
                    FilledButton(
                      onPressed: _submitting || !isFeedbackSubmittable(_messageController.text)
                          ? null
                          : _submit,
                      child: Text(_submitting ? 'Sending…' : 'Send feedback'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
