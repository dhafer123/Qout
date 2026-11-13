/// "Report an error" on a product: what the user says is wrong.
library;

/// What is wrong with the product shown. [value] is what the API receives.
enum ErrorReportReason {
  name('name'),
  nutrition('nutrition'),
  grade('grade'),
  additives('additives'),
  other('other')
  ;

  const ErrorReportReason(this.value);

  final String value;
}

/// Longest comment accepted.
const errorReportCommentMaxLength = 500;

/// Why a report can't be sent as filled in.
enum ErrorReportProblem {
  /// No reason ticked.
  noReason,

  /// "Something else" needs a comment saying what.
  otherNeedsComment,

  /// Longer than [errorReportCommentMaxLength].
  commentTooLong,
}

/// The first problem with a report, or null when it can be sent.
ErrorReportProblem? validateErrorReport({
  required Set<ErrorReportReason> reasons,
  required String comment,
}) {
  final text = comment.trim();
  if (reasons.isEmpty) return ErrorReportProblem.noReason;
  if (text.length > errorReportCommentMaxLength) {
    return ErrorReportProblem.commentTooLong;
  }
  if (reasons.contains(ErrorReportReason.other) && text.isEmpty) {
    return ErrorReportProblem.otherNeedsComment;
  }
  return null;
}
