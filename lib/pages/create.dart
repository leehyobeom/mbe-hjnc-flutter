import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> images = [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [

            /// 🔙 뒤로가기
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            /// 📸 이미지 Grid
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

                    /// ➕ Add 버튼
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
                              Text(
                                "Add Image",
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    /// 📸 이미지 카드
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

            /// 📄 입력 폼
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),

                  /// 제목
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "제목",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Vessel + Bay (3:1)
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

                  /// 내용
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: "내용",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// 선적 / 양하
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

                  /// 홀드 / 데크
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