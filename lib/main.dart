import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('CRASH: $error');
    debugPrintStack(stackTrace: stack);
  });
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
  late final WebViewController _controller;

  bool isDarkTheme = false;
  bool isLoading = true;
  bool showSocialButtons = true;

  static const String homeUrl = 'https://www.alevi-vakfi.com/';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => isLoading = true);
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => isLoading = false);
            await _injectTheme();
            await _checkCurrentUrl();
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(homeUrl));
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkTheme = !isDarkTheme;
    await prefs.setBool('isDarkTheme', isDarkTheme);
    if (mounted) setState(() {});
    await _injectTheme();
  }

  Future<void> _injectTheme() async {
    try {
      final js = isDarkTheme
          ? """
            (function() {
              if (document.getElementById('dark-style')) return;
              var s = document.createElement('style');
              s.id = 'dark-style';
              s.innerHTML = `
                body { background:#121212 !important; color:#fff !important; }
                * { background:#121212 !important; color:#fff !important; }
                a { color:#bb86fc !important; }
                input, textarea, select { background:#333 !important; color:#fff !important; }
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

      await _controller.runJavaScript(js);
    } catch (e) {
      debugPrint('JS inject error: $e');
    }
  }

  Future<void> _checkCurrentUrl() async {
    try {
      final url = await _controller.currentUrl();
      if (!mounted || url == null) return;

      setState(() {
        showSocialButtons = url.startsWith(homeUrl);
      });
    } catch (_) {}
  }

  static Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 16),
                  Text(
                    'Yükleniyor...',
                    style: TextStyle(color: Colors.purple, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white.withOpacity(0.85),
            onPressed: _toggleTheme,
            child: Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode),
          ),
          const SizedBox(height: 16),
          if (showSocialButtons) ...[
            _SocialButton(
              color: const Color(0xFF1877F2),
              icon: Icons.facebook,
              url: 'https://www.facebook.com/alevivakfi',
            ),
            _SocialButton(
              color: const Color(0xFFE4405F),
              icon: Icons.camera_alt,
              url: 'https://www.instagram.com/alevitischestiftung/',
            ),
            _SocialButton(
              color: Colors.red,
              icon: Icons.play_arrow,
              url: 'https://www.youtube.com/@uadevakfi/videos',
            ),
            _SocialButton(
              color: Colors.black,
              label: 'X',
              url: 'https://x.com/UADEVAKFI',
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
  final String url;

  const _SocialButton({
    required this.color,
    required this.url,
    this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton(
        mini: true,
        backgroundColor: color,
        onPressed: () => _WebViewPageState._openExternalUrl(url),
        child: icon != null
            ? Icon(icon, color: Colors.white)
            : Text(label ?? '', style: const TextStyle(color: Colors.white, fontSize: 20)),
      ),
    );
  }
}
