import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 1. COLLECT API (Sadece Altın Sayfası İçin)
  final String _apiKey = "apikey 2Z5unvNVIHhrG4vdhXsKqH:2jQ33qazJGA1uhPpgrGgG5"; // <--- BURAYA KEYİNİ YAPIŞTIR
  final String _collectBaseUrl = "https://api.collectapi.com/economy";

  // --- YENİ: DÖVİZLERİ ÇEK (CollectAPI) ---
  Future<Map<String, dynamic>> getCollectDoviz() async {
    final url = "$_collectBaseUrl/allCurrency";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'authorization': _apiKey, 'content-type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Map<String, dynamic> result = {};
          for (var item in data['result']) {
            result[item['code']] = item;
          }
          return {'success': true, 'data': result};
        }
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  // 2. FRANKFURTER API (Döviz ve Oklar İçin)
  final String _frankfurterBaseUrl = "https://api.frankfurter.app";

  // --- A) BUGÜNKÜ DÖVİZLER ---
  Future<Map<String, dynamic>> getFrankfurterDoviz() async {
    final url = "$_frankfurterBaseUrl/latest?from=USD";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  // --- B) DÜNKÜ DÖVİZLER (Oklar buna bakacak) ---
  Future<Map<String, dynamic>> getFrankfurterYesterday() async {
    DateTime now = DateTime.now();
    // Hafta sonuna denk gelirse Cuma'yı bulsun diye basit mantık
    DateTime past = now.subtract(Duration(days: (now.weekday == 1) ? 3 : 1)); 
    String dateStr = past.toIso8601String().split('T')[0];
    
    final url = "$_frankfurterBaseUrl/$dateStr?from=USD";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  // --- E) BELİRLİ BİR TARİHİ ÇEK (Değişim Oranı Düzeltmesi İçin) ---
  Future<Map<String, dynamic>> getRatesForDate(String date) async {
    final url = "$_frankfurterBaseUrl/$date?from=USD";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  // --- C) ALTINLARI ÇEK (CollectAPI) ---
  Future<List<dynamic>> getCollectAltin() async {
    final url = "$_collectBaseUrl/goldPrice";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'authorization': _apiKey, 'content-type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return data['result'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- D) GRAFİK GEÇMİŞİ ---
  Future<Map<String, dynamic>> getHistoryDocs(String baseCode, int days) async {
    DateTime now = DateTime.now();
    DateTime startDate = now.subtract(Duration(days: days));
    String endStr = now.toIso8601String().split('T')[0];
    String startStr = startDate.toIso8601String().split('T')[0];
    final url = "$_frankfurterBaseUrl/$startStr..$endStr?from=$baseCode&to=TRY";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  // --- F) KRİPTO PARALARI ÇEK (CollectAPI) ---
  Future<List<dynamic>> getCollectKripto() async {
    final url = "$_collectBaseUrl/cripto";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'authorization': _apiKey, 'content-type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return data['result'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- G) KRİPTO GEÇMİŞİ (Binance -> Fallback: CoinGecko) ---
  Future<List<dynamic>> getCryptoHistory(String code, String name, int days) async {
    // 1. Deneme: Binance (Sembol bazlı)
    final symbol = "${code.trim().toUpperCase()}USDT";
    final binanceUrl = "https://api.binance.com/api/v3/klines?symbol=$symbol&interval=1d&limit=$days";
    
    try {
      final response = await http.get(Uri.parse(binanceUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Binance bazen hata mesajı dönebilir, liste olup olmadığını kontrol edelim
        if (data is List && data.isNotEmpty) {
          return data;
        }
      }
    } catch (e) {
      // Binance hatası, CoinGecko'ya geç
    }

    // 2. Deneme: CoinGecko (İsim bazlı fallback)
    // İsimden ID tahmini: "Bitget Token" -> "bitget-token"
    String cgId = name.toLowerCase().trim().replaceAll(' ', '-');
    
    // Özel Mappingler (Otomatik bulunamayanlar için)
    if (code.toUpperCase() == 'USDT') cgId = 'tether';
    if (code.toUpperCase() == 'CRO') cgId = 'crypto-com-chain'; // Cronos
    if (code.toUpperCase() == 'KCS') cgId = 'kucoin-shares';
    if (code.toUpperCase() == 'LEO') cgId = 'leo-token';
    if (code.toUpperCase() == 'HT') cgId = 'huobi-token';
    if (code.toUpperCase() == 'OKB') cgId = 'okb';
    if (code.toUpperCase() == 'KAS') cgId = 'kaspa';
    if (code.trim().toUpperCase() == 'XDC') cgId = 'xdc-network';
    if (code.toUpperCase() == 'FLR') cgId = 'flare-networks';
    if (code.toUpperCase() == 'GT') cgId = 'gatechain-token';
    if (code.toUpperCase() == 'PI') cgId = 'pi-network';
    if (code.toUpperCase() == 'AERO') cgId = 'aerodrome-finance';
    if (code.toUpperCase() == 'MNT') cgId = 'mantle';
    if (code.toUpperCase() == 'BGB') cgId = 'bitget-token';
    if (code.toUpperCase() == 'AB') cgId = 'arcblock';

    // İsim bazlı özel düzeltmeler
    if (name.toLowerCase().contains('global dollar')) cgId = 'global-dollar';
    if (name.toLowerCase().contains('ripple usd')) cgId = 'ripple-usd';
    if (name.toLowerCase().contains('midnight')) cgId = 'midnight';
    if (name.toLowerCase().contains('canton')) cgId = 'canto';
    if (name.toLowerCase().contains('xdc')) cgId = 'xdc-network';
    if (name.toLowerCase().contains('pippin')) cgId = 'pippin';
    if (name.toLowerCase().contains('tether gold')) cgId = 'tether-gold';
    
    final cgUrl = "https://api.coingecko.com/api/v3/coins/$cgId/market_chart?vs_currency=usd&days=$days";
    
    try {
      final response = await http.get(Uri.parse(cgUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['prices'] != null) {
          List<dynamic> formattedList = [];
          for (var item in data['prices']) {
            // CoinGecko: [timestamp, price]
            // Binance formatına benzetiyoruz: [time, open, high, low, close, ...]
            // DetailPage sadece [0] (time) ve [4] (close) kullanıyor.
            formattedList.add([item[0], 0, 0, 0, item[1]]);
          }
          return formattedList;
        }
      }
    } catch (e) {
      // CoinGecko da başarısız
    }

    return [];
  }
}