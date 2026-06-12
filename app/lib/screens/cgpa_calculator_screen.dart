import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/cgpa.dart';
import '../models/plan.dart';
import '../state/planner_store.dart';
import '../storage/cgpa_store.dart';
import '../storage/local_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// CGPA / SGPA calculator for the current semester (plan courses + grades).
class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({super.key});

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> {
  CgpaStore? _store;
  final _priorCgpaCtrl = TextEditingController();
  final _priorCreditsCtrl = TextEditingController();

  List<CgpaCourseRow> _rows = [];
  Map<String, String> _savedGrades = {};
  bool _loaded = false;
  String _planSignature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _store = CgpaStore(context.read<LocalStore>().sharedPreferences);
    _loadSaved();
  }

  void _loadSaved() {
    final store = _store;
    if (store == null) return;
    final priorCgpa = store.loadPriorCgpa();
    final priorCredits = store.loadPriorCredits();
    if (priorCgpa != null) {
      _priorCgpaCtrl.text = priorCgpa.toString();
    }
    if (priorCredits != null) {
      _priorCreditsCtrl.text = _formatCreditsInput(priorCredits);
    }
    _savedGrades = store.loadGradeMap();
    _syncRowsFromPlan(context.read<PlannerStore>().selectedCourses);
    _loaded = true;
  }

  @override
  void dispose() {
    _store?.dispose();
    _priorCgpaCtrl.dispose();
    _priorCreditsCtrl.dispose();
    super.dispose();
  }

  double? get _priorCgpa => double.tryParse(_priorCgpaCtrl.text.trim());
  double? get _priorCredits => double.tryParse(_priorCreditsCtrl.text.trim());

  String _planCoursesSignature(List<SelectedCourse> courses) {
    return courses.map((c) => '${c.courseCode}:${c.totalCredits}').join('|');
  }

  void _syncRowsFromPlan(List<SelectedCourse> courses) {
    final grades = <String, String>{..._savedGrades};
    for (final row in _rows) {
      final g = normalizeGradeSelection(row.gradeSelection);
      if (g != null) grades[row.code] = g;
    }

    _rows = courses.map((c) {
      final saved = normalizeGradeSelection(grades[c.courseCode]);
      return CgpaCourseRow(
        code: c.courseCode,
        name: c.courseName,
        credits: c.totalCredits,
        gradeSelection: saved,
      );
    }).toList();
    _planSignature = _planCoursesSignature(courses);
  }

  void _persist() {
    final grades = <String, String>{};
    for (final row in _rows) {
      final g = normalizeGradeSelection(row.gradeSelection);
      if (g != null) grades[row.code] = g;
    }
    _savedGrades = grades;
    _store?.scheduleSave(
      priorCgpa: _priorCgpa,
      priorCredits: _priorCredits,
      gradesByCode: grades,
    );
  }

  void _setGrade(int index, String? grade) {
    setState(() {
      _rows = [..._rows]
        ..[index] = _rows[index].copyWith(
          gradeSelection: grade,
          clearGrade: grade == null,
        );
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final courses = context.watch<PlannerStore>().selectedCourses;
    final signature = _planCoursesSignature(courses);
    if (_loaded && signature != _planSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _syncRowsFromPlan(courses));
      });
    }

    final sgpa = computeSgpa(_rows);
    final cgpa = computeCgpa(
      priorCgpa: _priorCgpa,
      priorCredits: _priorCredits,
      rows: _rows,
    );
    final semCredits = semesterCreditsForSgpa(_rows);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CGPA calculator',
          style: AppText.serif(size: T.fs18, weight: FontWeight.w600, color: T.ink),
        ),
      ),
      body: Material(
        color: T.paper,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  PageHeader(
                    eyebrow: 'Tools',
                    title: 'CGPA calculator',
                    subtitle: Text(
                      'Grades from your plan on a 10-point scale',
                      style: AppText.sans(size: T.fs14, color: T.ink3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ResultsCard(sgpa: sgpa, cgpa: cgpa, semCredits: semCredits),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Before this semester',
                      style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'CGPA so far',
                            controller: _priorCgpaCtrl,
                            hint: 'e.g. 8.25',
                            onChanged: (_) => _persist(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabeledField(
                            label: 'Credits done',
                            controller: _priorCreditsCtrl,
                            hint: 'e.g. 60',
                            onChanged: (_) => _persist(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Saved on this device. Used for projected CGPA after this semester.',
                      style: AppText.sans(size: T.fs12, color: T.ink3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'This semester',
                      style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Courses from your plan — pick a grade for each.',
                      style: AppText.sans(size: T.fs12, color: T.ink3),
                    ),
                  ),
                  if (_rows.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: EmptyState(
                        message: 'Add courses to your plan first.',
                        icon: Icons.school_outlined,
                      ),
                    )
                  else
                    ...List.generate(_rows.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _CourseGradeRow(
                          row: _rows[i],
                          onGradeChanged: (g) => _setGrade(i, g),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}

String _formatCreditsInput(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

String _fmtCredits(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.sgpa,
    required this.cgpa,
    required this.semCredits,
  });

  final double? sgpa;
  final double? cgpa;
  final double semCredits;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.accentTint,
        border: Border.all(color: T.accentEdge),
        borderRadius: BorderRadius.circular(T.rLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SGPA', style: AppText.mono(size: T.fs12, color: T.accentInk)),
                const SizedBox(height: 4),
                Text(
                  formatGpa(sgpa),
                  style: AppText.mono(size: T.fs26, color: T.accentInk, weight: FontWeight.w700),
                ),
                Text(
                  semCredits > 0 ? '${_fmtCredits(semCredits)} graded cr' : 'Pick grades',
                  style: AppText.sans(size: T.fs12, color: T.ink3),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 56, color: T.accentEdge),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CGPA', style: AppText.mono(size: T.fs12, color: T.accentInk)),
                const SizedBox(height: 4),
                Text(
                  formatGpa(cgpa),
                  style: AppText.mono(size: T.fs26, color: T.accentInk, weight: FontWeight.w700),
                ),
                Text(
                  'after this semester',
                  style: AppText.sans(size: T.fs12, color: T.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.sans(size: T.fs12, color: T.ink3)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          decoration: InputDecoration(hintText: hint),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CourseGradeRow extends StatelessWidget {
  const _CourseGradeRow({
    required this.row,
    required this.onGradeChanged,
  });

  final CgpaCourseRow row;
  final ValueChanged<String?> onGradeChanged;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final selection = normalizeGradeSelection(row.gradeSelection);
    final hint = gradeSelectionHint(selection);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.rLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.code,
                  style: AppText.mono(size: T.fs13, weight: FontWeight.w600),
                ),
                if (row.name != null && row.name!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.name!,
                    style: AppText.sans(size: T.fs13, color: T.ink2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${_fmtCredits(row.credits)} cr',
                  style: AppText.mono(size: T.fs12, color: T.ink3),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: AppText.sans(size: T.fs12, color: T.ink3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('${row.code}-$selection'),
              initialValue: selection,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Grade',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              style: AppText.mono(size: T.fs14),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('—'),
                ),
                for (final g in kCgpaGradeOptions)
                  DropdownMenuItem<String?>(
                    value: g,
                    child: Text(gradeSelectionLabel(g)),
                  ),
              ],
              onChanged: onGradeChanged,
            ),
          ),
        ],
      ),
    );
  }
}
