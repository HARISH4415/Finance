import 'dart:convert';
import 'package:finance2/screens/customer_detail_screen.dart';
import 'package:finance2/services/customer_service.dart';
import 'package:finance2/services/localization_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CustomerService.listenable,
      builder: (context, box, _) {
        final customers = CustomerService.getCustomers();

        // Calculate Totals and Weekly Stats
        double totalGiven = 0;
        double totalGained = 0;

        // For Chart: Aggregate of ALL customers' current week status
        int paidCountThisWeek = 0;
        int pendingCountThisWeek = 0;

        List<Map<dynamic, dynamic>> dueCustomers = [];

        final now = DateTime.now();

        for (var customer in customers) {
          final givenAmount =
              double.tryParse(customer['givenAmount']?.toString() ?? '0') ?? 0;
          final weeklyPayment =
              double.tryParse(customer['weeklyPayment']?.toString() ?? '0') ??
              0;

          final payments = customer['payments'] as List<dynamic>?;
          final paidWeeks =
              payments?.map((e) => int.tryParse(e.toString()) ?? -1).toList() ??
              [];

          final paymentAmounts =
              customer['paymentAmounts'] as Map<dynamic, dynamic>? ?? {};

          totalGiven += givenAmount;

          // Calculate gained based on actual payments map and default weekly amount
          double customerGained = 0;
          paymentAmounts.forEach((key, value) {
            customerGained += double.tryParse(value.toString()) ?? 0;
          });
          
          for (var weekIdx in paidWeeks) {
            if (!paymentAmounts.containsKey(weekIdx.toString())) {
              customerGained += weeklyPayment;
            }
          }
          totalGained += customerGained;

          // Check for Current Week Status
          final createdAtString = customer['createdAt'] as String?;
          if (createdAtString != null) {
            final createdAt = DateTime.tryParse(createdAtString);
            if (createdAt != null) {
              final weeksDuration =
                  int.tryParse(customer['weeks']?.toString() ?? '0') ?? 0;

              // Calculate index of current week (7 days)
              final differenceInDays = now.difference(createdAt).inDays;
              final currentWeekIndex = (differenceInDays / 7).floor();

              if (currentWeekIndex >= 0 && currentWeekIndex < weeksDuration) {
                if (paidWeeks.contains(currentWeekIndex)) {
                  paidCountThisWeek++;
                } else {
                  pendingCountThisWeek++;
                  dueCustomers.add(customer);
                }
              }
            }
          }
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.translate(
                              context,
                              'amount_given',
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${totalGiven.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.white24,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.translate(
                              context,
                              'amount_gained',
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${totalGained.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Weekly Status Chart
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  LocalizationService.translate(context, 'weekly_status'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: paidCountThisWeek.toDouble(),
                            title: '$paidCountThisWeek',
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            color: Colors.green,
                            radius: 60,
                          ),
                          PieChartSectionData(
                            value: pendingCountThisWeek.toDouble(),
                            title: '$pendingCountThisWeek',
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            color: Colors.redAccent,
                            radius: 60,
                          ),
                        ],
                        sectionsSpace: 4,
                        centerSpaceRadius: 50,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (paidCountThisWeek + pendingCountThisWeek).toString(),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(width: 12, height: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(LocalizationService.translate(context, 'paid')),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Row(
                    children: [
                      Container(width: 12, height: 12, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Text(LocalizationService.translate(context, 'pending')),
                    ],
                  ),
                ],
              ),

              if (paidCountThisWeek == 0 && pendingCountThisWeek == 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      LocalizationService.translate(context, 'no_due'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Due This Week List
              if (dueCustomers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    LocalizationService.translate(context, 'due_this_week'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ] else ...[
                // If empty, show nothing or placeholder?
                // Logic above handles "no_due" if counts are 0,
                // but if paidCount > 0 and pending == 0, we still fall here.
                // Let's just skip the header if no due customers.
              ],

              if (dueCustomers.isNotEmpty)
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: dueCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = dueCustomers[index];
                      final photoBase64 = customer['photo'];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CustomerDetailScreen(
                                    customerIndex: customers.indexOf(customer),
                                    customerData: customer,
                                  ),
                            ),
                          );
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (photoBase64 != null &&
                                  photoBase64.toString().isNotEmpty)
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: MemoryImage(
                                    base64Decode(photoBase64.toString()),
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                customer['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                customer['phone'] ?? '',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 10),
              // All Customers Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'All Customers',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Customer List
              customers.isEmpty
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        LocalizationService.translate(context, 'no_customers'),
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customers.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final name = customer['name'] ?? 'Unknown';
                      // Handle both 'amount' (old) and 'givenAmount' (new)
                      final amount =
                          customer['givenAmount'] ?? customer['amount'] ?? '0';
                      // Handle both 'monthlyPayment' (old) and 'weeklyPayment' (new)
                      final paymentVal =
                          customer['weeklyPayment'] ??
                          customer['monthlyPayment'] ??
                          '0';
                      final photoBase64 = customer['photo'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading:
                              (photoBase64 != null &&
                                      photoBase64.toString().isNotEmpty)
                                  ? CircleAvatar(
                                    backgroundImage: MemoryImage(
                                      base64Decode(photoBase64.toString()),
                                    ),
                                  )
                                  : const CircleAvatar(
                                    backgroundColor: Colors.grey,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${LocalizationService.translate(context, 'loan')}: $amount',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${LocalizationService.translate(context, 'weekly_payment')}: $paymentVal',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CustomerDetailScreen(
                                      customerIndex: index,
                                      customerData: customer,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
