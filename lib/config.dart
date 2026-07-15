/// إعدادات الاتصال بالباك-إند الحالي (PHP) — بدون أي تعديل عليه.
/// عدّل هذه القيم فقط حسب دومين السيرفر عندك.
class ApiConfig {
  /// نفس مسار index.php الحالي (نفس الملف اللي كانت الواجهة القديمة
  /// ترسل له طلبات GET/POST بروابط فارغة "" أو "?action=...").
  static const String repIndexUrl =
      'https://brown-cheetah-206200.hostingersite.com/rep/index.php';

  /// مسار auth.php الفعلي (داخل مجلد api/) — يتعامل مع:
  /// ?action=login (POST, JSON body: username/password)
  /// ?action=logout (يدمر الجلسة على السيرفر)
  /// ?action=me (يرجع المستخدم الحالي من الجلسة، أو null لو ما فيه جلسة)
  static const String authUrl = 'https://brown-cheetah-206200.hostingersite.com/api/auth.php';

  /// نفس مسار ../api/rep_locations.php المستخدم لتتبع موقع المندوب.
  static const String repLocationsUrl =
      'https://brown-cheetah-206200.hostingersite.com/api/rep_locations.php';

  /// كل كم ثانية نرسل موقع المندوب (نفس القيمة القديمة: 10 ثوانٍ).
  static const int locationIntervalSeconds = 10;
}

/// أنواع الثلاجات المسموحة (نفس القائمة في index.php)
const List<String> kAllowedFridgeTypes = [
  'ارضي صغير',
  'ارضي كبير',
  'قائم كبير',
  'قائم وسط',
  'قائم صغير',
  'ثلاجه اكياس ثلج',
];

/// المدن المسموحة (نفس القائمة في index.php)
const List<String> kAllowedCities = ['جدة', 'الرياض'];
