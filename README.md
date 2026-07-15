# تطبيق المندوب — إدارة الثلاجات (Flutter)

تحويل واجهة `index.php` / `rep.js` إلى تطبيق فلاتر، مع إبقاء الـ backend
(PHP + قاعدة البيانات) كما هو تمامًا. التطبيق يتواصل مع نفس روابط PHP الحالية.

## 1) خطوة أولى مهمة: توليد ملفات المنصّات

هذا المستودع يحتوي فقط على كود Dart (`lib/`) و`pubspec.yaml`. لتشغيله
تحتاج تولّد مجلدات `android/` و `ios/` أول مرة:

```bash
cd fridge_rep_app
flutter create .
flutter pub get
```

هذا الأمر آمن ولن يمس أي ملف داخل `lib/` أو `pubspec.yaml` الموجودين.

## 2) اضبط رابط السيرفر

عدّل `lib/config.dart`:

```dart
static const String repIndexUrl = 'https://YOUR_DOMAIN.com/path/to/rep/index.php';
static const String repLocationsUrl = 'https://YOUR_DOMAIN.com/path/to/api/rep_locations.php';
```

## 3) تسجيل الدخول والجلسة (auth.php)

مبني الآن على ملف `auth.php` الفعلي (داخل مجلد `api/`)، بدون أي افتراضات:

- **تسجيل الدخول**: `POST auth.php?action=login` بجسم JSON
  `{"username": "...", "password": "..."}`. نجاح: `{success:true, user:{...}}`.
  فشل: HTTP 401 مع `{"error": "..."}`.
- **المستخدم الحالي**: `GET auth.php?action=me` يرجع `{"user": {...}}` أو
  `{"user": null}` حسب حالة الجلسة. التطبيق يستخدمه في `AuthGate`
  (`main.dart`) عند فتح التطبيق للتأكد فعليًا أن الجلسة المحفوظة ما زالت
  صالحة عند السيرفر (وليس فقط الاعتماد على علامة محلية).
- **تسجيل الخروج**: `GET auth.php?action=logout` يدمر الجلسة على السيرفر
  (`session_destroy()`)، ويُستدعى من زر 🚪 أعلى الشاشة الرئيسية.

فقط عدّل `authUrl` في `lib/config.dart` ليشير لمسار `auth.php` الحقيقي
عندك (مثلاً `https://domain.com/api/auth.php`). ما تحتاج تغيّر أي حقل
أو منطق آخر — الأسماء والشكل مطابقة تمامًا للباك-إند.

اسم المستخدم (`full_name`) يظهر تلقائيًا في تحية الشاشة الرئيسية بعد
تسجيل الدخول، ويُحفظ في `ApiService.instance.currentUser` لاستخدامه في
أي مكان ثاني بالتطبيق لو احتجت.

## 4) الأذونات المطلوبة (تُضاف بعد `flutter create .`)

### Android — `android/app/src/main/AndroidManifest.xml`
أضف داخل `<manifest>` قبل `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

### iOS — `ios/Runner/Info.plist`
أضف:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج موقعك لتتبع مواقع العهد وطلبات الصيانة</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>نحتاج موقعك لتتبع موقعك أثناء العمل الميداني</string>
<key>NSCameraUsageDescription</key>
<string>نحتاج الكاميرا لتصوير الفواتير والوثائق</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>نحتاج الوصول للصور لإرفاق الفواتير والوثائق</string>
```

## 5) ما تم تحويله (مطابق لملفات index.php / rep.js)

| الميزة | الشاشة | يستدعي |
|---|---|---|
| القائمة الرئيسية + طلبات الصيانة الجارية | `home_screen.dart` | `?action=get_service_requests` |
| تسجيل الدخول / الخروج / المستخدم الحالي | `login_screen.dart` + `AuthGate` في `main.dart` | `auth.php?action=login\|logout\|me` |
| بوابة كلمة سر المالك | `_OwnerGateSheet` داخل `home_screen.dart` | `mode=verify_owner` |
| تسجيل ثلاجة جديدة + عرض الباركود | `new_fridge_screen.dart` | `mode=new` |
| تسجيل عهدة جديدة (معالج 4 خطوات) | `custody_wizard_screen.dart` | `?action=get_fridge` ثم `mode=custody` |
| طلب صيانة / نقل | `service_request_screen.dart` | `?action=get_fridge` ثم `mode=update2` |
| إغلاق طلب صيانة | `_CloseRequestSheet` داخل `widgets/service_request_card.dart` | `mode=close_request` |
| تتبع موقع المندوب كل 10 ثوانٍ | `services/location_service.dart` | `../api/rep_locations.php` |

## 6) ما تم تأجيله (بناءً على طلبك)

- **مسح الباركود بالكاميرا (Quagga)**: حاليًا الإدخال يدوي فقط (نص). لإضافته
  لاحقًا، أنسب حزمة هي `mobile_scanner`، وتُستخدم بدل حقل النص في أي مكان
  فيه `TextField` خاص بالباركود.
- **الطباعة المباشرة عبر Zebra Browser Print (ZPL)**: هذي تقنية مرتبطة
  بالمتصفح (WebUSB/WebBluetooth عبر SDK جافاسكربت) وما تشتغل مباشرة من
  فلاتر. البديل لاحقًا: توليد ملف ZPL نصي (زي القديم) وإرساله عبر
  Bluetooth/Wi-Fi باستخدام حزمة مثل `blue_thermal_printer` أو
  `flutter_zebra_printer`، أو فتحه في تطبيق Zebra الرسمي على الجهاز.
  حاليًا الشاشة تعرض الباركود بصريًا فقط (`barcode_widget`).

## 7) بنية المشروع

```
lib/
  main.dart                      # نقطة الدخول + الثيم (ألوان cold-chain نفسها)
  config.dart                    # روابط API + قوائم الثلاجات/المدن المسموحة
  models/
    fridge.dart
    service_request.dart
    user.dart
  services/
    api_service.dart             # كل نداءات PHP (GET/POST + رفع ملفات + كوكي الجلسة)
    location_service.dart        # تتبع الموقع الدوري (Timer كل 10 ثوانٍ)
  screens/
    home_screen.dart
    login_screen.dart
    new_fridge_screen.dart
    custody_wizard_screen.dart
    service_request_screen.dart
  widgets/
    service_request_card.dart
```
