import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatı için eklendi
import '../service/api_service.dart';
import '../service/storage_service.dart';
import 'package:showcaseview/showcaseview.dart'; // Tanıtım için

class GoldPage extends StatefulWidget {
  const GoldPage({super.key});

  @override
  State<GoldPage> createState() => _GoldPageState();
}

class _GoldPageState extends State<GoldPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  static const String _storageKey = 'altin_takip_listesi';
  static const String _prefGoldName = 'gold_name';
  static const String _prefGoldAmount = 'gold_amount';
  List<dynamic> _altinListesi = []; // API'den gelen TÜM altınlar
  bool _isLoading = true;
  
  // Başlangıçta Gösterilecek Popüler Altınlar
  List<String> _aktifAltinlar = ["Gram Altın", "Çeyrek Altın", "Yarım Altın", "Tam Altın", "Ata Altın"];

  // Altın Çevirici Değişkenleri
  String? _secilenAltin; 
  double _adet = 1.0;
  double _bozdurma = 0;
  double _alma = 0;
  final TextEditingController _controller = TextEditingController(text: "1");
  String _sonGuncelleme = ""; // Son güncelleme zamanını tutacak değişken
  
  // Tanıtım Anahtarları
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _calculatorKey = GlobalKey();
  final GlobalKey _editKey = GlobalKey();
  final GlobalKey _refreshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _verileriYukle();
    _verileriCek();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tanitimiBaslat());
  }

  void _tanitimiBaslat() async {
    String? isShown = await _storageService.veriGetir('tutorial_shown_gold_v2');
    if (isShown == null) {
      if (!mounted) return;
      ShowCaseWidget.of(context).startShowCase([_listKey, _calculatorKey, _editKey, _refreshKey]);
      _storageService.veriKaydet('tutorial_shown_gold_v2', 'true');
    }
  }

  Future<void> _verileriYukle() async {
    List<String>? kayitliListe = await _storageService.listeyiGetir(_storageKey);
    if (kayitliListe != null) {
      setState(() {
        _aktifAltinlar = kayitliListe;
      });
    }
    
    // Kayıtlı miktarı yükle
    String? savedAmount = await _storageService.veriGetir(_prefGoldAmount);
    if (savedAmount != null) {
      setState(() {
        _controller.text = savedAmount;
        _adet = double.tryParse(savedAmount) ?? 1.0;
      });
    }
  }

  Future<void> _verileriCek() async {
    try {
      var data = await _apiService.getCollectAltin();
      setState(() {
        _altinListesi = data;
        _sonGuncelleme = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()); // Şu anki zamanı kaydet
        
        // Veri gelince hesaplayıcı için ilkini seç
        if (_altinListesi.isNotEmpty) {
          // Eğer listede Gram Altın varsa onu seç, yoksa ilkini seç
          _storageService.veriGetir(_prefGoldName).then((savedName) {
             if (mounted) {
               setState(() {
                 bool savedExists = savedName != null && _altinListesi.any((e) => e['name'] == savedName);
                 var gramVarMi = _altinListesi.any((e) => e['name'] == "Gram Altın");
                 _secilenAltin = savedExists ? savedName : (gramVarMi ? "Gram Altın" : _altinListesi[0]['name']);
                 _hesapla();
               });
             }
          });
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _hesapla() {
    if (_altinListesi.isEmpty || _secilenAltin == null) return;
    
    var altin = _altinListesi.firstWhere(
      (a) => a['name'] == _secilenAltin, 
      orElse: () => null
    );

    if (altin != null) {
      double alis = double.tryParse(altin['buying'].toString()) ?? 0;
      double satis = double.tryParse(altin['selling'].toString()) ?? 0;
      
      setState(() {
        _bozdurma = _adet * alis;
        _alma = _adet * satis;
      });
    }
  }

  // --- LİSTE DÜZENLEME EKRANI (ALTINLAR İÇİN) ---
  void _listeDuzenlePenceresiAc() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.8, 
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
                  Text("Altın Listesi", style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                  const SizedBox(height: 5),
                  Text("Ana ekranda görmek istediklerinizi seçin", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 15),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _altinListesi.length,
                      itemBuilder: (context, index) {
                        var altin = _altinListesi[index];
                        String isim = altin['name'];
                        bool seciliMi = _aktifAltinlar.contains(isim);

                        return CheckboxListTile(
                          activeColor: Colors.amber[600],
                          checkColor: Colors.black,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Icon(Icons.diamond, color: Colors.amber[600], size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(isim, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          value: seciliMi,
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                _aktifAltinlar.add(isim);
                              } else {
                                _aktifAltinlar.remove(isim);
                              }
                              _storageService.listeyiKaydet(_storageKey, _aktifAltinlar);
                            });
                            setState(() {}); // Ana ekranı güncelle
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[600], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("KAYDET VE KAPAT", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Altın Piyasası", style: theme.textTheme.titleLarge),
            if (_sonGuncelleme.isNotEmpty)
              Text("Son Güncelleme: $_sonGuncelleme", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          // DÜZENLEME BUTONU
          Showcase(
            key: _editKey,
            title: 'Listeyi Düzenle',
            description: 'Ana ekranda görmek istediğiniz altın türlerini buradan seçebilirsiniz.',
            child: IconButton(
              icon: Icon(Icons.edit_note, color: Colors.amber[600], size: 30),
              onPressed: _listeDuzenlePenceresiAc,
            ),
          ),
          Showcase(
            key: _refreshKey,
            title: 'Yenile',
            description: 'Fiyatları güncellemek için tıklayın.',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() { _isLoading = true; });
                _verileriCek();
              },
            ),
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.amber[600]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                
                // YATAY LİSTE (Sadece Seçilenleri Gösterir)
                Showcase(
                  key: _listKey,
                  title: 'Hızlı Takip',
                  description: 'Seçtiğiniz altınların fiyatlarını burada yan yana görebilirsiniz.',
                  child: SizedBox(
                    height: 160, 
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, 
                      itemCount: _aktifAltinlar.length, 
                      itemBuilder: (context, index) {
                        String isim = _aktifAltinlar[index];
                        // Listeden bu isme sahip veriyi bul
                        var veri = _altinListesi.firstWhere((e) => e['name'] == isim, orElse: () => null);
                        
                        if (veri == null) return const SizedBox(); // Veri yoksa boş geç

                        double degisim = double.tryParse(veri['rate'].toString()) ?? 0.0;
                        
                        return _altinKarti(
                          veri['name'], 
                          double.tryParse(veri['buying'].toString())??0, 
                          double.tryParse(veri['selling'].toString())??0, 
                          degisim
                        );
                      }
                    )
                  ),
                ),
                
                const SizedBox(height: 35), 
                Text("Altın Hesaplayıcı", style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)), 
                const SizedBox(height: 15),
                
                // HESAPLAMA KUTUSU
                Showcase(
                  key: _calculatorKey,
                  title: 'Hesaplayıcı',
                  description: 'Elinizdeki altının alış ve satış değerini anlık hesaplayın.',
                  child: _buildAltinCevirici(),
                ),
                
                const SizedBox(height: 40),
                
                // --- İSTEDİĞİN UYARI NOTU ---
                Center(
                  child: Column(
                    children: [
                      Text("Veri Kaynağı: Kapalıçarşı (Serbest Piyasa)", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: theme.brightness == Brightness.dark ? 0.05 : 0.15),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: const Text(
                          "* Fiyatlar piyasa ortalamasıdır. Kuyumcular veya bankalar arasında komisyon ve makas farklarından dolayı ufak fiyat farklılıkları olabilir.",
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ),
    );
  }

  Widget _altinKarti(String isim, double alis, double satis, double degisim) {
    bool artiyor = degisim >= 0;
    final theme = Theme.of(context);
    Color renk = degisim == 0 ? Colors.grey : (artiyor ? const Color(0xFF00C853) : const Color(0xFFFF3D00));
    IconData icon = degisim == 0 ? Icons.remove : (artiyor ? Icons.arrow_upward : Icons.arrow_downward);

    return Container(
        width: 160, 
        margin: const EdgeInsets.only(right: 15), 
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(
          color: theme.cardColor, 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: Colors.amber.withValues(alpha: 0.2))
        ), 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Row(
                  children: [
                    Icon(Icons.diamond, color: Colors.amber[600], size: 22), 
                    const SizedBox(width: 8), 
                    SizedBox(
                      width: 80, 
                      child: Text(isim.split(' ')[0], style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                    )
                  ]
                ), 
                Icon(icon, color: renk, size: 18)
              ]
            ),
            Divider(color: theme.dividerColor),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Alış", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)), Text(alis.toStringAsFixed(2), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Satış", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)), Text(satis.toStringAsFixed(2), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))]),
            Row(children: [Text("%${degisim.abs().toStringAsFixed(2)}", style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold))])
          ]
        )
    );
  }

  Widget _buildAltinCevirici() {
    final theme = Theme.of(context);
    if (_altinListesi.isEmpty || _secilenAltin == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(25), 
      decoration: BoxDecoration(
        color: theme.cardColor, 
        borderRadius: BorderRadius.circular(30), 
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2))
      ), 
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller, 
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(border: InputBorder.none, hintText: "Adet"),
                  onChanged: (v){
                    _adet=double.tryParse(v)??0;
                    _hesapla();
                    _storageService.veriKaydet(_prefGoldAmount, v);
                  }
                )
              ), 
              
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _secilenAltin, 
                  dropdownColor: theme.cardColor, 
                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.amber[600]),
                  items: _altinListesi.map((e) {
                    return DropdownMenuItem<String>(
                      value: e['name'].toString(), 
                      child: Row(
                        children: [
                          Icon(Icons.diamond, color: Colors.amber[600], size: 20),
                          const SizedBox(width: 8),
                          Text(e['name'], style: theme.textTheme.bodyLarge)
                        ],
                      )
                    );
                  }).toList(),
                  onChanged: (v){
                    setState((){_secilenAltin=v!;_hesapla();});
                    _storageService.veriKaydet(_prefGoldName, v!);
                  }
                )
              )
            ]
          ),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _sonucKarti("Bozdurursan", _bozdurma, Colors.redAccent)),
              const SizedBox(width: 15),
              Expanded(child: _sonucKarti("Alırsan", _alma, Colors.greenAccent)),
            ]
          )
        ]
      )
    );
  }

  Widget _sonucKarti(String baslik, double deger, Color renk) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15), 
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(15)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(baslik, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)), 
          Text("${deger.toStringAsFixed(2)} ₺", style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold))
        ]
      )
    );
  }
}