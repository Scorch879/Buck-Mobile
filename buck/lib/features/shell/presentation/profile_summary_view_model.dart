import 'package:supabase_flutter/supabase_flutter.dart';

import '../../finance/domain/finance_snapshot.dart';
import '../../settings/data/settings_service.dart';

/// Derives display labels and [BuckSettingsContext] for the header and side panel.
class ProfileSummaryViewModel {
  final String welcomeTitle;
  final String displayName;
  final String email;
  final String connectionLabel;
  final BuckSettingsContext settingsContext;

  const ProfileSummaryViewModel._({
    required this.welcomeTitle,
    required this.displayName,
    required this.email,
    required this.connectionLabel,
    required this.settingsContext,
  });

  factory ProfileSummaryViewModel.from({
    required FinanceSnapshot? snapshot,
    required User? user,
  }) {
    final profileName = snapshot?.displayName;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final metaName = (metadata['full_name'] ?? metadata['username']) as String?;
    final email = user?.email;
    final emailPrefix = email?.split('@').first;

    String? resolvedWelcomeName;
    if (profileName != null && profileName.trim().isNotEmpty) {
      resolvedWelcomeName = profileName.trim();
    } else if (metaName != null && metaName.trim().isNotEmpty) {
      resolvedWelcomeName = metaName.trim();
    } else if (emailPrefix != null && emailPrefix.isNotEmpty) {
      resolvedWelcomeName = emailPrefix;
    }

    final displayName = resolvedWelcomeName ?? 'Buck Account';
    final displayEmail =
        (email != null && email.isNotEmpty) ? email : 'Signed in';

    final isGoogle = user?.appMetadata['provider'] == 'google' ||
        (user?.identities?.any((id) => id.provider == 'google') ?? false);
    final connectionLabel = isGoogle
        ? 'Connected with Google'
        : (user != null ? 'Connected with Email' : 'Connected with Buck');

    return ProfileSummaryViewModel._(
      welcomeTitle: resolvedWelcomeName == null
          ? 'Welcome'
          : 'Welcome $resolvedWelcomeName',
      displayName: displayName,
      email: displayEmail,
      connectionLabel: connectionLabel,
      settingsContext: BuckSettingsContext(
        displayName: displayName,
        email: displayEmail,
        connectionLabel: connectionLabel,
        providerName: isGoogle ? 'Google' : 'Buck Auth',
        isGoogleManaged: isGoogle,
      ),
    );
  }
}
