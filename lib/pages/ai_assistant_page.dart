import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart'; // Official SDK
import '../main.dart';

// 1. Read the key safely from the environment
const _kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

// 2. Keep your system prompt clean and global
const _kSystemPrompt = '''
你是一位專業的嘉義旅遊 AI 助手，名叫「阿義」。你熟悉嘉義市與嘉義縣的所有旅遊景點、美食、交通與文化。
請用繁體中文回答，語氣親切、簡潔、有實用性。
- 回答景點時，請提及開放時間、票價（如有）、特色
- 回答美食時，請提及店名、地址（簡短）、特色料理
- 行程規劃要考慮景點距離，安排合理動線
- 適時加入實用小提示（如停車、最佳造訪時間等）
- 回答控制在 200 字以內，重點清晰

嘉義重要景點：阿里山、奮起湖、檜意森活村、嘉義文化路夜市、北回規線紀念碑、嘉義公園、竹崎公園、太平雲梯、奮起湖老街。
嘉義必吃：雞肉飯、方塊酥、砂鍋魚頭、火雞肉飯、義竹羊肉爐、嘉義涼麵。
''';

// ── Data models ───────────────────────────────────────────────────────────────

class _TravelSpot {
  final String name;
  final String tip;
  final String duration;
  const _TravelSpot({required this.name, required this.tip, required this.duration});

  factory _TravelSpot.fromJson(Map<String, dynamic> j) => _TravelSpot(
    name: j['name'] ?? '',
    tip: j['tip'] ?? '',
    duration: j['duration'] ?? '',
  );
}

class _ItineraryDay {
  final int day;
  final String title;
  final List<_TravelSpot> spots;
  const _ItineraryDay({required this.day, required this.title, required this.spots});

  factory _ItineraryDay.fromJson(Map<String, dynamic> j) => _ItineraryDay(
    day: j['day'] ?? 1,
    title: j['title'] ?? '',
    spots: (j['spots'] as List<dynamic>? ?? [])
        .map((s) => _TravelSpot.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

class _PrefOption {
  final String id;
  final String label;
  final IconData icon;
  const _PrefOption(this.id, this.label, this.icon);
}

const _kPrefs = [
  _PrefOption('family', '親子同樂', Icons.family_restroom_rounded),
  _PrefOption('history', '歷史文化', Icons.account_balance_rounded),
  _PrefOption('food', '美食饕客', Icons.ramen_dining_rounded),
  _PrefOption('nature', '自然生態', Icons.forest_rounded),
  _PrefOption('photo', '網美打卡', Icons.camera_alt_rounded),
  _PrefOption('budget', '省錢攻略', Icons.savings_rounded),
];

enum _MsgType { text, loading, itineraryPlanner, itinerary }

class _ChatMessage {
  final String text;
  final bool isUser;
  final _MsgType type;
  final List<_ItineraryDay>? itineraryDays;
  final String? itineraryLabel;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.type = _MsgType.text,
    this.itineraryDays,
    this.itineraryLabel,
  });
}

// ── Main page ─────────────────────────────────────────────────────────────────

class AiAssistantPage extends StatefulWidget {
  final String headerImagePath;
  const AiAssistantPage({
    super.key,
    this.headerImagePath = 'images/aipic.jpg',
  });

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _history = [];

  Future<String> _callGemini(List<Map<String, dynamic>> conversationHistory) async {
    try {
      // 1. Initialize using your active stable model string
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _kGeminiApiKey,
        systemInstruction: Content.system(_kSystemPrompt),
        generationConfig: GenerationConfig(
          maxOutputTokens: 600,
          temperature: 0.8,
        ),
      );

      // 2. Extract the active prompt directly from the end of the history
      final lastMessageMap = conversationHistory.last;
      final lastPartsList = lastMessageMap['parts'] as List;
      final String activePrompt = lastPartsList.first['text'] as String;

      // 3. Map the previous history using strict Content typing
      final List<Content> sdkHistory = conversationHistory
          .take(conversationHistory.length - 1)
          .map((msg) {
        final role = msg['role'] == 'user' ? 'user' : 'model';
        final parts = msg['parts'] as List;
        final text = parts.first['text'] as String;
        return Content(role, [TextPart(text)]);
      }).toList();

      // 4. Start the chat thread and push the request
      final chat = model.startChat(history: sdkHistory);
      final response = await chat.sendMessage(Content.text(activePrompt));

      return response.text ?? '阿義暫時想不出好點子呢。';
    } catch (e) {
      debugPrint("Gemini SDK Error: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text: '您好！我是嘉義旅遊 AI 助手 🌿\n有什麼旅遊問題我可以幫您解答嗎？\n\n💡 點擊下方快捷鍵快速開始！',
      isUser: false,
    ),
  ];

