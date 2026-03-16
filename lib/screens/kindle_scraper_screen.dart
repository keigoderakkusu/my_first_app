import 'package:flutter/material.dart';
import '../services/gas_service.dart';

class KindleScraperScreen extends StatefulWidget {
  const KindleScraperScreen({super.key});

  @override
  State<KindleScraperScreen> createState() => _KindleScraperScreenState();
}

class _KindleScraperScreenState extends State<KindleScraperScreen> {
  final TextEditingController _urlController = TextEditingController();
  List<KindleBook> _books = [];
  bool _isLoading = false;
  bool _isTriggering = false;

  @override
  void initState() {
    super.initState();
    _refreshLibrary();
  }

  Future<void> _refreshLibrary() async {
    setState(() => _isLoading = true);
    final data = await GasService.getKindleLibrary();
    if (mounted) {
      setState(() {
        _books = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _startScraper({String? url}) async {
    setState(() => _isTriggering = true);
    final success = await GasService.triggerKindleScan(bookUrl: url);
    if (mounted) {
      setState(() => _isTriggering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '🚀 スクレイパーを起動しました（GitHub Actions）' : '❌ 起動に失敗しました'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Kindle Scraper', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshLibrary,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildActionCard(),
            const SizedBox(height: 24),
            const Text(
              '📚 変換済みライブラリ',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _books.isEmpty
                      ? _buildEmptyState()
                      : _buildBookList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withOpacity(0.1), Colors.purpleAccent.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 40),
          const SizedBox(height: 12),
          const Text(
            '自動スクショ & PDF化',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
            'Kindleライブラリから未処理の本を自動検知してPDF化します。\nURLの入力がない場合はライブラリの先頭から開始します。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '特定の本のURL (任意)',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isTriggering ? null : () => _startScraper(url: _urlController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isTriggering
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow),
              label: Text(_isTriggering ? '起動中...' : 'スキャンを開始する'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList() {
    return ListView.builder(
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.book, color: Colors.blueAccent),
            title: Text(book.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${book.status} • ${book.lastUpdated}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: book.driveUrl.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.greenAccent),
                    onPressed: () {
                      // Launch drive URL
                    },
                  )
                : const Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 20),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 60, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('ライブラリは空です', style: TextStyle(color: Colors.white30)),
        ],
      ),
    );
  }
}
