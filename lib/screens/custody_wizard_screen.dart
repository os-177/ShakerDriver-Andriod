import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../main.dart';
import '../config.dart';
import '../services/api_service.dart';

class CustodyWizardScreen extends StatefulWidget {
  const CustodyWizardScreen({super.key});

  @override
  State<CustodyWizardScreen> createState() => _CustodyWizardScreenState();
}

class _CustodyWizardScreenState extends State<CustodyWizardScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const _stepLabels = ['مسح الثلاجة', 'بيانات المنشأة', 'الموقع الإداري', 'التراخيص والوثائق'];

  // Step 1
  final _barcodeCtrl = TextEditingController();
  String? _checkMsg;
  Color _checkColor = AppColors.ink400;
  bool _checking = false;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _scanHandled = false;

  // Step 2
  final _facilityNameCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _responsibleStaffCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Step 3
  String _city = kAllowedCities.first;
  final _districtCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();

  // Step 4
  final _municipalityLicenseNoCtrl = TextEditingController();
  final _commercialRegistrationNoCtrl = TextEditingController();
  final _nationalAddressTextCtrl = TextEditingController();
  File? _municipalityLicenseImg;
  File? _nationalAddressImg;
  double? _latitude;
  double? _longitude;
  String _locationStatus = 'لم يتم تحديد الموقع بعد';
  bool _submitting = false;

  Future<void> _checkBarcodeAndAdvance() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) {
      setState(() {
        _checkMsg = 'يرجى مسح أو إدخال الباركود أولاً';
        _checkColor = AppColors.danger;
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
        });
        return;
      }
      if (fridge.hasActiveCustody) {
        setState(() {
          _checkMsg =
              'لا يمكن تسجيل عهدة جديدة على هذه الثلاجة لوجود عهدة سارية عليها حالياً. يجب إنهاء العهدة الحالية أولاً';
          _checkColor = AppColors.danger;
        });
        return;
      }
      setState(() => _checkMsg = null);
      _goToStep(1);
    } catch (_) {
      setState(() {
        _checkMsg = 'تعذر الاتصال بالسيرفر للتحقق.';
        _checkColor = AppColors.danger;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _onLiveBarcodeDetected(BarcodeCapture capture) {
    if (_scanHandled || _checking) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _scanHandled = true;
    _barcodeCtrl.text = value;
    _checkBarcodeAndAdvance().then((_) {
      // اسمح بمسح جديد لو التحقق فشل ولسه بنفس الخطوة
      if (mounted && _step == 0) _scanHandled = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _goToStep(int index) {
    setState(() => _step = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    if (index == 0) {
      _scanHandled = false;
      _scannerController.start();
    } else {
      _scannerController.stop();
    }
  }

  bool _validateStep2() {
    if (_facilityNameCtrl.text.trim().isEmpty) {
      _showSnack('الحقل "اسم المنشأة" مطلوب');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_districtCtrl.text.trim().isEmpty) {
      _showSnack('الحقل "الحي" مطلوب');
      return false;
    }
    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage(bool isMunicipality) async {
    final source = await _chooseImageSource();
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      if (isMunicipality) {
        _municipalityLicenseImg = File(picked.path);
      } else {
        _nationalAddressImg = File(picked.path);
      }
    });
  }

  Future<ImageSource?> _chooseImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('تصوير بالكاميرا'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('اختيار من المعرض'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locationStatus = 'جاري تحديد الموقع...');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationStatus = 'تم رفض إذن الموقع');
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationStatus = 'تم تحديد الموقع ✔ (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
      });
    } catch (_) {
      setState(() => _locationStatus = 'تعذّر تحديد الموقع');
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await ApiService.instance.registerCustody(
        fridgeBarcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        facilityName: _facilityNameCtrl.text.trim(),
        clientName: _clientNameCtrl.text.trim().isEmpty ? null : _clientNameCtrl.text.trim(),
        responsibleStaff:
            _responsibleStaffCtrl.text.trim().isEmpty ? null : _responsibleStaffCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        city: _city,
        district: _districtCtrl.text.trim(),
        street: _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim(),
        municipalityLicenseNo: _municipalityLicenseNoCtrl.text.trim().isEmpty
            ? null
            : _municipalityLicenseNoCtrl.text.trim(),
        municipalityLicenseImg: _municipalityLicenseImg,
        commercialRegistrationNo: _commercialRegistrationNoCtrl.text.trim().isEmpty
            ? null
            : _commercialRegistrationNoCtrl.text.trim(),
        nationalAddressText:
            _nationalAddressTextCtrl.text.trim().isEmpty ? null : _nationalAddressTextCtrl.text.trim(),
        nationalAddressImg: _nationalAddressImg,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      if (result.success) {
        _showSnack(result.message ?? 'تم تسجيل العهدة بنجاح');
        Navigator.of(context).pop();
      } else {
        _showSnack('خطأ: ${result.error ?? 'حدث خطأ غير متوقع'}');
      }
    } catch (_) {
      if (mounted) _showSnack('حدث خطأ أثناء معالجة الطلب على السيرفر.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل عهدة جديدة')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(left: i == 3 ? 0 : 6),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.ice500 : AppColors.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('الخطوة ${_step + 1} من 4 — ${_stepLabels[_step]}',
                      style: const TextStyle(fontSize: 12, color: AppColors.ink600)),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapCard(String eyebrow, String title, List<Widget> children) {
    return ListView(
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
              Text(eyebrow,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ice500)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        Expanded(
          child: _wrapCard('الخطوة 1 من 4', 'مسح الثلاجة', [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 240,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
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
            const SizedBox(height: 6),
            const Text('📷 وجّه الكاميرا نحو الباركود، بينمسح تلقائيًا',
                style: TextStyle(fontSize: 12, color: AppColors.ink600), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            TextField(
              controller: _barcodeCtrl,
              onSubmitted: (_) => _checkBarcodeAndAdvance(),
              decoration: InputDecoration(
                labelText: 'الباركود',
                hintText: 'أو اكتبه هنا يدويًا',
                suffixIcon: IconButton(
                  icon: _checking
                      ? const Padding(
                          padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  onPressed: _checking ? null : _checkBarcodeAndAdvance,
                ),
              ),
            ),
            if (_checkMsg != null) ...[
              const SizedBox(height: 6),
              Text(_checkMsg!, style: TextStyle(fontSize: 12.5, color: _checkColor)),
            ],
          ]),
        ),
        _navBar(showBack: false, onNext: _checkBarcodeAndAdvance),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: _wrapCard('الخطوة 2 من 4', 'بيانات المنشأة', [
            TextField(controller: _facilityNameCtrl, decoration: const InputDecoration(labelText: 'اسم المنشأة *')),
            const SizedBox(height: 12),
            TextField(controller: _clientNameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل')),
            const SizedBox(height: 12),
            TextField(
                controller: _responsibleStaffCtrl,
                decoration: const InputDecoration(labelText: 'الموظف المسؤول')),
            const SizedBox(height: 12),
            TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الجوال')),
          ]),
        ),
        _navBar(
          showBack: true,
          onBack: () => _goToStep(0),
          onNext: () {
            if (_validateStep2()) _goToStep(2);
          },
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        Expanded(
          child: _wrapCard('الخطوة 3 من 4', 'الموقع الإداري', [
            DropdownButtonFormField<String>(
              value: _city,
              decoration: const InputDecoration(labelText: 'المدينة *'),
              items: kAllowedCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _city = v!),
            ),
            const SizedBox(height: 12),
            TextField(controller: _districtCtrl, decoration: const InputDecoration(labelText: 'الحي *')),
            const SizedBox(height: 12),
            TextField(controller: _streetCtrl, decoration: const InputDecoration(labelText: 'الشارع')),
          ]),
        ),
        _navBar(
          showBack: true,
          onBack: () => _goToStep(1),
          onNext: () {
            if (_validateStep3()) _goToStep(3);
          },
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      children: [
        Expanded(
          child: _wrapCard('الخطوة 4 من 4', 'التراخيص والموقع والوثائق', [
            TextField(
                controller: _municipalityLicenseNoCtrl,
                decoration: const InputDecoration(labelText: 'رقم رخصة البلدية')),
            const SizedBox(height: 12),
            _imageField('📸 صورة رخصة البلدية', _municipalityLicenseImg, () => _pickImage(true)),
            const SizedBox(height: 12),
            TextField(
                controller: _commercialRegistrationNoCtrl,
                decoration: const InputDecoration(labelText: 'رقم السجل التجاري')),
            const SizedBox(height: 12),
            TextField(
                controller: _nationalAddressTextCtrl,
                decoration: const InputDecoration(labelText: 'نص العنوان الوطني')),
            const SizedBox(height: 12),
            _imageField('📸 صورة العنوان الوطني', _nationalAddressImg, () => _pickImage(false)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('تحديد الموقع الحالي'),
            ),
            const SizedBox(height: 6),
            Text(_locationStatus, style: const TextStyle(fontSize: 12, color: AppColors.ink400)),
          ]),
        ),
        _navBar(
          showBack: true,
          onBack: () => _goToStep(2),
          nextLabel: 'حفظ العهدة ✔',
          onNext: _submitting ? null : _submit,
          loading: _submitting,
        ),
      ],
    );
  }

  Widget _imageField(String label, File? file, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.image_outlined, color: AppColors.ink400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(file != null ? file.path.split('/').last : 'اختر صورة',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.ink600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _navBar({
    required bool showBack,
    VoidCallback? onBack,
    VoidCallback? onNext,
    String nextLabel = 'التالي',
    bool loading = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: OutlinedButton(onPressed: onBack, child: const Text('السابق')),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: onNext,
              child: loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(nextLabel),
            ),
          ),
        ],
      ),
    );
  }
}