  bool _isLoading = false;

  static const _kChips = [
    ('📅 一日遊規劃', '我想規劃嘉義一日遊'),
    ('🍜 必吃美食', '嘉義有哪些必吃美食？'),
    ('👨‍👩‍👧 親子景點', '嘉義親子景點推薦'),
    ('🗺️ 智能行程', '__itinerary__'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendToGemini(String userText) async {
    setState(() {
      _messages.add(_ChatMessage(text: userText, isUser: true));
      _messages.add(const _ChatMessage(text: '', isUser: false, type: _MsgType.loading));
      _isLoading = true;
    });
    _scrollToBottom();

    _history.add({
      'role': 'user',
      'parts': [{'text': userText}]
    });

    String reply;
    try {
      reply = await _callGemini(_history);
    } catch (e) {
      reply = '連線失敗，請稍後再試。($e)';
    }

    _history.add({
      'role': 'model',
      'parts': [{'text': reply}]
    });

    setState(() {
      _messages.removeLast();
      _messages.add(_ChatMessage(text: reply, isUser: false));
      _isLoading = false;
    });
    _scrollToBottom();
  }


  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isLoading) return;
    _ctrl.clear();
    _sendToGemini(text);
  }

  void _chipTap(String action) {
    if (action == '__itinerary__') {
      _showItineraryPlanner();
    } else {
      _ctrl.text = action;
      _send();
    }
  }

