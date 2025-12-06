import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GigListWidget extends StatefulWidget {
  @override
  _GigListWidgetState createState() => _GigListWidgetState();
}

class _GigListWidgetState extends State<GigListWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RangeValues? _selectedPriceRange;
  String _locationFilter = '';
  double _maxPrice = 1000.0; // Giá trị mặc định, sẽ được cập nhật
  Set<String> _appliedGigIds = {}; // Set để lưu ID các gig đã ứng tuyển

  @override
  void initState() {
    super.initState();
    _fetchAppliedGigs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Lấy danh sách các gig đã ứng tuyển khi widget được khởi tạo
  Future<void> _fetchAppliedGigs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('applied_gigs')
        .get();
    
    final ids = snapshot.docs.map((doc) => doc.id).toSet();
    if (mounted) setState(() => _appliedGigIds = ids);
  }

  Future<void> applyForGig(BuildContext context, DocumentSnapshot gig) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng đăng nhập để áp dụng!')),
      );
      return;
    }
    if (currentUser.uid == gig['poster_uid']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bạn không thể ứng tuyển vào gig của chính mình.')),
      );
      return;
    }
    try {
      // Lấy thông tin chi tiết của worker hiện tại
      final workerDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (!workerDoc.exists) {
        throw Exception('Không tìm thấy thông tin người dùng của bạn.');
      }
      final workerData = workerDoc.data() as Map<String, dynamic>;

      // 1. Ghi vào sub-collection 'applied_gigs' của worker (như cũ)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('applied_gigs')
          .doc(gig.id)
          .set({
        'gig_id': gig.id,
        'title': gig['title'],
        'price': gig['price'],
        'location': gig['location'],
        'applied_at': FieldValue.serverTimestamp(),
      });

      // 2. Ghi vào sub-collection 'applicants' của gig
      await FirebaseFirestore.instance
          .collection('gigs')
          .doc(gig.id)
          .collection('applicants')
          .doc(currentUser.uid) // Sử dụng UID của worker làm ID document
          .set({
        'worker_uid': currentUser.uid,
        'worker_name': workerData['name'] ?? 'N/A',
        'worker_email': currentUser.email ?? 'N/A',
        'worker_rating': workerData['rating'] ?? 0.0,
        'applied_at': FieldValue.serverTimestamp(),
      });

      // Cập nhật UI ngay lập tức
      if (mounted) {
        setState(() => _appliedGigIds.add(gig.id));
      }

      // Hiển thị dialog thông báo thành công thay vì SnackBar
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Thành công!'),
              content: Text('Bạn đã ứng tuyển thành công vào gig "${gig['title']}".'),
              actions: <Widget>[
                TextButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  void _showFilterDialog(double maxPrice) {
    showDialog(
      context: context,
      builder: (context) {
        // Sử dụng StatefulWidgetBuilder để quản lý trạng thái của RangeSlider trong dialog
        RangeValues currentRange = _selectedPriceRange ?? RangeValues(0, maxPrice);
        final locationController = TextEditingController(text: _locationFilter);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Bộ lọc nâng cao'),
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Giá', style: TextStyle(fontWeight: FontWeight.bold)),
                  RangeSlider(
                    values: currentRange,
                    min: 0,
                    max: maxPrice,
                    divisions: maxPrice > 0 ? maxPrice.toInt() ~/ 10 : 1,
                    labels: RangeLabels(
                      '${currentRange.start.round()}',
                      '${currentRange.end.round()}',
                    ),
                    onChanged: (values) {
                      setDialogState(() {
                        currentRange = values;
                      });
                    },
                  ),
                  Text('Từ: ${currentRange.start.round()} - Đến: ${currentRange.end.round()}'),
                  SizedBox(height: 20),
                  Text('Địa điểm', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(labelText: 'Nhập địa điểm', border: OutlineInputBorder()),
                    onChanged: (value) {},
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedPriceRange = currentRange;
                      _locationFilter = locationController.text;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('Áp dụng'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController, // ... (giữ nguyên)
            decoration: InputDecoration( // ... (giữ nguyên)
              labelText: 'Tìm theo tiêu đề...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: (_selectedPriceRange != null || _locationFilter.isNotEmpty) ? Theme.of(context).primaryColor : null,
                    ),
                    onPressed: () => _showFilterDialog(_maxPrice),
                  ),
                  if (_selectedPriceRange != null || _locationFilter.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.filter_alt_off_outlined, color: Colors.redAccent),
                      onPressed: () => setState(() {
                        _selectedPriceRange = null;
                        _locationFilter = '';
                      }),
                    ),
                ],
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Chỉ lấy các gig đang ở trạng thái 'open'
            stream: FirebaseFirestore.instance
                .collection('gigs')
                .where('status', isEqualTo: 'open')
                .snapshots(),
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

              // Cập nhật giá trị maxPrice từ dữ liệu
              final allGigs = snapshot.data!.docs;
              if (allGigs.isNotEmpty) {
                _maxPrice = allGigs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  final priceValue = data?['price'];
                  if (priceValue is num) {
                    return priceValue.toDouble();
                  }
                  if (priceValue is String) {
                    return double.tryParse(priceValue) ?? 0.0;
                  }
                  return 0.0;
                }).reduce((a, b) => a > b ? a : b);
              }

              // Lọc dữ liệu
              var filteredGigs = allGigs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                // Lọc theo tìm kiếm
                final title = (data['title']?.toString() ?? '').toLowerCase();
                final matchesSearch = title.contains(_searchQuery);

                // Lọc theo địa điểm từ dialog
                final location = (data['location']?.toString() ?? '').toLowerCase();
                final matchesLocation = _locationFilter.isEmpty || location.contains(_locationFilter.toLowerCase());
                
                // Lọc theo giá
                final priceValue = data['price'];
                double price = 0.0;
                if (priceValue is num) {
                  price = priceValue.toDouble();
                } else if (priceValue is String) {
                  price = double.tryParse(priceValue) ?? 0.0;
                }

                final matchesPrice = _selectedPriceRange == null ||
                    (price >= _selectedPriceRange!.start && price <= _selectedPriceRange!.end);

                return matchesSearch && matchesLocation && matchesPrice;
              }).toList();

              if (filteredGigs.isEmpty) {
                return Center(child: Text('Không tìm thấy gig phù hợp'));
              }

              return ListView.builder(
                itemCount: filteredGigs.length,
                itemBuilder: (context, index) {
                  var gig = filteredGigs[index];
                  final data = gig.data() as Map<String, dynamic>;
                  final isOwner = FirebaseAuth.instance.currentUser?.uid == data['poster_uid'];
                  final hasApplied = _appliedGigIds.contains(gig.id);
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, '/detail', arguments: gig),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(0), // Đặt padding về 0 cho Card
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                              child: data.containsKey('image_url') && data['image_url'] != null
                                  ? Image.network(
                                      data['image_url']!,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(height: 150, color: Colors.grey[300], child: Icon(Icons.image_not_supported)),
                                    )
                                  : Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.work, size: 50, color: Colors.grey[600]),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'No Title',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '${data['price'] ?? '0'} VNĐ - ${data['location'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                                  ),
                                  SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: (isOwner || hasApplied) ? null : () => applyForGig(context, gig),
                                      child: Text(
                                        isOwner 
                                          ? 'Bạn là người đăng' 
                                          : hasApplied 
                                            ? 'Đã ứng tuyển' 
                                            : 'Apply'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}