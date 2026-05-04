import 'models.dart';

final samplePushWorkout = Workout(
  id: 'push',
  name: 'Push Day',
  items: [
    WorkoutExercise(
      exercise: Exercise(
        id: 'bench',
        name: 'Bench Press',
        muscleGroups: ['Chest', 'Triceps'],
        icon: '🏋️',
      ),
      plannedSets: 3,
      plannedReps: 8,
    ),
    WorkoutExercise(
      exercise: Exercise(
        id: 'overhead',
        name: 'Overhead Press',
        muscleGroups: ['Shoulders', 'Triceps'],
        icon: '🏋️',
      ),
      plannedSets: 3,
      plannedReps: 8,
    ),
    WorkoutExercise(
      exercise: Exercise(
        id: 'triceps',
        name: 'Tricep Pushdown',
        muscleGroups: ['Triceps'],
        icon: '🏋️',
      ),
      plannedSets: 3,
      plannedReps: 10,
    ),
  ],
);
