import 'package:equatable/equatable.dart';

import 'package:fitpilot/domain/entities/machine_analysis.dart';

/// One saved gym machine scan, as stored in the local `machine_scans` table.
///
/// Persisted so a result stays readable offline — the scan itself needs a
/// network, re-reading it does not.
class MachineScan extends Equatable {
  final String id;
  final String machineName;
  final MachineAnalysis analysis;
  final DateTime createdAt;

  const MachineScan({
    required this.id,
    required this.machineName,
    required this.analysis,
    required this.createdAt,
  });

  /// Short relative age for the history list ("Just now", "3h ago").
  String relativeAge({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(createdAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '${weeks}w ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  @override
  List<Object?> get props => [id, machineName, createdAt];
}
