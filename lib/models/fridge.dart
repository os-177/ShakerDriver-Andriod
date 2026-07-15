/// يمثل نتيجة التحقق من باركود ثلاجة (?action=get_fridge&barcode=...)
class FridgeCheckResult {
  final bool exists;
  final bool hasActiveCustody;
  final Map<String, dynamic> raw;

  FridgeCheckResult({
    required this.exists,
    required this.hasActiveCustody,
    required this.raw,
  });

  factory FridgeCheckResult.fromJson(Map<String, dynamic> json) {
    return FridgeCheckResult(
      exists: json['exists'] == true,
      hasActiveCustody: json['has_active_custody'] == true,
      raw: json,
    );
  }
}
