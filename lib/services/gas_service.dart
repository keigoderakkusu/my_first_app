// ============================================================
// Flutter → GAS へのデータ送信サンプル
// ファイル: lib/services/gas_service.dart
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class GasService {
  // ← デプロイ後のWebアプリURLに差し替える
  static const String _gasUrl = 'https://script.google.com/macros/s/AKfycbybvMEhnJQxadFsCgWULo7uyq07UuZ58rWp-UZN_mSwRqCxpcnuUA6iCftKPoihVdy7/exec';

  /// 音声テキストをGASに送信して日報を生成・保存する
  static Future<GasResult> sendVoiceReport(String voiceText) async {
    try {
      final response = await http
          .post(
            Uri.parse(_gasUrl),
            headers: {'Content-Type': 'text/plain'},
            body: jsonEncode({
              'text': voiceText,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return GasResult.success(ReportData.fromJson(data['data']));
        } else {
          return GasResult.failure(data['error'] ?? '不明なエラー');
        }
      } else {
        return GasResult.failure('HTTPエラー: ${response.statusCode}');
      }
    } catch (e) {
      return GasResult.failure('通信エラー: $e');
    }
  }

  /// Kindle ライブラリ情報を取得する
  static Future<List<KindleBook>> getKindleLibrary() async {
    try {
      final response = await http
          .get(Uri.parse('$_gasUrl?action=get_kindle_library'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((b) => KindleBook.fromJson(b))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('getKindleLibrary error: $e');
      return [];
    }
  }

  /// スクレイパーを起動する
  static Future<bool> triggerKindleScan({String? bookUrl}) async {
    try {
      final url = '$_gasUrl?action=trigger_kindle&book_url=${Uri.encodeComponent(bookUrl ?? '')}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('triggerKindleScan error: $e');
      return false;
    }
  }
}

// ===== Kindle データモデル =====
class KindleBook {
  final String title;
  final String url;
  final String status;
  final String lastUpdated;
  final String driveUrl;

  KindleBook({
    required this.title,
    required this.url,
    required this.status,
    required this.lastUpdated,
    required this.driveUrl,
  });

  factory KindleBook.fromJson(Map<String, dynamic> json) => KindleBook(
        title: json['タイトル'] ?? '',
        url: json['URL'] ?? '',
        status: json['ステータス'] ?? '',
        lastUpdated: json['最終更新'].toString(),
        driveUrl: json['保存先URL'] ?? '',
      );
}

// ===== 結果モデル =====
class GasResult {
  final bool success;
  final ReportData? data;
  final String? error;

  GasResult._({required this.success, this.data, this.error});

  factory GasResult.success(ReportData data) =>
      GasResult._(success: true, data: data);

  factory GasResult.failure(String error) =>
      GasResult._(success: false, error: error);
}

// ===== 日報データモデル =====
class ReportData {
  final String title;
  final String meetingPartner;
  final String date;
  final String location;
  final String summary;
  final List<String> decisions;
  final List<String> concerns;
  final List<NextAction> nextActions;
  final String memo;

  ReportData({
    required this.title,
    required this.meetingPartner,
    required this.date,
    required this.location,
    required this.summary,
    required this.decisions,
    required this.concerns,
    required this.nextActions,
    required this.memo,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) => ReportData(
        title: json['title'] ?? '',
        meetingPartner: json['meeting_partner'] ?? '',
        date: json['date'] ?? '',
        location: json['location'] ?? '',
        summary: json['summary'] ?? '',
        decisions: List<String>.from(json['decisions'] ?? []),
        concerns: List<String>.from(json['concerns'] ?? []),
        nextActions: (json['next_actions'] as List? ?? [])
            .map((a) => NextAction.fromJson(a))
            .toList(),
        memo: json['memo'] ?? '',
      );
}

class NextAction {
  final String action;
  final String owner;
  final String deadline;

  NextAction(
      {required this.action, required this.owner, required this.deadline});

  factory NextAction.fromJson(Map<String, dynamic> json) => NextAction(
        action: json['action'] ?? '',
        owner: json['owner'] ?? '',
        deadline: json['deadline'] ?? '',
      );
}

// ============================================================
// 使用例 (Flutter Widget内からの呼び出し方)
// ============================================================
// 
// ```dart
// void _submitReport() async {
//   setState(() => _isSending = true);
//
//   final result = await GasService.sendVoiceReport(_recognizedText);
//
//   if (result.success) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('日報を送信しました: ${result.data!.title}')),
//     );
//   } else {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('エラー: ${result.error}')),
//     );
//   }
//
//   setState(() => _isSending = false);
// }
// ```
