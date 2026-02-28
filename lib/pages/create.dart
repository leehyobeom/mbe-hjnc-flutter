import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  List<Uint8List> webImages = []; // 웹용 이미지 바이트
  bool isUploading = false;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController vesselController = TextEditingController();
  final TextEditingController bayController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  String selectedType = "선적";
  String selectedLocation = "홀드";

  /// ==============================
  /// 이미지 선택
  /// ==============================
  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;

    if (images.length + picked.length > 9) {
      Fluttertoast.showToast(msg: "최대 9장까지 업로드 가능합니다.");
      return;
    }

    if (kIsWeb) {
      for (var file in picked) {
        final bytes = await file.readAsBytes();
        webImages.add(bytes);
        images.add(file);
      }
    } else {
      images.addAll(picked);
    }

    setState(() {});
  }

  /// ==============================
  /// 이미지 삭제
  /// ==============================
  void removeImage(int index) {
    images.removeAt(index);
    if (kIsWeb) {
      webImages.removeAt(index);
    }
    setState(() {});
  }

  /// ==============================
  /// 이미지 순서 변경
  /// ==============================
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > images.length) newIndex = images.length;

    final img = images.removeAt(oldIndex);
    images.insert(newIndex, img);

    if (kIsWeb) {
      final bytes = webImages.removeAt(oldIndex);
      webImages.insert(newIndex, bytes);
    }

    setState(() {});
  }

  /// ==============================
  /// 업로드
  /// ==============================
  Future<void> uploadCommunity() async {
    final backUrl = dotenv.env['BACK_URL'];
    if (backUrl == null) {
      print("BACK_URL 없음");
      return;
    }

    try {
      setState(() => isUploading = true);

      List<MultipartFile> imageFiles = [];

      for (int i = 0; i < images.length; i++) {
        if (kIsWeb) {
          imageFiles.add(
            MultipartFile.fromBytes(
              webImages[i],
              filename: images[i].name,
            ),
          );
        } else {
          imageFiles.add(
            await MultipartFile.fromFile(
              images[i].path,
              filename: images[i].name,
            ),
          );
        }
      }

      final formData = FormData.fromMap({
        "title": titleController.text,
        "text": contentController.text,
        "vesselCode": vesselController.text,
        "bay": bayController.text,
        "isHold": selectedLocation == "홀드" ? "true" : "false",
        "isLD": selectedType == "선적" ? "true" : "false",
        "files": imageFiles,
      });

      final response = await dio.put(
        "$backUrl/community/create",
        data: formData,
        options: Options(
          contentType: "multipart/form-data",
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("업로드 성공")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("업로드 실패 (${response.statusCode})")),
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

  /// ==============================
  /// UI
  /// ==============================
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
                      key: ValueKey(images[index].name + index.toString()),
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: kIsWeb
                                ? Image.memory(
                              webImages[index],
                              fit: BoxFit.cover,
                            )
                                : Image.file(
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