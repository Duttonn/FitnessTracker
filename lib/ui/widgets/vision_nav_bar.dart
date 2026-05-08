import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fitness_app/theme.dart';

/// FM-design bottom nav: Home | Workout | [+FAB] | Progress | Foods
/// The center FAB is raised 16px above the bar and fires [onLogPressed].
/// [currentIndex]: 0=Home, 1=Workout, 2=Progress, 3=Foods
class VisionNavBar extends StatelessWidget {
  const VisionNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onLogPressed,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogPressed;

  static const double kHeight = 72.0;

  static const _items = <_NavItem>[
    _NavItem(icon: Icons.grid_view_rounded,      label: 'Home'),
    _NavItem(icon: Icons.fitness_center_rounded,  label: 'Workout'),
    null,                                         // center FAB placeholder
    _NavItem(icon: Icons.show_chart_rounded,      label: 'Progress'),
    _NavItem(icon: Icons.restaurant_rounded,      label: 'Foods'),
  ];

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, pad > 0 ? pad - 4 : 8),
      // Extra top padding so the FAB has room to overflow
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_items.length, (i) {
            final item = _items[i];

            // Center FAB
            if (item == null) {
              return _LogFab(onTap: onLogPressed);
            }

            // Map visual index → logical currentIndex
            // Visual: 0=Home,1=Workout,[2=FAB],3=Progress,4=Foods
            // Logical: 0=Home, 1=Workout, 2=Progress, 3=Foods
            final logicalIndex = i > 2 ? i - 1 : i;
            final selected = logicalIndex == currentIndex;

            return _NavIcon(
              icon: item.icon,
              label: item.label,
              selected: selected,
              onTap: () {
                HapticFeedback.selectionClick();
                onItemSelected(logicalIndex);
              },
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _LogFab extends StatefulWidget {
  const _LogFab({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_LogFab> createState() => _LogFabState();
}

class _LogFabState extends State<_LogFab> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); HapticFeedback.mediumImpact(); },
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: AnimatedScale(
          scale: _pressed ? .92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Colors.black.withValues(alpha: .38);
    return Semantics(
      label: label, button: true, selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 56, height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: selected
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                    : EdgeInsets.zero,
                decoration: selected
                    ? BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(20))
                    : null,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: selected ? 1.0 : 0.88,
                  curve: Curves.easeOut,
                  child: Icon(icon, size: 22, color: color),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: color,
                  letterSpacing: selected ? 0.2 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Backwards-compat
const double kVisionNavBarHeight = VisionNavBar.kHeight;
