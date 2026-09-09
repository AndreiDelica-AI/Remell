import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' as html;

class UserEnergyState {
  final double energy;
  final String ageGroup; // 'teen' or 'adult'
  final DateTime lastActiveTime;
  final bool hasSetAge;

  UserEnergyState({
    required this.energy,
    required this.ageGroup,
    required this.lastActiveTime,
    required this.hasSetAge,
  });

  UserEnergyState copyWith({
    double? energy,
    String? ageGroup,
    DateTime? lastActiveTime,
    bool? hasSetAge,
  }) {
    return UserEnergyState(
      energy: energy ?? this.energy,
      ageGroup: ageGroup ?? this.ageGroup,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      hasSetAge: hasSetAge ?? this.hasSetAge,
    );
  }
}

class UserEnergyNotifier extends StateNotifier<UserEnergyState> {
  UserEnergyNotifier()
      : super(UserEnergyState(
          energy: 100.0,
          ageGroup: 'adult',
          lastActiveTime: DateTime.now(),
          hasSetAge: false,
        )) {
    _loadFromStorage();
  }

  // Key names for localStorage
  static const String _keyEnergy = 'remell_energy_level';
  static const String _keyAgeGroup = 'remell_age_group';
  static const String _keyLastActive = 'remell_last_active';
  static const String _keyHasSetAge = 'remell_has_set_age';

  String? _storageGet(String key) {
    if (!kIsWeb) return null;
    try {
      return html.window.localStorage[key];
    } catch (_) {}
    return null;
  }

  void _storageSet(String key, String value) {
    if (!kIsWeb) return;
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  void _loadFromStorage() {
    final hasSetAgeStr = _storageGet(_keyHasSetAge);
    final hasSetAge = hasSetAgeStr == 'true';

    if (!hasSetAge) {
      // Not configured yet, keep defaults
      return;
    }

    final ageGroup = _storageGet(_keyAgeGroup) ?? 'adult';
    final energyStr = _storageGet(_keyEnergy);
    double energy = energyStr != null ? (double.tryParse(energyStr) ?? 100.0) : 100.0;

    final lastActiveStr = _storageGet(_keyLastActive);
    DateTime lastActive = lastActiveStr != null
        ? (DateTime.tryParse(lastActiveStr) ?? DateTime.now())
        : DateTime.now();

    // Calculate dynamic regeneration based on idle time
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    final hoursIdle = difference.inMinutes / 60.0;

    if (hoursIdle > 0.0) {
      // Adult needs 7 hours of sleep/idle to regain 100% (~14.28% per hour)
      // Teen needs 8 hours of sleep/idle to regain 100% (12.5% per hour)
      final regenRate = ageGroup == 'teen' ? 12.5 : 14.2857;
      final regained = hoursIdle * regenRate;
      energy = (energy + regained).clamp(0.0, 100.0);
    }

    state = UserEnergyState(
      energy: energy,
      ageGroup: ageGroup,
      lastActiveTime: now,
      hasSetAge: true,
    );

    // Save regenerated values
    _saveToStorage();
  }

  void _saveToStorage() {
    _storageSet(_keyEnergy, state.energy.toStringAsFixed(2));
    _storageSet(_keyAgeGroup, state.ageGroup);
    _storageSet(_keyLastActive, state.lastActiveTime.toIso8601String());
    _storageSet(_keyHasSetAge, state.hasSetAge ? 'true' : 'false');
  }

  /// Sets the age group (adult or teen). Initializes energy to 100% on first setup.
  void setAgeGroup(String group) {
    state = UserEnergyState(
      energy: 100.0,
      ageGroup: group,
      lastActiveTime: DateTime.now(),
      hasSetAge: true,
    );
    _saveToStorage();
  }

  /// Refreshes the last active time to the current time, tracking app usage
  void updateActive() {
    if (!state.hasSetAge) return;
    state = state.copyWith(lastActiveTime: DateTime.now());
    _saveToStorage();
  }

  /// Deducts energy based on completed task difficulty
  void drainEnergy(String difficulty) {
    if (!state.hasSetAge) return;

    double deduction = 8.0; // default medium
    if (difficulty == 'low') {
      deduction = 3.0;
    } else if (difficulty == 'high') {
      deduction = 15.0;
    }

    final newEnergy = (state.energy - deduction).clamp(0.0, 100.0);
    state = state.copyWith(
      energy: newEnergy,
      lastActiveTime: DateTime.now(),
    );
    _saveToStorage();
  }

  /// Regains a small amount of energy directly (e.g. manually resetting or resting)
  void gainEnergy(double amount) {
    if (!state.hasSetAge) return;
    final newEnergy = (state.energy + amount).clamp(0.0, 100.0);
    state = state.copyWith(
      energy: newEnergy,
      lastActiveTime: DateTime.now(),
    );
    _saveToStorage();
  }
}

final userEnergyProvider = StateNotifierProvider<UserEnergyNotifier, UserEnergyState>((ref) {
  return UserEnergyNotifier();
});
