import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/palettes.dart';
import '../theme/tokens.dart';

/// Persists and applies the selected app theme via [T.apply].
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    final saved = _prefs.getString(_kThemeId);
    final option = AppPalettes.byId(saved ?? AppPalettes.defaultId);
    _currentId = option.id;
    T.apply(option.palette);
  }

  static const _kThemeId = 'cg_theme';

  final SharedPreferences _prefs;
  late String _currentId;

  String get currentId => _currentId;
  AppPalette get palette => T.active;

  ThemeOption get currentOption => AppPalettes.byId(_currentId);

  Future<void> select(String id) async {
    if (id == _currentId) return;
    final option = AppPalettes.byId(id);
    _currentId = option.id;
    T.apply(option.palette);
    notifyListeners();
    await _prefs.setString(_kThemeId, _currentId);
  }
}
