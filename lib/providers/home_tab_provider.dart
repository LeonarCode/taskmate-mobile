import 'package:flutter/foundation.dart';

/// Which tab of the home screen is showing. Lets other screens (for example a
/// tapped notification) jump to a tab.
class HomeTabProvider extends ChangeNotifier {
  static const tasks = 0;
  static const servers = 1;
  static const chats = 2;
  static const alerts = 3;
  static const profile = 4;

  int _index = tasks;
  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }

  /// Back to the first tab (used after signing out).
  void reset() => _index = tasks;
}
