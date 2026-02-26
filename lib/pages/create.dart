import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final ImagePicker _picker = ImagePicker();
  final Dio dio = Dio();

  List<XFile> images = [];
  bool isUploading = false;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController vesselController = TextEditingController();
  final TextEditingController bayController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  String selectedType = "선적";
  String selectedLocation = "홀드";

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    if (images.length + picked.length > 9) {
      Fluttertoast.showToast(msg: "최대 9장까지 업로드 가능합니다.");
      return;
    }

    setState(() {
      images.addAll(picked);
    });
  }

  void removeImage(int index) {
    setState(() {
      images.removeAt(index);
    });
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < images.length && newIndex < images.length) {
      final item = images.removeAt(oldIndex);
      images.insert(newIndex, item);
      setState(() {});
    }
  }

  Future<void> uploadCommunity() async {
    final backUrl = dotenv.env['BACK_URL'];

    if (backUrl == null) {
      print("BACK_URL 없음");
      return;
    }

    try {
      setState(() => isUploading = true);

      final dio = Dio();

      List<MultipartFile> imageFiles = [];

      for (var img in images) {
        imageFiles.add(
          await MultipartFile.fromFile(
            img.path,
            filename: img.name,
          ),
        );
      }

      final formData = FormData.fromMap({
        "title": titleController.text,
        "text": contentController.text,
        "vesselCode": vesselController.text,
        "bay": bayController.text,

        // ⚠ multipart는 문자열로 들어가니까
        "isHold": selectedLocation == "홀드" ? "true" : "false",
        "isLD": selectedType == "선적" ? "true" : "false",
        "files": imageFiles,
      });

      print("=== REQUEST URL ===");
      print("$backUrl/community/create");

      final response = await dio.put(
        "$backUrl/community/create",
        data: formData,
        options: Options(
          contentType: "multipart/form-data",
          validateStatus: (status) => true, // 400도 응답 받게
        ),
      );

      print("=== RESPONSE ===");
      print("STATUS: ${response.statusCode}");
      print("DATA: ${response.data}");

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("업로드 성공")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("업로드 실패")),
        );
      }

    } catch (e) {
      print("업로드 예외 발생: $e");
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [

            /// 뒤로가기
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            /// 이미지 Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: ReorderableGridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length < 9 ? images.length + 1 : 9,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  onReorder: reorder,
                  itemBuilder: (context, index) {

                    if (index == images.length && images.length < 9) {
                      return Container(
                        key: const ValueKey("add_button"),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: pickImages,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 30),
                              SizedBox(height: 6),
                              Text("Add Image",
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }

                    return Stack(
                      key: ValueKey(images[index].path),
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(images[index].path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => removeImage(index),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            /// 입력폼
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  const SizedBox(height: 20),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "제목",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: vesselController,
                          decoration: const InputDecoration(
                            labelText: "Vessel Code",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: bayController,
                          decoration: const InputDecoration(
                            labelText: "Bay",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: "내용",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text("작업 구분"),
                  Row(
                    children: [
                      Radio(
                        value: "선적",
                        groupValue: selectedType,
                        onChanged: (value) =>
                            setState(() => selectedType = value!),
                      ),
                      const Text("선적"),
                      Radio(
                        value: "양하",
                        groupValue: selectedType,
                        onChanged: (value) =>
                            setState(() => selectedType = value!),
                      ),
                      const Text("양하"),
                    ],
                  ),
                  const SizedBox(height: 10),

                  const Text("위치"),
                  Row(
                    children: [
                      Radio(
                        value: "홀드",
                        groupValue: selectedLocation,
                        onChanged: (value) =>
                            setState(() => selectedLocation = value!),
                      ),
                      const Text("홀드"),
                      Radio(
                        value: "데크",
                        groupValue: selectedLocation,
                        onChanged: (value) =>
                            setState(() => selectedLocation = value!),
                      ),
                      const Text("데크"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: isUploading ? null : uploadCommunity,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: isUploading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text("업로드"),
                  ),

                  const SizedBox(height: 50),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}