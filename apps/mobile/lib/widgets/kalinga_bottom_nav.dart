import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Shared accessible bottom navigation bar across main app pages.
class KalingaBottomNav extends StatelessWidget {
  final int activeIndex;

  const KalingaBottomNav({
    super.key,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded),
        label: 'Today',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline_rounded),
        label: 'Ask',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.mic_none_rounded),
        label: 'Log',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.medication_outlined),
        label: 'Meds',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.help_outline_rounded),
        label: 'Help',
      ),
    ];

    final validIndex = (activeIndex >= 0 && activeIndex < items.length)
        ? activeIndex
        : 0;

    return BottomNavigationBar(
      currentIndex: validIndex,
      onTap: (i) {
        if (i == activeIndex) return;
        switch (i) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/ask');
            break;
          case 2:
            context.go('/log');
            break;
          case 3:
            context.go('/meds');
            break;
          case 4:
            context.go('/help');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.mutedText,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 12),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 12),
      elevation: 8,
      items: items,
    );
  }
}
