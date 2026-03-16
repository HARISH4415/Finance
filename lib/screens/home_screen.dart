import 'package:finance2/screens/tabs/add_customer_tab.dart';
import 'package:finance2/screens/tabs/dashboard_tab.dart';
import 'package:finance2/screens/tabs/profile_tab.dart';
import 'package:finance2/services/excel_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request SMS and Phone permissions on startup
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.phone,
    ].request();
    
    if (statuses[Permission.sms]!.isPermanentlyDenied) {
      // If permanently denied, guide user to settings
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text('SMS permission is required to send payment codes. Please enable it in settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onCustomerAdded() {
    setState(() {
      _selectedIndex = 0; // Go back to dashboard to see new customer
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const DashboardTab(),
      AddCustomerTab(onSuccess: _onCustomerAdded),
      const ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          letterSpacing: 1.2,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.blue),
            tooltip: 'Import Excel',
            onPressed: () async {
              final count = await ExcelService.importCustomersFromExcel();
              if (mounted && count > 0) {
                _onCustomerAdded();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported $count customers')),
                );
              } else if (mounted && count == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No data imported or cancelled')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_view, color: Colors.green),
            onPressed: () async {
              final path = await ExcelService.exportCustomersToExcel();
              if (mounted) {
                if (path != null) {
                  await Share.shareXFiles([
                    XFile(path),
                  ], text: 'finance2 Customer Export');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to export or no data'),
                    ),
                  );
                }
              }
            },
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Add Customer',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
