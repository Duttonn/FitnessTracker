import 'package:flutter/material.dart';

class ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const ExerciseCard({Key? key, required this.title, required this.subtitle})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(title), subtitle: Text(subtitle)),
    );
  }
}
