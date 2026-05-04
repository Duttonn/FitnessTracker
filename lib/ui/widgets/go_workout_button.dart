// filepath: /Users/ndn18/PersonalProjects/FitnessTracker/lib/ui/widgets/go_workout_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';

class GoWorkoutButton extends StatelessWidget {
  final AppState appState; // Add AppState as a required parameter

  const GoWorkoutButton({
    super.key,
    required this.appState, // Mark appState as required
    this.onTap,
  });
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isWorkout = appState.isWorkoutMode;

    // smaller pill, elevated, always visible above nav
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          debugPrint('GoWorkoutButton tapped');
          onTap!();
        } else {
          debugPrint('GoWorkoutButton onTap is null');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isWorkout
              ? const Color(0xFF5B6BFF)
              : const Color(0xFFE53935), // blue in workout, red in macro
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Text(
                'GO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
