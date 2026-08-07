import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/machine_scanner_provider.dart';
import 'package:fitpilot/application/providers/network_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/domain/entities/machine_scan.dart';

/// Landing screen for the gym machine scanner.
///
/// Deliberately not the camera: scanning needs a network, but re-reading a past
/// scan does not. Opening on this screen keeps saved results reachable offline,
/// and the online gate applies only to the scan action itself.
class MachineScannerScreen extends ConsumerWidget {
  const MachineScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final recentScans = ref.watch(recentMachineScansProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Machine Scanner'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(recentMachineScansProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ScanCallToAction(
                isOnline: isOnline,
                onTap: () => _startScan(context, ref),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Recent scans', style: theme.textTheme.h2),
                  const Spacer(),
                  recentScans.maybeWhen(
                    data: (scans) => scans.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            '${scans.length} saved',
                            style: theme.textTheme.caption,
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Saved on this device so you can read them without a connection.',
                style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
              ),
              const SizedBox(height: 12),
              recentScans.when(
                data: (scans) {
                  if (scans.isEmpty) return const _NoScansYet();
                  return Column(
                    children: [
                      for (final scan in scans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RecentScanTile(scan: scan),
                        ),
                    ],
                  );
                },
                loading: () => const SkeletonList(count: 2),
                error: (error, _) => ErrorState(
                  reason: "Couldn't load your saved scans.",
                  onRetry: () => ref.invalidate(recentMachineScansProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startScan(BuildContext context, WidgetRef ref) {
    if (!requireOnline(context, ref, feature: 'Machine Scanner')) return;
    context.push('/machine-scanner/camera');
  }
}

/// The primary action. Stays tappable while offline so the gate can explain
/// why it isn't available, rather than leaving a dead-looking button.
class _ScanCallToAction extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onTap;

  const _ScanCallToAction({required this.isOnline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      variant: AppCardVariant.hero,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kIsWeb ? 'Upload a machine photo' : 'Scan a machine',
                      style: theme.textTheme.h2,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      kIsWeb
                          ? 'Pick a photo of any gym machine to learn it'
                          : 'Point your camera at any gym machine to learn it',
                      style: theme.textTheme.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                isOnline ? Icons.auto_awesome : Icons.cloud_off_rounded,
                size: 14,
                color: isOnline ? ext.energy : ext.textDisabled,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Get the muscles worked, step-by-step form, and safety tips'
                      : "You're offline — connect to scan a new machine",
                  style: theme.textTheme.caption.copyWith(
                    color: isOnline ? ext.energy : ext.textDisabled,
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

class _NoScansYet extends StatelessWidget {
  const _NoScansYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Icon(Icons.fitness_center_rounded, size: 40, color: ext.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No scans yet',
            style: theme.textTheme.bodyStrong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Scan a machine at the gym and it will be saved here for later.',
            style: theme.textTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  final MachineScan scan;

  const _RecentScanTile({required this.scan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final muscles = scan.analysis.primaryMuscles.take(3).join(' • ');

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(
        '/machine-scanner/result',
        extra: <String, dynamic>{'analysis': scan.analysis, 'fromHistory': true},
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.machineName.isEmpty ? 'Unknown machine' : scan.machineName,
                  style: theme.textTheme.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  muscles.isEmpty ? scan.relativeAge() : '$muscles  ·  ${scan.relativeAge()}',
                  style: theme.textTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
        ],
      ),
    );
  }
}
