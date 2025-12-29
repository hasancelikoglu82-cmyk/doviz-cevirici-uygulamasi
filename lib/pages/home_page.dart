import 'package:flutter/material.dart';
import 'dart:convert'; // JSON işlemleri için eklendi
import 'package:intl/intl.dart'; 
import '../service/api_service.dart';
import '../main.dart'; // Tema değişimi için
import '../service/storage_service.dart';
import 'detail_page.dart';
import 'package:showcaseview/showcaseview.dart'; // Tanıtım için eklendi

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  static const String _storageKey = 'doviz_takip_listesi';
  
  // Cache Anahtarları
  static const String _cacheTodayKey = 'doviz_cache_today';
  static const String _cacheYesterdayKey = 'doviz_cache_yesterday';
  static const String _cacheDateKey = 'doviz_cache_date';
  static const String _cacheYesterdayDateKey = 'doviz_cache_yesterday_date';
  
  // Çevirici Kayıt Anahtarları
  static const String _prefBaseCurrency = 'home_base_currency';
  static const String _prefTargetCurrency = 'home_target_currency';
  static const String _prefAmount = 'home_amount';

  // Veriler
  Map<String, dynamic>? _todayData;
  Map<String, dynamic>? _yesterdayData;
  bool _isLoading = true;
  String _veriTarihi = "";
  String _yesterdayDate = ""; // Dünün tarihini tutmak için
  
  // Çevirici
  String _baseCurrency = "USD";
  String _targetCurrency = "TRY";
  double _inputValue = 1.0;
  double _bozdurmaSonucu = 0;
  double _almaSonucu = 0;
  
  final TextEditingController _controller = TextEditingController(text: "1");
  List<String> _aktifKurlar = ["USD", "EUR", "GBP", "CHF", "JPY"]; 

  // Tanıtım Anahtarı
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _editKey = GlobalKey();
  final GlobalKey _refreshKey = GlobalKey();
  final GlobalKey _calculatorKey = GlobalKey();

  final Map<String, String> _tumKurlarHavuzu = {
    "USD": "Amerikan Doları", "EUR": "Euro", "GBP": "İngiliz Sterlini", "JPY": "Japon Yeni",
    "CHF": "İsviçre Frangı", "CAD": "Kanada Doları", "AUD": "Avustralya Doları",
    "CNY": "Çin Yuanı", "SEK": "İsveç Kronu", "NOK": "Norveç Kronu",
    "DKK": "Danimarka Kronu", "BGN": "Bulgar Levası",
    "CZK": "Çek Korunası", "HUF": "Macar Forinti", "PLN": "Polonya Zlotisi",
    "RON": "Rumen Leyi", "ISK": "İzlanda Kronu", "BRL": "Brezilya Reali",
    "HKD": "Hong Kong Doları", "IDR": "Endonezya Rupiahı", "ILS": "İsrail Şekeli",
    "INR": "Hindistan Rupisi", "KRW": "Güney Kore Wonu", "MXN": "Meksika Pesosu",
    "MYR": "Malezya Ringgiti", "NZD": "Yeni Zelanda Doları", "PHP": "Filipinler Pesosu",
    "SGD": "Singapur Doları", "THB": "Tayland Bahtı", "ZAR": "Güney Afrika Randı",
  };

  final Map<String, String> _currencyToFlagCode = {
    "USD": "us", "EUR": "de", "GBP": "gb", "JPY": "jp", "CHF": "ch", 
    "CAD": "ca", "AUD": "au", "CNY": "cn", "SEK": "se", 
    "NOK": "no", "DKK": "dk", "BGN": "bg", "CZK": "cz", 
    "HUF": "hu", "PLN": "pl", "RON": "ro", "ISK": "is", "BRL": "br", 
    "HKD": "hk", "IDR": "id", "ILS": "il", "INR": "in", "KRW": "kr", 
    "MXN": "mx", "MYR": "my", "NZD": "nz", "PHP": "ph", "SGD": "sg", 
    "THB": "th", "ZAR": "za", "TRY": "tr"
  };

  @override
  void initState() {
    super.initState();
    _verileriYukle();
    _verileriGetir();
    _loadConverterPreferences();
  }

  void _tanitimiBaslat() async {
    String? isShown = await _storageService.veriGetir('tutorial_shown_home_v2'); // v2 yaptık
    if (isShown == null) {
      if (!mounted) return;
      ShowCaseWidget.of(context).startShowCase([_listKey, _calculatorKey, _editKey, _refreshKey]);
      _storageService.veriKaydet('tutorial_shown_home_v2', 'true');
    }
  }

  Future<void> _loadConverterPreferences() async {
    String? base = await _storageService.veriGetir(_prefBaseCurrency);
    String? target = await _storageService.veriGetir(_prefTargetCurrency);
    String? amount = await _storageService.veriGetir(_prefAmount);

    if (mounted) {
      setState(() {
        if (base != null && (_tumKurlarHavuzu.containsKey(base) || base == "TRY")) _baseCurrency = base;
        if (target != null && (_tumKurlarHavuzu.containsKey(target) || target == "TRY")) _targetCurrency = target;
        if (amount != null) {
          _controller.text = amount;
          String rawVal = amount.replaceAll('.', '');
          _inputValue = double.tryParse(rawVal.replaceAll(',', '.')) ?? 0.0;
        }
      });
      _hesapla();
    }
  }

  Future<void> _verileriYukle() async {
    // 1. Takip Listesini Yükle
    List<String>? kayitliListe = await _storageService.listeyiGetir(_storageKey);
    if (kayitliListe != null) {
      setState(() {
        // Sadece desteklenen kurları listeye al (Eski kayıtlarda RUB/SAR varsa patlamasın)
        _aktifKurlar = kayitliListe.where((kod) => _tumKurlarHavuzu.containsKey(kod)).toList();
      });
    }

    // 2. Önbellekteki Kur Verilerini Yükle (Sıfırlanmayı önlemek için)
    try {
      String? todayJson = await _storageService.veriGetir(_cacheTodayKey);
      String? yesterdayJson = await _storageService.veriGetir(_cacheYesterdayKey);
      String? dateStr = await _storageService.veriGetir(_cacheDateKey);
      String? yesterdayDateStr = await _storageService.veriGetir(_cacheYesterdayDateKey);

      if (todayJson != null && yesterdayJson != null) {
        setState(() {
          _todayData = jsonDecode(todayJson);
          _yesterdayData = jsonDecode(yesterdayJson);
          _veriTarihi = dateStr ?? "";
          _yesterdayDate = yesterdayDateStr ?? "";
          _isLoading = false; // Cache varsa loading'i kapat, kullanıcı beklemesin
        });
        _hesapla();
        WidgetsBinding.instance.addPostFrameCallback((_) => _tanitimiBaslat()); // Veri gelince başlat
      }
    } catch (e) {
      debugPrint("Cache yükleme hatası: $e");
    }
  }

  Future<void> _verileriGetir() async {
    try {
      // 1. Önce en güncel veriyi çek
      var bugunMap = await _apiService.getFrankfurterDoviz();
      
      Map<String, dynamic>? newYesterdayData;
      String newYesterdayDate = "";
      String apiTodayDate = "";

      if (bugunMap.containsKey('rates')) {
        apiTodayDate = bugunMap['date'] ?? "";
        
        // 2. Bu tarihe göre "dünü" hesapla (API'nin döndüğü tarihten geriye git)
        // Böylece "Bugün" verisi aslında dünün verisi olsa bile, biz ondan bir öncekini alırız.
        DateTime currentDataDate = DateTime.parse(apiTodayDate);
        
        // Önceki iş gününü bul (Hafta sonunu atla)
        DateTime prevDate = currentDataDate.subtract(const Duration(days: 1));
        while (prevDate.weekday == 6 || prevDate.weekday == 7) {
          prevDate = prevDate.subtract(const Duration(days: 1));
        }
        
        String targetYesterdayStr = prevDate.toIso8601String().split('T')[0];

        // 3. Hesaplanan "dün" için veriyi çek
        var dunMap = await _apiService.getRatesForDate(targetYesterdayStr);
        
        if (dunMap.containsKey('rates')) {
          newYesterdayData = dunMap['rates'];
          newYesterdayData!['USD'] = 1.0;
          newYesterdayDate = targetYesterdayStr;
        }
      }

      setState(() {
        if (bugunMap.containsKey('rates')) {
          _todayData = bugunMap['rates'];
          _todayData!['USD'] = 1.0; 
          _veriTarihi = apiTodayDate;
        }
        
        if (newYesterdayData != null) {
          _yesterdayData = newYesterdayData;
          _yesterdayDate = newYesterdayDate;
        }
        
        _isLoading = false;
      });
      
      _hesapla(); 
      WidgetsBinding.instance.addPostFrameCallback((_) => _tanitimiBaslat()); // Veri gelince başlat

      // Verileri Cache'e Kaydet
      if (_todayData != null) {
        _storageService.veriKaydet(_cacheTodayKey, jsonEncode(_todayData));
        _storageService.veriKaydet(_cacheDateKey, _veriTarihi);
      }
      if (_yesterdayData != null) {
        _storageService.veriKaydet(_cacheYesterdayKey, jsonEncode(_yesterdayData));
        _storageService.veriKaydet(_cacheYesterdayDateKey, _yesterdayDate);
      }

    } catch (e) {
      debugPrint("Hata: $e");
      setState(() => _isLoading = false);
    }
  }

  // İSMİNİ DÜZELTTİĞİMİZ VE TEK OLAN FONKSİYON
  Map<String, dynamic> _fiyatVeDegisimBul(String kod) {
    if (kod == "TRY") {
      return {'alis': 1.0, 'satis': 1.0, 'degisim': 0.0};
    }

    if (_todayData == null || !_todayData!.containsKey('TRY')) {
      return {'alis': 0.0, 'satis': 0.0, 'degisim': 0.0};
    }
    
    if (kod != "USD" && !_todayData!.containsKey(kod)) {
      return {'alis': 0.0, 'satis': 0.0, 'degisim': 0.0};
    }

    double bugunDolarTL = (_todayData!['TRY'] as num).toDouble(); 
    double bugunParaDolar = (_todayData![kod] as num?)?.toDouble() ?? 1.0; 
    double ortaKurTL = bugunDolarTL / bugunParaDolar;
    
    // Dünün Kuru
    double dunOrtaKur = ortaKurTL;
    if (_yesterdayData != null && _yesterdayData!.containsKey('TRY')) {
      double dunDolarTL = (_yesterdayData!['TRY'] as num).toDouble();
      double dunParaDolar = (_yesterdayData!.containsKey(kod)) ? (_yesterdayData![kod] as num).toDouble() : bugunParaDolar;
      dunOrtaKur = dunDolarTL / dunParaDolar;
    }
    
    double degisim = 0.0;
    if (dunOrtaKur > 0) {
      degisim = ((ortaKurTL - dunOrtaKur) / dunOrtaKur) * 100;
    }

    double makas = 0.005; 

    return {
      'alis': ortaKurTL * (1 - makas),
      'satis': ortaKurTL * (1 + makas),
      'degisim': degisim 
    };
  }

  void _hesapla() {
    if (_todayData == null) return;

    // Buradaki isim de düzeltildi (_fiyatVeDegisimBul)
    var kaynakFiyatlar = _fiyatVeDegisimBul(_baseCurrency);
    var hedefFiyatlar = _fiyatVeDegisimBul(_targetCurrency);

    double kaynakAlis = kaynakFiyatlar['alis']!;
    double kaynakSatis = kaynakFiyatlar['satis']!;
    double hedefAlis = hedefFiyatlar['alis']!;
    double hedefSatis = hedefFiyatlar['satis']!;

    if (hedefSatis == 0 || hedefAlis == 0) return;

    setState(() {
      _bozdurmaSonucu = (_inputValue * kaynakAlis) / hedefSatis;
      _almaSonucu = (_inputValue * kaynakSatis) / hedefAlis;
    });
  }

  void _swapCurrencies() {
    setState(() {
      String temp = _baseCurrency;
      _baseCurrency = _targetCurrency;
      _targetCurrency = temp;
      _hesapla();
      _storageService.veriKaydet(_prefBaseCurrency, _baseCurrency);
      _storageService.veriKaydet(_prefTargetCurrency, _targetCurrency);
    });
  }

  void _listeDuzenlePenceresiAc() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context, backgroundColor: theme.cardColor, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20), height: MediaQuery.of(context).size.height * 0.8,
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
              Text("Takip Listesi", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(child: ListView(children: _tumKurlarHavuzu.keys.map((String kod) {
                bool secili = _aktifKurlar.contains(kod);
                String flagCode = _currencyToFlagCode[kod] ?? 'us';
                
                return CheckboxListTile(
                  activeColor: theme.primaryColor, checkColor: Colors.white, contentPadding: EdgeInsets.zero,
                  title: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.network("https://flagcdn.com/w40/$flagCode.png", width: 24, errorBuilder: (c,e,s)=>const Icon(Icons.error, size: 20, color: Colors.grey))),
                    const SizedBox(width: 10), Expanded(child: Text("$kod - ${_tumKurlarHavuzu[kod]}", style: theme.textTheme.bodyLarge))
                  ]),
                  value: secili, 
                  onChanged: (v) { 
                    setModalState(() { 
                      if (v!) {
                        _aktifKurlar.add(kod);
                      } else {
                        _aktifKurlar.remove(kod);
                      }
                      _storageService.listeyiKaydet(_storageKey, _aktifKurlar);
                    }); 
                    setState((){}); 
                  }
                );
              }).toList())),
              SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text("KAYDET", style: TextStyle(fontWeight: FontWeight.bold))))
            ]),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // backgroundColor: const Color(0xFF121212), // ARTIK TEMADAN GELİYOR
      appBar: AppBar(
        // backgroundColor: Colors.transparent, elevation: 0, // ARTIK TEMADAN GELİYOR
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text("Döviz Piyasası", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), 
           FittedBox(
             fit: BoxFit.scaleDown, 
             alignment: Alignment.centerLeft, 
             child: Text("ECB (Makaslı) - $_veriTarihi", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))
           )
        ]), 
        actions: [
          // Bildirim Butonu
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => NotificationsPage(messages: MainScreen.notifications),
              ));
            },
          ),
          IconButton(icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode), onPressed: () {
             MyApp.of(context).changeTheme(isDark ? ThemeMode.light : ThemeMode.dark);
          }),
          Showcase(
            key: _editKey,
            title: 'Listeyi Düzenle',
            description: 'Takip etmek istediğiniz döviz kurlarını buradan seçebilirsiniz.',
            child: IconButton(icon: Icon(Icons.edit_note, color: theme.primaryColor), onPressed: _listeDuzenlePenceresiAc),
          ), 
          Showcase(
            key: _refreshKey,
            title: 'Yenile',
            description: 'Kurları güncellemek için tıklayın.',
            child: IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() { _isLoading = true; }); _verileriGetir(); }),
          )
        ]),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: theme.primaryColor)) : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        const Text("Takip Listeniz", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
        SizedBox(height: 180, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _aktifKurlar.length, itemBuilder: (context, index) {
          String kod = _aktifKurlar[index];
          // Fonksiyon ismi düzeltildi
          var veri = _fiyatVeDegisimBul(kod);
          Widget card = _piyasaKarti(context, kod, _tumKurlarHavuzu[kod]!, veri['alis'], veri['satis'], veri['degisim']);
          
          if (index == 0) {
            return Showcase(
              key: _listKey,
              title: 'Döviz Kurları',
              description: 'Güncel kurları buradan takip edebilir, detaylar ve grafik için üzerine tıklayabilirsiniz.',
              child: card,
            );
          }
          return card;
        })),
        const SizedBox(height: 35), const Text("Döviz Hesaplayıcı", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
        Showcase(
          key: _calculatorKey,
          title: 'Döviz Hesaplayıcı',
          description: 'Anlık kurlar üzerinden hızlıca çeviri ve maliyet hesabı yapın.',
          child: _buildGelismiCevirici(),
        ),
        const SizedBox(height: 40),
        Center(child: Column(children: [const Text("Veri Kaynağı: Avrupa Merkez Bankası (ECB)", style: TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 5), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)), child: const Text("* Fiyatlar piyasa ortalamasıdır. Bankalar arasında komisyon ve makas farklarından dolayı ufak fiyat farklılıkları olabilir.", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic), textAlign: TextAlign.center))])),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _piyasaKarti(BuildContext context, String kod, String isim, dynamic alis, dynamic satis, dynamic degisim) {
    bool artiyor = degisim >= 0.001;
    bool azaliyor = degisim <= -0.001;
    Color renk = !artiyor && !azaliyor ? Colors.grey : (artiyor ? const Color(0xFF00C853) : const Color(0xFFFF3D00));
    IconData icon = !artiyor && !azaliyor ? Icons.remove : (artiyor ? Icons.arrow_upward : Icons.arrow_downward);
    String flagCode = _currencyToFlagCode[kod] ?? 'us';
    final theme = Theme.of(context);
    
    final formatter = NumberFormat("#,##0.00", "tr_TR");

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(currencyCode: kod, currencyName: isim))),
      borderRadius: BorderRadius.circular(20),
      child: Container(width: 160, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))]), child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network("https://flagcdn.com/w40/$flagCode.png", width: 22, height: 16, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.error, color: Colors.grey, size: 20))), 
          const SizedBox(width: 8), Text(kod, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18))]), 
          Icon(icon, color: renk, size: 18)]),
        Divider(color: theme.dividerColor),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Alış", style: TextStyle(color: Colors.grey, fontSize: 12)), Text(formatter.format(alis), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Satış", style: TextStyle(color: Colors.grey, fontSize: 12)), Text(formatter.format(satis), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("%${degisim.abs().toStringAsFixed(2)}", style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold)),
          const Row(children: [Icon(Icons.show_chart, size: 12, color: Colors.grey), SizedBox(width: 2), Text("Grafiği Gör", style: TextStyle(color: Colors.grey, fontSize: 10))])
        ])
      ])),
    );
  }

  Widget _buildGelismiCevirici() {
    final theme = Theme.of(context);
    return Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(30), border: Border.all(color: theme.dividerColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(children: [
      Row(children: [
        Expanded(child: TextField(
          controller: _controller, 
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), 
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: "Miktar", border: InputBorder.none), 
          onChanged: (val) {
            if (val.isEmpty) {
              _inputValue = 0.0;
              _hesapla();
              return;
            }

            // 1. Ham veriyi al (Noktaları temizle: 100.000 -> 100000)
            String rawVal = val.replaceAll('.', '');
            
            // 2. Hesaplama yap
            _inputValue = double.tryParse(rawVal.replaceAll(',', '.')) ?? 0.0;
            _hesapla();

            // 3. Formatla (100000 -> 100.000)
            final formatter = NumberFormat("#,###", "tr_TR");
            String newText = rawVal;
            try {
              if (rawVal.contains(',')) {
                List<String> parts = rawVal.split(',');
                if (parts[0].isNotEmpty) {
                  newText = "${formatter.format(int.parse(parts[0]))},${parts.length > 1 ? parts[1] : ''}";
                }
              } else {
                newText = formatter.format(int.parse(rawVal));
              }
            } catch (_) {}

            if (val != newText) {
              _controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            }
            _storageService.veriKaydet(_prefAmount, newText);
          }
        )), 
        const SizedBox(width: 10), 
        _paraBirimiDropdown(true)
      ]),
      Stack(
        alignment: Alignment.center,
        children: [
          Divider(color: theme.dividerColor, height: 30),
          InkWell(
            onTap: _swapCurrencies,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: theme.cardColor, shape: BoxShape.circle, border: Border.all(color: theme.dividerColor)),
              child: Icon(Icons.swap_vert, color: theme.primaryColor, size: 22),
            ),
          ),
        ],
      ),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Text("Şuna Çevir:", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(width: 10), _paraBirimiDropdown(false)]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _sonucKarti("Bozdurursan", _bozdurmaSonucu, Colors.redAccent)),
        const SizedBox(width: 15),
        Expanded(child: _sonucKarti("Alırsan (Maliyet)", _almaSonucu, Colors.greenAccent)),
      ]),
    ]));
  }

  Widget _sonucKarti(String baslik, double deger, Color renk) {
    final formatter = NumberFormat("#,##0.00", "tr_TR");
    final theme = Theme.of(context);
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(baslik, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(formatter.format(deger), style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold)), Text(_targetCurrency, style: const TextStyle(color: Colors.grey, fontSize: 12))]));
  }

  Widget _paraBirimiDropdown(bool isBase) {
    List<String> list = ["TRY", ..._tumKurlarHavuzu.keys]; list.sort();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: isBase ? _baseCurrency : _targetCurrency, dropdownColor: theme.cardColor, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        items: list.map((v) {
          String flagCode = _currencyToFlagCode[v] ?? 'us';
          return DropdownMenuItem(value: v, child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.network("https://flagcdn.com/w40/$flagCode.png", width: 20, height: 15, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.error, size: 15))),
            const SizedBox(width: 8), Text(v, style: theme.textTheme.bodyLarge)
          ]));
        }).toList(),
        onChanged: (newValue) {
          setState(() { 
            if (isBase) {
              _baseCurrency = newValue!;
            } else {
              _targetCurrency = newValue!;
            }
            _hesapla(); 
            _storageService.veriKaydet(_prefBaseCurrency, _baseCurrency);
            _storageService.veriKaydet(_prefTargetCurrency, _targetCurrency);
          });
        },
      )),
    );
  }
}