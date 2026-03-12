import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class Memo {
  final String id;
  final String content;
  final DateTime date;

  Memo({required this.id, required this.content, required this.date});

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'date': date.toIso8601String(),
      };

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        id: json['id'],
        content: json['content'],
        date: DateTime.parse(json['date']),
      );
}

class LoveScreen extends StatefulWidget {
  const LoveScreen({super.key});

  @override
  State<LoveScreen> createState() => _LoveScreenState();
}

class _LoveScreenState extends State<LoveScreen> {
  DateTime? _anniversaryDate;
  List<Memo> _memos = [];
  final _memoController = TextEditingController();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString('anniversary_date');
    final memosData = prefs.getString('love_memos');

    setState(() {
      if (dateStr != null) _anniversaryDate = DateTime.parse(dateStr);
      if (memosData != null) {
        final list = jsonDecode(memosData) as List;
        _memos = list.map((e) => Memo.fromJson(e)).toList();
      }
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_anniversaryDate != null) {
      await prefs.setString(
          'anniversary_date', _anniversaryDate!.toIso8601String());
    }
    await prefs.setString(
      'love_memos',
      jsonEncode(_memos.map((m) => m.toJson()).toList()),
    );
  }

  int get _daysTogether {
    if (_anniversaryDate == null) return 0;
    return DateTime.now().difference(_anniversaryDate!).inDays;
  }

  int get _daysToNext {
    if (_anniversaryDate == null) return 0;
    final now = DateTime.now();
    var next = DateTime(now.year, _anniversaryDate!.month, _anniversaryDate!.day);
    if (next.isBefore(now) || next == now) {
      next = DateTime(now.year + 1, _anniversaryDate!.month, _anniversaryDate!.day);
    }
    return next.difference(now).inDays;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anniversaryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFEC4899),
            surface: Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _anniversaryDate = picked);
      _save();
    }
  }

  void _addMemo() {
    if (_memoController.text.trim().isEmpty) return;
    setState(() {
      _memos.insert(
        0,
        Memo(
          id: _uuid.v4(),
          content: _memoController.text.trim(),
          date: DateTime.now(),
        ),
      );
      _memoController.clear();
    });
    _save();
  }

  void _deleteMemo(String id) {
    setState(() => _memos.removeWhere((m) => m.id == id));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFEC4899);
    const pinkDark = Color(0xFFBE185D);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          '💕 恋愛',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Anniversary card
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [pink, pinkDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      '❤️',
                      style: TextStyle(fontSize: 44),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _anniversaryDate == null
                          ? '記念日を設定する'
                          : '${DateFormat('yyyy年MM月dd日').format(_anniversaryDate!)} から',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _anniversaryDate == null
                          ? 'タップして設定'
                          : '$_daysTogether 日目',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_anniversaryDate != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '次の記念日まで $_daysToNext 日',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'タップして記念日を変更',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Milestone cards
            if (_anniversaryDate != null) ...[
              const SizedBox(height: 20),
              const Text(
                'マイルストーン',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [100, 365, 1000].map((days) {
                  final target = _anniversaryDate!.add(Duration(days: days));
                  final isPast = DateTime.now().isAfter(target);
                  final daysLeft = target.difference(DateTime.now()).inDays;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPast
                              ? pink.withOpacity(0.6)
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$days日',
                            style: TextStyle(
                              color: isPast ? pink : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPast
                                ? '達成 ✓'
                                : 'あと$daysLeft日',
                            style: TextStyle(
                              color: isPast ? Colors.white70 : Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Memo section
            const SizedBox(height: 24),
            const Text(
              'ラブメモ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '思い出・伝えたいことをメモ...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: pink,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _addMemo,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_memos.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '思い出をメモして残しましょう ❤️',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
              )
            else
              ..._memos.map((memo) => Dismissible(
                    key: Key(memo.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.red),
                    ),
                    onDismissed: (_) => _deleteMemo(memo.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: pink.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memo.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('yyyy/MM/dd HH:mm').format(memo.date),
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
