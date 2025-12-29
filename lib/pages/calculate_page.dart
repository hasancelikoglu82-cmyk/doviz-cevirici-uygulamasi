import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart'; // Tanıtım için
import '../service/storage_service.dart'; // Kayıt kontrolü için

class CalculatePage extends StatefulWidget {
  const CalculatePage({super.key});

  @override
  State<CalculatePage> createState() => _CalculatePageState();
}

class _CalculatePageState extends State<CalculatePage> {
  final StorageService _storageService = StorageService();
  static const String _prefAnaPara = 'calc_anapara';
  static const String _prefFaiz = 'calc_faiz';
  static const String _prefGun = 'calc_gun';

  // Varsayılan Değerler
  double _anaPara = 100000;
  double _faizOrani = 45.0; 
  int _gunSayisi = 32;
  
  double _netKazanc = 0;
  double _toplamPara = 0;
  double _uygulananStopaj = 17.5; // Varsayılan en yüksek stopaj

  final TextEditingController _paraController = TextEditingController(text: "100000");
  final TextEditingController _faizController = TextEditingController(text: "45");

  // Tanıtım Anahtarları
  final GlobalKey _inputKey = GlobalKey();
  final GlobalKey _daysKey = GlobalKey();
  final GlobalKey _resultKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tanitimiBaslat());
  }

  Future<void> _loadPreferences() async {
    String? savedAnaPara = await _storageService.veriGetir(_prefAnaPara);
    String? savedFaiz = await _storageService.veriGetir(_prefFaiz);
    String? savedGun = await _storageService.veriGetir(_prefGun);

    if (mounted) {
      setState(() {
        if (savedAnaPara != null) {
          _paraController.text = savedAnaPara;
          _anaPara = double.tryParse(savedAnaPara) ?? 100000;
        }
        if (savedFaiz != null) {
          _faizController.text = savedFaiz;
          _faizOrani = double.tryParse(savedFaiz) ?? 45.0;
        }
        if (savedGun != null) {
          _gunSayisi = int.tryParse(savedGun) ?? 32;
        }
      });
      _hesapla();
    }
  }

  void _tanitimiBaslat() async {
    String? isShown = await _storageService.veriGetir('tutorial_shown_calculate_v2'); // v2 yaptık
    if (isShown == null) {
      if (!mounted) return;
      ShowCaseWidget.of(context).startShowCase([_inputKey, _daysKey, _resultKey]);
      _storageService.veriKaydet('tutorial_shown_calculate_v2', 'true');
    }
  }

  void _hesapla() {
    // GÜNCEL MEVZUAT (09.07.2025 sonrası)
    // Kaynak: Resmi Gazete & Kullanıcı Araştırması
    double stopajOrani = 0.0;
    
    if (_gunSayisi <= 180) {
      stopajOrani = 0.175; // 6 aya kadar %17.50
    } else if (_gunSayisi <= 365) {
      stopajOrani = 0.15;  // 1 yıla kadar %15
    } else {
      stopajOrani = 0.10;  // 1 yıldan uzun %10
    }

    // 2. Brüt Kazanç Hesabı: (Anapara * Faiz * Gün) / 36500
    double brutKazanc = (_anaPara * _faizOrani * _gunSayisi) / 36500;
    
    // 3. Vergi Kesintisi
    double kesinti = brutKazanc * stopajOrani;
    
    setState(() {
      _uygulananStopaj = stopajOrani * 100; // Ekrana yazdırmak için (Örn: 17.5)
      _netKazanc = brutKazanc - kesinti;
      _toplamPara = _anaPara + _netKazanc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Faiz Hesapla", style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- GİRİŞ KUTULARI ---
            Showcase(
              key: _inputKey,
              title: 'Veri Girişi',
              description: 'Ana paranızı ve bankanın faiz oranını buradan girin.',
              child: _buildInputCard(),
            ),
            
            const SizedBox(height: 30),
            
            // --- GÜN SEÇİMİ ---
            const Text("Vade Süresi", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Showcase(
              key: _daysKey,
              title: 'Vade Seçimi',
              description: 'Paranızın ne kadar süre faizde kalacağını seçin. Stopaj oranı otomatik ayarlanır.',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _gunButonu(32),  // Kısa vade (%17.5)
                    _gunButonu(46),
                    _gunButonu(92),
                    _gunButonu(181), // Orta vade (%15)
                    _gunButonu(366), // Uzun vade (%10)
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- SONUÇ KARTI ---
            Showcase(
              key: _resultKey,
              title: 'Net Kazanç',
              description: 'Vergi (stopaj) düşüldükten sonra elinize geçecek net tutar.',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4B45B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Text("Net Kazanç ($_gunSayisi Gün)", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text("${_netKazanc.toStringAsFixed(2)} ₺", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    
                    const Divider(color: Colors.white24, height: 30),
                    
                    // Detay Satırları
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Vade Sonu Toplam:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        Text("${_toplamPara.toStringAsFixed(2)} ₺", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Uygulanan Stopaj:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text("%$_uygulananStopaj", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            // YASAL UYARI VE BİLGİLENDİRME
            Text(
              "* 09.07.2025 sonrası güncel mevzuat uygulanmıştır:\n(6 aya kadar: %17.5 | 1 yıla kadar: %15 | 1 yıldan uzun: %10)",
              style: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _inputSatiri("Anapara (TL)", _paraController, (val) {
            _anaPara = double.tryParse(val) ?? 0;
            _hesapla();
            _storageService.veriKaydet(_prefAnaPara, val);
          }),
          Divider(color: theme.dividerColor, height: 30),
          _inputSatiri("Faiz Oranı (%)", _faizController, (val) {
            _faizOrani = double.tryParse(val) ?? 0;
            _hesapla();
            _storageService.veriKaydet(_prefFaiz, val);
          }),
        ],
      ),
    );
  }

  Widget _inputSatiri(String baslik, TextEditingController controller, Function(String) onChanged) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Text(baslik, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(width: 15),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.right,
            decoration: InputDecoration(border: InputBorder.none, hintText: "0", hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _gunButonu(int gun) {
    bool secili = _gunSayisi == gun;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() { _gunSayisi = gun; });
        _hesapla();
        _storageService.veriKaydet(_prefGun, gun.toString());
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: secili ? const Color(0xFFBB86FC) : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[300]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text("$gun Gün", style: TextStyle(color: secili ? Colors.black : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.bold)),
      ),
    );
  }
}