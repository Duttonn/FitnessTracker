import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/theme.dart';

/// Vision-style bottom indicator bar.
/// - Stateless/controlled via [currentIndex].
/// - Parent updates page & index; we only render.
class VisionNavBar extends StatelessWidget {
  const VisionNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  static const _icons = <IconData>[
    Icons.dashboard_outlined, // 0 Dashboard
    Icons.list_alt, // 1 Logs
    Icons.show_chart, // 2 Progress
    Icons.flag_outlined, // 3 Goals
    Icons.restaurant_outlined, // 4 Foods
  ];

  // Public height for layout helpers
  static const double kHeight =
      64; // includes visual pill (container is 44 inside)

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context).bottom;
    return IgnorePointer(
      ignoring: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, (pad > 0 ? pad - 6 : 6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white30.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Removed background highlight pill per request; only icon color indicates selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_icons.length, (i) {
                  final selected = i == currentIndex;
                  return _NavIcon(
                    icon: _icons[i],
                    selected: selected,
                    onTap: () => onItemSelected(i),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 170),
        scale: selected ? 1.0 : 0.86,
        curve: Curves.easeOut,
        child: Icon(
          icon,
          size: 24,
          color: selected ? primary : Colors.black.withValues(alpha: .45),
        ),
      ),
    );
  }
}

// Backwards compat constant for older helpers
const double kVisionNavBarHeight = VisionNavBar.kHeight;
