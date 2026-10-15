import '../../../core/constants/app_constants.dart';

/// Represents user subscription status and feature entitlements.
class SubscriptionTier {
  final bool isPremium;
  final int remainingAiScans;
  final int activeGroupCount;

  const SubscriptionTier({
    this.isPremium = false,
    this.remainingAiScans = AppConstants.freeMonthlyAiScans,
    this.activeGroupCount = 0,
  });

  /// Whether the user can create a new group.
  bool get canCreateNewGroup =>
      isPremium || activeGroupCount < AppConstants.maxFreeGroups;

  /// Whether the user can export CSV reports.
  bool get canExportCsv => isPremium;

  /// Whether high-precision AI receipt scanning is available.
  bool get hasAiScanAvailable => isPremium || remainingAiScans > 0;

  SubscriptionTier copyWith({
    bool? isPremium,
    int? remainingAiScans,
    int? activeGroupCount,
  }) {
    return SubscriptionTier(
      isPremium: isPremium ?? this.isPremium,
      remainingAiScans: remainingAiScans ?? this.remainingAiScans,
      activeGroupCount: activeGroupCount ?? this.activeGroupCount,
    );
  }
}
