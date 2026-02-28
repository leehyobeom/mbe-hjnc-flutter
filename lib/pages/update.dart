import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  List<String> deletedImages = [];

  bool isHold = true;
  bool isLD = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

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

  Future<void> pickImages() async {
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        images.addAll(picked);
      });
    }
  }

  void removeImage(int index) {
    final img = images[index];

    if (img is String) {
      deletedImages.add(img);
    }

    setState(() {
      images.removeAt(index);
    });
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;

    setState(() {
      final item = images.removeAt(oldIndex);
      images.insert(newIndex, item);
    });
  }

  Future<void> submitUpdate() async {
    final backUrl = dotenv.env['BACK_URL'];

    try {
      setState(() => isLoading = true);

      List<Map<String, dynamic>> changedImages = [];
      List<MultipartFile> newFiles = [];

      // 현재 화면 순서 그대로 index 부여
      for (int i = 0; i < images.length; i++) {
        final img = images[i];

        if (img is String && img.isNotEmpty) {
          changedImages.add({
            "index": i,
            "url": img,
          });
        } else if (img is XFile) {
          newFiles.add(
            await MultipartFile.fromFile(
              img.path,
              filename: img.name,
            ),
          );
        }
      }

      FormData formData = FormData();

      formData.fields.add(MapEntry("communityId", widget.communityId));
      formData.fields.add(MapEntry("title", titleController.text));
      formData.fields.add(MapEntry("text", textController.text));
      formData.fields.add(MapEntry("vesselCode", vesselController.text));
      formData.fields.add(MapEntry("bay", bayController.text));
      formData.fields.add(MapEntry("isHold", isHold.toString()));
      formData.fields.add(MapEntry("isLD", isLD.toString()));

      formData.fields.add(
        MapEntry("deletedImages", jsonEncode(deletedImages)),
      );

      formData.fields.add(
        MapEntry("changedImages", jsonEncode(changedImages)),
      );

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

    } on DioException catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("업데이트 실패")),
      );
    }
  }

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
                      imageWidget = Image.file(
                        File(img.path),
                        fit: BoxFit.cover,
                      );
                    } else {
                      imageWidget = const SizedBox();
                    }

                    return Stack(
                      key: ValueKey(img.toString()),
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