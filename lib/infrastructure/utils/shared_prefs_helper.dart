import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static final SharedPrefsService _instance = SharedPrefsService._internal();
  SharedPreferences? _prefs;

  factory SharedPrefsService() {
    return _instance;
  }

  SharedPrefsService._internal();

  /// Inicializa SharedPreferences antes de su uso
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Guarda cualquier tipo de dato en SharedPreferences
  Future<void> setValue<T>(String key, T value) async {
    if (_prefs == null) return;

    if (value is String) {
      await _prefs!.setString(key, value);
    } else if (value is int) {
      await _prefs!.setInt(key, value);
    } else if (value is bool) {
      await _prefs!.setBool(key, value);
    } else if (value is double) {
      await _prefs!.setDouble(key, value);
    } else if (value is List<String>) {
      await _prefs!.setStringList(key, value);
    } else {
      throw Exception("Tipo de dato no soportado");
    }
  }

  /// Obtiene un valor de SharedPreferences
  T? getValue<T>(String key) {
    if (_prefs == null) return null;
    return _prefs!.get(key) as T?;
  }

  /// Elimina un valor de SharedPreferences
  Future<void> removeValue(String key) async {
    if (_prefs == null) return;
    await _prefs!.remove(key);
  }

  /// Limpia todos los datos de SharedPreferences
  Future<void> clear() async {
    if (_prefs == null) return;
    await _prefs!.clear();
  }
}