  void _showItineraryPlanner() {
    setState(() {
      _messages.add(const _ChatMessage(
        text: '',
        isUser: false,
        type: _MsgType.itineraryPlanner,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _generateItinerary(List<String> prefs, int days) async {
    final prefMap = {
      'family': '親子同樂', 'history': '歷史文化', 'food': '美食饕客',
      'nature': '自然生態', 'photo': '網美打卡', 'budget': '省錢攻略',
    };
    final prefLabel = prefs.isEmpty ? '一般觀光' : prefs.map((p) => prefMap[p]!).join('、');
    final prompt =
        '請為我規劃一份嘉義 $days 天的旅遊行程，偏好：$prefLabel。'
        '請以 JSON 格式回應，結構如下：'
        '{"days":[{"day":1,"title":"主題標題","spots":[{"name":"景點名","tip":"簡短建議","duration":"建議停留時間"}]}]}'
        '，只回傳 JSON 不要其他文字。';

    setState(() {
      _messages.removeLast();
      _messages.add(_ChatMessage(text: '$days 天「$prefLabel」智能行程規劃', isUser: true));
      _messages.add(const _ChatMessage(text: '', isUser: false, type: _MsgType.loading));
      _isLoading = true;
    });
    _scrollToBottom();

    String raw;
    try {
      // 📍 1. Call our new customized helper method instead of the raw JSON layout
      raw = await _callGeminiForItinerary(prompt);
    } catch (e) {
      debugPrint("Itinerary Generator Error: $e");
      raw = '';
    }

    List<_ItineraryDay> itinDays = [];
    try {
      final clean = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      itinDays = (decoded['days'] as List)
          .map((d) => _ItineraryDay.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (_) {
      itinDays = [
        const _ItineraryDay(day: 1, title: '嘉義精華遊', spots: [
          _TravelSpot(name: '阿里山森林遊樂區', tip: '建議早上搭乘森林鐵路，欣賞日出雲海', duration: '3 小時'),
          _TravelSpot(name: '奮起湖老街', tip: '必吃奮起湖便當，感受山城古樸風情', duration: '1.5 小時'),
          _TravelSpot(name: '嘉義文化路夜市', tip: '必吃雞肉飯、砂鍋魚頭，建議 17:00 前到', duration: '2 小時'),
        ]),
      ];
    }

    // 📍 2. Ensure we display the newly generated itinerary and toggle off loading state
    setState(() {
      _messages.removeLast();
      _messages.add(_ChatMessage(
        text: '',
        isUser: false,
        type: _MsgType.itinerary,
        itineraryDays: itinDays,
        itineraryLabel: '$days 天「$prefLabel」行程',
      ));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<String> _callGeminiForItinerary(String complexPrompt) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite', // Updated to match your available models
        apiKey: _kGeminiApiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: 1200,
          temperature: 0.7,
          responseMimeType: 'application/json', // Forces pristine JSON back
        ),
      );

      final content = [Content.text(complexPrompt)];
      final response = await model.generateContent(content);
      return response.text ?? '';
    } catch (e) {
      debugPrint("Itinerary SDK Error: $e");
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _CurvedHeader(imagePath: widget.headerImagePath),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: _messages.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return const _DateDivider(label: '今天');
                final msg = _messages[i - 1];
                return switch (msg.type) {
                  _MsgType.loading => const _LoadingBubble(),
                  _MsgType.itineraryPlanner => _ItineraryPlannerBubble(
                    onGenerate: _generateItinerary,
                  ),
                  _MsgType.itinerary => _ItineraryBubble(
                    days: msg.itineraryDays!,
                    label: msg.itineraryLabel!,
                    onAskMore: () => _sendToGemini('請給我這份行程的交通建議和注意事項'),
                  ),
                  _MsgType.text => _BubbleTile(msg: msg),
                };
              },
            ),
          ),
          _QuickChips(chips: _kChips, onTap: _chipTap, disabled: _isLoading),
          _InputBar(ctrl: _ctrl, onSend: _send, disabled: _isLoading),
        ],
      ),
    );
  }
}

// ── Quick chips row ────────────────────────────────────────────────────────────
class _QuickChips extends StatelessWidget {
  final List<(String, String)> chips;
  final void Function(String) onTap;
  final bool disabled;

