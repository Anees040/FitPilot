import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a debounced boolean indicating whether the device is online.
/// Flapping is debounced by 500ms to prevent rapid UI changes.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final controller = StreamController<bool>();
  Timer? debounceTimer;
  
  void updateState(List<ConnectivityResult> results) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) {
        final isOnline = !results.contains(ConnectivityResult.none);
        controller.add(isOnline);
      }
    });
  }
  
  final sub = Connectivity().onConnectivityChanged.listen(updateState);
  
  // Emit initial value immediately without debounce for fast startup
  final initial = await Connectivity().checkConnectivity();
  if (!controller.isClosed) {
    controller.add(!initial.contains(ConnectivityResult.none));
  }

  ref.onDispose(() {
    debounceTimer?.cancel();
    sub.cancel();
    controller.close();
  });
  
  yield* controller.stream;
});
