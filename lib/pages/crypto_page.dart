import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/api_service.dart';
import '../service/storage_service.dart';
import 'package:showcaseview/showcaseview.dart'; // Tanıtım için
import 'detail_page.dart'; // Detay sayfası eklendi

class CryptoPage extends StatefulWidget {
  const CryptoPage({super.key});

  @override
  State<CryptoPage> createState() => _CryptoPageState();
}

class _CryptoPageState extends State<CryptoPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  static const String _favKey = 'favorite_coins';

  List<dynamic> _cryptoList = [];
  List<dynamic> _filteredList = [];
  List<String> _favorites = []; // Favori coin kodları (BTC, ETH vs.)

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Tanıtım Anahtarları
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _refreshKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _favorileriYukle();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tanitimiBaslat());
  }

  void _tanitimiBaslat() async {
    String? isShown = await _storageService.veriGetir('tutorial_shown_crypto_v2');
    if (isShown == null) {
      if (!mounted) return;
      ShowCaseWidget.of(context).startShowCase([_searchKey, _refreshKey, _listKey]);
      _storageService.veriKaydet('tutorial_shown_crypto_v2', 'true');
    }
  }

  Future<void> _favorileriYukle() async {
    List<String>? savedFavs = await _storageService.listeyiGetir(_favKey);
    if (savedFavs != null) {
      setState(() {
        _favorites = savedFavs;
      });
    }
    _verileriCek();
  }

  Future<void> _verileriCek() async {
    setState(() => _isLoading = true);
    try {
      var data = await _apiService.getCollectKripto();
      setState(() {
        _cryptoList = data;
        _listeyiSiralaVeFiltrele();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _listeyiSiralaVeFiltrele() {
    // Önce favoriler, sonra diğerleri
    _cryptoList.sort((a, b) {
      bool isAFav = _favorites.contains(a['code']);
      bool isBFav = _favorites.contains(b['code']);
      if (isAFav && !isBFav) return -1; // a favori, b değil -> a öne
      if (!isAFav && isBFav) return 1;  // b favori, a değil -> b öne
      return 0;
    });
    _filtrele(_searchController.text);
  }

  void _filtrele(String query) {
    if (query.isEmpty) {
      setState(() => _filteredList = _cryptoList);
    } else {
      setState(() {
        _filteredList = _cryptoList.where((item) {
          String name = item['name'].toString().toLowerCase();
          String code = item['code'].toString().toLowerCase();
          return name.contains(query.toLowerCase()) || code.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  void _favoriDegistir(String code) {
    setState(() {
      if (_favorites.contains(code)) {
        _favorites.remove(code);
      } else {
        _favorites.add(code);
      }
    });
    _storageService.listeyiKaydet(_favKey, _favorites);
    _listeyiSiralaVeFiltrele(); // Listeyi yeniden düzenle
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat("#,##0.00", "en_US"); // Kripto genelde USD olduğu için en_US formatı

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kripto Piyasası"),
        actions: [
          Showcase(
            key: _refreshKey,
            title: 'Yenile',
            description: 'Kripto fiyatlarını anlık güncelleyin.',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _verileriCek,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // ARAMA KUTUSU
          Showcase(
            key: _searchKey,
            title: 'Coin Ara',
            description: 'Merak ettiğiniz kripto parayı buradan arayıp bulabilirsiniz.',
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Coin Ara (BTC, Ethereum...)",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _filtrele,
              ),
            ),
          ),

          // LİSTE
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : _filteredList.isEmpty
                    ? Center(child: Text("Veri bulunamadı.", style: TextStyle(color: Colors.grey[600])))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredList.length,
                        itemBuilder: (context, index) {
                          var coin = _filteredList[index];
                          double price = double.tryParse(coin['price'].toString()) ?? 0;
                          double change = double.tryParse(coin['changeDay'].toString()) ?? 0;
                          bool artiyor = change >= 0;
                          bool isFav = _favorites.contains(coin['code']);

                          Widget card = Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              onTap: () {
                                // Detay sayfasına git
                                Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(currencyCode: coin['code'], currencyName: coin['name'], isCrypto: true)));
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: InkWell(
                                onTap: () => _favoriDegistir(coin['code']), // İkona tıklayınca favorile
                                borderRadius: BorderRadius.circular(20),
                                child: CircleAvatar(
                                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                  child: Icon(
                                    isFav ? Icons.star : Icons.currency_bitcoin, 
                                    color: isFav ? Colors.amber : Colors.orange
                                  ),
                                ),
                              ),
                              title: Text(coin['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(coin['code'] ?? ""),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("\$${formatter.format(price)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(artiyor ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: artiyor ? Colors.green : Colors.red, size: 20),
                                      Text(
                                        "%${change.abs().toStringAsFixed(2)}",
                                        style: TextStyle(color: artiyor ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (index == 0) {
                            return Showcase(
                              key: _listKey,
                              title: 'Detaylar ve Grafik',
                              description: 'Grafiği incelemek için coinin üzerine tıklayabilirsiniz.',
                              child: card,
                            );
                          }
                          return card;
                        },
                      ),
          ),
        ],
      ),
    );
  }
}