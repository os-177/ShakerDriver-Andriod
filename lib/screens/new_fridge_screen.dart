import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../main.dart';
import '../config.dart';
import '../services/api_service.dart';

class NewFridgeScreen extends StatefulWidget {
  const NewFridgeScreen({super.key});

  @override
  State<NewFridgeScreen> createState() => _NewFridgeScreenState();
}

class _NewFridgeScreenState extends State<NewFridgeScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _fridgeType;
  final _serialCtrl = TextEditingController();
  DateTime? _purchaseDate;
  File? _invoiceImg;
  File? _warrantyImg;
  bool _loading = false;
  String? _resultBarcode;

  Future<void> _pickImage(bool isInvoice) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      if (isInvoice) {
        _invoiceImg = File(picked.path);
      } else {
        _warrantyImg = File(picked.path);
      }
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _purchaseDate = date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await ApiService.instance.registerNewFridge(
        fridgeType: _fridgeType!,
        serialNumber: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        purchaseDate: _purchaseDate != null ? DateFormat('yyyy-MM-dd').format(_purchaseDate!) : null,
        invoiceImg: _invoiceImg,
        warrantyImg: _warrantyImg,
      );
      if (!mounted) return;
      if (result.success) {
        setState(() => _resultBarcode = result.raw['barcode']?.toString());
      } else {
        _showError(result.error ?? 'حدث خطأ غير متوقع');
      }
    } catch (_) {
      if (mounted) _showError('حدث خطأ أثناء معالجة الطلب على السيرفر.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطأ: $msg'), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_resultBarcode != null) {
      return _BarcodeResultView(barcode: _resultBarcode!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل ثلاجة جديدة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FormCard(
              eyebrow: 'ثلاجة جديدة',
              title: 'بيانات الثلاجة',
              children: [
                DropdownButtonFormField<String>(
                  value: _fridgeType,
                  decoration: const InputDecoration(labelText: 'نوع الثلاجة *'),
                  items: kAllowedFridgeTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _fridgeType = v),
                  validator: (v) => v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _serialCtrl,
                  decoration: const InputDecoration(labelText: 'السريال نمبر'),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ الشراء'),
                    child: Text(
                      _purchaseDate != null
                          ? DateFormat('yyyy-MM-dd').format(_purchaseDate!)
                          : 'اختر التاريخ',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ImagePickerField(
                  label: '📄 صورة الفاتورة',
                  file: _invoiceImg,
                  onTap: () => _pickImage(true),
                ),
                const SizedBox(height: 14),
                _ImagePickerField(
                  label: '📄 صورة الضمان',
                  file: _warrantyImg,
                  onTap: () => _pickImage(false),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ البيانات ✔'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeResultView extends StatelessWidget {
  final String barcode;
  const _BarcodeResultView({required this.barcode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تم التسجيل')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✔', style: TextStyle(fontSize: 40, color: AppColors.success)),
              const SizedBox(height: 8),
              const Text('تم تسجيل الثلاجة بنجاح!',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('يمكنك نسخ رقم الباركود أدناه لطباعته لاحقًا',
                  style: TextStyle(fontSize: 12.5, color: AppColors.ink400),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: barcode,
                  width: 260,
                  height: 100,
                  drawText: true,
                ),
              ),
              const SizedBox(height: 24),
              // ملاحظة: طباعة Zebra (ZPL) ومسح الباركود بالكاميرا تم تأجيلهم
              // لمرحلة لاحقة بناءً على طلبك. حاليًا نعرض الباركود فقط للمعاينة.
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('تسجيل آخر / العودة للقائمة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Widget> children;

  const _FormCard({required this.eyebrow, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;

  const _ImagePickerField({required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                  child: Text(
                    file != null ? file!.path.split('/').last : 'اختر صورة',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.ink600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
