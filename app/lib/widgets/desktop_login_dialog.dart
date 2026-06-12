import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/auth_token.dart';
import '../state/auth_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// OAuth for Linux/Windows: browser shows a copyable token page (no deep link).
class DesktopLoginDialog extends StatefulWidget {
  const DesktopLoginDialog({super.key});

  @override
  State<DesktopLoginDialog> createState() => _DesktopLoginDialogState();
}

class _DesktopLoginDialogState extends State<DesktopLoginDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _openedBrowser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowser());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openBrowser() async {
    final url = Uri.parse(AppConfig.browserLoginUrl);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (mounted) {
      setState(() => _openedBrowser = opened);
      if (!opened) _error = 'Could not open the browser.';
    }
  }

  Future<void> _submit() async {
    final token = parseSessionTokenInput(_controller.text);
    if (token == null) {
      setState(() => _error = 'Paste the full token from the browser page.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final auth = context.read<AuthProvider>();
    try {
      await auth.completeLogin(token);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Sign-in failed. Copy the token again from the browser.';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return AlertDialog(
      title: Text('IITD login', style: AppText.serif(size: T.fs18, weight: FontWeight.w600, color: T.ink)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _openedBrowser
                  ? '1. Sign in with IITD in the browser tab that opened.\n'
                      '2. On the success page, click Copy token.\n'
                      '3. Paste below and tap Continue.'
                  : 'Open the sign-in page in your browser, complete IITD login, then paste the token here.',
              style: AppText.sans(size: T.fs13, color: T.ink2),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openBrowser,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Open sign-in page'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Session token',
                hintText: 'Paste from browser',
              ),
              maxLines: 3,
              style: AppText.mono(size: T.fs12),
              autocorrect: false,
              enableSuggestions: false,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppText.sans(size: T.fs12, color: T.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}
