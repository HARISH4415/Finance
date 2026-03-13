import 'package:flutter/material.dart';

class LocalizationService {
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    const Locale('en'),
  );

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'FINANCER',
      'dashboard': 'Home',
      'add_customer': 'Add Customer',
      'profile': 'Profile',
      'amount_given': 'Amount Given',
      'amount_gained': 'Amount Gained',
      'due_this_week': 'Due This Week',
      'weekly_status': 'Weekly Status',
      'paid': 'Paid',
      'pending': 'Pending',
      'settings': 'Settings',
      'language': 'Language',
      'logout': 'LOGOUT',
      'no_due': 'No pending payments for this week!',
      'no_customers': 'No customers found. Add one!',
      'loan': 'Given',
      'weekly': 'Weekly',
      'week': 'Week',
      'customize': 'Customize',
      'verify_add': 'VERIFY & ADD CUSTOMER',
      'customer_name': 'Customer Name',
      'phone_number': 'Phone Number',
      'given_amount': 'Given Amount',
      'extra_amount': 'Extra Amount',
      'total_amount': 'Total Amount',
      'weeks': 'Weeks',
      'weekly_payment': 'Weekly Payment',
      'enter_otp': 'Enter Verification Code',
      'cancel': 'CANCEL',
      'verify': 'VERIFY',
      'verify_pay': 'VERIFY & PAY',
      'capture_photo': 'Capture Photo',
      'take_photo': 'Take Photo',
      'amount': 'Amount',
    },
    'ta': {
      'app_title': 'நிதியாளர்',
      'dashboard': 'முகப்பு',
      'add_customer': 'வாடிக்கையாளர் சேர்',
      'profile': 'சுயவிவரம்',
      'amount_given': 'வழங்கிய தொகை',
      'amount_gained': 'லாபம்',
      'due_this_week': 'இந்த வாரம் நிலுவை',
      'weekly_status': 'வார நிலை',
      'paid': 'செலுத்தியது',
      'pending': 'நிலுவை',
      'settings': 'அமைப்புகள்',
      'language': 'மொழி',
      'logout': 'வெளியேறு',
      'no_due': 'இந்த வாரத்திற்கான நிலுவை இல்லை!',
      'no_customers': 'வாடிக்கையாளர்கள் இல்லை. சேர்க்கவும்!',
      'loan': 'வழங்கியது',
      'weekly': 'வாரம்',
      'week': 'வாரம்',
      'customize': 'மாற்றியமைக்க',
      'verify_add': 'சரிபார்த்து சேர்',
      'customer_name': 'பெயர்',
      'phone_number': 'தொடர்பு எண்',
      'given_amount': 'வழங்கிய தொகை',
      'extra_amount': 'கூடுதல் தொகை',
      'total_amount': 'மொத்த தொகை',
      'weeks': 'வாரங்கள்',
      'weekly_payment': 'வார தவணை',
      'enter_otp': 'சரிபார்ப்பு குறியீட்டை உள்ளிடவும்',
      'cancel': 'ரத்து',
      'verify': 'சரிபார்',
      'verify_pay': 'சரிபார்த்து செலுத்து',
      'capture_photo': 'புகைப்படம் எடு',
      'take_photo': 'புகைப்படம்',
      'amount': 'தொகை',
    },
  };

  static String translate(BuildContext context, String key) {
    final locale = localeNotifier.value.languageCode;
    return _localizedValues[locale]?[key] ?? key;
  }

  static void changeLocale(String languageCode) {
    localeNotifier.value = Locale(languageCode);
  }
}
