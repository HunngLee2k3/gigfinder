import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart'; // Tạo file này sau

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CollectionReference gigs = FirebaseFirestore.instance.collection('gigs');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedIndex = 0; // Index của tab hiện tại
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late List<Widget> _pages; // Declare as late

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildGigList(), // Now safe to call instance method
      ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> applyForGig(BuildContext context, dynamic gig) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng đăng nhập để áp dụng!')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('applied_gigs')
          .doc(gig.id)
          .set({
            'gig_id': gig.id,
            'title': gig['title'],
            'price': gig['price'],
            'location': gig['location'],
            'applied_at': FieldValue.serverTimestamp(),
          });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Áp dụng gig thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Widget _buildGigList() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Tìm gig...',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: gigs.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('Không có gig nào'));
              }
              var filteredGigs = snapshot.data!.docs.where((doc) {
                var title = doc['title']?.toString().toLowerCase() ?? '';
                var location = doc['location']?.toString().toLowerCase() ?? '';
                return title.contains(_searchQuery) || location.contains(_searchQuery);
              }).toList();

              return ListView.builder(
                itemCount: filteredGigs.length,
                itemBuilder: (context, index) {
                  var gig = filteredGigs[index];
                  return ListTile(
                    title: Text(gig['title'] ?? 'No Title'),
                    subtitle: Text('${gig['price'] ?? '0'} - ${gig['location'] ?? 'N/A'}'),
                    trailing: ElevatedButton(
                      child: Text('Apply'),
                      onPressed: () => applyForGig(context, gig),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/detail', arguments: gig);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gig Finder'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              // Filter logic sẽ thêm sau
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex], // Hiển thị trang hiện tại
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}