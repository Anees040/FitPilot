import 'package:flutter_riverpod/flutter_riverpod.dart';


final demoProvider = Provider<bool>((ref) {
  // If we have an env variable for demo mode, we could read it here,
  // but for now we default to false.
  return false;
});
