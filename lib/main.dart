import 'package:flutter/material.dart';
import 'dart:convert'; // JSON işlemleri için gerekli
import 'package:flutter/foundation.dart'; // Debug/Release kontrolü için
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart'; // Linkleri açmak için
import 'package:intl/intl.dart'; // Tarih formatı için
import 'package:intl/date_symbol_data_local.dart'; // Türkçe tarih formatı için gerekli
import 'package:showcaseview/showcaseview.dart'; // Tanıtım baloncukları için
import 'pages/home_page.dart';
import 'service/storage_service.dart'; // Kayıt servisi
import 'pages/gold_page.dart'; // Yeni sayfa
import 'pages/calculate_page.dart';
import 'pages/portfolio_page.dart'; // Varlıklarım sayfası
import 'pages/crypto_page.dart'; // Kripto sayfası

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Arka plan bildirimi: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr'); // Tarih formatını Türkçe olarak başlat
  if (!kIsWeb) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();

  // Sayfaların bu fonksiyona erişip tema değiştirmesi için
  static MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<MyAppState>()!;
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system; // Varsayılan: Sistem teması
  ThemeMode get themeMode => _themeMode; // Temayı okumak için getter
  
  // Performans için temaları önbelleğe alıyoruz
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  ThemeData get lightTheme {
    _lightTheme ??= ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
        primaryColor: const Color(0xFF6200EE),
        cardColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[100],
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF6200EE),
          unselectedItemColor: Colors.grey,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      );
    return _lightTheme!;
  }

  ThemeData get darkTheme {
    _darkTheme ??= ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFBB86FC),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFFBB86FC),
          unselectedItemColor: Colors.grey,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      );
    return _darkTheme!;
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kur Cepte',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode, // Dinamik tema
      home: ShowCaseWidget(
        builder: (builderContext) => const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  
  // Bildirim listesini statik yapıyoruz ki HomePage'den erişilebilsin
  static final List<RemoteMessage> notifications = [];
  // Okunan bildirimlerin ID'lerini tutacak Set (Küme)
  static final Set<String> readNotificationIds = {};

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final StorageService _storageService = StorageService();
  static const String _notificationsKey = 'saved_notifications';
  static const String _readNotificationsKey = 'read_notifications';
  final GlobalKey _bottomNavKey = GlobalKey(); // Tanıtım için anahtar
  
  final List<Widget> _pages = [
    const HomePage(),      // 0: Döviz
    const GoldPage(),      // 1: Altın (YENİ)
    const CryptoPage(),    // 2: Kripto (YENİ)
    const CalculatePage(), // 2: Faiz
    const PortfolioPage(), // 3: Varlıklarım (YENİ)
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications(); // Uygulama açılınca eski bildirimleri yükle
    _loadReadStatus();    // Okunma durumlarını yükle
    _setupFirebaseMessaging();
    _setupInteractedMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tanitimiBaslat());
  }

  void _tanitimiBaslat() async {
    // Eğer daha önce gösterilmediyse tanıtımı başlat
    String? isShown = await _storageService.veriGetir('tutorial_shown_main');
    if (isShown == null) {
      if (!mounted) return;
      ShowCaseWidget.of(context).startShowCase([_bottomNavKey]);
      _storageService.veriKaydet('tutorial_shown_main', 'true');
    }
  }

  // Kayıtlı bildirimleri yükleyen fonksiyon
  Future<void> _loadNotifications() async {
    List<String>? savedList = await _storageService.listeyiGetir(_notificationsKey);
    if (savedList != null) {
      setState(() {
        MainScreen.notifications.clear(); // Yüklemeden önce temizle ki duble kayıt olmasın
        // Mevcut listenin sonuna ekle (varsa yeni gelenler en üstte kalsın)
        for (String jsonStr in savedList) {
          try {
            Map<String, dynamic> map = jsonDecode(jsonStr);
            MainScreen.notifications.add(RemoteMessage.fromMap(map));
          } catch (e) {
            debugPrint("Bildirim yükleme hatası: $e");
          }
        }
      });
    }
  }

  // Okunma durumlarını hafızadan yükleyen fonksiyon
  Future<void> _loadReadStatus() async {
    List<String>? savedList = await _storageService.listeyiGetir(_readNotificationsKey);
    if (savedList != null) {
      setState(() {
        MainScreen.readNotificationIds.addAll(savedList);
      });
    }
  }

  // Bildirimleri kaydeden fonksiyon
  Future<void> _saveNotifications() async {
    // LİMİT KOYMA: Listenin sonsuza kadar uzamasını engellemek için
    // sadece en son gelen 50 bildirimi tutalım, eskileri silelim.
    if (MainScreen.notifications.length > 50) {
      MainScreen.notifications.removeRange(50, MainScreen.notifications.length);
    }

    List<String> jsonList = MainScreen.notifications.map((msg) {
      return jsonEncode(msg.toMap());
    }).toList();
    await _storageService.listeyiKaydet(_notificationsKey, jsonList);
  }

  void _setupFirebaseMessaging() async {
    if (kIsWeb) return; // Web'de Firebase yapılandırması yoksa hata vermemesi için
    debugPrint("🚀 FCM Başlatılıyor..."); 
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Bildirim izni iste (Özellikle Android 13+ ve iOS için)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    debugPrint("🔔 İzin Durumu: ${settings.authorizationStatus}");

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Cihazın Token'ını al ve konsola yazdır (Test için bunu kopyalayacağız)
      try {
        String? token = await messaging.getToken();
        debugPrint("🔥 FCM Token: $token");
        
        // Geliştirme ve Canlı ortamı ayırmak için konu (topic) ayrımı yapıyoruz
        if (kDebugMode) {
          await messaging.subscribeToTopic('genel_test'); // Sadece geliştiricilere (size) gider
        } else {
          await messaging.subscribeToTopic('genel'); // Gerçek kullanıcılara gider
        }

      } catch (e) {
        debugPrint("❌ Token Hatası: $e");
      }

      // 3. Uygulama AÇIKKEN gelen bildirimleri dinle ve göster
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (mounted && message.notification != null) {
          // Bildirimi listeye ekle (En üste)
          setState(() {
            MainScreen.notifications.insert(0, message);
          });
          _saveNotifications(); // Yeni bildirim gelince kaydet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${message.notification!.title}: ${message.notification!.body}"),
              backgroundColor: Theme.of(context).primaryColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    } else {
      debugPrint("⚠️ Kullanıcı bildirim izni vermedi.");
    }
  }

  // Bildirime tıklandığında çalışacak fonksiyon
  Future<void> _setupInteractedMessage() async {
    if (kIsWeb) return;
    // 1. Uygulama TAMAMEN KAPALIYKEN (Terminated) bildirime tıklandıysa
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 2. Uygulama ARKA PLANDAYKEN (Background) bildirime tıklandıysa
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    // EKSİK OLAN KISIM: Bildirime tıklandığında da mesajı listeye ekle
    setState(() {
      MainScreen.notifications.insert(0, message);
    });
    _saveNotifications(); // Bildirime tıklanınca da listeye ekleyip kaydet

    // Eğer bildirim verisinde "sayfa" anahtarı varsa ve değeri "altin" ise
    if (message.data['sayfa'] == 'altin') {
      setState(() {
        _selectedIndex = 1; // Altın sekmesine (Index 1) geçiş yap
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Showcase(
        key: _bottomNavKey,
        description: 'Sayfalar arasında buradan geçiş yapabilirsiniz.',
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.currency_exchange), label: 'Döviz'),
            BottomNavigationBarItem(icon: Icon(Icons.diamond), label: 'Altın'),
            BottomNavigationBarItem(icon: Icon(Icons.currency_bitcoin), label: 'Kripto'),
            BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Faiz'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Varlıklarım'),
          ],
        ),
      ),
    );
  }
}

