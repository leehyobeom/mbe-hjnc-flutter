import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'update.dart';

class ReadPage extends StatefulWidget {
  final String communityId;

  const ReadPage({super.key, required this.communityId});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  final Dio dio = Dio();
  final PageController _pageController = PageController();

  bool isLoading = true;
  bool isDeleting = false;

  Map<String, dynamic>? community;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    final backUrl = dotenv.env['BACK_URL'];

    try {
      final response = await dio.put(
        "$backUrl/community/read",
        data: {
          "communityId": widget.communityId,
        },
      );

      setState(() {
        community = response.data['result'];
        isLoading = false;
      });
    } catch (e) {
      print("상세 로드 실패: $e");
      setState(() => isLoading = false);
    }
  }

  /// 🔥 이미지 전체화면 뷰어
  void openImageViewer(List images, int initialIndex) {
    final backUrl = dotenv.env['BACK_URL'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PhotoViewGallery.builder(
                pageController:
                PageController(initialPage: initialIndex),
                itemCount: images.length,
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(
                      "$backUrl/${images[index]}",
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale:
                    PhotoViewComputedScale.covered * 3,
                  );
                },
                backgroundDecoration:
                const BoxDecoration(color: Colors.black),
              ),

              /// 닫기 버튼
              Positioned(
                top: 50,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> deleteCommunity() async {
    final backUrl = dotenv.env['BACK_URL'];
    setState(() => isDeleting = true);

    try {
      final response = await dio.put(
        "$backUrl/community/delete",
        data: {
          "communityId": widget.communityId,
        },
      );

      setState(() => isDeleting = false);

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            title: const Text("삭제 성공"),
            content: const Text("게시글이 삭제되었습니다."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text("확인"),
              )
            ],
          ),
        );
      } else {
        showFailDialog();
      }
    } catch (e) {
      setState(() => isDeleting = false);
      showFailDialog();
    }
  }

  void showFailDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("삭제 실패"),
        content:
        const Text("삭제 중 오류가 발생했습니다."),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("확인"),
          )
        ],
      ),
    );
  }

  void showDeleteBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.all(16),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Text(
                  "정말 삭제하시겠습니까?",
                  style: TextStyle(
                      fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.red,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    deleteCommunity();
                  },
                  child:
                  const Text("삭제"),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                          context),
                  child:
                  const Text("취소"),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
            child:
            CircularProgressIndicator()),
      );
    }

    if (community == null) {
      return const Scaffold(
        body:
        Center(child: Text("데이터 없음")),
      );
    }

    final images = community!['images'] ?? [];
    final title = community!['title'] ?? "";
    final text = community!['text'] ?? "";
    final vesselCode =
        community!['vesselCode'] ?? "";
    final bay =
        community!['bay'] ?? "";
    final isHold =
        community!['isHold'] == true;
    final isLD =
        community!['isLD'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result =
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      UpdatePage(
                        communityId:
                        widget.communityId,
                      ),
                ),
              );

              if (result == true) {
                fetchDetail();
              }
            },
          ),
          IconButton(
            icon:
            const Icon(Icons.delete),
            onPressed:
            showDeleteBottomSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding:
              const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  /// 이미지 슬라이더
                  if (images.isNotEmpty) ...[
                    SizedBox(
                      height: 250,
                      child:
                      PageView.builder(
                        controller:
                        _pageController,
                        itemCount:
                        images.length,
                        onPageChanged:
                            (index) {
                          setState(() {
                            currentPage =
                                index;
                          });
                        },
                        itemBuilder:
                            (context,
                            index) {
                          return GestureDetector(
                            onTap: () =>
                                openImageViewer(
                                    images,
                                    index),
                            child:
                            Image.network(
                              "${dotenv.env['BACK_URL']}/${images[index]}",
                              fit: BoxFit
                                  .cover,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(
                        height: 8),

                    /// 페이지 인디케이터
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children:
                      List.generate(
                        images.length,
                            (index) =>
                            Container(
                              margin: const EdgeInsets
                                  .symmetric(
                                  horizontal:
                                  4),
                              width:
                              currentPage ==
                                  index
                                  ? 10
                                  : 8,
                              height:
                              currentPage ==
                                  index
                                  ? 10
                                  : 8,
                              decoration:
                              BoxDecoration(
                                shape: BoxShape
                                    .circle,
                                color: currentPage ==
                                    index
                                    ? Colors
                                    .blue
                                    : Colors
                                    .grey,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(
                        height: 24),
                  ],

                  const Text("제목",
                      style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          color:
                          Colors.grey)),
                  const SizedBox(
                      height: 4),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight:
                          FontWeight
                              .w600)),
                  const SizedBox(
                      height: 24),

                  const Text("내용",
                      style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          color:
                          Colors.grey)),
                  const SizedBox(
                      height: 4),
                  Text(text),
                  const SizedBox(
                      height: 24),

                  Text(
                      "vessel code: $vesselCode    bay: $bay"),
                  const SizedBox(
                      height: 12),

                  Text(
                      "target: ${isHold ? "hold" : "deck"} / operation: ${isLD ? "선적" : "양하"}"),

                  const SizedBox(
                      height: 40),
                ],
              ),
            ),
          ),

          if (isDeleting)
            Container(
              color: Colors.black26,
              child: const Center(
                child:
                CircularProgressIndicator(),
              ),
            )
        ],
      ),
    );
  }
}