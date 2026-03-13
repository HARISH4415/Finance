import 'dart:convert';
import 'dart:math';

import 'package:finance2/services/customer_service.dart';
import 'package:finance2/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerIndex;
  final Map<dynamic, dynamic> customerData;

  const CustomerDetailScreen({
    super.key,
    required this.customerIndex,
    required this.customerData,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late List<int> _paidWeeks;
  late Map<String, double> _paymentAmounts;
  late int _totalWeeks;
  late double _weeklyPayment;
  late double _givenAmount;
  static const platform = MethodChannel('com.example.finance2/sms');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final payments = widget.customerData['payments'];
    if (payments != null) {
      _paidWeeks = List<int>.from(payments);
    } else {
      _paidWeeks = [];
    }

    final amounts = widget.customerData['paymentAmounts'];
    if (amounts != null && amounts is Map) {
      _paymentAmounts = Map<String, double>.from(
        amounts.map(
          (k, v) => MapEntry(k.toString(), double.parse(v.toString())),
        ),
      );
    } else {
      _paymentAmounts = {};
    }

    _totalWeeks = int.tryParse(widget.customerData['weeks'].toString()) ?? 0;
    _weeklyPayment =
        double.tryParse(widget.customerData['weeklyPayment'].toString()) ?? 0;
    _givenAmount =
        double.tryParse(widget.customerData['givenAmount'].toString()) ?? 0;
  }

  Future<void> _initiatePayment(int weekIndex) async {
    if (_paidWeeks.contains(weekIndex)) {
      await _togglePayment(weekIndex, 0);
      return;
    }

    double amountToPay = _weeklyPayment;

    final bool? isCustom = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(LocalizationService.translate(context, 'weekly_payment')),
          content: const Text('Choose payment amount'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Full Weekly (₹${_weeklyPayment.toStringAsFixed(0)})',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(LocalizationService.translate(context, 'customize')),
            ),
          ],
        );
      },
    );

    if (isCustom == null) return;

    if (isCustom) {
      final customAmountController = TextEditingController(
        text: _weeklyPayment.toStringAsFixed(0),
      );
      final customResult = await showDialog<double>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(LocalizationService.translate(context, 'customize')),
              content: TextField(
                controller: customAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: LocalizationService.translate(context, 'amount'),
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(LocalizationService.translate(context, 'cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(customAmountController.text);
                    if (val != null && val > 0) {
                      Navigator.pop(context, val);
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
      );

      if (customResult == null) return;
      amountToPay = customResult;
    }

    final random = Random();
    final otp = (100000 + random.nextInt(900000)).toString();
    final phone = (widget.customerData['phone']?.toString() ?? '').replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final message =
        'finance2R: Code for Week ${weekIndex + 1} (Rs.${amountToPay.toStringAsFixed(0)}) is $otp.';

    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer phone number missing')),
        );
      }
      return;
    }

    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    // Also request phone state for dual-sim support reliability
    if (await Permission.phone.isDenied) {
      await Permission.phone.request();
    }

    if (status.isGranted) {
      try {
        await platform.invokeMethod('sendSMS', {
          'phone': phone,
          'message': message,
        });

        if (mounted) {
          _showOtpDialog(otp, weekIndex, amountToPay);
        }
      } on PlatformException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send SMS: ${e.message}')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS Permission Required')),
        );
      }
    }
  }

  void _showOtpDialog(String sentOtp, int weekIndex, double amount) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(LocalizationService.translate(context, 'enter_otp')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Code sent for Week ${weekIndex + 1} Payment (Rs.${amount.toStringAsFixed(0)})',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Enter 6-digit code',
                    border: OutlineInputBorder(),
                  ),
                ),
                Text(
                  'Debug: $sentOtp',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocalizationService.translate(context, 'cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  if (otpController.text == sentOtp) {
                    Navigator.pop(context);
                    _confirmPayment(weekIndex, amount);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid OTP')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  LocalizationService.translate(context, 'verify_pay'),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmPayment(int weekIndex, double amount) async {
    await _togglePayment(weekIndex, amount);

    double totalPaid = 0;
    for (var val in _paymentAmounts.values) {
      totalPaid += val;
    }

    final totalAmount =
        double.tryParse(widget.customerData['totalAmount'].toString()) ?? 0;
    final totalPending = totalAmount - totalPaid;

    final phone = (widget.customerData['phone']?.toString() ?? '').replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final weekNum = weekIndex + 1;

    final message =
        'Payment Successful for Week $weekNum! \n'
        'Paid: Rs.${amount.toStringAsFixed(0)} \n'
        'Total Paid: Rs.${totalPaid.toStringAsFixed(0)} \n'
        'Pending: Rs.${totalPending.toStringAsFixed(0)}';

    try {
      await platform.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Confirmed & SMS Sent!')),
        );
      }
    } catch (e) {
      debugPrint('Error sending confirmation SMS: $e');
    }
  }

  Future<void> _togglePayment(int weekIndex, double amount) async {
    setState(() {
      if (_paidWeeks.contains(weekIndex)) {
        _paidWeeks.remove(weekIndex);
        _paymentAmounts.remove(weekIndex.toString());
      } else {
        _paidWeeks.add(weekIndex);
        _paymentAmounts[weekIndex.toString()] = amount;
      }
      _paidWeeks.sort();
    });

    await CustomerService.updateCustomerPayment(
      widget.customerIndex,
      _paidWeeks,
      _paymentAmounts,
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Customer'),
            content: Text(
              'Are you sure you want to delete ${widget.customerData['name']}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocalizationService.translate(context, 'cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteCustomer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteCustomer() async {
    try {
      await CustomerService.deleteCustomer(widget.customerIndex);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalPaid = 0;
    _paymentAmounts.forEach((_, val) => totalPaid += val);

    for (var w in _paidWeeks) {
      if (!_paymentAmounts.containsKey(w.toString())) {
        totalPaid += _weeklyPayment;
      }
    }

    final totalAmount =
        double.tryParse(widget.customerData['totalAmount'].toString()) ?? 0;
    final totalPending = totalAmount - totalPaid;

    final List<int> pendingWeeksList = [];
    final List<int> paidWeeksList = [];

    for (int i = 0; i < _totalWeeks; i++) {
      if (_paidWeeks.contains(i)) {
        paidWeeksList.add(i);
      } else {
        pendingWeeksList.add(i);
      }
    }

    // Get customer photo
    final photoBase64 = widget.customerData['photo'];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerData['name'] ?? 'Customer Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Customer',
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Customer Photo & Info Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Customer Photo
                if (photoBase64 != null && photoBase64.toString().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.memory(
                      base64Decode(photoBase64.toString()),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                const SizedBox(height: 16),

                _buildInfoRow(
                  LocalizationService.translate(context, 'loan'),
                  '₹${_givenAmount.toStringAsFixed(0)}',
                  Colors.white,
                ),
                const Divider(color: Colors.white24, height: 20),
                _buildInfoRow(
                  LocalizationService.translate(context, 'weekly'),
                  '₹${_weeklyPayment.toStringAsFixed(0)}',
                  Colors.white,
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoColumn(
                        LocalizationService.translate(context, 'paid'),
                        '₹${totalPaid.toStringAsFixed(0)}',
                        Colors.greenAccent,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Expanded(
                      child: _buildInfoColumn(
                        LocalizationService.translate(context, 'pending'),
                        '₹${totalPending.toStringAsFixed(0)}',
                        const Color(0xFFFF8A80),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.black,
                    indicatorColor: Colors.black,
                    tabs: [
                      Tab(
                        text:
                            LocalizationService.translate(
                              context,
                              'pending',
                            ).toUpperCase(),
                      ),
                      Tab(
                        text:
                            LocalizationService.translate(
                              context,
                              'paid',
                            ).toUpperCase(),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildWeekList(pendingWeeksList, false),
                        _buildWeekList(paidWeeksList, true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekList(List<int> weeks, bool isPaidList) {
    if (weeks.isEmpty) {
      return Center(
        child: Text(
          isPaidList ? 'No payments made yet' : 'All payments completed!',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      itemBuilder: (context, index) {
        final weekIndex = weeks[index];
        final weekNumber = weekIndex + 1;

        String subtitleText;
        if (isPaidList) {
          final paidAmt =
              _paymentAmounts[weekIndex.toString()] ?? _weeklyPayment;
          subtitleText =
              '${LocalizationService.translate(context, 'paid')}: ₹${paidAmt.toStringAsFixed(0)}';
        } else {
          subtitleText =
              '${LocalizationService.translate(context, 'weekly')}: ₹${_weeklyPayment.toStringAsFixed(0)}';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor:
                  isPaidList
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
              child: Text(
                '$weekNumber',
                style: TextStyle(
                  color: isPaidList ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '${LocalizationService.translate(context, 'week')} $weekNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              subtitleText,
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing:
                isPaidList
                    ? IconButton(
                      icon: const Icon(Icons.undo, color: Colors.grey),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Undo Payment'),
                                content: const Text(
                                  'Are you sure you want to undo this payment? This will mark the week as unpaid.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(
                                      LocalizationService.translate(context, 'cancel'),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('UNDO'),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          _togglePayment(weekIndex, 0);
                        }
                      },
                      tooltip: 'Mark as Unpaid',
                    )
                    : ElevatedButton(
                      onPressed: () => _initiatePayment(weekIndex),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('PAY'),
                    ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
