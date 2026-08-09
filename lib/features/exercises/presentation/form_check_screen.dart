import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/data/ml/pose_detection_service.dart';
import 'package:fitpilot/domain/engines/form_rules.dart';
import 'package:fitpilot/domain/engines/squat_form_analyzer.dart';

/// On-device squat form check.
///
/// Take a photo at the bottom of a squat, or pick one, and the app measures
/// knee angle and torso lean from the detected joints.
///
/// Deliberately narrow. Pose estimation gives joint positions, not a coaching
/// opinion, so this reports the two things joint angles genuinely support —
/// depth and forward lean — and says so plainly. Everything runs on the phone:
/// no upload, no storage, no API key, and it works with no signal.
class FormCheckScreen extends ConsumerStatefulWidget {
  const FormCheckScreen({super.key});

  @override
  ConsumerState<FormCheckScreen> createState() => _FormCheckScreenState();
}

class _FormCheckScreenState extends ConsumerState<FormCheckScreen> {
  final _service = PoseDetectionService();

  FormExercise _exercise = FormExercise.squat;
  String? _imagePath;
  FormFeedback? _feedback;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _capture(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Enough resolution for joints, small enough to detect quickly.
        maxWidth: 1280,
      );
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }

      final pose = await _service.detectInFile(picked.path);
      // Each exercise has its own joint and thresholds; FormChecker routes to
      // the right rule set rather than judging everything as a squat.
      final feedback = FormChecker.check(_exercise, pose);

      if (!mounted) return;
      setState(() {
        _imagePath = picked.path;
        _feedback = feedback;
        _busy = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FormCheck] $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Couldn't read that photo. Try again in better light.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Form check'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _ExercisePicker(
              selected: _exercise,
              onSelect: (e) => setState(() {
                _exercise = e;
                // The previous verdict was for a different movement, so it
                // would be nonsense against the new rules.
                _feedback = null;
                _imagePath = null;
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
            _HowToCard(exercise: _exercise),
            const SizedBox(height: 16),
            if (_imagePath != null && !kIsWeb) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(_imagePath!),
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!)
            else if (_feedback != null)
              _ResultCard(feedback: _feedback!, exercise: _exercise),
            const SizedBox(height: 20),
            Row(
              children: [
                if (!kIsWeb) ...[
                  Expanded(
                    child: PrimaryButton(
                      label: _feedback == null ? 'Take photo' : 'Again',
                      onPressed: _busy
                          ? null
                          : () => _capture(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SecondaryButton(
                    label: 'Choose photo',
                    onPressed: _busy
                        ? null
                        : () => _capture(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _LimitsNote(),
          ],
        ),
      ),
    );
  }
}

/// Horizontal picker for the supported movements.
///
/// Only six are listed, and that is the honest limit: each needs its own
/// validated joint thresholds, and a guessed rule gives confident bad advice
/// to someone under load.
class _ExercisePicker extends StatelessWidget {
  final FormExercise selected;
  final ValueChanged<FormExercise> onSelect;

  const _ExercisePicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: FormExercise.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final exercise = FormExercise.values[i];
          final isSelected = exercise == selected;
          return Center(
            child: InkWell(
              onTap: () => onSelect(exercise),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.16)
                      : ext.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : ext.hairline,
                  ),
                ),
                child: Text(
                  exercise.label,
                  style: theme.textTheme.caption.copyWith(
                    color: isSelected ? theme.colorScheme.primary : null,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  final FormExercise exercise;

  const _HowToCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${exercise.label} check',
                  style: theme.textTheme.h2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(exercise.setupHint, style: theme.textTheme.caption),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 13, color: ext.textDisabled),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Measures: ${exercise.measures}',
                  style: theme.textTheme.caption.copyWith(
                    color: ext.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final FormFeedback feedback;
  final FormExercise exercise;

  const _ResultCard({required this.feedback, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    if (!feedback.isVisible) {
      return AppCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined, color: ext.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feedback.notVisibleReason!,
                style: theme.textTheme.body,
              ),
            ),
          ],
        ),
      );
    }

    final good = feedback.depth == SquatDepth.deep && !feedback.torsoTooFarForward;
    final accent = good ? ext.success : ext.warning;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                good ? Icons.check_circle_rounded : Icons.info_rounded,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  FormChecker.cueFor(exercise, feedback),
                  style: theme.textTheme.h2.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Metric(
            label: 'Joint angle',
            value: feedback.kneeAngle == null
                ? '—'
                : '${feedback.kneeAngle!.round()}°',
            note: 'Measured at the joint this movement works',
          ),
          const SizedBox(height: 10),
          _Metric(
            label: 'Position',
            value: exercise.positionLabel(feedback.depth),
            note: 'Compared against the target for this movement',
          ),
          // Only shown when the rule set actually measures lean. A "Torso:
          // Upright" row on a push-up would report a check that never ran.
          if (exercise.measuresTorsoLean) ...[
            const SizedBox(height: 10),
            _Metric(
              label: 'Torso',
              value: feedback.torsoTooFarForward ? 'Leaning forward' : 'Upright',
              note: exercise.torsoNote!,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String note;

  const _Metric({
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.body)),
            Text(value, style: theme.textTheme.bodyStrong),
          ],
        ),
        Text(
          note,
          style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: ext.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: theme.textTheme.body)),
        ],
      ),
    );
  }
}

/// States the limits plainly. A form checker that implies it can judge
/// everything is more dangerous than one that names what it measures.
class _LimitsNote extends StatelessWidget {
  const _LimitsNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Text(
      'Beta. This measures joint angles for six movements — squat, push-up, '
      'lunge, plank, glute bridge and overhead press. It cannot judge bar path, '
      'knee tracking or spinal position, and it is not a substitute for a '
      'coach. Everything is processed on your phone; no photo is uploaded or '
      'saved.',
      style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
    );
  }
}
