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
  final _analyzer = SquatFormAnalyzer();

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
      _analyzer.reset();
      final feedback = _analyzer.analyze(pose);

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
            const _HowToCard(),
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
              _ResultCard(feedback: _feedback!),
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

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  static const _steps = [
    'Prop your phone side-on, about 2 metres away',
    'Get your whole body in frame — head to feet',
    'Take the photo at the bottom of your squat',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              Text('Squat depth check', style: theme.textTheme.h2),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: theme.textTheme.caption.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_steps[i], style: theme.textTheme.caption),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final FormFeedback feedback;

  const _ResultCard({required this.feedback});

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
                  SquatFormAnalyzer.cueFor(feedback),
                  style: theme.textTheme.h2.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Metric(
            label: 'Knee angle',
            value: feedback.kneeAngle == null
                ? '—'
                : '${feedback.kneeAngle!.round()}°',
            note: 'About 90° is parallel; lower is deeper',
          ),
          const SizedBox(height: 10),
          _Metric(
            label: 'Depth',
            value: switch (feedback.depth) {
              SquatDepth.deep => 'At or below parallel',
              SquatDepth.partial => 'Above parallel',
              SquatDepth.standing => 'Standing',
            },
            note: 'Measured from hip, knee and ankle positions',
          ),
          const SizedBox(height: 10),
          _Metric(
            label: 'Torso',
            value: feedback.torsoTooFarForward ? 'Leaning forward' : 'Upright',
            note: 'Some forward lean is normal in a squat',
          ),
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
      'Beta. This measures squat depth and torso lean from your joint '
      'positions — it cannot judge bar path, knee tracking or spinal position, '
      'and it is not a substitute for a coach. Everything is processed on your '
      'phone; no photo is uploaded or saved.',
      style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
    );
  }
}
