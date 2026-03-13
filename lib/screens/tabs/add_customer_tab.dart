import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:finance2/services/customer_service.dart';
import 'package:finance2/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AddCustomerTab extends StatefulWidget {
  final VoidCallback onSuccess;

  const AddCustomerTab({super.key, required this.onSuccess});

  @override
  State<AddCustomerTab> createState() => _AddCustomerTabState();
}

class _AddCustomerTabState extends State<AddCustomerTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _givenAmountController = TextEditingController();
  final _extraAmountController = TextEditingController();
  final _weeksController = TextEditingController();
  final _customPaymentController = TextEditingController();

  String _totalAmount = '0';
  String _weeklyPayment = '0';
  bool _isCustomPayment = false;
  String? _photoBase64;
  File? _photoFile;

  static const platform = MethodChannel('com.example.finance2/sms');

  @override
  void initState() {
    super.initState();
    _givenAmountController.addListener(_calculate);
    _extraAmountController.addListener(_calculate);
    _weeksController.addListener(_calculate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _givenAmountController.dispose();
    _extraAmountController.dispose();
    _weeksController.dispose();
    _customPaymentController.dispose();
    super.dispose();
  }

  void _calculate() {
    final givenAmount = double.tryParse(_givenAmountController.text) ?? 0;
    final extraAmount = double.tryParse(_extraAmountController.text) ?? 0;
    final weeks = double.tryParse(_weeksController.text) ?? 0;

    if (givenAmount > 0 && weeks > 0) {
      final total = givenAmount + extraAmount;
      final weekly = total / weeks;

      setState(() {
        _totalAmount = total.toStringAsFixed(2);
        _weeklyPayment = weekly.toStringAsFixed(2);
        if (!_isCustomPayment) {
          _customPaymentController.text = _weeklyPayment;
        }
      });
    } else {
      setState(() {
        _totalAmount = '0';
        _weeklyPayment = '0';
      });
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();

    // Show dialog to choose camera or gallery
    final source = await showDialog<ImageSource>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              LocalizationService.translate(context, 'capture_photo'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );

    if (source == null) return;

    try {
      final XFile? photo = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _photoFile = File(photo.path);
          _photoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    }
  }

  void _verifyAndAdd() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final givenAmount = _givenAmountController.text.trim();
    final extraAmount = _extraAmountController.text.trim();
    final weeks = _weeksController.text.trim();

    if (name.isEmpty || phone.isEmpty || givenAmount.isEmpty || weeks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }

    // Generate 6 digit OTP
    final random = Random();
    final otp = (100000 + random.nextInt(900000)).toString();
    final message = 'Finance: Registration code for $name (Loan: Rs.$_totalAmount) is $otp.';

    // Direct SMS Sending using Native MethodChannel
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

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
          _showOtpDialog(otp);
        }
      } on PlatformException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send SMS: ${e.message}')),
          );
        }
        return;
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS Permission Required')),
        );
      }
      return;
    }
  }

  void _showOtpDialog(String sentOtp) {
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
                const Text(
                  'Please enter the 6-digit code sent to the customer.',
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
                // Debug help for simulator
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
                onPressed: () async {
                  if (otpController.text == sentOtp) {
                    Navigator.pop(context); // Close dialog
                    await _saveCustomer();
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
                child: Text(LocalizationService.translate(context, 'verify')),
              ),
            ],
          ),
    );
  }

  Future<void> _saveCustomer() async {
    final customerData = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'photo': _photoBase64,
      'givenAmount': _givenAmountController.text.trim(),
      'extraAmount':
          _extraAmountController.text.trim().isEmpty
              ? '0'
              : _extraAmountController.text.trim(),
      'totalAmount': _totalAmount,
      'weeks': _weeksController.text.trim(),
      'weeklyPayment':
          _isCustomPayment
              ? _customPaymentController.text.trim()
              : _weeklyPayment,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await CustomerService.addCustomer(customerData);

    // Send Registration Confirmation SMS
    final confirmedPhone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final confirmMessage = 
        'Registration Successful! \n'
        'Name: ${_nameController.text.trim()} \n'
        'Loan Amount: Rs.$_totalAmount \n'
        'Weekly Payment: Rs.${_isCustomPayment ? _customPaymentController.text : _weeklyPayment} \n'
        'Duration: ${_weeksController.text} Weeks';

    try {
      await platform.invokeMethod('sendSMS', {
        'phone': confirmedPhone,
        'message': confirmMessage,
      });
    } catch (e) {
      debugPrint('Error sending confirmation: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer Added Successfully!')),
      );
      // Reset form
      _nameController.clear();
      _phoneController.clear();
      _givenAmountController.clear();
      _extraAmountController.clear();
      _weeksController.clear();
      setState(() {
        _totalAmount = '0';
        _weeklyPayment = '0';
        _customPaymentController.clear();
        _isCustomPayment = false;
        _photoBase64 = null;
        _photoFile = null;
      });
      // Callback to switch tab
      widget.onSuccess();
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo Section
          GestureDetector(
            onTap: _capturePhoto,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child:
                  _photoFile != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_photoFile!, fit: BoxFit.cover),
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            LocalizationService.translate(
                              context,
                              'capture_photo',
                            ),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(
            LocalizationService.translate(context, 'customer_name'),
            _nameController,
          ),
          _buildTextField(
            LocalizationService.translate(context, 'phone_number'),
            _phoneController,
            isNumber: true,
          ),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  LocalizationService.translate(context, 'given_amount'),
                  _givenAmountController,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  LocalizationService.translate(context, 'extra_amount'),
                  _extraAmountController,
                  isNumber: true,
                ),
              ),
            ],
          ),
          _buildTextField(
            LocalizationService.translate(context, 'weeks'),
            _weeksController,
            isNumber: true,
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${LocalizationService.translate(context, 'total_amount')}:',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      _totalAmount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${LocalizationService.translate(context, 'weekly_payment')}:',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (_isCustomPayment)
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _customPaymentController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        _weeklyPayment,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Theme(
                      data: ThemeData(unselectedWidgetColor: Colors.white70),
                      child: Checkbox(
                        value: _isCustomPayment,
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        onChanged: (value) {
                          setState(() {
                            _isCustomPayment = value ?? false;
                            if (!_isCustomPayment) {
                              _customPaymentController.text = _weeklyPayment;
                            }
                          });
                        },
                      ),
                    ),
                    Text(
                      LocalizationService.translate(context, 'customize'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _verifyAndAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LocalizationService.translate(context, 'verify_add'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
