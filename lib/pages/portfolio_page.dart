import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../service/api_service.dart';
import '../service/storage_service.dart';
import 'package:showcaseview/showcaseview.dart'; // Tanıtım için

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  static const String _storageKey = 'user_portfolio';
  final GlobalKey _addBtnKey = GlobalKey();
  final GlobalKey _removeBtnKey = GlobalKey();
  final GlobalKey _totalCardKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();
  final GlobalKey _sortKey = GlobalKey();

  // Kullanıcının Varlıkları: [{'type': 'doviz', 'code': 'USD', 'amount': 100.0, 'cost': 32.5, 'date': '2023-10-27...'}, ...]
  List<Map<String, dynamic>> _assets = [];
  
  // Anlık Piyasa Verileri
  Map<String, dynamic> _dovizVerileri = {};
  List<dynamic> _altinVerileri = [];
  List<dynamic> _kriptoVerileri = []; // Kripto verileri için liste
  
  bool _isLoading = true;
  double _toplamVarlikTL = 0.0;
  double _toplamKarZarar = 0.0; // Toplam Kâr/Zarar

  // Eklenecek Varlık İçin Değişkenler
  String _selectedType = "Döviz"; // Döviz veya Altın
  String _selectedCode = "USD";
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _costController = TextEditingController(); // Alış Maliyeti
  
  // Arama ve Sıralama Durumları
  bool _isSearching = false;
  bool _isSortedByCode = false;
  final TextEditingController _searchController = TextEditingController();

  // Yedek Altın Listesi (İnternet yoksa veya API boşsa kullanılır)
  final List<String> _altinKodlari = ["Gram Altın", "Çeyrek Altın", "Yarım Altın", "Tam Altın", "Ata Altın"];
  
  // Geniş Döviz Havuzu
  final Map<String, String> _tumKurlarHavuzu = {
    "USD": "Amerikan Doları", "EUR": "Euro", "GBP": "İngiliz Sterlini", "JPY": "Japon Yeni",
    "CHF": "İsviçre Frangı", "CAD": "Kanada Doları", "AUD": "Avustralya Doları",
    "CNY": "Çin Yuanı", "SEK": "İsveç Kronu", "NOK": "Norveç Kronu", "DKK": "Danimarka Kronu", 
    "SAR": "Suudi Arabistan Riyali", "RUB": "Rus Rublesi", "BGN": "Bulgar Levası",
    "CZK": "Çek Korunası", "HUF": "Macar Forinti", "PLN": "Polonya Zlotisi", "RON": "Rumen Leyi", 
    "ISK": "İzlanda Kronu", "BRL": "Brezilya Reali", "HKD": "Hong Kong Doları", "IDR": "Endonezya Rupiahı", 
    "ILS": "İsrail Şekeli", "INR": "Hindistan Rupisi", "KRW": "Güney Kore Wonu", "MXN": "Meksika Pesosu",
    "MYR": "Malezya Ringgiti", "NZD": "Yeni Zelanda Doları", "PHP": "Filipinler Pesosu", "SGD": "Singapur Doları", 
    "THB": "Tayland Bahtı", "ZAR": "Güney Afrika Randı"
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
    _baslangicIslemleri();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tanitimiBaslat());
  }

  void _tanitimiBaslat() async {
    // Varlıklarım sayfasına ilk girişte butonları tanıt
    String? isShown = await _storageService.veriGetir('tutorial_shown_portfolio_v3'); // v3 ile güncelledik
    if (isShown == null) {
      if (!mounted) return;
      ShowCaseWidget.of(context).startShowCase([_totalCardKey, _addBtnKey, _removeBtnKey, _historyKey, _sortKey]);
      _storageService.veriKaydet('tutorial_shown_portfolio_v3', 'true');
    }
  }

  Future<void> _baslangicIslemleri() async {
    await _varliklariYukle();
    await _piyasaVerileriniCek();
  }

  Future<void> _varliklariYukle() async {
    List<String>? savedList = await _storageService.listeyiGetir(_storageKey);
    if (savedList != null) {
      setState(() {
        _assets = savedList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
        // ReorderableListView için benzersiz ID (tarih) kontrolü
        for (var asset in _assets) {
          if (asset['date'] == null) {
             asset['date'] = DateTime.now().subtract(Duration(milliseconds: _assets.indexOf(asset))).toIso8601String();
          }
        }
      });
    }
  }

  Future<void> _varliklariKaydet() async {
    List<String> saveList = _assets.map((e) => jsonEncode(e)).toList();
    await _storageService.listeyiKaydet(_storageKey, saveList);
    _toplamHesapla();
  }

  Future<void> _piyasaVerileriniCek() async {
    setState(() => _isLoading = true);
    try {
      // Dövizleri Çek
      var dovizResponse = await _apiService.getCollectDoviz();
      if (dovizResponse['success'] == true) {
        _dovizVerileri = dovizResponse['data'];
      }

      // Altınları Çek
      var altinResponse = await _apiService.getCollectAltin();
      _altinVerileri = altinResponse;

      // Kriptoları Çek
      var kriptoResponse = await _apiService.getCollectKripto();
      _kriptoVerileri = kriptoResponse;

      _toplamHesapla();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _toplamHesapla() {
    double toplam = 0;
    double toplamMaliyet = 0;
    
    // Kripto hesabı için güncel Dolar kurunu al (Çünkü kripto fiyatı USD geliyor)
    double dolarKuru = 0;
    if (_dovizVerileri.containsKey('USD')) {
      dolarKuru = double.tryParse(_dovizVerileri['USD']['buying'].toString()) ?? 0;
    }

    for (var asset in _assets) {
      double miktar = asset['amount'];
      double birimFiyat = 0;

      if (asset['type'] == 'Döviz') {
        // Döviz Fiyatını Bul (Satış fiyatını baz alıyoruz - Bozdurursak ne kadar eder?)
        if (_dovizVerileri.containsKey(asset['code'])) {
          birimFiyat = double.tryParse(_dovizVerileri[asset['code']]['buying'].toString()) ?? 0;
        }
      } else if (asset['type'] == 'Altın') {
        // Altın Fiyatını Bul
        var altin = _altinVerileri.firstWhere((e) => e['name'] == asset['code'], orElse: () => null);
        if (altin != null) {
          birimFiyat = double.tryParse(altin['buying'].toString()) ?? 0;
        }
      } else if (asset['type'] == 'Kripto') {
        // Kripto Fiyatını Bul (USD) ve TL'ye çevir
        var coin = _kriptoVerileri.firstWhere((e) => e['code'] == asset['code'], orElse: () => null);
        if (coin != null) {
          double dolarFiyati = double.tryParse(coin['price'].toString()) ?? 0;
          birimFiyat = dolarFiyati * dolarKuru; // TL Karşılığı
        }
      }
      toplam += miktar * birimFiyat;
      
      // Maliyet Hesabı (Eğer eski kayıtsa ve cost yoksa, o anki fiyattan sayıp kârı 0 gösterelim)
      // DÜZELTME: Eğer maliyet 0 ise (girilmemişse), o anki fiyatı maliyet say ki %100 kâr gibi saçma durmasın.
      double alisMaliyeti = (asset['cost'] != null && asset['cost'] > 0) ? asset['cost'] : birimFiyat;
      toplamMaliyet += miktar * alisMaliyeti;
    }
    setState(() {
      _toplamVarlikTL = toplam;
      _toplamKarZarar = toplam - toplamMaliyet;
    });
  }

  // Seçilen birimin o anki fiyatını bulur (Otomatik doldurma için)
  double _guncelFiyatGetir(String type, String code) {
    if (type == 'Döviz' && _dovizVerileri.containsKey(code)) {
      return double.tryParse(_dovizVerileri[code]['buying'].toString()) ?? 0;
    } else if (type == 'Altın') {
      var altin = _altinVerileri.firstWhere((e) => e['name'] == code, orElse: () => null);
      if (altin != null) return double.tryParse(altin['buying'].toString()) ?? 0;
    } else if (type == 'Kripto') {
      var coin = _kriptoVerileri.firstWhere((e) => e['code'] == code, orElse: () => null);
      if (coin != null && _dovizVerileri.containsKey('USD')) {
        double dolarKuru = double.tryParse(_dovizVerileri['USD']['buying'].toString()) ?? 0;
        double dolarFiyati = double.tryParse(coin['price'].toString()) ?? 0;
        return dolarFiyati * dolarKuru; // TL Karşılığı
      }
    }
    return 0;
  }

  // Dropdown için liste öğelerini güvenli bir şekilde getiren yardımcı fonksiyon
  List<String> _getDropdownItems() {
    if (_selectedType == "Döviz") {
      return _tumKurlarHavuzu.keys.toList()..sort();
    } else if (_selectedType == "Altın") {
      return _altinVerileri.isNotEmpty 
          ? _altinVerileri.map((e) => e['name'].toString()).toList() 
          : _altinKodlari;
    } else {
      // Kripto
      return _kriptoVerileri.isNotEmpty 
          ? _kriptoVerileri.map((e) => e['code'].toString()).toList() 
          : ["BTC", "ETH"];
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _assets.removeAt(oldIndex);
      _assets.insert(newIndex, item);
    });
    _varliklariKaydet();
  }

  void _yeniVarlikEkleDialog() {
    _amountController.clear();
    _selectedType = "Döviz";
    _selectedCode = "USD";
    _costController.text = _guncelFiyatGetir("Döviz", "USD").toString(); // Varsayılan fiyatı doldur

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Varlık Ekle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // TÜR SEÇİMİ (Döviz / Altın)
                Row(
                  children: [
                    Expanded(child: _turButonu("Döviz", setModalState)),
                    const SizedBox(width: 10),
                    Expanded(child: _turButonu("Altın", setModalState)),
                    const SizedBox(width: 10),
                    Expanded(child: _turButonu("Kripto", setModalState)),
                  ],
                ),
                const SizedBox(height: 20),

                // BİRİM SEÇİMİ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3))
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCode,
                      isExpanded: true,
                      items: _getDropdownItems().map((String value) {
                        Widget icerik;
                        if (_selectedType == "Döviz") {
                          String flagCode = _currencyToFlagCode[value] ?? 'us';
                          icerik = Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Image.network("https://flagcdn.com/w40/$flagCode.png", width: 24, height: 16, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.monetization_on, size: 16, color: Colors.grey)),
                              ),
                              const SizedBox(width: 10),
                              Text(value)
                            ],
                          );
                        } else if (_selectedType == "Altın") {
                          icerik = Row(
                            children: [
                              Icon(Icons.diamond, color: Colors.amber[600], size: 18),
                              const SizedBox(width: 10),
                              Text(value)
                            ],
                          );
                        } else {
                          icerik = Row(
                            children: [
                              const Icon(Icons.currency_bitcoin, color: Colors.orange, size: 18),
                              const SizedBox(width: 10),
                              Text(value)
                            ],
                          );
                        }
                        return DropdownMenuItem<String>(value: value, child: icerik);
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => _selectedCode = val!);
                        // Seçim değişince o anki fiyatı maliyet kutusuna yaz
                        _costController.text = _guncelFiyatGetir(_selectedType, _selectedCode).toString();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // MİKTAR GİRİŞİ
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Miktar Giriniz",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixText: _selectedType == "Döviz" ? "" : "Adet",
                  ),
                ),
                const SizedBox(height: 15),

                // ALIŞ FİYATI GİRİŞİ (Maliyet)
                TextField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Birim Alış Fiyatı (Maliyet)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixText: "TL",
                    helperText: "Kâr/Zarar hesabı için gereklidir.",
                  ),
                ),
                const SizedBox(height: 20),

                // KAYDET BUTONU
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15)
                    ),
                    onPressed: () {
                      if (_amountController.text.isNotEmpty) {
                        double miktar = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
                        double maliyet = double.tryParse(_costController.text.replaceAll(',', '.')) ?? 0;
                        
                        // DÜZELTME: Eğer kullanıcı maliyet girmediyse, o anki kurdan almış varsayalım.
                        if (maliyet == 0) {
                          maliyet = _guncelFiyatGetir(_selectedType, _selectedCode);
                        }

                        if (miktar > 0) {
                          setState(() {
                            _assets.add({
                              'type': _selectedType,
                              'code': _selectedCode,
                              'amount': miktar,
                              'cost': maliyet, // Maliyeti kaydet
                              'date': DateTime.now().toIso8601String() // İşlem tarihini kaydet
                            });
                          });
                          _varliklariKaydet();
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Text("VARLIK EKLE", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        });
      },
    );
  }

  Widget _turButonu(String tur, StateSetter setModalState) {
    bool isSelected = _selectedType == tur;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedType = tur;
          if (tur == "Döviz") {
            _selectedCode = "USD";
          } else if (tur == "Altın") {
            _selectedCode = _altinVerileri.isNotEmpty ? _altinVerileri.first['name'] : _altinKodlari[0];
          } else {
            // Kripto
            _selectedCode = _kriptoVerileri.isNotEmpty ? _kriptoVerileri.first['code'] : "BTC";
          }
          _costController.text = _guncelFiyatGetir(_selectedType, _selectedCode).toString();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey),
        ),
        alignment: Alignment.center,
        child: Text(tur, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- VARLIK ÇIKARMA / AZALTMA İŞLEMLERİ ---
  void _varlikAzalt(String type, String code, double amount) {
    double remaining = amount;
    
    // Listeyi baştan sona dönerek (FIFO mantığıyla) düşelim
    for (int i = 0; i < _assets.length; i++) {
      if (remaining <= 0) break;
      
      var asset = _assets[i];
      if (asset['type'] == type && asset['code'] == code) {
        double currentAmount = (asset['amount'] as num).toDouble();
        
        if (currentAmount > remaining) {
          // Kısmi düşüş (Örn: 45 vardı, 20 satıldı, 25 kaldı)
          asset['amount'] = currentAmount - remaining;
          remaining = 0;
        } else {
          // Bu parça tamamen bitti (Örn: 10 vardı, 20 satılacak -> bu 10 gitti, kaldı 10)
          remaining -= currentAmount;
          _assets.removeAt(i);
          i--; // Eleman silindiği için indeksi geri çek
        }
      }
    }
    setState(() {});
    _varliklariKaydet();
  }

  void _varlikCikarDialog() {
    String selectedType = "Döviz";
    String selectedCode = "";
    final TextEditingController amountCtrl = TextEditingController();

    // Mevcut varlık türlerini bul
    var ownedTypes = _assets.map((e) => e['type'] as String).toSet().toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          // Anlık olarak sahip olunanları tekrar hesapla (Hata olmaması için)
          var currentOwnedTypes = _assets.map((e) => e['type'] as String).toSet().toList();
          
          if (currentOwnedTypes.isEmpty) {
             return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Çıkarılacak varlık bulunmamaktadır.")));
          }
          
          // Seçili tür geçerli mi?
          if (!currentOwnedTypes.contains(selectedType)) selectedType = currentOwnedTypes.first;

          // Seçili türe ait kodları bul
          var currentOwnedCodes = _assets.where((e) => e['type'] == selectedType).map((e) => e['code'] as String).toSet().toList();
          if (selectedCode.isEmpty || !currentOwnedCodes.contains(selectedCode)) {
            if (currentOwnedCodes.isNotEmpty) selectedCode = currentOwnedCodes.first;
          }

          // Toplam sahip olunan miktarı hesapla
          double totalOwned = 0;
          for (var asset in _assets) {
            if (asset['type'] == selectedType && asset['code'] == selectedCode) {
              totalOwned += (asset['amount'] as num).toDouble();
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Varlık Çıkar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                const SizedBox(height: 20),
                
                // Tür Seçimi
                DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: currentOwnedTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setModalState(() { selectedType = val!; selectedCode = ""; }),
                ),
                
                // Kod Seçimi
                if (currentOwnedCodes.isNotEmpty)
                  DropdownButton<String>(
                    value: selectedCode,
                    isExpanded: true,
                    items: currentOwnedCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setModalState(() => selectedCode = val!),
                  ),
                
                const SizedBox(height: 10),
                Text("Cüzdandaki Toplam: $totalOwned", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("(Otomatik çıkarma listenin en üstündeki varlıktan başlar. Özel seçim için listedeki karta tıklayınız.)", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 15),

                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Çıkarılacak Miktar", border: OutlineInputBorder(), suffixIcon: Icon(Icons.remove_circle_outline, color: Colors.red)),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: () {
                      double amountToRemove = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
                      if (amountToRemove > 0 && amountToRemove <= totalOwned) {
                        _varlikAzalt(selectedType, selectedCode, amountToRemove);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("VARLIK ÇIKAR", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        });
      },
    );
  }

  // --- İŞLEM GEÇMİŞİ SAYFASI ---
  void _gecmisSayfasiniAc() {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      final theme = Theme.of(context);
      // Listeyi tarihe göre (yeniden eskiye) sıralayalım
      List<Map<String, dynamic>> siraliListe = List.from(_assets);
      siraliListe.sort((a, b) {
        String dateA = a['date'] ?? "";
        String dateB = b['date'] ?? "";
        return dateB.compareTo(dateA); // Yeniden eskiye
      });

      return Scaffold(
        appBar: AppBar(title: const Text("İşlem Geçmişi")),
        body: siraliListe.isEmpty 
          ? Center(child: Text("Henüz işlem geçmişi yok.", style: TextStyle(color: Colors.grey[600])))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: siraliListe.length,
              itemBuilder: (context, index) {
                var asset = siraliListe[index];
                String dateStr = asset['date'] ?? "";
                DateTime? date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
                String formattedDate = date != null ? DateFormat('dd.MM.yyyy HH:mm').format(date) : "Tarih Yok";
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: Icon(Icons.history, color: Colors.grey[700], size: 20),
                    ),
                    title: Text("${asset['code']} Alımı", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(formattedDate),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("+${asset['amount']} ${asset['type'] == 'Altın' ? 'Adet' : ''}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text("Fiyat: ${asset['cost']} ₺", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
      );
    }));
  }

  // --- TEKİL VARLIK İŞLEM MENÜSÜ (Tıklayınca Açılan) ---
  void _tekilVarlikIslemDialog(Map<String, dynamic> asset) {
    final TextEditingController islemMiktarCtrl = TextEditingController();
    double mevcutMiktar = (asset['amount'] as num).toDouble();
    String kod = asset['code'];
    double maliyet = (asset['cost'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$kod İşlemleri", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Alış Maliyeti: $maliyet TL", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              const Text("Bu parçadan ne kadar çıkarmak/azaltmak istiyorsunuz?", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              TextField(
                controller: islemMiktarCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Miktar (Mevcut: $mevcutMiktar)",
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                ),
              ),
              
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("İptal"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      onPressed: () {
                        double miktar = double.tryParse(islemMiktarCtrl.text.replaceAll(',', '.')) ?? 0;
                        if (miktar > 0) {
                          setState(() {
                            if (miktar >= mevcutMiktar) {
                              _assets.remove(asset); // Hepsini satarsa sil
                            } else {
                              asset['amount'] = mevcutMiktar - miktar; // Kısmi düşüş
                            }
                          });
                          _varliklariKaydet();
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("ÇIKAR / DÜŞ"),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset, NumberFormat formatter) {
    double miktar = asset['amount'];
    String kod = asset['code'];
    String type = asset['type'];
    double maliyet = (asset['cost'] != null && asset['cost'] > 0) ? asset['cost'] : 0.0;
    
    double birimFiyat = 0;
    if (type == 'Döviz' && _dovizVerileri.containsKey(kod)) {
      birimFiyat = double.tryParse(_dovizVerileri[kod]['buying'].toString()) ?? 0;
    } else if (type == 'Altın') {
      var altin = _altinVerileri.firstWhere((e) => e['name'] == kod, orElse: () => null);
      if (altin != null) birimFiyat = double.tryParse(altin['buying'].toString()) ?? 0;
    } else if (type == 'Kripto') {
      var coin = _kriptoVerileri.firstWhere((e) => e['code'] == kod, orElse: () => null);
      if (coin != null && _dovizVerileri.containsKey('USD')) {
        double dolarKuru = double.tryParse(_dovizVerileri['USD']['buying'].toString()) ?? 0;
        double dolarFiyati = double.tryParse(coin['price'].toString()) ?? 0;
        birimFiyat = dolarFiyati * dolarKuru;
      }
    }
    double toplamDeger = miktar * birimFiyat;
    
    double hesaplananMaliyet = maliyet > 0 ? maliyet : birimFiyat;
    double toplamMaliyet = miktar * hesaplananMaliyet;
    double fark = toplamDeger - toplamMaliyet;
    double yuzde = toplamMaliyet > 0 ? (fark / toplamMaliyet) * 100 : 0;
    bool assetKar = fark >= 0;

    return Dismissible(
      key: ValueKey(asset['date']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        setState(() {
          _assets.remove(asset);
        });
        _varliklariKaydet();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          onTap: () => _tekilVarlikIslemDialog(asset), // Karta tıklayınca özel işlem menüsü aç
          leading: CircleAvatar(
            backgroundColor: type == 'Altın' ? Colors.amber[100] : (type == 'Kripto' ? Colors.orange[100] : Colors.blue[100]),
            child: Icon(
              type == 'Altın' ? Icons.diamond : (type == 'Kripto' ? Icons.currency_bitcoin : Icons.attach_money),
              color: type == 'Altın' ? Colors.amber[800] : (type == 'Kripto' ? Colors.orange[800] : Colors.blue[800]),
            ),
          ),
          title: Text(kod, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("$miktar ${type == 'Altın' ? 'Adet' : ''} • Alış: ₺${formatter.format(hesaplananMaliyet)}"),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₺${formatter.format(toplamDeger)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(assetKar ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: assetKar ? Colors.green : Colors.red, size: 16),
                Text("%${yuzde.abs().toStringAsFixed(1)} (${assetKar ? '+' : ''}${formatter.format(fark)})", style: TextStyle(fontSize: 11, color: assetKar ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat("#,##0.00", "tr_TR");
    
    bool karVar = _toplamKarZarar >= 0;
    Color karRenk = karVar ? Colors.greenAccent : Colors.redAccent;

    // LİSTE FİLTRELEME VE SIRALAMA
    List<Map<String, dynamic>> displayList = List.from(_assets);

    // 1. Arama Filtresi
    if (_searchController.text.isNotEmpty) {
      displayList = displayList.where((asset) {
        return asset['code'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
      }).toList();
    }

    // 2. Sıralama (Kod'a göre gruplama - Tüm Dolarlar alt alta)
    if (_isSortedByCode) {
      displayList.sort((a, b) => a['code'].toString().compareTo(b['code'].toString()));
    }

    // DÜZELTME: Veriler yüklenmeden sayfayı gösterme (0 TL ve %100 Zarar sorununu çözer)
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Varlıklarım")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.primaryColor),
              const SizedBox(height: 15),
              const Text("Cüzdanınız güncelleniyor...", style: TextStyle(color: Colors.grey, fontSize: 14))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Varlık Ara (USD, Gram...)",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey)
              ),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              onChanged: (v) => setState((){}),
            )
          : const Text("Varlıklarım"),
        actions: [
          // SIRALAMA BUTONU
          Showcase(
            key: _sortKey,
            title: 'Sırala',
            description: 'Varlıklarınızı isme göre gruplayın.',
            child: IconButton(
              icon: Icon(_isSortedByCode ? Icons.sort_by_alpha : Icons.sort, color: _isSortedByCode ? theme.primaryColor : null),
              tooltip: "Grupla / Sırala",
              onPressed: () {
                setState(() {
                  _isSortedByCode = !_isSortedByCode;
                });
              },
            ),
          ),
          // ARAMA BUTONU
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          Showcase(
            key: _historyKey,
            title: 'Geçmiş',
            description: 'Alım-satım geçmişinizi inceleyin.',
            child: IconButton(icon: const Icon(Icons.history), onPressed: _gecmisSayfasiniAc, tooltip: "İşlem Geçmişi")
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _piyasaVerileriniCek)
        ],
      ),
      body: Column(
        children: [
          // TOPLAM VARLIK KARTI
          Showcase(
            key: _totalCardKey,
            title: 'Varlık Özeti',
            description: 'Toplam servetinizi ve kâr/zarar durumunuzu buradan takip edin.',
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))]
              ),
              child: Column(
                children: [
                  const Text("Toplam Servetim", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(
                    "₺${formatter.format(_toplamVarlikTL)}",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "${karVar ? '+' : ''}₺${formatter.format(_toplamKarZarar)} (${karVar ? 'Kâr' : 'Zarar'})",
                      style: TextStyle(color: karRenk, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),
          ),

          // VARLIK LİSTESİ
          Expanded(
            child: displayList.isEmpty
                ? Center(child: Text(_assets.isEmpty ? "Henüz varlık eklemediniz." : "Sonuç bulunamadı.", style: TextStyle(color: Colors.grey[600])))
                : (_isSearching || _isSortedByCode)
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) => _buildAssetCard(displayList[index], formatter),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _assets.length,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) => _buildAssetCard(_assets[index], formatter),
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Showcase(
              key: _removeBtnKey,
              title: 'Varlık Çıkar',
              description: 'Buradan varlıklarınızı portföyden çıkarabilir veya azaltabilirsiniz.',
              child: FloatingActionButton.extended(
                onPressed: _varlikCikarDialog,
                label: const Text("Varlık Çıkar"),
                icon: const Icon(Icons.remove),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                heroTag: "btnCikar",
              ),
            ),
            Showcase(
              key: _addBtnKey,
              title: 'Varlık Ekle',
              description: 'Portföyünüze yeni döviz, altın veya kripto ekleyin.',
              child: FloatingActionButton.extended(
                onPressed: _yeniVarlikEkleDialog,
                label: const Text("Varlık Ekle"),
                icon: const Icon(Icons.add),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                heroTag: "btnEkle",
              ),
            ),
          ],
        ),
      ),
    );
  }
}