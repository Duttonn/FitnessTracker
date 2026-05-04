import 'models.dart';

const List<String> kBodyPartFilters = [
  'All',
  'Back',
  'Chest',
  'Shoulders',
  'Biceps',
  'Triceps',
  'Quads',
  'Hamstrings',
  'Glutes',
  'Calves',
  'Core',
];

const List<Exercise> kBuiltInExercises = [
  // ── Back ──────────────────────────────────────────────────────────────────
  Exercise(id: 'pullup',            name: 'Pull-Up',                    muscleGroups: ['Back', 'Biceps'],           icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'latpulldown',       name: 'Lat Pulldown',               muscleGroups: ['Back'],                    icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'seatedrow',         name: 'Seated Cable Row',           muscleGroups: ['Back'],                    icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'bbrow',             name: 'Barbell Row',                muscleGroups: ['Back', 'Biceps'],           icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'tbarrow',           name: 'T-Bar Row',                  muscleGroups: ['Back'],                    icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'facepull',          name: 'Face Pull',                  muscleGroups: ['Back', 'Shoulders'],       icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'straightarmdown',   name: 'Straight-Arm Pulldown',      muscleGroups: ['Back'],                    icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'chestsupportrow',   name: 'Chest-Supported Row',        muscleGroups: ['Back'],                    icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'singlearmirow',     name: 'Single-Arm Dumbbell Row',    muscleGroups: ['Back'],                    icon: '🏋️', defaultIncrementKg: 2.0),

  // ── Chest ─────────────────────────────────────────────────────────────────
  Exercise(id: 'bench',             name: 'Bench Press',                muscleGroups: ['Chest', 'Triceps'],        icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'inclinebench',      name: 'Incline Bench Press',        muscleGroups: ['Chest', 'Shoulders'],      icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'declinebench',      name: 'Decline Bench Press',        muscleGroups: ['Chest', 'Triceps'],        icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'dbfly',             name: 'Dumbbell Fly',               muscleGroups: ['Chest'],                   icon: '🏋️', defaultIncrementKg: 2.0),
  Exercise(id: 'cablefly',          name: 'Cable Fly',                  muscleGroups: ['Chest'],                   icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'pecdeck',           name: 'Pec Deck',                   muscleGroups: ['Chest'],                   icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'dip',               name: 'Dip',                        muscleGroups: ['Chest', 'Triceps'],        icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'inclinedbpress',    name: 'Incline Dumbbell Press',     muscleGroups: ['Chest', 'Shoulders'],      icon: '🏋️', defaultIncrementKg: 2.0),

  // ── Shoulders ─────────────────────────────────────────────────────────────
  Exercise(id: 'ohp',               name: 'Overhead Press',             muscleGroups: ['Shoulders', 'Triceps'],    icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'lateralraise',      name: 'Lateral Raise',              muscleGroups: ['Shoulders'],               icon: '🏋️', defaultIncrementKg: 1.0),
  Exercise(id: 'frontraise',        name: 'Front Raise',                muscleGroups: ['Shoulders'],               icon: '🏋️', defaultIncrementKg: 1.0),
  Exercise(id: 'reardelfly',        name: 'Rear Delt Fly',              muscleGroups: ['Shoulders'],               icon: '🏋️', defaultIncrementKg: 1.0),
  Exercise(id: 'arnoldpress',       name: 'Arnold Press',               muscleGroups: ['Shoulders'],               icon: '🏋️', defaultIncrementKg: 2.0),
  Exercise(id: 'uprightrow',        name: 'Upright Row',                muscleGroups: ['Shoulders', 'Biceps'],     icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'cablelateralraise', name: 'Cable Lateral Raise',        muscleGroups: ['Shoulders'],               icon: '🏋️', defaultIncrementKg: 1.0),

  // ── Biceps ────────────────────────────────────────────────────────────────
  Exercise(id: 'bbcurl',            name: 'Barbell Curl',               muscleGroups: ['Biceps'],                  icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'dbcurl',            name: 'Dumbbell Curl',              muscleGroups: ['Biceps'],                  icon: '🏋️', defaultIncrementKg: 1.0),
  Exercise(id: 'hammercurl',        name: 'Hammer Curl',                muscleGroups: ['Biceps'],                  icon: '🏋️', defaultIncrementKg: 1.0),
  Exercise(id: 'preachercurl',      name: 'Preacher Curl',              muscleGroups: ['Biceps'],                  icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'cablecurl',         name: 'Cable Curl',                 muscleGroups: ['Biceps'],                  icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'inclinecurl',       name: 'Incline Dumbbell Curl',      muscleGroups: ['Biceps'],                  icon: '🏋️', defaultIncrementKg: 1.0),
  Exercise(id: 'ezbarcurl',         name: 'EZ-Bar Curl',                muscleGroups: ['Biceps'],                  icon: '🏋️', defaultIncrementKg: 2.5),

  // ── Triceps ───────────────────────────────────────────────────────────────
  Exercise(id: 'triceppushdown',    name: 'Tricep Pushdown',            muscleGroups: ['Triceps'],                 icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'skullcrusher',      name: 'Skull Crusher',              muscleGroups: ['Triceps'],                 icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'cgbench',           name: 'Close-Grip Bench Press',     muscleGroups: ['Triceps', 'Chest'],        icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'ohtriext',          name: 'Overhead Tricep Extension',  muscleGroups: ['Triceps'],                 icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'cableohext',        name: 'Cable Overhead Extension',   muscleGroups: ['Triceps'],                 icon: '🏋️', defaultIncrementKg: 2.5),

  // ── Quads ─────────────────────────────────────────────────────────────────
  Exercise(id: 'squat',             name: 'Squat',                      muscleGroups: ['Quads', 'Glutes'],         icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'legpress',          name: 'Leg Press',                  muscleGroups: ['Quads', 'Glutes'],         icon: '🏋️', defaultIncrementKg: 10.0),
  Exercise(id: 'hacksquat',         name: 'Hack Squat',                 muscleGroups: ['Quads'],                   icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'legextension',      name: 'Leg Extension',              muscleGroups: ['Quads'],                   icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'bulgsplitsquat',    name: 'Bulgarian Split Squat',      muscleGroups: ['Quads', 'Glutes'],         icon: '🏋️', defaultIncrementKg: 2.0),
  Exercise(id: 'lunge',             name: 'Lunge',                      muscleGroups: ['Quads', 'Glutes'],         icon: '🏋️', defaultIncrementKg: 2.0),
  Exercise(id: 'frontsquat',        name: 'Front Squat',                muscleGroups: ['Quads'],                   icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'gobletsquat',       name: 'Goblet Squat',               muscleGroups: ['Quads', 'Glutes'],         icon: '🏋️', defaultIncrementKg: 2.0),

  // ── Hamstrings ────────────────────────────────────────────────────────────
  Exercise(id: 'rdl',               name: 'Romanian Deadlift',          muscleGroups: ['Hamstrings', 'Glutes'],    icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'deadlift',          name: 'Deadlift',                   muscleGroups: ['Hamstrings', 'Back'],      icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'legcurl',           name: 'Lying Leg Curl',             muscleGroups: ['Hamstrings'],              icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'seatedlegcurl',     name: 'Seated Leg Curl',            muscleGroups: ['Hamstrings'],              icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'goodmorning',       name: 'Good Morning',               muscleGroups: ['Hamstrings', 'Back'],      icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'sumodl',            name: 'Sumo Deadlift',              muscleGroups: ['Hamstrings', 'Glutes'],    icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'nordiccurl',        name: 'Nordic Curl',                muscleGroups: ['Hamstrings'],              icon: '🏋️', defaultIncrementKg: 0.0),

  // ── Glutes ────────────────────────────────────────────────────────────────
  Exercise(id: 'hipthrust',         name: 'Hip Thrust',                 muscleGroups: ['Glutes'],                  icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'glutebridge',       name: 'Glute Bridge',               muscleGroups: ['Glutes'],                  icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'cablekickback',     name: 'Cable Kickback',             muscleGroups: ['Glutes'],                  icon: '🏋️', defaultIncrementKg: 1.0),
  Exercise(id: 'abductormachine',   name: 'Abductor Machine',           muscleGroups: ['Glutes'],                  icon: '🏋️', defaultIncrementKg: 5.0),

  // ── Calves ────────────────────────────────────────────────────────────────
  Exercise(id: 'standcalfraise',    name: 'Standing Calf Raise',        muscleGroups: ['Calves'],                  icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'seatedcalfraise',   name: 'Seated Calf Raise',          muscleGroups: ['Calves'],                  icon: '🏋️', defaultIncrementKg: 5.0),
  Exercise(id: 'legpresscalf',      name: 'Leg Press Calf Raise',       muscleGroups: ['Calves'],                  icon: '🏋️', defaultIncrementKg: 10.0),

  // ── Core ──────────────────────────────────────────────────────────────────
  Exercise(id: 'plank',             name: 'Plank',                      muscleGroups: ['Core'],                    icon: '🏋️', defaultIncrementKg: 0.0),
  Exercise(id: 'cablecrunch',       name: 'Cable Crunch',               muscleGroups: ['Core'],                    icon: '🏋️', defaultIncrementKg: 2.5),
  Exercise(id: 'legraise',          name: 'Leg Raise',                  muscleGroups: ['Core'],                    icon: '🏋️', defaultIncrementKg: 0.0),
  Exercise(id: 'abwheel',           name: 'Ab Wheel',                   muscleGroups: ['Core'],                    icon: '🏋️', defaultIncrementKg: 0.0),
  Exercise(id: 'russiantwist',      name: 'Russian Twist',              muscleGroups: ['Core'],                    icon: '🏋️', defaultIncrementKg: 0.0),
  Exercise(id: 'hanginglegraise',   name: 'Hanging Leg Raise',          muscleGroups: ['Core'],                    icon: '🏋️', defaultIncrementKg: 0.0),
  Exercise(id: 'deadbug',           name: 'Dead Bug',                   muscleGroups: ['Core'],                    icon: '🏋️', defaultIncrementKg: 0.0),
];

List<Exercise> filterExercises(List<Exercise> all, String bodyPart) {
  if (bodyPart == 'All') return all;
  return all.where((e) => e.muscleGroups.contains(bodyPart)).toList();
}
