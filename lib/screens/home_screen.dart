import 'package:flutter/material.dart';

import '../main.dart';
import '../models/service_request.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/service_request_card.dart';
import 'new_fridge_screen.dart';
import 'custody_wizard_screen.dart';
import 'service_request_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ServiceRequest> _requests = [];
  bool _loadingRequests = true;
  String? _requestsError;

  LocationTrackingState _locState = LocationTrackingState.error;

  @override
  void initState() {
    super.initState();
    _loadServiceRequests();
    LocationService.instance.stateStream.listen((state) {
      if (mounted) setState(() => _locState = state);
    });
    LocationService.instance.start();
  }

  @override
  void dispose() {
    LocationService.instance.stop();
    super.dispose();
  }

  Future<void> _loadServiceRequests() async {
    setState(() {
      _loadingRequests = true;
      _requestsError = null;
    });
    try {
      final requests = await ApiService.instance.getServiceRequests();
      setState(() {
        _requests = requests;
        _loadingRequests = false;
      });
    } catch (_) {
      setState(() {
        _requestsError = 'تعذر تحميل طلبات الصيانة';
        _loadingRequests = false;
      });
    }
  }

  IconData get _locIcon {
    switch (_locState) {
      case LocationTrackingState.active:
        return Icons.location_on;
      case LocationTrackingState.denied:
        return Icons.location_off;
      case LocationTrackingState.error:
        return Icons.location_disabled;
    }
  }

  String get _locTooltip {
    switch (_locState) {
      case LocationTrackingState.active:
        return 'تتبع الموقع مفعّل';
      case LocationTrackingState.denied:
        return 'رفضت مشاركة الموقع — التتبع متوقف';
      case LocationTrackingState.error:
        return 'تعذّر تحديد الموقع';
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من التطبيق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل الخروج')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    LocationService.instance.stop();
    await ApiService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openOwnerGate() async {
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OwnerGateSheet(),
    );
    if (verified == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewFridgeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Shakersyrup · ميداني',
                style: TextStyle(
                    fontSize: 11, color: AppColors.ice400, fontWeight: FontWeight.w600)),
            Text('إدارة الثلاجات',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Tooltip(
              message: _locTooltip,
              child: Icon(_locIcon,
                  color: _locState == LocationTrackingState.active
                      ? AppColors.ice400
                      : Colors.white38),
            ),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadServiceRequests,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  children: [
                    Text(
                      ApiService.instance.currentUser != null
                          ? 'مرحبًا ${ApiService.instance.currentUser!.fullName} 👋'
                          : 'مرحبًا بك 👋',
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ink900),
                    ),
                    const SizedBox(height: 6),
                    const Text('اختر الإجراء الذي تريد تنفيذه للثلاجة',
                        style: TextStyle(fontSize: 13.5, color: AppColors.ink400)),
                  ],
                ),
              ),
            ),
            _ActionTile(
              icon: '➕',
              iconBg: AppColors.blue.withOpacity(0.1),
              title: 'تسجيل ثلاجة جديدة',
              subtitle: '🔒 يتطلب كلمة سر المالك',
              onTap: _openOwnerGate,
            ),
            _ActionTile(
              icon: '📋',
              iconBg: AppColors.violet.withOpacity(0.1),
              title: 'تسجيل عهدة جديدة',
              subtitle: 'ربط ثلاجة بمنشأة أو عميل',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustodyWizardScreen()),
              ),
            ),
            _ActionTile(
              icon: '🛠',
              iconBg: AppColors.amber.withOpacity(0.1),
              title: 'طلب نقل / صيانة',
              subtitle: 'فتح طلب خدمة لثلاجة قائمة',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServiceRequestScreen()),
                );
                _loadServiceRequests();
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('🛠 طلبات  قيد التنفيذ',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                if (_requests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${_requests.length}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.amber)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingRequests)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_requestsError != null)
              _EmptyMsg(_requestsError!)
            else if (_requests.isEmpty)
              const _EmptyMsg('لا توجد طلبات صيانة قيد التنفيذ حاليًا 👍')
            else
              ..._requests.map((r) => ServiceRequestCard(
                    request: r,
                    onClosed: _loadServiceRequests,
                  )),
          ],
        ),
      ),
    );
  }
}

class _EmptyMsg extends StatelessWidget {
  final String text;
  const _EmptyMsg(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(color: AppColors.ink400, fontSize: 13)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.ink900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.ink400)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: AppColors.ink400),
            ],
          ),
        ),
      ),
    );
  }
}

/// بوابة كلمة سر المالك (mode=verify_owner) — تفتح قبل السماح
/// بالدخول لشاشة "تسجيل ثلاجة جديدة"، تمامًا مثل ownerGate القديم.
class _OwnerGateSheet extends StatefulWidget {
  const _OwnerGateSheet();

  @override
  State<_OwnerGateSheet> createState() => _OwnerGateSheetState();
}

class _OwnerGateSheetState extends State<_OwnerGateSheet> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

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
      final result = await ApiService.instance
          .verifyOwner(username: username, password: password);
      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = result.error ?? 'اسم المستخدم أو كلمة المرور غير صحيحة');
      }
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('تحقق من هوية المالك',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('هذا الإجراء يتطلب كلمة سر المالك للمتابعة',
                style: TextStyle(fontSize: 12.5, color: AppColors.ink400),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'كلمة السر'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('فتح'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
