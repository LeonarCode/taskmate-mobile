import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/alert_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/home_tab_provider.dart';
import '../tasks/tasks_screen.dart';
import '../servers/servers_screen.dart';
import '../chats/chats_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.check_circle_outline_rounded,
      activeIcon: Icons.check_circle_rounded,
      label: 'Tasks',
    ),
    _NavItem(
      icon: Icons.dns_outlined,
      activeIcon: Icons.dns_rounded,
      label: 'Servers',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chats',
    ),
    _NavItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Alerts',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = context.watch<HomeTabProvider>().index;
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          TasksScreen(),
          ServersScreen(),
          ChatsScreen(),
          NotificationsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, isDark, currentIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark, int currentIndex) {
    final badges = {
      HomeTabProvider.chats: context.select<ChatProvider, int>(
        (c) => c.totalUnread,
      ),
      HomeTabProvider.alerts: context.select<AlertProvider, int>(
        (a) => a.unreadCount,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dark600 : AppColors.gray200,
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = currentIndex == i;
              final color = isActive
                  ? (isDark ? AppColors.purple400 : AppColors.purple600)
                  : (isDark ? AppColors.gray500 : AppColors.gray400);
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.read<HomeTabProvider>().go(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.purple600.withAlpha(20)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Badge(
                          isLabelVisible: (badges[i] ?? 0) > 0,
                          label: Text(
                            (badges[i] ?? 0) > 9 ? '9+' : '${badges[i]}',
                          ),
                          backgroundColor: AppColors.red500,
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            size: 24,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        // Replaces (not merges with) the inherited text style,
                        // so the app font is set here explicitly.
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: color,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
