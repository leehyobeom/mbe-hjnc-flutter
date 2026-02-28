import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class UpdatePage extends StatefulWidget {
  final String communityId;

  const UpdatePage({super.key, required this.communityId});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final Dio dio = Dio();
  final ImagePicker picker = ImagePicker();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController textController = TextEditingController();
  final TextEditingController vesselController = TextEditingController();
  final TextEditingController bayController = TextEditingController();

  List<Object> images = []; // String (서버) + XFile (로컬)
  Map<XFile, Uint8List> webImageBytes = {}; // 웹용 바이트 저장

  List<String> deletedImages = [];

  bool isHold = true;
  bool isLD = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  /// ==============================
  /// 상세 조회
  /// ==============================
  Future<void> fetchDetail() async {
    final backUrl = dotenv.env['BACK_URL'];

    final response = await dio.put(
      "$backUrl/community/read",
      data: {"communityId": widget.communityId},
    );

    final data = response.data['result'];

    titleController.text = data['title'] ?? "";
    textController.text = data['text'] ?? "";
    vesselController.text = data['vesselCode'] ?? "";
    bayController.text = data['bay'] ?? "";
    isHold = data['isHold'] ?? true;
    isLD = data['isLD'] ?? true;

    images = [];
    final serverImages = data['images'] ?? [];
    for (var img in serverImages) {
      images.add(img);
    }

    setState(() => isLoading = false);
  }

  /// ==============================
  /// 이미지 선택
  /// ==============================
  Future<void> pickImages() async {
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    for (var file in picked) {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        webImageBytes[file] = bytes;
      }
      images.add(file);
    }

    setState(() {});
  }

  /// ==============================
  /// 이미지 삭제
  /// ==============================
  void removeImage(int index) {
    final img = images[index];

    if (img is String) {
      deletedImages.add(img);
    } else if (img is XFile && kIsWeb) {
      webImageBytes.remove(img);
    }

    images.removeAt(index);
    setState(() {});
  }

  /// ==============================
  /// 순서 변경
  /// ==============================
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;

    final item = images.removeAt(oldIndex);
    images.insert(newIndex, item);

    setState(() {});
  }

  /// ==============================
  /// 수정 제출
  /// ==============================
  Future<void> submitUpdate() async {
    final backUrl = dotenv.env['BACK_URL'];

    try {
      setState(() => isLoading = true);

      List<Map<String, dynamic>> changedImages = [];
      List<MultipartFile> newFiles = [];

      for (int i = 0; i < images.length; i++) {
        final img = images[i];

        if (img is String && img.isNotEmpty) {
          changedImages.add({
            "index": i,
            "url": img,
          });
        } else if (img is XFile) {
          if (kIsWeb) {
            newFiles.add(
              MultipartFile.fromBytes(
                webImageBytes[img]!,
                filename: img.name,
              ),
            );
          } else {
            newFiles.add(
              await MultipartFile.fromFile(
                img.path,
                filename: img.name,
              ),
            );
          }
        }
      }

      FormData formData = FormData.fromMap({
        "communityId": widget.communityId,
        "title": titleController.text,
        "text": textController.text,
        "vesselCode": vesselController.text,
        "bay": bayController.text,
        "isHold": isHold.toString(),
        "isLD": isLD.toString(),
        "deletedImages": jsonEncode(deletedImages),
        "changedImages": jsonEncode(changedImages),
      });

      for (var file in newFiles) {
        formData.files.add(MapEntry("files", file));
      }

      await dio.put(
        "$backUrl/community/update",
        data: formData,
        options: Options(contentType: "multipart/form-data"),
      );

      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("수정 완료")),
        );
        Navigator.pop(context, true);
      }
    } on DioException {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("업데이트 실패")),
      );
    }
  }

  /// ==============================
  /// UI
  /// ==============================
  @override
  Widget build(BuildContext context) {
    final backUrl = dotenv.env['BACK_URL'];

    return Scaffold(
      appBar: AppBar(title: const Text("수정")),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              children: [
                ReorderableGridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length + 1,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  onReorder: reorder,
                  itemBuilder: (context, index) {
                    if (index == images.length) {
                      return GestureDetector(
                        key: const ValueKey("add_button"),
                        onTap: pickImages,
                        child: Container(
                          color: Colors.grey[300],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add),
                              SizedBox(height: 4),
                              Text("Add Image")
                            ],
                          ),
                        ),
                      );
                    }

                    final img = images[index];
                    Widget imageWidget;

                    if (img is String) {
                      imageWidget = Image.network(
                        "$backUrl/$img",
                        fit: BoxFit.cover,
                      );
                    } else if (img is XFile) {
                      imageWidget = kIsWeb
                          ? Image.memory(
                        webImageBytes[img]!,
                        fit: BoxFit.cover,
                      )
                          : Image.file(
                        File(img.path),
                        fit: BoxFit.cover,
                      );
                    } else {
                      imageWidget = const SizedBox();
                    }

                    return Stack(
                      key: ValueKey(img.toString() + index.toString()),
                      children: [
                        Positioned.fill(child: imageWidget),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () => removeImage(index),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "제목"),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: "내용"),
                  maxLines: 5,
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: vesselController,
                  decoration:
                  const InputDecoration(labelText: "Vessel Code"),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: bayController,
                  decoration: const InputDecoration(labelText: "Bay"),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    const Text("Operation: "),
                    Radio<bool>(
                      value: true,
                      groupValue: isLD,
                      onChanged: (v) => setState(() => isLD = v!),
                    ),
                    const Text("선적"),
                    Radio<bool>(
                      value: false,
                      groupValue: isLD,
                      onChanged: (v) => setState(() => isLD = v!),
                    ),
                    const Text("양하"),
                  ],
                ),

                Row(
                  children: [
                    const Text("Target: "),
                    Radio<bool>(
                      value: true,
                      groupValue: isHold,
                      onChanged: (v) => setState(() => isHold = v!),
                    ),
                    const Text("홀드"),
                    Radio<bool>(
                      value: false,
                      groupValue: isHold,
                      onChanged: (v) => setState(() => isHold = v!),
                    ),
                    const Text("데크"),
                  ],
                ),
              ],
            ),
          ),

          if (isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: isLoading ? null : submitUpdate,
              child: const Text(
                "수정 완료",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}