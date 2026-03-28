// ============================================================
// Flutter → GAS へのデータ送信サンプル
// ファイル: lib/services/gas_service.dart
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class GasService {
  // ← デプロイ後のWebアプリURLに差し替える
  static const String _gasUrl =
      'https://script.google.com/macros/s/AKfycbx-0EPpnFl2jl3vPp1UuAxZo83KK1ucobp1ywymmsjwnK4e1Vl68fcIqS_H-NKPANAU/exec';

  /// 音声テキストをGASに送信して日報を生成・保存する
  static Future<GasResult> sendVoiceReport(String voiceText) async {
    try {
      final response = await http
          .post(
            Uri.parse(_gasUrl),
            headers: {'Content-Type': 'text/plain'}, // CORS回避のため text/plain
            body: jsonEncode({
              'action': 'report',
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
      // NOTE: GAS requires GET or simple POST to avoid CORS preflight.
      // We'll use GET here for fetching data.
      final response = await http
          .get(Uri.parse('$_gasUrl?action=get_kindle_library'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
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

  /// スクレイパーを起動する (POST方式に統合してCORS回避)
  static Future<GasResult> triggerKindleScan({String? bookUrl}) async {
    try {
      final response = await http
          .post(
            Uri.parse(_gasUrl),
            headers: {'Content-Type': 'text/plain'}, // CORS回避のため text/plain
            body: jsonEncode({
              'action': 'trigger_kindle',
              'book_url': bookUrl ?? '',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return GasResult.success(ReportData(title: 'Trigger', meetingPartner: '', date: '', location: '', summary: '', decisions: [], concerns: [], nextActions: [], memo: ''));
        } else {
          return GasResult.failure(data['error'] ?? 'エラー: ${response.statusCode}');
        }
      } else {
        return GasResult.failure('HTTPエラー: ${response.statusCode}');
      }
    } catch (e) {
      return GasResult.failure('通信エラー: $e');
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
