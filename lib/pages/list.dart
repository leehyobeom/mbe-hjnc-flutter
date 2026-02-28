import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'create.dart';
import 'read.dart';

class Community {
  final String communityId;
  final String title;
  final List images;
  final String updatedAt;

  Community({
    required this.communityId,
    required this.title,
    required this.images,
    required this.updatedAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      communityId: json['communityId'],
      title: json['title'] ?? "",
      images: json['images'] ?? [],
      updatedAt: json['updatedAt'] ?? "",
    );
  }
}

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final Dio dio = Dio();
  final ScrollController scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  Timer? _debounce;

  List<Community> communities = [];

  int page = 0;
  bool isLoading = false;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    fetchList();

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        fetchList();
      }
    });
  }

  Future<void> fetchList({bool reset = false}) async {
    final backUrl = dotenv.env['BACK_URL'];
    if (isLoading) return;
    if (reset) {
      page = 0;
      communities.clear();
      hasMore = true;
    }
    setState(() => isLoading = true);
    try {
      final response = await dio.put(
        "$backUrl/community/read/list",
        data: {
          "search": searchController.text,
          "page": page,
        },
      );

      final data = response.data;
      List list = [];
      if (data is Map &&
          data['result'] != null &&
          data['result']['communities'] is List) {
        list = data['result']['communities'];
      }

      if (list.isNotEmpty) {
        setState(() {
          communities.addAll(
            list.map((e) => Community.fromJson(e)).toList(),
          );
          page++;
        });
      } else {
        hasMore = false;
      }

    } catch (e) {
      print("리스트 로드 실패: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String formatDate(String iso) {
    if (iso.isEmpty) return "";
    final date = DateTime.parse(iso);
    return "${date.year.toString().substring(2)}."
        "${date.month.toString().padLeft(2, '0')}."
        "${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _debounce?.cancel();
    scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("")),

      body: Column(
        children: [

          /// 🔍 검색창
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "검색어 입력",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) {
                  _debounce!.cancel();
                }

                _debounce = Timer(const Duration(milliseconds: 400), () {
                  fetchList(reset: true);
                });
              },
            ),
          ),

          /// 📄 리스트
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: communities.length + 1,
              itemBuilder: (context, index) {

                if (index == communities.length) {
                  return isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                      : const SizedBox();
                }

                final item = communities[index];

                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(formatDate(item.updatedAt)),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReadPage(
                          communityId: item.communityId,
                        ),
                      ),
                    );

                    if (result == true) {
                      fetchList(reset: true);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),

      /// ➕ 글쓰기 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreatePage(),
            ),
          );

          fetchList(reset: true);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}