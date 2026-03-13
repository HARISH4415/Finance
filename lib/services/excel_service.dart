import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finance2/services/customer_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';

class ExcelService {
  static const platform = MethodChannel('com.example.finance2/sms');

  static Future<String?> exportCustomersToExcel() async {
    // Request storage permissions
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }

    final customers = CustomerService.getCustomers();
    if (customers.isEmpty) return null;

    // Create a workbook with one worksheet
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Customers';

    // Find max weeks
    int maxWeeks = 0;
    for (var customer in customers) {
      final w = int.tryParse(customer['weeks']?.toString() ?? '0') ?? 0;
      if (w > maxWeeks) maxWeeks = w;
    }

    // Add Headers
    List<String> headers = [
      'Photo',
      'Name',
      'Phone',
      'Loan Amount',
      'Extra Amount',
      'Total Loan',
      'Total Paid',
      'Remaining',
      'Weeks',
      'Weekly Payment',
      'Created At',
    ];

    for (int i = 1; i <= maxWeeks; i++) {
      headers.add('Week $i');
    }

    // Write Headers to Row 1
    sheet.setColumnWidthInPixels(1, 70); // Photo column
    for (int i = 0; i < headers.length; i++) {
        final colIdx = i + 1;
        final range = sheet.getRangeByIndex(1, colIdx);
        range.setText(headers[i]);
        range.cellStyle.bold = true;
        range.cellStyle.hAlign = HAlignType.center;
        range.cellStyle.vAlign = VAlignType.center;
        
        if (colIdx > 1) {
            sheet.setColumnWidthInPixels(colIdx, 100);
        }
    }

