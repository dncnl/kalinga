import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/selected_profile.dart';
import '../theme.dart';

/// Reusable accessible app page header containing profile avatar, name, and action icons.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SelectedProfile.instance,
      builder: (context, _) {
        final recipient = SelectedProfile.instance.careRecipient;
        final displayName = recipient?.displayName ?? 'Add a profile';

        return Row(
          children: [
            Semantics(
              label: 'Switch profile, currently $displayName',
              button: true,
              child: GestureDetector(
                onTap: () => context.push('/profiles'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      recipient?.initials ?? '?',
                      style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/profiles'),
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTextStyles.bodyMedium(fontSize: 15)
                                .copyWith(color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (recipient != null)
                            Text(
                              [
                                if (recipient.age != null) '${recipient.age}',
                                if (recipient.preferredLanguages.isNotEmpty)
                                  'speaks ${recipient.preferredLanguages.first}',
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.mutedText,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Tooltip(
              message: 'Notifications',
              child: IconButton(
                onPressed: () => context.push('/activity'),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.secondaryText,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Settings',
              child: IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.secondaryText,
                  size: 24,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
