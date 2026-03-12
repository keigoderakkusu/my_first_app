import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '資産管理アプリ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF7931A), // Bitcoin orange
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const BitcoinTrackerPage(),
    );
  }
}

class BitcoinTrackerPage extends StatefulWidget {
  const BitcoinTrackerPage({super.key});

  @override
  State<BitcoinTrackerPage> createState() => _BitcoinTrackerPageState();
}

class _BitcoinTrackerPageState extends State<BitcoinTrackerPage>
    with SingleTickerProviderStateMixin {
  double? _priceUSD;
  double? _priceJPY;
  String _lastUpdated = '---';
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _fetchBitcoinPrice();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchBitcoinPrice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _animationController.reset();

    try {
      // CoinGecko API (no API key required)
      final response = await http
          .get(
            Uri.parse(
              'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd,jpy',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final now = DateTime.now();
        final formatter = DateFormat('yyyy/MM/dd HH:mm:ss');

        setState(() {
          _priceUSD = (data['bitcoin']['usd'] as num).toDouble();
          _priceJPY = (data['bitcoin']['jpy'] as num).toDouble();
          _lastUpdated = formatter.format(now);
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _errorMessage = 'APIエラー: ステータスコード ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ネットワークエラーが発生しました。\nインターネット接続を確認してください。';
        _isLoading = false;
      });
    }
  }

  String _formatUSD(double price) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '\$${formatter.format(price)}';
  }

  String _formatJPY(double price) {
    final formatter = NumberFormat('#,##0', 'ja_JP');
    return '¥${formatter.format(price)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              'https://cryptologos.cc/logos/bitcoin-btc-logo.png',
              width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.currency_bitcoin,
                color: Color(0xFFF7931A),
                size: 28,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '資産管理アプリ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Header card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF7931A).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.currency_bitcoin,
                      color: Color(0xFFF7931A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Bitcoin (BTC) リアルタイム価格',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Main price card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E1E1E),
                        Color(0xFF2A1A0A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFF7931A).withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF7931A).withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading) ...[
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            color: Color(0xFFF7931A),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '価格を取得中...',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ] else if (_errorMessage != null) ...[
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFFF6B6B),
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ] else if (_priceUSD != null) ...[
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              const Text(
                                'BTC/USD',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatUSD(_priceUSD!),
                                style: const TextStyle(
                                  color: Color(0xFFF7931A),
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 1,
                                color: Colors.white10,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'BTC/JPY',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatJPY(_priceJPY!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    color: Colors.white30,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '最終更新: $_lastUpdated',
                                    style: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'ボタンを押して価格を取得',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Update button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _fetchBitcoinPrice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF3A3A3A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFFF7931A).withOpacity(0.4),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(
                    _isLoading ? '取得中...' : '更新',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'データソース: CoinGecko API',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
