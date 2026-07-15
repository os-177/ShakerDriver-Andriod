import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../models/service_request.dart';
import '../services/api_service.dart';

class ServiceRequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback onClosed;

  const ServiceRequestCard({super.key, required this.request, required this.onClosed});

  String get _typeLabel => request.requestType == 'maintenance' ? '🛠 صيانة' : '🚚 نقل ثلاجة';

  Future<bool?> _confirmCompleteTransfer(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool loading = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تأكيد إنهاء طلب النقل'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('هل تم نقل الثلاجة (${request.fridgeBarcode}) بنجاح؟'),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: loading
                      ? null
                      : () async {
                          setState(() {
                            loading = true;
                            error = null;
                          });
                          try {
                            final result = await ApiService.instance
                                .completeTransfer(requestId: request.id);
                            if (result.success) {
                              Navigator.of(dialogContext).pop(true);
                            } else {
                              setState(() {
                                loading = false;
                                error = result.error ?? 'حدث خطأ غير متوقع';
                              });
                            }
                          } catch (_) {
                            setState(() {
                              loading = false;
                              error = 'حدث خطأ أثناء معالجة الطلب على السيرفر.';
                            });
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('تأكيد ✔'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = request.createdAt != null
        ? DateFormat('yyyy/MM/dd — HH:mm').format(request.createdAt!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$_typeLabel — ${request.fridgeBarcode}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          if (request.facilityName != null && request.facilityName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('📍 ${request.facilityName}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink600)),
          ],
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(request.notes!, style: const TextStyle(fontSize: 12.5, color: AppColors.ink600)),
          ],
          if (dateStr != null) ...[
            const SizedBox(height: 6),
            Text(dateStr, style: const TextStyle(fontSize: 11.5, color: AppColors.ink400)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: request.hasLocation
                      ? () => launchUrl(Uri.parse(request.mapsUrl),
                          mode: LaunchMode.externalApplication)
                      : null,
                  icon: const Icon(Icons.location_on_outlined, size: 16),
                  label: Text(request.hasLocation ? 'الانتقال إلى الموقع' : 'لا يوجد موقع مسجل',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () async {
                    final closed = request.requestType == 'transfer'
                        ? await _confirmCompleteTransfer(context)
                        : await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _CloseRequestSheet(requestId: request.id),
                          );
                    if (closed == true) onClosed();
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('إغلاق الطلب', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CloseRequestSheet extends StatefulWidget {
  final int requestId;
  const _CloseRequestSheet({required this.requestId});

  @override
  State<_CloseRequestSheet> createState() => _CloseRequestSheetState();
}

class _CloseRequestSheetState extends State<_CloseRequestSheet> {
  final _notesCtrl = TextEditingController();
  File? _invoiceImg;
  bool _loading = false;
  String? _error;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) setState(() => _invoiceImg = File(picked.path));
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _invoiceImg = File(picked.path));
  }

  Future<void> _submit() async {
    if (_invoiceImg == null) {
      setState(() => _error = 'يرجى إرفاق صورة فاتورة الإصلاح');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.instance.closeServiceRequest(
        requestId: widget.requestId,
        invoiceImg: _invoiceImg!,
        closingNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message ?? 'تم إغلاق طلب الصيانة بنجاح')));
      } else {
        setState(() => _error = result.error ?? 'حدث خطأ غير متوقع');
      }
    } catch (_) {
      setState(() => _error = 'حدث خطأ أثناء معالجة الطلب على السيرفر.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('✔', style: TextStyle(fontSize: 32), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('إغلاق طلب الصيانة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('ارفق صورة فاتورة الإصلاح واكتب ملاحظة عن العطل',
                  style: TextStyle(fontSize: 12.5, color: AppColors.ink400),
                  textAlign: TextAlign.center),
              const SizedBox(height: 18),
              const Text('صورة فاتورة الإصلاح *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('كاميرا'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('معرض الصور'),
                    ),
                  ),
                ],
              ),
              if (_invoiceImg != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_invoiceImg!, height: 120, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (وش كان العطل)',
                  hintText: 'اكتب وصف العطل الذي تم إصلاحه...',
                ),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('تأكيد الإغلاق ✔'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}