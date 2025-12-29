import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Listeyi kaydetme fonksiyonu
  Future<void> listeyiKaydet(String key, List<String> liste) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, liste);
  }

  // Listeyi okuma fonksiyonu
  Future<List<String>?> listeyiGetir(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  // Tekil veri (String/JSON) kaydetme fonksiyonu
  Future<void> veriKaydet(String key, String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // Tekil veri (String/JSON) okuma fonksiyonu
  Future<String?> veriGetir(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}