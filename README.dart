# college_football_ai
대학미식축구랭킹과 관련된 챗
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==================== CFBDApi ====================
class CFBDApi {
  final String apiKey = "NwvR0m+vC1ONr2BDomlUuEBYygOu2jAaV+CKHN6MAn9yJibcmxTJv98n/zOqs1kR";
  final String baseUrl = "https://api.collegefootballdata.com";

  Future<List<dynamic>> fetchTeams() async {
    final uri = Uri.parse("$baseUrl/teams");
    final response = await http.get(uri, headers: {"Authorization": "Bearer $apiKey"});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("팀 로드 실패: ${response.statusCode}");
    }
  }

  Future<List<dynamic>> fetchRankings(int year, {String poll = 'CFP'}) async {
    final params = {'year': year.toString(), 'seasonType': 'both'};
    final uri = Uri.parse("$baseUrl/rankings").replace(queryParameters: params);
    final response = await http.get(uri, headers: {"Authorization": "Bearer $apiKey"});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      for (var entry in data) {
        for (var p in entry['polls']) {
          if (p['poll'].toLowerCase().contains(poll.toLowerCase())) {
            return p['ranks'];
          }
        }
      }
      return [];
    } else {
      return [];
    }
  }
}

// ==================== 메인 앱 ====================
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'College Football AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TeamListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== 팀 리스트 페이지 ====================
class TeamListPage extends StatefulWidget {
  const TeamListPage({super.key});

  @override
  State<TeamListPage> createState() => _TeamListPageState();
}

class _TeamListPageState extends State<TeamListPage> {
  final CFBDApi api = CFBDApi();
  List<dynamic> teams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTeams();
  }

  Future<void> loadTeams() async {
    try {
      final data = await api.fetchTeams();
      setState(() {
        teams = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("팀 로드 실패: $e")),
        );
      }
    }
  }

  // 안전한 색상 파싱 함수 (0xFFnull 오류 방지)
  Color getTeamColor(String? hex) {
    if (hex == null || hex.isEmpty || hex.toLowerCase() == "null" || hex == "#null") {
      return Colors.grey[600]!;
    }
    String cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length < 6) return Colors.grey[600]!;
    try {
      return Color(int.parse('0xFF$cleaned'));
    } catch (_) {
      return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text("College Football Teams", style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.deepPurple, Colors.indigoAccent],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.sports_football, size: 90, color: Colors.white24),
                ),
              ),
            ),
            actions: [
              IconButton(
                iconSize: 30,
                icon: const Icon(Icons.chat_bubble_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 700),
                      pageBuilder: (_, animation, __) => FadeTransition(
                        opacity: animation,
                        child: ChatBotPage(cfbdApi: api),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
          isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(strokeWidth: 4)),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final team = teams[index];
                      final school = team['school'] ?? "Unknown";
                      final conference = team['conference'] ?? "Independent";
                      final Color teamColor = getTeamColor(team['color']);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: teamColor,
                            child: Text(
                              school[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(school, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          subtitle: Text(conference, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.deepPurple),
                        ),
                      );
                    },
                    childCount: teams.length,
                  ),
                ),
        ],
      ),
    );
  }
}

// ==================== 챗봇 페이지 ====================
class ChatBotPage extends StatefulWidget {
  final CFBDApi cfbdApi;
  const ChatBotPage({super.key, required this.cfbdApi});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  final int currentYear = 2025;

  void _sendMessage() async {
    String userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'text': userMessage});
      messages.add({'role': 'bot', 'text': '', 'isTyping': true});
    });
    _controller.clear();

    String botResponse = "잘 모르겠어요. '랭킹'이나 '최고 팀'이라고 물어봐주세요!";

    try {
      if (userMessage.toLowerCase().contains('최고') ||
          userMessage.toLowerCase().contains('1위') ||
          userMessage.toLowerCase().contains('랭킹') ||
          userMessage.toLowerCase().contains('순위')) {
        final rankings = await widget.cfbdApi.fetchRankings(currentYear);
        if (rankings.isNotEmpty) {
          final top = rankings[0];
          botResponse = "🏈 **2025 CFP 랭킹 1위**\n\n"
              "🏆 **${top['school']}**\n"
              "순위: #${top['rank']}\n"
              "컨퍼런스: ${top['conference'] ?? 'Independent'}\n\n"
              "현재 무패 행진 중이에요! 플레이오프 우승 후보 1순위!";
        } else {
          botResponse = "랭킹 로드 중... 하지만 최신 소식으로는 **Indiana Hoosiers**가 무패 1위예요! 🏆";
        }
      } else if (userMessage.toLowerCase().contains('heisman') ||
                 userMessage.toLowerCase().contains('mendoza') ||
                 userMessage.toLowerCase().contains('선수')) {
        botResponse = "🏆 **2025 Heisman Trophy 수상자**\n\n"
            "**Fernando Mendoza**\n"
            "포지션: QB\n"
            "팀: Indiana Hoosiers\n\n"
            "무패 팀을 이끌며 역사적인 활약으로 수상!";
      } else {
        botResponse = "🤖 **대학 미식축구 AI 챗봇**입니다!\n\n"
            "추천 질문:\n"
            "• 올해 최고 팀은?\n"
            "• 랭킹 알려줘\n"
            "• Heisman 누구야?\n"
            "• Indiana 성적 어때?\n\n"
            "더 많은 기능이 곧 추가될 거예요!";
      }
    } catch (e) {
      botResponse = "데이터 연결 오류... 기본 정보: **Indiana Hoosiers** 무패 1위! 🏈";
    }

    await Future.delayed(const Duration(milliseconds: 1000)); // 타이핑 효과

    setState(() {
      messages.removeLast();
      messages.add({'role': 'bot', 'text': botResponse});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("🏈 Grok AI 챗봇", style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => messages.clear()),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isUser = msg['role'] == 'user';

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(18),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.deepPurple[400] : Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: msg['isTyping'] == true
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(3, (i) => _typingDot(i * 150)),
                              )
                            : Text(
                                msg['text'],
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 16.5,
                                  height: 1.5,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "질문을 입력하세요...",
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      onPressed: _sendMessage,
                      backgroundColor: Colors.deepPurple,
                      elevation: 8,
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typingDot(int delayMs) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: AnimatedScale(
        scale: 1.0,
        duration: Duration(milliseconds: 600 + delayMs),
        curve: Curves.easeInOut,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
