import 'package:flutter/material.dart';

import '../core/calendar_events.dart';
import '../core/course_policy.dart';
import '../models/actor.dart';
import '../models/course_policy.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class CoursePolicySheet extends StatefulWidget {
  const CoursePolicySheet({
    super.key,
    required this.initial,
  });

  final CoursePolicyDraft initial;

  static Future<CoursePolicyDraft?> show(
    BuildContext context, {
    required CoursePolicy? policy,
  }) {
    return showModalBottomSheet<CoursePolicyDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CoursePolicySheet(
        initial: CoursePolicyDraft.fromPolicy(policy),
      ),
    );
  }

  @override
  State<CoursePolicySheet> createState() => _CoursePolicySheetState();
}

class _CoursePolicySheetState extends State<CoursePolicySheet> {
  late CoursePolicyDraft _draft;
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _draft = CoursePolicyDraft.fromPolicy(null)
      ..markingScheme = widget.initial.markingScheme
      ..attendancePolicy = widget.initial.attendancePolicy
      ..auditWithdrawalPolicy = widget.initial.auditWithdrawalPolicy
      ..otherNotes = widget.initial.otherNotes
      ..createdBy = widget.initial.createdBy
      ..updatedBy = widget.initial.updatedBy;
    _controllers = {
      for (final field in kPolicyFields)
        field.key: TextEditingController(text: draftField(_draft, field.key)),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _editing => widget.initial.hasContent;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final submittable = isPolicySubmittable(_draft);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final title = _editing ? 'Edit course policy' : 'Add course policy';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            color: T.surface,
            child: Column(
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
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppText.serif(size: T.fs21, weight: FontWeight.w600, color: T.ink),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, size: 20, color: T.ink3),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space16),
                    children: [
                      if (_editing &&
                          (_draft.createdBy != null || _draft.updatedBy != null)) ...[
                        if (_draft.createdBy != null)
                          _PolicyActorLine(label: 'Added by', actor: _draft.createdBy!),
                        if (_draft.updatedBy != null &&
                            !actorsMatch(_draft.createdBy, _draft.updatedBy))
                          _PolicyActorLine(
                            label: 'Last edited by',
                            actor: _draft.updatedBy!,
                          ),
                        const SizedBox(height: T.space12),
                      ],
                      for (final field in kPolicyFields) ...[
                        Text(field.label, style: AppText.sans(size: T.fs12, color: T.ink2)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _controllers[field.key],
                          onChanged: (v) => setDraftField(_draft, field.key, v),
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(hintText: field.placeholder),
                        ),
                        const SizedBox(height: T.space16),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    T.space16,
                    T.space8,
                    T.space16,
                    T.space16 + bottomInset,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submittable ? () => Navigator.pop(context, _draft) : null,
                      child: const Text('Save policy'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on CoursePolicyDraft {
  bool get hasContent => isPolicySubmittable(this);
}

class _PolicyActorLine extends StatelessWidget {
  const _PolicyActorLine({required this.label, required this.actor});

  final String label;
  final Actor actor;

  @override
  Widget build(BuildContext context) {
    final info = formatEventActor(actor);
    if (info == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: AppText.sans(size: T.fs12, color: T.ink3, height: 1.35),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: info.who,
              style: AppText.mono(size: T.fs12, color: T.ink2),
            ),
            if (info.when.isNotEmpty)
              TextSpan(
                text: '  · ${info.when}',
                style: AppText.mono(size: T.fs11, color: T.ink4),
              ),
          ],
        ),
      ),
    );
  }
}
