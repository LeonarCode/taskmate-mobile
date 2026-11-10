import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../core/theme.dart';
import 'gradient_button.dart';

/// What the user chose in [showRatingDialog].
class RatingDialogResult {
  /// Null when the user chose to remove their rating.
  final double? score;
  final String? comment;

  const RatingDialogResult.rate(double this.score, this.comment);
  const RatingDialogResult.remove() : score = null, comment = null;

  bool get isRemoval => score == null;
}

/// Asks for a 1 to 5 star rating (half stars allowed) and an optional comment.
/// Pass [initialScore] / [initialComment] to edit an existing rating, which
/// also offers "Remove rating".
Future<RatingDialogResult?> showRatingDialog(
  BuildContext context, {
  required String memberName,
  double? initialScore,
  String? initialComment,
}) {
  return showDialog<RatingDialogResult>(
    context: context,
    builder: (_) => _RatingDialog(
      memberName: memberName,
      initialScore: initialScore,
      initialComment: initialComment,
    ),
  );
}

class _RatingDialog extends StatefulWidget {
  final String memberName;
  final double? initialScore;
  final String? initialComment;

  const _RatingDialog({
    required this.memberName,
    this.initialScore,
    this.initialComment,
  });

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late double _score = widget.initialScore ?? 3.0;
  late final TextEditingController _comment = TextEditingController(
    text: widget.initialComment ?? '',
  );

  bool get _isEdit => widget.initialScore != null;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.dark800 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Rate ${widget.memberName}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : AppColors.gray900,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Leave a 1 to 5 star rating for this member.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
            const SizedBox(height: 16),
            RatingBar(
              initialRating: _score,
              minRating: 1,
              allowHalfRating: true,
              glow: false,
              itemSize: 40,
              ratingWidget: RatingWidget(
                full: const Icon(Icons.star_rounded, color: AppColors.amber500),
                half: const Icon(
                  Icons.star_half_rounded,
                  color: AppColors.amber500,
                ),
                empty: Icon(
                  Icons.star_outline_rounded,
                  color: isDark ? AppColors.gray500 : AppColors.gray300,
                ),
              ),
              onRatingUpdate: (value) => setState(() => _score = value),
            ),
            const SizedBox(height: 6),
            Text(
              _score.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.amber500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 255,
              decoration: const InputDecoration(
                hintText: 'Add a comment (optional)',
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const RatingDialogResult.remove()),
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('Remove'),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
          ),
        SizedBox(
          width: 130,
          child: GradientButton(
            label: _isEdit ? 'Update' : 'Submit',
            height: 44,
            borderRadius: 12,
            onTap: () => Navigator.pop(
              context,
              RatingDialogResult.rate(_score, _comment.text.trim()),
            ),
          ),
        ),
      ],
    );
  }
}
