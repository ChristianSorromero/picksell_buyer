import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../services/review_service.dart';

/// A review card with the website's Helpful and Report actions. Helpful
/// flips at once and goes back if the server refuses; the server's count wins.
class ReviewWithFeedback extends StatefulWidget {
  const ReviewWithFeedback({super.key, required this.review, this.reasons = ReportReason.defaults});

  final Review review;
  final List<ReportReason> reasons;

  @override
  State<ReviewWithFeedback> createState() => _ReviewWithFeedbackState();
}

class _ReviewWithFeedbackState extends State<ReviewWithFeedback> {
  final _service = ReviewService();
  late Review _review = widget.review;
  bool _voting = false;

  @override
  void didUpdateWidget(covariant ReviewWithFeedback old) {
    super.didUpdateWidget(old);
    if (old.review != widget.review) _review = widget.review;
  }

  Future<void> _toggleHelpful() async {
    final want = !_review.isHelpful;
    final before = _review;
    setState(() {
      _voting = true;
      _review = _review.copyWith(isHelpful: want, helpfulCount: _review.helpfulCount + (want ? 1 : -1));
    });
    try {
      final r = await _service.setHelpful(_review.id, helpful: want);
      if (mounted) setState(() => _review = _review.copyWith(isHelpful: r.helpful, helpfulCount: r.count));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _review = before);
      PsToast.error(context, e.isNetworkError ? 'You’re offline. Try again.' : e.message);
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _report() async {
    final message = await PsBottomSheet.show<String>(
      context,
      title: 'Report this review',
      builder: (_) => _ReportSheet(reviewId: _review.id, reasons: widget.reasons, service: _service),
    );
    if (message == null || !mounted) return;
    setState(() => _review = _review.copyWith(reported: true));
    PsToast.success(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final r = _review;
    return PsReviewCard(
      review: r,
      footer: r.isMine
          ? Text('Your review', style: PsText.caption)
          : Row(
              children: [
                TextButton.icon(
                  onPressed: _voting ? null : _toggleHelpful,
                  style: TextButton.styleFrom(
                    foregroundColor: r.isHelpful ? PsColors.primaryStrong : PsColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(r.isHelpful ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 18),
                  label: Text(r.helpfulCount > 0 ? 'Helpful (${r.helpfulCount})' : 'Helpful'),
                ),
                const Spacer(),
                if (r.reported)
                  Text('Reported', style: PsText.caption)
                else
                  TextButton(
                    onPressed: _report,
                    style: TextButton.styleFrom(foregroundColor: PsColors.textMuted, visualDensity: VisualDensity.compact),
                    child: const Text('Report'),
                  ),
              ],
            ),
    );
  }
}

/// Pick a reason (and optionally say more), then send. Pops the server's thank-you.
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.reviewId, required this.reasons, required this.service});

  final int reviewId;
  final List<ReportReason> reasons;
  final ReviewService service;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) {
      setState(() => _error = 'Choose why you are reporting this review.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await widget.service.report(widget.reviewId, reason: _reason!, details: _details.text);
      if (mounted) Navigator.of(context).pop(message);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.fieldError('reason') ?? e.fieldError('details') ?? e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PickSell’s team checks every report. The reviewer isn’t told who reported it.', style: PsText.caption),
        const SizedBox(height: PsSpace.sm),
        RadioGroup<String>(
          groupValue: _reason,
          onChanged: (v) => setState(() {
            _reason = v;
            _error = null;
          }),
          child: Column(
            children: [
              for (final r in widget.reasons)
                RadioListTile<String>(
                  value: r.code,
                  title: Text(r.label, style: PsText.body),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.xs),
        const PsFieldLabel('More details (optional)'),
        TextField(
          controller: _details,
          maxLines: 3,
          maxLength: 500,
          style: PsText.input,
          decoration: psInputDecoration(hint: 'What’s wrong with this review?', hasError: false),
        ),
        if (_error != null) PsFieldError(_error!),
        const SizedBox(height: PsSpace.md),
        PsPrimaryButton(label: 'Send report', uppercase: false, loading: _sending, onPressed: _send),
      ],
    );
  }
}
