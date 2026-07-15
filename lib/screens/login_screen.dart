import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

/// شاشة تسجيل دخول المندوب. الباك-إند (index.php) يشترط وجود
/// $_SESSION['user']['id'] قبل قبول أي عملية POST، وهذي الجلسة تُنشأ عبر
/// auth.php?action=login (مجلد api/). لازم هذي الشاشة تنجح أول قبل
/// استخدام أي شاشة ثانية في التطبيق.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  /// الأدوار المسموح لها بالدخول لهذا التطبيق (تطبيق المندوب الميداني).
  static const _allowedRole = 'rep';

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل اسم المستخدم وكلمة المرور');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await ApiService.instance.login(username: username, password: password);
      if (!mounted) return;

      if (!result.success) {
        setState(() => _error = result.error ?? 'اسم المستخدم أو كلمة المرور غير صحيحة');
        return;
      }

      final user = ApiService.instance.currentUser;
      if (user == null || user.role != _allowedRole) {
        // الجلسة انشأت على السيرفر فعليًا وقت اللوجن، فلازم ندمرها
        // فورًا حتى ما يضل حساب غير مصرح له بجلسة فعّالة.
        await ApiService.instance.logout();
        if (!mounted) return;
        setState(() => _error = 'هذا الحساب غير مصرح له بالدخول لتطبيق المندوبين');
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy950,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assetsx/images/logo.png',
                  width: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),
                const Text('Shakersyrup · ميداني',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.ice400, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('تسجيل دخول المندوب',
                    style: TextStyle(
                        fontSize: 20, color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('تسجيل الدخول'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}