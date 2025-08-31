import 'package:flutter/material.dart';

class AppRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<T?> push<T>(Route<T> route) => navigatorKey.currentState!.push(route);
  static Future<T?> pushPage<T>(Widget page) => push(MaterialPageRoute(builder: (_) => page));
  static void pop<T extends Object?>([T? result]) => navigatorKey.currentState!.pop(result);
}
