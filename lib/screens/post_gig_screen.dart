import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class PostGigScreen extends StatefulWidget {
  // Thêm gig tùy chọn để chỉnh sửa
  final DocumentSnapshot? gigToEdit;

  PostGigScreen({this.gigToEdit});

  @override
  _PostGigScreenState createState() => _PostGigScreenState();
}

class _PostGigScreenState extends State<PostGigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isUploadingImage = false; // Trạng thái mới để theo dõi việc tải ảnh
  File? _imageFile;
  String? _existingImageUrl; // Lưu URL ảnh cũ khi chỉnh sửa
  final ImagePicker _picker = ImagePicker();
  
  // THAY THẾ CÁC GIÁ TRỊ NÀY BẰNG THÔNG TIN CỦA BẠN
  final cloudinary = CloudinaryPublic(
    'dfs1bwlez',      // <<== Thay bằng Cloud Name của bạn
    'gig_finder_preset',   // <<== Thay bằng Upload Preset Name của bạn
  );

  @override
  void initState() {
    super.initState();
    // Nếu đang chỉnh sửa, điền dữ liệu cũ vào các trường
    if (widget.gigToEdit != null) {
      final data = widget.gigToEdit!.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _priceController.text = (data['price'] ?? 0).toString();
      _locationController.text = data['location'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      if (data.containsKey('image_url') && data['image_url'] != null) {
        _existingImageUrl = data['image_url'];
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToCloudinary(File image) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image),
      );
      // Nếu không có lỗi, thư viện sẽ trả về một response chứa secureUrl.
      // Nếu có lỗi, nó sẽ ném ra một Exception và được bắt ở khối catch bên dưới.
      return response.secureUrl;
    } catch (e) {
      // In lỗi ra terminal để bạn có thể thấy
      print('Lỗi khi tải ảnh: $e');
      // Ném lại lỗi để hàm _submitGig có thể bắt được
      rethrow;
    }
  }

  Future<void> _submitGig() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bạn cần đăng nhập để đăng gig.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      try {
        String? imageUrl;
        // 1. Xử lý tải ảnh và cập nhật UI
        if (_imageFile != null) {
          setState(() {
            _isUploadingImage = true; // Bắt đầu tải ảnh
          });
          imageUrl = await _uploadImageToCloudinary(_imageFile!);
          setState(() {
            _isUploadingImage = false; // Kết thúc tải ảnh
          });
        }

        // 2. Bắt đầu trạng thái loading chung để lưu gig
        setState(() {
          _isLoading = true;
        });
        if (_imageFile != null && imageUrl == null) {
          throw Exception('Không thể lấy được URL ảnh sau khi tải lên.');
        }

        final gigData = {
          'title': _titleController.text.trim(),
          'price': num.tryParse(_priceController.text.trim()) ?? 0,
          'location': _locationController.text.trim(),
          'description': _descriptionController.text.trim(),
          // Nếu có ảnh mới thì dùng, không thì giữ ảnh cũ
          'image_url': imageUrl ?? _existingImageUrl,
        };

        if (widget.gigToEdit == null) {
          // Tạo gig mới
          await FirebaseFirestore.instance.collection('gigs').add({
            ...gigData,
            'poster_uid': user.uid,
            'created_at': FieldValue.serverTimestamp(),
            'status': 'open', // Trạng thái mặc định khi tạo mới
          });
        } else {
          // Cập nhật gig cũ
          await FirebaseFirestore.instance.collection('gigs').doc(widget.gigToEdit!.id).update(gigData);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.gigToEdit == null ? 'Đăng gig thành công!' : 'Cập nhật gig thành công!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          // Đảm bảo các trạng thái loading được tắt khi có lỗi
          setState(() {
            _isUploadingImage = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi đăng gig: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gigToEdit == null ? 'Đăng một Gig mới' : 'Chỉnh sửa Gig'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16.0),
                children: [
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _pickImage, // Không cho chọn ảnh khi đang tải
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: _imageFile != null
                              ? ClipRRect( // Hiển thị ảnh mới chọn
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                                )
                              : _existingImageUrl != null
                                ? ClipRRect( // Hiển thị ảnh cũ khi chỉnh sửa
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(_existingImageUrl!, fit: BoxFit.cover),
                                  )
                                : Column( // Placeholder mặc định
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: Colors.grey[700], size: 50),
                                    Text('Thêm ảnh cho Gig', style: TextStyle(color: Colors.grey[700])),
                                  ],
                                ),
                        ),
                        if (_isUploadingImage)
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                            child: Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: 'Tiêu đề', border: OutlineInputBorder()),
                    validator: (value) => value!.trim().isEmpty ? 'Vui lòng nhập tiêu đề' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(labelText: 'Giá (VNĐ)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Vui lòng nhập giá' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(labelText: 'Địa điểm', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Vui lòng nhập địa điểm' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: 'Mô tả chi tiết', border: OutlineInputBorder()),
                    maxLines: 5,
                    validator: (value) => value!.isEmpty ? 'Vui lòng nhập mô tả' : null,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _submitGig,
                    icon: Icon(Icons.post_add),
                    label: Text(widget.gigToEdit == null ? 'Đăng Gig' : 'Lưu thay đổi'),
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                  ),
                  
                ],
              ),
            ),
    );
  }
}