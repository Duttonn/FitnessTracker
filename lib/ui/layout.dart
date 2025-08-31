import 'package:flutter/material.dart';
import 'package:flutter_fitness_app/ui/widgets/vision_nav_bar.dart';

const kIndicatorHeight = 44.0; // legacy, can be removed later

double bottomReserve(BuildContext context) {
  final pad = MediaQuery.viewPaddingOf(context).bottom;
  return VisionNavBar.kHeight + pad + 24; // bar + safe + breathing room
}
