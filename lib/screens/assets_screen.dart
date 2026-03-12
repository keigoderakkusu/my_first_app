import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  Map<String, dynamic>? _prices;
  bool _isLoading = false;
  String? _error;
  String _lastUpdated = '---';

  // Mock historical data for chart (7 days)
  final List<FlSpot> _btcHistory = const [
    FlSpot(0, 8200000),
    FlSpot(1, 8450000),
    FlSpot(2, 8100000),
    FlSpot(3, 8700000),
    FlSpot(4, 8600000),
    FlSpot(5, 9100000),
    FlSpot(6, 8900000),
  ];

  @override
  void initState() {
    super.initState();
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(
            'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd,jpy',
          ))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() {
          _prices = jsonDecode(res.body);
          _lastUpdated = DateFormat('MM/dd HH:mm').format(DateTime.now());
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'APIエラー';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'ネットワークエラー';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jpyFmt = NumberFormat('#,##0', 'ja_JP');
    final usdFmt = NumberFormat('#,##0.00', 'en_US');

    final coins = [
      {
        'id': 'bitcoin',
        'name': 'Bitcoin',
        'symbol': 'BTC',
        'emoji': '₿',
        'color': const Color(0xFFF7931A),
      },
      {
        'id': 'ethereum',
        'name': 'Ethereum',
        'symbol': 'ETH',
        'emoji': 'Ξ',
        'color': const Color(0xFF627EEA),
      },
      {
        'id': 'solana',
        'name': 'Solana',
        'symbol': 'SOL',
        'emoji': '◎',
        'color': const Color(0xFF9945FF),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          '📈 資産',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchPrices,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFF7931A),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFFF7931A)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last updated
            Text(
              '最終更新: $_lastUpdated',
              style: const TextStyle(color: Colors.white30, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Error
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const Spacer(),
                    TextButton(
                      onPressed: _fetchPrices,
                      child: const Text('再試行'),
                    ),
                  ],
                ),
              ),

            // Coin cards
            ...coins.map((coin) {
              final id = coin['id'] as String;
              final color = coin['color'] as Color;
              final jpy = _prices?[id]?['jpy'];
              final usd = _prices?[id]?['usd'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          coin['emoji'] as String,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coin['name'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            coin['symbol'] as String,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          jpy != null ? '¥${jpyFmt.format(jpy)}' : '---',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          usd != null ? '\$${usdFmt.format(usd)}' : '---',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),

            // BTC 7-day chart
            const SizedBox(height: 24),
            const Text(
              'Bitcoin 7日間推移（参考）',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['月', '火', '水', '木', '金', '土', '日'];
                            return Text(
                              days[value.toInt() % 7],
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _btcHistory,
                        isCurved: true,
                        color: const Color(0xFFF7931A),
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFFF7931A).withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
