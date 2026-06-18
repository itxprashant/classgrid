import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/history_api.dart';
import '../models/instructor_summary.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import 'prof_detail_screen.dart';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class ProfExplorerScreen extends StatefulWidget {
  const ProfExplorerScreen({super.key});

  @override
  State<ProfExplorerScreen> createState() => _ProfExplorerScreenState();
}

class _ProfExplorerScreenState extends State<ProfExplorerScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<InstructorSummary> _results = [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
        _lastQuery = q;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = q;
    });
    try {
      final results = await context.read<HistoryApi>().searchInstructors(q);
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Search failed';
      });
    }
  }

  void _openInstructor(InstructorSummary instructor) {
    pushAppRoute<void>(
      context,
      ProfDetailScreen(
        instructorEmail: instructor.email,
        instructorName: instructor.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);

    return ScreenShell(
      eyebrow: 'Tools',
      title: 'Prof explorer',
      subtitle: Text(
        'Search by name or IITD email',
        style: AppText.sans(size: T.fs14, color: T.ink2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space32),
        children: [
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'e.g. dewan or @cse.iitd.ac.in',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(T.r)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: T.space12),
            Text(_error!, style: AppText.sans(size: T.fs13, color: T.danger)),
          ],
          if (_controller.text.trim().length < 2 && !_loading) ...[
            const SizedBox(height: T.space24),
            EmptyState(
              message: 'Type at least 2 characters to search past and current offerings.',
              icon: Icons.person_search_outlined,
            ),
          ] else if (!_loading && _results.isEmpty && _controller.text.trim().length >= 2) ...[
            const SizedBox(height: T.space24),
            EmptyState(message: 'No instructors matched “${_controller.text.trim()}”.', icon: Icons.search_off),
          ] else ...[
            const SizedBox(height: T.space16),
            for (final row in _results)
              Padding(
                padding: const EdgeInsets.only(bottom: T.space8),
                child: Material(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(T.r),
                  child: InkWell(
                    onTap: () => _openInstructor(row),
                    borderRadius: BorderRadius.circular(T.r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: T.line),
                        borderRadius: BorderRadius.circular(T.r),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: T.accentTint,
                            child: Text(
                              _initials(row.name),
                              style: AppText.mono(size: T.fs11, color: T.accentInk, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: T.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.name, style: AppText.sans(size: T.fs14, weight: FontWeight.w600)),
                                Text(row.email, style: AppText.mono(size: T.fs12, color: T.ink3)),
                              ],
                            ),
                          ),
                          Pill('${row.offeringCount}', tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
