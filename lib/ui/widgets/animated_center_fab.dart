import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/theme.dart';

/// An animated, centered FAB that slides/fades in when mounted.
/// Place it in a Stack so it can sit above your VisionNavBar.
class AnimatedCenterFab extends StatefulWidget {
  const AnimatedCenterFab({
    super.key,
    required this.onPressed,
    this.bottomOffset = 0,
    this.size = 64,
  });
  final VoidCallback onPressed;
  final double bottomOffset;
  final double size;
  @override
  State<AnimatedCenterFab> createState() => _AnimatedCenterFabState();
}

class _AnimatedCenterFabState extends State<AnimatedCenterFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ac.forward(from: 0));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final size = widget.size;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomSafe + widget.bottomOffset + 12,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Material(
                color: AppColors.primary,
                elevation: 8,
                shadowColor: AppColors.primary.withValues(alpha: .35),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onPressed,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