  const _QuickChips({required this.chips, required this.onTap, required this.disabled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, action) = chips[i];
          return GestureDetector(
            onTap: disabled ? null : () => onTap(action),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: disabled ? Colors.grey.shade200 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: disabled ? Colors.grey.shade300 : AppTheme.primaryGreen.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: disabled ? Colors.grey : AppTheme.primaryGreen,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Loading bubble ─────────────────────────────────────────────────────────────
class _LoadingBubble extends StatefulWidget {
  const _LoadingBubble();
  @override
  State<_LoadingBubble> createState() => _LoadingBubbleState();
}

class _LoadingBubbleState extends State<_LoadingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_anim.value - i * 0.2).clamp(0.0, 1.0);
                  final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Itinerary planner bubble ───────────────────────────────────────────────────
class _ItineraryPlannerBubble extends StatefulWidget {
  final Future<void> Function(List<String> prefs, int days) onGenerate;
  const _ItineraryPlannerBubble({required this.onGenerate});

  @override
  State<_ItineraryPlannerBubble> createState() => _ItineraryPlannerBubbleState();
}

class _ItineraryPlannerBubbleState extends State<_ItineraryPlannerBubble> {
  final Set<String> _selected = {};
  int _days = 1;
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('請選擇您的旅遊偏好 🗺️', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  const Text('我將為您量身規劃最適合的行程', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _kPrefs.map((p) {
                      final sel = _selected.contains(p.id);
                      return GestureDetector(
                        onTap: () => setState(() => sel ? _selected.remove(p.id) : _selected.add(p.id)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? AppTheme.primaryGreen : const Color(0xFFF0FBF7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? AppTheme.primaryGreen : AppTheme.primaryGreen.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(p.icon, size: 14, color: sel ? Colors.white : AppTheme.primaryGreen),
                              const SizedBox(width: 5),
                              Text(p.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppTheme.primaryGreen)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('旅遊天數', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
                      const SizedBox(width: 12),
                      ...List.generate(3, (i) {
                        final d = i + 1;
                        final sel = _days == d;
                        return GestureDetector(
                          onTap: () => setState(() => _days = d),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            width: 40, height: 36,
                            decoration: BoxDecoration(
                              color: sel ? AppTheme.primaryGreen : const Color(0xFFF0FBF7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: sel ? AppTheme.primaryGreen : AppTheme.primaryGreen.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text('$d 天', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppTheme.primaryGreen)),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generating ? null : () async {
                        setState(() => _generating = true);
                        await widget.onGenerate(_selected.toList(), _days);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      child: _generating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('✨ 生成智能行程', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Itinerary result bubble ────────────────────────────────────────────────────
class _ItineraryBubble extends StatelessWidget {
  final List<_ItineraryDay> days;
  final String label;
  final VoidCallback onAskMore;

  const _ItineraryBubble({required this.days, required this.label, required this.onAskMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBF7),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_rounded, color: AppTheme.primaryGreen, size: 15),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('嘉義行程 · $label',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F6E56))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...days.map((day) => _DaySection(day: day)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onAskMore,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Text('💬 詢問此行程的交通與注意事項',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final _ItineraryDay day;
  const _DaySection({required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('第 ${day.day} 天${day.title.isNotEmpty ? ' — ${day.title}' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF085041))),
          const SizedBox(height: 4),
          ...day.spots.asMap().entries.map((e) => _SpotRow(index: e.key + 1, spot: e.value)),
        ],
      ),
    );
  }
}

class _SpotRow extends StatelessWidget {
  final int index;
  final _TravelSpot spot;
  const _SpotRow({required this.index, required this.spot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
            child: Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(spot.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textDark))),
                    if (spot.duration.isNotEmpty)
                      Text(spot.duration, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
                  ],
                ),
                if (spot.tip.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(spot.tip, style: const TextStyle(fontSize: 11.5, color: AppTheme.textGrey, height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI avatar ──────────────────────────────────────────────────────────────────
class _AiAvatar extends StatelessWidget {
  const _AiAvatar();
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), shape: BoxShape.circle),
      child: const Icon(Icons.auto_awesome, color: AppTheme.primaryGreen, size: 16),
    );
  }
}

// ── Curved header ──────────────────────────────────────────────────────────────
class _CurvedHeader extends StatelessWidget {
  final String imagePath;
  const _CurvedHeader({required this.imagePath});

  ImageProvider _imageProvider() {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    return AssetImage(imagePath);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 170 + topPadding,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image: _imageProvider(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppTheme.primaryGreen),
            ),
          ),
          const Positioned(
            bottom: -1, left: 0, right: 0,
            child: CustomPaint(
              size: Size(double.infinity, 38),
              painter: _CurvePainter(fillColor: Color(0xFFEEF4FC)),
            ),
          ),
          Positioned(
            top: topPadding + 8, left: 16, right: 16, bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: SizedBox()),
                Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2AA090), size: 26),
                        ),
                        Positioned(
                          bottom: 2, right: 2,
                          child: Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.cream, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('AI 旅遊助手 ✨',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 35),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final Color fillColor;
  const _CurvePainter({required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fillColor;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.4)
      ..quadraticBezierTo(size.width / 2, 0, size.width, size.height * 0.4)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.fillColor != fillColor;
}

// ── Date divider ───────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
      ),
    );
  }
}

// ── Chat bubble ────────────────────────────────────────────────────────────────
class _BubbleTile extends StatelessWidget {
  final _ChatMessage msg;
  const _BubbleTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[const _AiAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Text(
                msg.text,
                style: TextStyle(fontSize: 14, color: msg.isUser ? Colors.white : AppTheme.textDark, height: 1.4),
              ),
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool disabled;
  const _InputBar({required this.ctrl, required this.onSend, required this.disabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).viewInsets.bottom + 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.25), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onSubmitted: disabled ? null : (_) => onSend(),
                      enabled: !disabled,
                      decoration: const InputDecoration(
                        hintText: '詢問嘉義旅遊問題…',
                        hintStyle: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: disabled ? null : onSend,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: disabled ? Colors.grey.shade300 : AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}