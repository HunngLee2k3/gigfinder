import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _momoPhoneController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true; // Dùng cho việc tải dữ liệu ban đầu
  bool _isSaving = false; // Dùng cho quá trình lưu
  File? _avatarFile;
  String? _existingAvatarUrl;
  final ImagePicker _picker = ImagePicker();

  // THAY THẾ CÁC GIÁ TRỊ NÀY BẰNG THÔNG TIN CỦA BẠN
  final cloudinary = CloudinaryPublic(
    'dfs1bwlez',      // <<== Thay bằng Cloud Name của bạn
    'gig_finder_preset',   // <<== Thay bằng Upload Preset Name của bạn
  );


  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        _momoPhoneController.text = data['momo_phone'] ?? '';
        _existingAvatarUrl = data['avatar_url'];
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickAvatar() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadAvatarToCloudinary(File image) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      print('Lỗi khi tải ảnh đại diện: $e');
      rethrow;
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });
      try {
        String? newAvatarUrl;
        if (_avatarFile != null) {
          newAvatarUrl = await _uploadAvatarToCloudinary(_avatarFile!);
        }

        final dataToUpdate = {
          'name': _nameController.text.trim(),
          'momo_phone': _momoPhoneController.text.trim(),
          if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
        };

        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update(dataToUpdate);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi cập nhật: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _momoPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chỉnh sửa hồ sơ'),
      ),
      body: _isLoading || _isSaving
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16.0),
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : (_existingAvatarUrl != null
                                  ? NetworkImage(_existingAvatarUrl!)
                                  : null) as ImageProvider?,
                          child: _avatarFile == null && _existingAvatarUrl == null
                              ? Icon(Icons.person, size: 60, color: Colors.grey.shade700)
                              : null,
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            onPressed: _pickAvatar,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'Họ Tên', border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Vui lòng nhập họ tên' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _momoPhoneController,
                    decoration: InputDecoration(labelText: 'Số MoMo', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(onPressed: _saveProfile, child: Text('Lưu thay đổi')),
                ],
              ),
            ),
    );
  }
}