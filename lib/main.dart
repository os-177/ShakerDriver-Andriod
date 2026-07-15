import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // تأكد من استيراد هذه المكتبة
// ألوان مأخوذة من نفس بالتة "cold-chain" الموجودة في index.php (:root)
class AppColors {
  static const navy950 = Color(0xFF071427);
  static const navy900 = Color(0xFF0B1D34);
  static const navy800 = Color(0xFF12294A);
  static const ice400 = Color(0xFF67E8F9);
  static const ice500 = Color(0xFF22D3EE);
  static const frostBg = Color(0xFFEEF3F8);
  static const ink900 = Color(0xFF0F172A);
  static const ink600 = Color(0xFF4B5768);
  static const ink400 = Color(0xFF8A94A6);
  static const line = Color(0xFFE3E9F0);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
  static const amber = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
}

void main() {
  runApp(const FridgeRepApp());
}

class FridgeRepApp extends StatelessWidget {
  const FridgeRepApp({super.key});

  @override
  Widget build(BuildContext context) {
return MaterialApp(
  title: 'إدارة الثلاجات — المندوب',
  debugShowCheckedModeBanner: false,
  // تأكد من ضبط اللغة هنا
  locale: const Locale('ar'),
  supportedLocales: const [
    Locale('ar'),
    Locale('en'),
  ],
  // أضف هذه السطور بدقة لحل خطأ No MaterialLocalizations found
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
      // ملاحظة: لو احتجت ودجات نظام كاملة بالعربي (مثل DatePicker)، أضف
      // حزمة flutter_localizations في pubspec.yaml واربطها هنا عبر
      // localizationsDelegates. تم تبسيطها هنا لتفادي تعقيد غير ضروري.
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.frostBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.ice500,
          primary: AppColors.blue,
          secondary: AppColors.ice500,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navy950,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.line, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.line, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.ice500, width: 1.5),
          ),
          labelStyle: const TextStyle(color: AppColors.ink600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        // التطبيق الأصلي dir="rtl" lang="ar" بالكامل
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}

/// يقرر هل يعرض شاشة تسجيل الدخول أو الشاشة الرئيسية مباشرة، بناءً على
/// التحقق الفعلي من صلاحية الجلسة عند السيرفر (auth.php?action=me)،
/// وليس فقط على علامة محلية. لو الكوكي المحفوظ منتهي الصلاحية أو تم
/// تسجيل الخروج من جهاز/مكان آخر، سيرجع "me" بدون مستخدم وتُعرض شاشة
/// تسجيل الدخول من جديد تلقائيًا.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // أول فحص سريع محلي (فيه جلسة محفوظة من الأساس؟)، ولو فيه نتحقق
    // فعليًا من صلاحيتها عند السيرفر عبر auth.php?action=me، لأن
    // الجلسة ممكن تكون انتهت أو انسحبت من مكان ثاني.
    final hasLocalFlag = await ApiService.instance.isLoggedIn();
    bool loggedIn = false;
    if (hasLocalFlag) {
      final user = await ApiService.instance.fetchCurrentUser();
      loggedIn = user != null;
    }
    if (mounted) {
      setState(() {
        _loggedIn = loggedIn;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.navy950,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return _loggedIn ? const HomeScreen() : const LoginScreen();
  }
}
