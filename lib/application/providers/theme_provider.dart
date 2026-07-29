import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/entities/profile.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  final profileAsync = ref.watch(profileProvider);
  final themePref = profileAsync.valueOrNull?.themeMode ?? ThemeModePref.system;
  
  switch (themePref) {
    case ThemeModePref.light:
      return ThemeMode.light;
    case ThemeModePref.dark:
      return ThemeMode.dark;
    case ThemeModePref.system:
      return ThemeMode.system;
  }
});
