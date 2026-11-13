import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/features/product/data/error_report_repository.dart';
import 'package:qout/features/product/domain/error_report.dart';

/// Opens the "Report an error" sheet; shows a confirmation once saved.
Future<void> showReportErrorSheet(
  BuildContext context, {
  required String ean,
  required DateTime productUpdatedAt,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        ReportErrorSheet(ean: ean, productUpdatedAt: productUpdatedAt),
  );
  if (sent ?? false) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Thanks! Your report is saved and will be sent to Qout.'),
      ),
    );
  }
}

/// What is wrong, plus an optional comment. Pops `true` once saved.
class ReportErrorSheet extends ConsumerStatefulWidget {
  const ReportErrorSheet({
    required this.ean,
    required this.productUpdatedAt,
    super.key,
  });

  final String ean;
  final DateTime productUpdatedAt;

  @override
  ConsumerState<ReportErrorSheet> createState() => _ReportErrorSheetState();
}

class _ReportErrorSheetState extends ConsumerState<ReportErrorSheet> {
  final _reasons = <ErrorReportReason>{};
  final _comment = TextEditingController();
  ErrorReportProblem? _problem;
  bool _showProblem = false;
  bool _saving = false;
  bool _failed = false;

  static const Map<ErrorReportReason, String> _labels = {
    ErrorReportReason.name: 'Name or brand',
    ErrorReportReason.nutrition: 'Nutrition values',
    ErrorReportReason.grade: 'Grade or score',
    ErrorReportReason.additives: 'Additives',
    ErrorReportReason.other: 'Something else',
  };

  @override
  void initState() {
    super.initState();
    _comment.addListener(_validate);
    _validate();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _validate() => setState(() {
    _problem = validateErrorReport(reasons: _reasons, comment: _comment.text);
  });

  Future<void> _send() async {
    if (_problem != null) {
      setState(() => _showProblem = true);
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref
          .read(errorReportRepositoryProvider)
          .submit(
            ean: widget.ean,
            reasons: _reasons,
            comment: _comment.text,
            productUpdatedAt: widget.productUpdatedAt,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _showProblem ? _problem : null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report an error', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('What is wrong with this product?'),
            for (final MapEntry(key: reason, value: label) in _labels.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                value: _reasons.contains(reason),
                onChanged: (checked) {
                  (checked ?? false)
                      ? _reasons.add(reason)
                      : _reasons.remove(reason);
                  _validate();
                },
              ),
            if (problem == ErrorReportProblem.noReason)
              Text(
                'Choose at least one.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLength: errorReportCommentMaxLength,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'For example: salt is 0.3 g on the label',
                border: const OutlineInputBorder(),
                errorText: switch (problem) {
                  ErrorReportProblem.otherNeedsComment => 'Say what is wrong.',
                  ErrorReportProblem.commentTooLong =>
                    'At most $errorReportCommentMaxLength characters.',
                  _ => null,
                },
              ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Could not save the report. Try again.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _send,
              child: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
