import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../widgets/barcode_scanner_screen.dart';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({super.key});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _barcodeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _requestType = 'maintenance';

  String? _checkMsg;
  Color _checkColor = AppColors.ink400;
  bool _checking = false;
  bool _barcodeVerified = false;
  bool _submitting = false;
  final MobileScannerController _liveScannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _liveScanHandled = false;

  @override
  void dispose() {
    _liveScannerController.dispose();
    super.dispose();
  }

  Future<void> _checkBarcode() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) {
      setState(() {
        _checkMsg = 'يرجى مسح أو إدخال الباركود أولاً';
        _checkColor = AppColors.danger;
        _barcodeVerified = false;
      });
      return;
    }
    setState(() {
      _checking = true;
      _checkMsg = 'جاري التحقق...';
      _checkColor = AppColors.ink400;
    });
    try {
      final fridge = await ApiService.instance.checkFridgeBarcode(barcode);
      if (!fridge.exists) {
        setState(() {
          _checkMsg = 'الثلاجة غير موجودة! لا يمكن المتابعة بهذا الباركود.';
          _checkColor = AppColors.danger;
          _barcodeVerified = false;
        });
        return;
      }
      setState(() {
        _checkMsg = null;
        _barcodeVerified = true;
      });
    } catch (_) {
      setState(() {
        _checkMsg = 'تعذر الاتصال بالسيرفر للتحقق.';
        _checkColor = AppColors.danger;
        _barcodeVerified = false;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned == null || scanned.isEmpty) return;
    _barcodeCtrl.text = scanned;
    setState(() => _barcodeVerified = false);
    await _checkBarcode();
  }

  void _onLiveBarcodeDetected(BarcodeCapture capture) {
    if (_liveScanHandled || _checking) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _liveScanHandled = true;
    _barcodeCtrl.text = value;
    setState(() => _barcodeVerified = false);
    _checkBarcode().then((_) {
      if (mounted) _liveScanHandled = false;
    });
  }

  Future<void> _submit() async {
    if (!_barcodeVerified) {
      await _checkBarcode();
      if (!_barcodeVerified) return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ApiService.instance.submitServiceRequest(
        barcode: _barcodeCtrl.text.trim(),
        requestType: _requestType,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message ?? 'تم تسجيل طلب الخدمة بنجاح')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${result.error ?? 'حدث خطأ غير متوقع'}'),
              backgroundColor: AppColors.danger),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء معالجة الطلب على السيرفر.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب نقل / صيانة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('طلب خدمة',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ice500)),
                const SizedBox(height: 4),
                const Text('نوع الطلب المطلوب',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _requestType,
                  decoration: const InputDecoration(labelText: 'نوع الطلب'),
                  items: const [
                    DropdownMenuItem(value: 'maintenance', child: Text('🛠 صيانة')),
                    DropdownMenuItem(value: 'transfer', child: Text('🚚 نقل ثلاجة')),
                  ],
                  onChanged: (v) => setState(() => _requestType = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل إضافية',
                    hintText: 'اكتب تفاصيل المشكلة أو الموقع الجديد هنا...',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _barcodeCtrl,
                  onChanged: (_) => setState(() => _barcodeVerified = false),
                  onSubmitted: (_) => _checkBarcode(),
                  decoration: InputDecoration(
                    labelText: 'الباركود',
                    hintText: 'اكتب الباركود هنا أو استخدم الماسح',
                    prefixIcon: IconButton(
                      tooltip: 'مسح بالكاميرا',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _checking ? null : _scanBarcode,
                    ),
                    suffixIcon: IconButton(
                      icon: _checking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      onPressed: _checking ? null : _checkBarcode,
                    ),
                  ),
                ),
                if (_checkMsg != null) ...[
                  const SizedBox(height: 6),
                  Text(_checkMsg!, style: TextStyle(fontSize: 12.5, color: _checkColor)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ البيانات ✔'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ماسح حي',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ice500)),
                const SizedBox(height: 4),
                const Text('وجّه الكاميرا نحو الباركود',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 240,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _liveScannerController,
                          onDetect: _onLiveBarcodeDetected,
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 200,
                              height: 130,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.ice500, width: 3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (_checking)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('📷 بينمسح تلقائيًا ويعبّي حقل الباركود بالأعلى',
                    style: TextStyle(fontSize: 11.5, color: AppColors.ink400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}