import 'package:flutter/material.dart';
import 'package:mbe_hjnc_flutter/pages/create.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});
  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> posts = List.generate(
    20,
        (index) => {
      "title": "게시글 제목 ${index + 1}",
      "date": _formatDate(DateTime.now().subtract(Duration(hours: index * 3))),
    },
  );

  static String _formatDate(DateTime date) {
    return "${date.year.toString().substring(2)}."
        "${date.month.toString().padLeft(2, '0')}."
        "${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();

    // 스크롤 끝 감지 (나중에 서버에서 추가 로딩용)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        print("맨 아래 도달 - 나중에 서버 호출");
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      ),
      body: Column(
        children: [
          // 🔍 검색창
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "검색어를 입력하세요",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    print("검색: ${_searchController.text}");
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // 📄 게시글 목록
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              itemCount: posts.length,
              separatorBuilder: (context, index) =>
              const Divider(height: 1),
              itemBuilder: (context, index) {
                final post = posts[index];

                return ListTile(
                  title: Text(
                    post["title"]!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    post["date"]!,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    print("글 클릭: ${post["title"]}");
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ➕ 글쓰기 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreatePage(),
            ),
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}