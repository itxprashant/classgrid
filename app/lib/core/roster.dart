import '../models/enrolled_student.dart';

class BranchCount {
  const BranchCount({required this.branch, required this.count});

  final String branch;
  final int count;
}

/// Groups enrolled students by 3-character kerberos prefix (matches web CourseDetails).
List<BranchCount> branchCounts(Iterable<EnrolledStudent> students) {
  final counts = <String, int>{};
  final prefix = RegExp(r'^([a-z0-9]{3})', caseSensitive: false);

  for (final student in students) {
    final match = prefix.firstMatch(student.id);
    final branch = match != null ? match.group(1)!.toUpperCase() : 'Others';
    counts[branch] = (counts[branch] ?? 0) + 1;
  }

  final rows = counts.entries
      .map((e) => BranchCount(branch: e.key, count: e.value))
      .toList();
  rows.sort((a, b) => b.count.compareTo(a.count));
  return rows;
}
