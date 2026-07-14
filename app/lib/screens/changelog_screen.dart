import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/app_version_api.dart';
import '../models/app_version_info.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/release_notes_body.dart';

/// Paginated release history from GET /api/app/changelog.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  static const _pageSize = 20;

  List<AppReleaseEntry> _releases = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await AppVersionApi(widget.apiClient).fetchChangelog(
        limit: _pageSize,
        offset: reset ? 0 : _releases.length,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _releases = page.releases;
        } else {
          _releases = [..._releases, ...page.releases];
        }
        _total = page.total;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load release history.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return ScreenShell(
      eyebrow: 'About',
      title: 'Release history',
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: T.accent,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _releases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && _releases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(T.space24),
        children: [
          Text(_error!, style: AppText.sans(color: T.danger)),
          const SizedBox(height: T.space12),
          OutlinedButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
        ],
      );
    }

    if (_releases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(T.space24),
        children: [
          Text(
            'No releases published yet.',
            style: AppText.sans(size: T.fs14, color: T.ink2),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(T.space16, T.space8, T.space16, T.space32),
      itemCount: _releases.length + (_releases.length < _total ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _releases.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: T.space12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: () => _load(reset: false),
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        return _ReleaseCard(entry: _releases[index]);
      },
    );
  }
}

class _ReleaseCard extends StatefulWidget {
  const _ReleaseCard({required this.entry});

  final AppReleaseEntry entry;

  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final entry = widget.entry;
    final dateLabel = entry.publishedAt != null
        ? '${entry.publishedAt!.year}-${entry.publishedAt!.month.toString().padLeft(2, '0')}-${entry.publishedAt!.day.toString().padLeft(2, '0')}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: T.space12),
      child: AppCard(
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(T.r),
          child: Padding(
            padding: const EdgeInsets.all(T.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'v${entry.version}',
                        style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      'build ${entry.build}',
                      style: AppText.mono(size: T.fs12, color: T.ink3),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: T.ink3,
                    ),
                  ],
                ),
                if (dateLabel != null) ...[
                  const SizedBox(height: T.space4),
                  Text(dateLabel, style: AppText.mono(size: T.fs11, color: T.ink4)),
                ],
                if (_expanded) ...[
                  const SizedBox(height: T.space12),
                  if (entry.releaseNotes.isEmpty)
                    Text(
                      'No release notes.',
                      style: AppText.sans(size: T.fs13, color: T.ink3),
                    )
                  else
                    ReleaseNotesBody(notes: entry.releaseNotes),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
