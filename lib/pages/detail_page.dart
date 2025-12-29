import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:intl/intl.dart'; // Tarih formatı için eklendi
import '../service/api_service.dart';

class DetailPage extends StatefulWidget {
  final String currencyCode; // Örn: USD
  final String currencyName; // Örn: Amerikan Doları
  final bool isCrypto;       // Kripto mu?

  const DetailPage({super.key, required this.currencyCode, required this.currencyName, this.isCrypto = false});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<FlSpot> _spots = [];
  List<String> _dates = []; // Tarihleri tutmak için yeni liste
  double _minY = 0;
  double _maxY = 0;
  int _selectedDays = 30; 

  @override
  void initState() {
    super.initState();
    _gecmisVeriyiCek();
  }

  Future<void> _gecmisVeriyiCek() async {
    setState(() => _isLoading = true);
    try {
      List<FlSpot> tempSpots = [];
      List<String> tempDates = [];

      if (widget.isCrypto) {
        // --- KRİPTO VERİSİ (Binance) ---
        var data = await _apiService.getCryptoHistory(widget.currencyCode, widget.currencyName, _selectedDays);
        // Binance formatı: [[timestamp, open, high, low, close, ...], ...]
        for (int i = 0; i < data.length; i++) {
          var mum = data[i];
          int timestamp = mum[0]; // Milisaniye cinsinden zaman
          double closePrice = double.tryParse(mum[4].toString()) ?? 0.0;
          
          DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          String dateStr = DateFormat('yyyy-MM-dd').format(date);

          tempSpots.add(FlSpot(i.toDouble(), closePrice));
          tempDates.add(dateStr);
        }
      } else {
        // --- DÖVİZ VERİSİ (Frankfurter) ---
        var data = await _apiService.getHistoryDocs(widget.currencyCode, _selectedDays);
        if (data.containsKey('rates')) {
          Map<String, dynamic> rates = data['rates'];
          double index = 0;
          
          // Tarihleri sıralayalım
          var sortedKeys = rates.keys.toList()..sort();

          for (var date in sortedKeys) {
            var valueMap = rates[date];
            if (valueMap is Map && valueMap.containsKey('TRY')) {
              double rate = (valueMap['TRY'] as num).toDouble();
              tempSpots.add(FlSpot(index, rate));
              tempDates.add(date);
              index++;
            }
          }
        }
      }

      if (tempSpots.isNotEmpty) {
        // Min ve Max değerleri grafiğin sınırlarını belirlemek için buluyoruz
        double minVal = tempSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
        double maxVal = tempSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
        
        // Grafiğin alt ve üstünde biraz boşluk bırakalım
        _minY = minVal * 0.99; 
        _maxY = maxVal * 1.01;

        setState(() { 
          _spots = tempSpots; 
          _dates = tempDates; 
          _isLoading = false; 
        });
      } else {
        setState(() => _isLoading = false); // Veri yoksa yüklemeyi bitir
      }

    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _zamanAraliginiDegistir(int gun) {
    if (_selectedDays == gun) return;
    setState(() { _selectedDays = gun; });
    _gecmisVeriyiCek();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDarkMode ? Colors.white10 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text(widget.currencyName, style: TextStyle(color: textColor)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.center, 
               children: [
                 Text("${widget.currencyCode} / ${widget.isCrypto ? 'USD' : 'TRY'}", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold))
               ]
             ),
             const Text("Değişim Grafiği", style: TextStyle(color: Colors.grey)),
             const SizedBox(height: 25),
             Container(
               padding: const EdgeInsets.all(5),
               decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor)),
               child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_zamanButonu("1H", 7), _zamanButonu("1A", 30), _zamanButonu("3A", 90), _zamanButonu("1Y", 365)]),
             ),
             const SizedBox(height: 30),
            Expanded(
              child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                : _spots.isEmpty 
                  ? Center(child: Text("Bu birim için grafik verisi bulunamadı.", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)))
                  : LineChart(LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: textColor.withValues(alpha: 0.1), strokeWidth: 1)),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        // SOL EKSEN (FİYATLAR)
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45, // Yazı için ayrılan alan
                            getTitlesWidget: (value, meta) {
                              if (value == _minY || value == _maxY) return const SizedBox(); // En alt ve en üstü yazma (çakışmasın)
                              return Text(
                                value.toStringAsFixed(widget.isCrypto ? (value < 1 ? 4 : 2) : 2), // Kripto küçükse 4 hane göster
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              );
                            },
                          ),
                        ),
                        // ALT EKSEN (TARİHLER)
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: _spots.length > 5 ? _spots.length / 5 : 1, // Ekrana sığması için aralık belirle
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < _dates.length) {
                                DateTime date = DateTime.parse(_dates[index]);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(DateFormat('d MMM', 'tr').format(date), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: _minY, maxY: _maxY,
                      lineBarsData: [LineChartBarData(spots: _spots, isCurved: true, color: const Color(0xFF00C853), barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFF00C853).withValues(alpha: 0.3), const Color(0xFF00C853).withValues(alpha: 0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))]
                    )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zamanButonu(String yazi, int gun) {
    bool isSelected = _selectedDays == gun;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _zamanAraliginiDegistir(gun),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF00C853) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(yazi, style: TextStyle(color: isSelected ? Colors.black : (isDarkMode ? Colors.grey : Colors.grey[700]), fontWeight: FontWeight.bold)),
      ),
    );
  }
}