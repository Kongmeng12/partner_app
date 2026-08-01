import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/data.dart';
import '../theme/tokens.dart';

/// The five bottom-nav destinations, each with its own navigation stack, so
/// opening a booking and switching tabs does not lose your place.
class PartnerShell extends ConsumerWidget {
  const PartnerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A dropped poll must not blank the badge, so a failed request reads as
    // zero rather than an error.
    final unreadChat = ref.watch(unreadChatProvider).value ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are already on returns to its root — the
          // standard "go back to the top" gesture.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: C.accentDark),
            label: 'ໜ້າຫຼັກ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: C.accentDark),
            label: 'ການຈອງ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: C.accentDark),
            label: 'ປະຕິທິນ',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadChat > 0,
              label: Text('$unreadChat'),
              backgroundColor: C.accent,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble, color: C.accentDark),
            label: 'ແຊັດ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu_open, color: C.accentDark),
            label: 'ເພີ່ມເຕີມ',
          ),
        ],
      ),
    );
  }
}
