import 'package:flutter/material.dart';
import 'deposit_requests_widget.dart';
import 'withdrawal_requests_widget.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column( // Thay Scaffold bằng Column để tích hợp vào HomeScreen
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Yêu cầu nạp tiền'),
              Tab(text: 'Yêu cầu rút tiền'),
            ],
          ),
          Expanded( // Bọc TabBarView trong Expanded để nó lấp đầy không gian còn lại
            child: TabBarView(
              children: [
                DepositRequestsWidget(),
                WithdrawalRequestsWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}