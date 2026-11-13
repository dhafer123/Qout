import 'package:flutter_test/flutter_test.dart';
import 'package:qout/features/product/domain/error_report.dart';

void main() {
  ErrorReportProblem? validate(
    Set<ErrorReportReason> reasons, [
    String comment = '',
  ]) => validateErrorReport(reasons: reasons, comment: comment);

  test('one reason is enough, the comment is optional', () {
    expect(validate({ErrorReportReason.nutrition}), isNull);
    expect(
      validate({ErrorReportReason.name, ErrorReportReason.grade}, 'Typo'),
      isNull,
    );
  });

  test('needs at least one reason', () {
    expect(validate({}), ErrorReportProblem.noReason);
    expect(validate({}, 'Something is off'), ErrorReportProblem.noReason);
  });

  test('"something else" needs a comment', () {
    expect(
      validate({ErrorReportReason.other}),
      ErrorReportProblem.otherNeedsComment,
    );
    expect(
      validate({ErrorReportReason.other}, '   \n'),
      ErrorReportProblem.otherNeedsComment,
    );
    expect(validate({ErrorReportReason.other}, 'Wrong photo'), isNull);
  });

  test('the comment has a length limit, surrounding spaces excluded', () {
    final longest = 'x' * errorReportCommentMaxLength;
    expect(validate({ErrorReportReason.name}, longest), isNull);
    expect(validate({ErrorReportReason.name}, '  $longest  '), isNull);
    expect(
      validate({ErrorReportReason.name}, '${longest}x'),
      ErrorReportProblem.commentTooLong,
    );
  });

  test('reason values are the API names', () {
    expect(ErrorReportReason.values.map((r) => r.value), [
      'name',
      'nutrition',
      'grade',
      'additives',
      'other',
    ]);
  });
}
