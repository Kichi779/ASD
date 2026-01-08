import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Hive eklendi
import 'package:url_launcher/url_launcher.dart';

void main() async {
  // CRASH ENGELLEME: Native bağlayıcılar ve veritabanı başlatılıyor
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter(); // Hive kurulumu
    await Hive.openBox('settings'); // Ayarlar kutusunu aç
  } catch (e) {
    log("HIVE INITIALIZATION ERROR: $e");
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    log('FLUTTER ERROR', error: details.exception, stackTrace: details.stack);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Uluslararası Alevi Vakfı',
      debugShowCheckedModeBanner: false,
      home: WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isDarkTheme = false;
  bool showSocialButtons = true;
  bool isLoading = true;

  // Hive kutusuna erişim
  final Box settingsBox = Hive.box('settings');
  static const String homeUrl = "https://www.alevi-vakfi.com/";

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    _loadTheme(); // Kayıtlı temayı yükle
    _setupController(); // WebView'ı hazırla
  }

  void _setupController() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => isLoading = true);
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => isLoading = false);
            _injectTheme();
            await _checkCurrentUrl();
          },
          onWebResourceError: (error) {
            log("WEBVIEW ERROR: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(homeUrl));
  }

  void _loadTheme() {
    // Hive üzerinden temayı oku
    setState(() {
      isDarkTheme = settingsBox.get('isDarkTheme', defaultValue: false);
    });
  }

  void _toggleTheme() {
    setState(() {
      isDarkTheme = !isDarkTheme;
      settingsBox.put('isDarkTheme', isDarkTheme); // Hive'a kaydet
    });
    _injectTheme();
  }

  void _injectTheme() {
    final String js = isDarkTheme
        ? """
        (function() {
          if (document.getElementById('dark-style')) return;
          var s = document.createElement('style');
          s.id = 'dark-style';
          s.innerHTML = `
            body { background:#121212 !important; color:#fff !important; }
            * { color:#fff !important; background:#121212 !important; }
            a { color:#bb86fc !important; }
          `;
          document.head.appendChild(s);
        })();
        """
        : """
        (function() {
          var s = document.getElementById('dark-style');
          if (s) s.remove();
        })();
        """;
    controller.runJavaScript(js).catchError((e) => log("JS Inject Error: $e"));
  }

  Future<void> _checkCurrentUrl() async {
    try {
      final currentUrl = await controller.currentUrl();
      if (!mounted) return;
      setState(() {
        showSocialButtons = currentUrl == null || currentUrl == homeUrl || currentUrl.startsWith(homeUrl);
      });
    } catch (e) {
      log("URL Check Error: $e");
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      log("URL Launch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.purple)),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "theme_btn",
            mini: true,
            backgroundColor: Colors.white.withOpacity(0.8),
            child: Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
          const SizedBox(height: 16),
          if (showSocialButtons) ...[
            _SocialButton(
              heroTag: "fb",
              color: const Color(0xFF1877F2),
              icon: Icons.facebook,
              onTap: () => _openUrl("https://www.facebook.com/alevivakfi"),
            ),
            _SocialButton(
              heroTag: "ig",
              color: const Color(0xFFE4405F),
              icon: Icons.camera_alt,
              onTap: () => _openUrl("https://www.instagram.com/alevitischestiftung/"),
            ),
            _SocialButton(
              heroTag: "yt",
              color: Colors.red,
              icon: Icons.play_arrow,
              onTap: () => _openUrl("https://www.youtube.com/@uadevakfi/videos"),
            ),
            _SocialButton(
              heroTag: "x_btn",
              color: Colors.black,
              label: "X",
              onTap: () => _openUrl("https://x.com/UADEVAKFI"),
            ),
            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String? label;
  final VoidCallback onTap;
  final String heroTag;

  const _SocialButton({
    required this.color,
    this.icon,
    this.label,
    required this.onTap,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton(
        heroTag: heroTag,
        mini: true,
        backgroundColor: color,
        onPressed: onTap,
        child: icon != null
            ? Icon(icon, color: Colors.white)
            : Text(
          label ?? '',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }
}