    // Add Data
    for (int r = 0; r < customers.length; r++) {
      final customer = customers[r];
      final rowIdx = r + 2;
      final payments = customer['payments'] as List<dynamic>? ?? [];
      final paymentAmounts =
          customer['paymentAmounts'] as Map<dynamic, dynamic>? ?? {};
      final weeklyPayment =
          double.tryParse(customer['weeklyPayment']?.toString() ?? '0') ?? 0;
      final totalWeeks =
          int.tryParse(customer['weeks']?.toString() ?? '0') ?? 0;

      double totalPaid = 0;
      paymentAmounts.forEach(
        (_, val) => totalPaid += double.tryParse(val.toString()) ?? 0,
      );
      for (var weekIdx in payments) {
        if (!paymentAmounts.containsKey(weekIdx.toString())) {
          totalPaid += weeklyPayment;
        }
      }

      final totalLoan =
          double.tryParse(customer['totalAmount']?.toString() ?? '0') ?? 0;
      final remaining = totalLoan - totalPaid;

      // 1. Photo (decode and insert)
      final photoBase64 = customer['photo']?.toString();
      sheet.setRowHeightInPixels(rowIdx, 60);
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(photoBase64);
          final Picture picture = sheet.pictures.addStream(rowIdx, 1, bytes);
          
          // Size and Center Alignment Logic
          // Cell is 60px height, 70px width (set above)
          picture.height = 50;
          picture.width = 50;
          
          // Approximate centering (pixels to points conversion is roughly 1:1 in some contexts, 
          // but xlsio handles internal offsets accurately if we set them)
          // We can't easily set pixel-perfect offsets without more complex calc, 
          // but setting smaller size than cell usually looks good.
        } catch (e) {
          debugPrint('Error inserting image in Excel: $e');
          final range = sheet.getRangeByIndex(rowIdx, 1);
          range.setText('Error');
          range.cellStyle.hAlign = HAlignType.center;
          range.cellStyle.vAlign = VAlignType.center;
        }
      } else {
        final range = sheet.getRangeByIndex(rowIdx, 1);
        range.setText('No Photo');
        range.cellStyle.hAlign = HAlignType.center;
        range.cellStyle.vAlign = VAlignType.center;
      }

      // 2. Text/Number Data
      for (int i = 2; i <= 11; i++) {
          sheet.getRangeByIndex(rowIdx, i).cellStyle.hAlign = HAlignType.center;
          sheet.getRangeByIndex(rowIdx, i).cellStyle.vAlign = VAlignType.center;
      }
      
      sheet.getRangeByIndex(rowIdx, 2).setText(customer['name']?.toString() ?? '');
      sheet.getRangeByIndex(rowIdx, 3).setText(customer['phone']?.toString() ?? '');
      sheet.getRangeByIndex(rowIdx, 4).setNumber(double.tryParse(customer['givenAmount']?.toString() ?? '0'));
      sheet.getRangeByIndex(rowIdx, 5).setNumber(double.tryParse(customer['extraAmount']?.toString() ?? '0'));
      sheet.getRangeByIndex(rowIdx, 6).setNumber(totalLoan);
      sheet.getRangeByIndex(rowIdx, 7).setNumber(totalPaid);
      sheet.getRangeByIndex(rowIdx, 8).setNumber(remaining);
      sheet.getRangeByIndex(rowIdx, 9).setNumber(totalWeeks.toDouble());
      sheet.getRangeByIndex(rowIdx, 10).setNumber(weeklyPayment);
      sheet.getRangeByIndex(rowIdx, 11).setText(customer['createdAt']?.toString() ?? '');

      // 3. Weekly Status
      for (int i = 0; i < maxWeeks; i++) {
        final colIdx = 12 + i;
        final range = sheet.getRangeByIndex(rowIdx, colIdx);
        range.cellStyle.hAlign = HAlignType.center;
        range.cellStyle.vAlign = VAlignType.center;
        
        if (i < totalWeeks) {
          final isPaid = payments.contains(i);
          range.setText(isPaid ? 'Paid' : 'Pending');
          range.cellStyle.fontColor = isPaid ? '#008000' : '#FF0000';
        } else {
          range.setText('-');
        }
      }

      // 4. Hidden Image Data for Import (Base64 chunking)
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        // Excel cell limit is 32767 chars. We split into 30k chunks.
        const int chunkSize = 30000;
        int chunkIdx = 0;
        final int startCol = 12 + maxWeeks; // Right after week columns
        
        for (int i = 0; i < photoBase64.length; i += chunkSize) {
          int end = i + chunkSize;
          if (end > photoBase64.length) end = photoBase64.length;
          final chunk = photoBase64.substring(i, end);
          
          final col = startCol + chunkIdx;
          sheet.getRangeByIndex(rowIdx, col).setText(chunk);
          // Set column name and hide it on the first data row
          if (r == 0) {
            sheet.getRangeByIndex(1, col).setText('IMG_DATA_$chunkIdx');
            sheet.setColumnWidthInPixels(col, 0); // Hide the data column
          }
          chunkIdx++;
        }
      }
    }

    // Save File
    final directory =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final String path =
        "${directory.path}/finance2_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx";

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  static Future<int> importCustomersFromExcel() async {
    try {
      debugPrint('Triggering native pickExcel...');
      final dynamic result = await platform.invokeMethod('pickExcel');

      if (result == null) {
        debugPrint('Excel picking cancelled or returned null');
        return 0;
      }

      final Uint8List bytes = result as Uint8List;
      debugPrint('Bytes received: ${bytes.length}');
      
      var excel = excel_pkg.Excel.decodeBytes(bytes);
      int count = 0;

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Detect if this is the new format (with Photo column) or old format
        bool hasPhotoColumn = false;
        int imgDataStartCol = -1;

        if (sheet.maxRows > 0) {
          var headerRow = sheet.row(0);
          if (headerRow.isNotEmpty && headerRow[0]?.value?.toString().toLowerCase() == 'photo') {
            hasPhotoColumn = true;
          }
          // Find where IMG_DATA starts
          for (int c = 0; c < headerRow.length; c++) {
            if (headerRow[c]?.value?.toString() == 'IMG_DATA_0') {
              imgDataStartCol = c;
              break;
            }
          }
        }

        int offset = hasPhotoColumn ? 1 : 0;

        for (int i = 1; i < sheet.maxRows; i++) {
          try {
            var row = sheet.row(i);
            if (row.isEmpty) continue;

            // Helper to safely get value string
            String val(int idx) => (row.length > idx) ? row[idx]?.value?.toString() ?? '' : '';

            final name = val(0 + offset);
            if (name.isEmpty || name == 'null' || name == 'Name') continue; 

            // Reconstruct Image if available
            String? photo;
            if (imgDataStartCol != -1) {
              StringBuffer sb = StringBuffer();
              for (int c = imgDataStartCol; c < row.length; c++) {
                final chunk = val(c);
                if (chunk.isEmpty) break;
                sb.write(chunk);
              }
              if (sb.isNotEmpty) photo = sb.toString();
            }

            // Read Weekly Statuses
            final List<int> paidWeeks = [];
            final totalWeeksInt = int.tryParse(val(7 + offset)) ?? 0;
            const int weekStartCol = 11; // Based on export header indices
            
            // Limit search by imgDataStartCol or row length
            final int statusEndCol = (imgDataStartCol != -1) ? imgDataStartCol : row.length;
            
            for (int c = weekStartCol; c < statusEndCol; c++) {
              final status = val(c).toLowerCase();
              if (status == 'paid') {
                paidWeeks.add(c - weekStartCol); // weekIndex 0 for 'Week 1'
              }
            }

            final customerData = {
              'name': name,
              'phone': val(1 + offset),
              'photo': photo,
              'givenAmount': val(2 + offset).isEmpty ? '0' : val(2 + offset),
              'extraAmount': val(3 + offset).isEmpty ? '0' : val(3 + offset),
              'totalAmount': val(4 + offset).isEmpty ? '0' : val(4 + offset),
              'weeks': val(7 + offset).isEmpty ? '0' : val(7 + offset),
              'weeklyPayment': val(8 + offset).isEmpty ? '0' : val(8 + offset),
              'createdAt': val(9 + offset).isEmpty ? DateTime.now().toIso8601String() : val(9 + offset),
              'payments': paidWeeks,
              'paymentAmounts': <String, dynamic>{}, // Re-syncing custom amounts from Excel is complex, using defaults
            };

            await CustomerService.addCustomer(customerData);
            count++;
          } catch (rowErr) {
            debugPrint('Error importing row $i: $rowErr');
          }
        }
      }
      return count;
    } catch (e) {
      debugPrint('Deep Error importing Excel: $e');
      return 0;
    }
  }
}
