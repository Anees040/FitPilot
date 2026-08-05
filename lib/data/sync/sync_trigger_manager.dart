import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/domain/repositories/auth_repository.dart';

class SyncTriggerManager with WidgetsBindingObserver {
  final SyncService _syncService;
  final AuthRepository _authRepo;

  StreamSubscription? _connectivitySub;
  StreamSubscription? _authSub;
  Timer? _periodicTimer;
  Timer? _debounceTimer;

  bool _isForeground = true;

  SyncTriggerManager(this._syncService, this._authRepo) {
    WidgetsBinding.instance.addObserver(this);

    // Listen to network changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) return;
      _trigger('network_regained');
    });

    // Auth state changes
    _authSub = _authRepo.authStateChanges.listen((user) {
      if (user != null) {
        _trigger('sign_in');
      }
    });

    // Periodic timer (every 1 minute while foregrounded)
    _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isForeground) _trigger('periodic');
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _authSub?.cancel();
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = (state == AppLifecycleState.resumed);
    if (_isForeground) {
      _trigger('app_resume');
    }
  }

  /// Triggers a sync with a short debounce
  void _trigger(String reason) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!Env.isSupabaseConfigured) return;
      if (_authRepo.currentUser == null) return;

      _syncService.syncNow();
    });
  }

  /// Public method to call after a local write
  void onLocalWrite() {
    _trigger('local_write');
  }

  /// Pauses sync background triggers (e.g. before sign-out)
  void pause() {
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
  }

  /// Pauses triggers and waits for any in-flight sync to finish
  Future<void> pauseAndDrain() async {
    pause();
    await _syncService.drain();
  }
}
