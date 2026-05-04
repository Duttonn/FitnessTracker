import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/ui/workout/WorkoutStatCard.dart';
import 'package:flutter_fitness_app/ui/workout/SectionHeader.dart';

class WorkoutDashboardScreen extends StatelessWidget {
  const WorkoutDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 60), // Header space
              Row(
                children: [
                  Expanded(
                    child: WorkoutStatCard(
                      icon: Icons.local_fire_department,
                      title: 'Calories',
                      value: '1200',
                      sub: 'kcal',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WorkoutStatCard(
                      icon: Icons.restaurant,
                      title: 'Protein',
                      value: '150',
                      sub: 'g',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WorkoutStatCard(
                      icon: Icons.grain,
                      title: 'Carbs',
                      value: '200',
                      sub: 'g',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WorkoutStatCard(
                      icon: Icons.opacity,
                      title: 'Fat',
                      value: '80',
                      sub: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.56,
                  height: MediaQuery.of(context).size.width * 0.56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/workout/session');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.15),
                    ),
                    child: const Text(
                      'Go Workout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildTile(
                      icon: Icons.edit,
                      label: 'Composer',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTile(
                      icon: Icons.history,
                      label: 'History',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const SectionHeader(title: 'Recent Workouts'),
              const SizedBox(height: 16),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildRecentWorkoutCard('Bench Press', 'Completed'),
                  const SizedBox(height: 12),
                  _buildRecentWorkoutCard('Squats', 'Completed'),
                  const SizedBox(height: 12),
                  _buildRecentWorkoutCard('Deadlift', 'Completed'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF171717),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(icon, color: const Color(0x33DC2626), size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentWorkoutCard(String title, String status) {
    return Card(
      color: const Color(0xFF171717),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x33DC2626),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