// --- YENİ BİLDİRİM GEÇMİŞİ SAYFASI ---
class NotificationsPage extends StatefulWidget {
  final List<RemoteMessage> messages;

  const NotificationsPage({super.key, required this.messages});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bildirimler")),
      body: widget.messages.isEmpty
          ? const Center(child: Text("Henüz bildirim yok."))
          : ListView.builder(
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                final notification = message.notification;
                // Bu mesajın ID'si okunanlar listesinde var mı?
                final isRead = MainScreen.readNotificationIds.contains(message.messageId);

                return Card(
                  elevation: isRead ? 0 : 2, // Okunanlar düzleşsin
                  color: isRead ? Theme.of(context).cardColor.withValues(alpha: 0.6) : Theme.of(context).cardColor, // Okunanlar soluklaşsın
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications_active, 
                      color: isRead ? Colors.grey : Colors.amber // Okunan gri, okunmayan sarı
                    ),
                    title: Text(
                      notification?.title ?? "Başlıksız",
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold, // Okunmayan kalın
                        color: isRead ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(notification?.body ?? "İçerik yok", maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () async {
                      // Tıklandığında okundu olarak işaretle ve kaydet
                      if (!isRead && message.messageId != null) {
                        setState(() {
                          MainScreen.readNotificationIds.add(message.messageId!);
                        });
                        StorageService().listeyiKaydet('read_notifications', MainScreen.readNotificationIds.toList());
                      }
                      // Tıklandığında detay sayfasına git
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationDetailPage(message: message)));
                      setState(() {}); // Geri dönünce sayfayı yenile
                    },
                  ),
                );
              },
            ),
    );
  }
}

// --- YENİ BİLDİRİM DETAY SAYFASI (Bundle Tarzı) ---
class NotificationDetailPage extends StatefulWidget {
  final RemoteMessage message;

  const NotificationDetailPage({super.key, required this.message});

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  String? _link;
  String _displayBody = "";

  @override
  void initState() {
    super.initState();
    _prepareContent();
  }

  void _prepareContent() {
    final notification = widget.message.notification;
    final data = widget.message.data;
    
    String? link = data['link'];
    _displayBody = notification?.body ?? "İçerik yok";

    // Eğer Custom Data'da link yoksa, metnin içinden bulup çıkaralım
    if (link == null && notification?.body != null) {
      final RegExp urlRegExp = RegExp(
        r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)'
      );
      final match = urlRegExp.firstMatch(notification!.body!);
      if (match != null) {
        link = match.group(0);
        // Linki metinden siliyoruz ki detay sayfasında temiz gözüksün
        _displayBody = notification!.body!.replaceFirst(link!, '').trim();
      }
    }

    if (link != null) {
      _link = link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bildirim Detayı")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Text(widget.message.notification?.title ?? "Başlıksız", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Tarih
            if (widget.message.sentTime != null)
              Text(DateFormat('dd.MM.yyyy HH:mm').format(widget.message.sentTime!), style: const TextStyle(color: Colors.grey)),
            
            const Divider(height: 30),
            
            // İçerik Metni
            Text(_displayBody, style: Theme.of(context).textTheme.bodyLarge),

            const SizedBox(height: 30),
            
            // Link Butonu (Varsa Göster - Güvenli Tarayıcıda Aç)
            if (_link != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse(_link!);
                    // LaunchMode.inAppWebView: Uygulama içinde güvenli tarayıcı (Chrome Custom Tabs) açar
                    await launchUrl(url, mode: LaunchMode.inAppWebView);
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text("Haberi Kaynağında Oku"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}