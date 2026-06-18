/// Shared feedback and report labels (parity with src/utils/feedback.js).
library;

class FeedbackCategory {
  const FeedbackCategory(this.id, this.label);
  final String id;
  final String label;
}

class ReportReason {
  const ReportReason(this.id, this.label);
  final String id;
  final String label;
}

const feedbackCategories = [
  FeedbackCategory('feature', 'Feature idea'),
  FeedbackCategory('improvement', 'Improvement'),
  FeedbackCategory('bug', 'Bug'),
  FeedbackCategory('other', 'Other'),
];

const reportReasons = [
  ReportReason('spam', 'Spam'),
  ReportReason('wrong_info', 'Wrong info'),
  ReportReason('offensive', 'Offensive'),
  ReportReason('duplicate', 'Duplicate'),
  ReportReason('other', 'Other'),
];

const feedbackMinMessageLen = 10;
const feedbackMaxMessageLen = 4000;
const reportMaxDetailsLen = 2000;

bool isFeedbackSubmittable(String message) {
  final trimmed = message.trim();
  return trimmed.length >= feedbackMinMessageLen &&
      trimmed.length <= feedbackMaxMessageLen;
}

String feedbackErrorMessage(String? code) {
  switch (code) {
    case 'message_too_short':
      return 'Please write at least 10 characters.';
    case 'message_too_long':
      return 'Message is too long.';
    case 'rate_limited':
      return 'Too many submissions recently. Try again later.';
    case 'database_unavailable':
      return 'Service temporarily unavailable.';
    default:
      return 'Could not send feedback. Try again.';
  }
}

String reportErrorMessage(String? code) {
  switch (code) {
    case 'duplicate_report':
      return 'You already reported this. We will follow up if needed.';
    case 'not_authenticated':
      return 'Sign in to report content.';
    case 'target_not_found':
      return 'This content could not be found. It may have been removed.';
    case 'invalid_reason':
      return 'Choose a reason for your report.';
    case 'database_unavailable':
      return 'Service temporarily unavailable.';
    default:
      return 'Could not send report. Try again.';
  }
}

String reportContextForEvent({
  required String courseCode,
  required String title,
  required String date,
}) => '$courseCode · $title · $date';

String reportContextForPolicy(String courseCode) => '$courseCode · course policy';

String reportContextForOccupiedRoom({
  required String room,
  required String date,
}) => '$room · $date';
