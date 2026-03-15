import 'package:flutter/material.dart';
import '../services/gas_service.dart';

class VoiceReportScreen extends StatefulWidget {
  const VoiceReportScreen({super.key});

  @override
  State<VoiceReportScreen> createState() => _VoiceReportScreenState();
}

class _VoiceReportScreenState extends State<VoiceReportScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  ReportData? _resultData;
  String? _errorMessage;

  Future<void> _submitReport() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resultData = null;
    });

    final result = await GasService.sendVoiceReport(_controller.text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _resultData = result.data;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 日報を送信・保存しました')),
          );
        } else {
          _errorMessage = result.error;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Background color from main.dart
      appBar: AppBar(
        title: const Text('音声日報 AI要約', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '認識されたテキスト',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '例: 本日田中さんと商談しました。来週契約予定です。',
                  hintStyle: TextStyle(color: Colors.white30),
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('AIで要約して保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                '❌ エラー: $_errorMessage',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            if (_resultData != null) ...[
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              const Text(
                '✨ AI解析結果',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final data = _resultData!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('タイトル', data.title, Icons.title),
          _buildInfoRow('商談相手', data.meetingPartner, Icons.person),
          _buildInfoRow('日時', data.date, Icons.calendar_today),
          _buildInfoRow('場所', data.location, Icons.location_on),
          const SizedBox(height: 12),
          const Text('要約', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(data.summary, style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 16),
          _buildListSection('決定事項', data.decisions, Colors.greenAccent),
          _buildListSection('懸念点', data.concerns, Colors.orangeAccent),
          const SizedBox(height: 12),
          const Text('ネクストアクション', style: TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          ...data.nextActions.map((a) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('・${a.action} (${a.owner} / ${data.date})', style: const TextStyle(color: Colors.white, fontSize: 14)),
          )),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('・$item', style: const TextStyle(color: Colors.white, fontSize: 14)),
        )),
      ],
    );
  }
}
