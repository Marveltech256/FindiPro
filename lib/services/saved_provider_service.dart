import 'package:shared_preferences/shared_preferences.dart';

class SavedProviderService {
  static const _key = 'saved_providers';

  Future<List<String>> getSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> toggle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await getSavedIds();

    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }

    await prefs.setStringList(_key, ids);
  }
}