import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'gig_list_widget.dart';
import 'applied_gigs_screen.dart';
import 'chat_list_screen.dart'; // Import màn hình chat list
import 'user_management_screen.dart'; // Import màn hình quản lý người dùng
import 'admin/admin_dashboard_screen.dart';
import 'admin_gig_list_screen.dart'; // Thêm lại import cho màn hình quản lý Gigs

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Index của tab hiện tại
  String _userRole = 'worker'; // Mặc định là worker
  bool _isLoading = true;

  List<Widget> _pages = [];
  List<String> _pageTitles = [];
  List<BottomNavigationBarItem> _navBarItems = [];

  @override
  void initState() {
    super.initState();
    _fetchUserRoleAndSetupUI();
  }

  Future<void> _fetchUserRoleAndSetupUI() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userRole = doc.data()?['role'] ?? 'worker';
        });
      }
    }
    _setupUIBasedOnRole();
    setState(() {
      _isLoading = false;
    });
  }

  void _setupUIBasedOnRole() {
    if (_userRole == 'admin') {
      _pageTitles = ['Dashboard', 'Quản lý Gigs', 'Quản lý Người dùng'];
      _pages = [AdminDashboardScreen(), AdminGigListScreen(), UserManagementScreen()];
      _navBarItems = [
        BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Gigs'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
      ];
    } else { // Giao diện cho người dùng thường
      _pageTitles = ['Tìm kiếm', 'Quản lý', 'Chat', 'Hồ sơ'];
      _pages = [GigListWidget(), AppliedGigsScreen(), ChatListScreen(), ProfileScreen()];
      _navBarItems = [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize_outlined), label: 'Quản lý'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hồ sơ'),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Hàm để xử lý đăng xuất
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      // Admin có AppBar riêng trong từng tab, user thì dùng AppBar chung
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        actions: [
          if (_userRole == 'admin')
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => _signOut(context),
              tooltip: 'Đăng xuất',
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      // Chỉ hiển thị nút đăng gig cho người dùng thường ở tab đầu tiên
      floatingActionButton: (_userRole == 'worker' && _selectedIndex == 0) ? FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/post_gig'),
        child: Icon(Icons.add),
        tooltip: 'Đăng Gig mới',
      ) : null,
      bottomNavigationBar: BottomNavigationBar(
        items: _navBarItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Đảm bảo thanh nav không bị trắng
        backgroundColor: Theme.of(context).primaryColor, // Thêm dòng này để đặt màu nền
        selectedItemColor: Colors.white, // Màu của mục đang được chọn
        unselectedItemColor: Colors.white70, // Màu của các mục khác
      ),
    );
  }
}