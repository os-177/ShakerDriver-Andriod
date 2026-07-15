import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/fridge.dart';
import '../models/service_request.dart';
import '../models/user.dart';

/// نتيجة عامة لأي عملية POST (نفس شكل {success, message/error, ...} في PHP)
class ApiResult {
  final bool success;
  final String? error;
  final String? message;
  final Map<String, dynamic> raw;

  ApiResult({
    required this.success,
    this.error,
    this.message,
    required this.raw,
  });

  factory ApiResult.fromJson(Map<String, dynamic> json) {
    return ApiResult(
      success: json['success'] == true,
      error: json['error']?.toString(),
      message: json['message']?.toString(),
      raw: json,
    );
  }
}

/// طبقة تواصل موحّدة مع index.php الحالي.
///
/// ملاحظة مهمة عن الجلسة (Session):
/// الباك-إند يعتمد على session_start() الخاصة بـPHP، ويشترط وجود
/// $_SESSION['user']['id'] (أي المندوب لازم يكون مسجّل دخول من قبل عبر
/// شاشة/طلب لوجن منفصلة غير موجودة في الملفات المرفوعة). لذلك هذا
/// الصف يحفظ كوكي PHPSESSID المُستلم من أول استجابة ويرفقه في كل طلب
/// لاحق، تمامًا مثل ما يفعل المتصفح تلقائيًا.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String? _cookie;

  /// آخر مستخدم تم جلبه من login() أو fetchCurrentUser()، متاح للواجهات
  /// (مثلاً لعرض "مرحبًا بك {full_name}" في الشاشة الرئيسية).
  AppUser? currentUser;

  Future<void> _loadCookie() async {
    if (_cookie != null) return;
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('phpsessid_cookie');
  }

  Future<void> _saveCookieFromResponse(http.BaseResponse response) async {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie == null) return;
    // نأخذ فقط الجزء name=value قبل أول فاصلة منقوطة
    final cookie = rawCookie.split(';').first;
    _cookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phpsessid_cookie', cookie);
  }

  Map<String, String> _headers() {
    return {
      if (_cookie != null) 'cookie': _cookie!,
    };
  }

  /// اسمح لشاشة تسجيل الدخول (إن وُجدت) بضبط كوكي الجلسة يدويًا بعد اللوجن.
  Future<void> setSessionCookie(String cookie) async {
    _cookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phpsessid_cookie', cookie);
  }

  // ---------------------------------------------------------------------
  // تسجيل الدخول / الخروج / المستخدم الحالي — auth.php (مجلد api/)
  // ---------------------------------------------------------------------

  /// POST auth.php?action=login  — الجسم JSON: {username, password}
  /// نجاح: {success:true, user:{...}}   فشل: HTTP 401 + {error: "..."}
  Future<ApiResult> login({
    required String username,
    required String password,
  }) async {
    await _loadCookie();
    final uri = Uri.parse(ApiConfig.authUrl).replace(queryParameters: {
      'action': 'login',
    });
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ..._headers(),
      },
      body: jsonEncode({'username': username, 'password': password}),
    );
    await _saveCookieFromResponse(res);
    final result = _parseResult(res);
    if (result.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', true);
      final userJson = result.raw['user'];
      if (userJson is Map<String, dynamic>) {
        currentUser = AppUser.fromJson(userJson);
      }
    }
    return result;
  }

  /// GET auth.php?action=me — يرجع المستخدم الحالي من الجلسة أو null.
  /// يُستخدم عند فتح التطبيق للتحقق من صلاحية الجلسة المحفوظة فعليًا
  /// عند السيرفر (بدل الاكتفاء بعلامة محلية فقط).
  Future<AppUser?> fetchCurrentUser() async {
    await _loadCookie();
    try {
      final uri = Uri.parse(ApiConfig.authUrl).replace(queryParameters: {
        'action': 'me',
      });
      final res = await http.get(uri, headers: _headers());
      await _saveCookieFromResponse(res);
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final userJson = json['user'];
      if (userJson == null || userJson is! Map<String, dynamic>) {
        currentUser = null;
        return null;
      }
      currentUser = AppUser.fromJson(userJson);
      return currentUser;
    } catch (_) {
      return null;
    }
  }

  /// يدمر الجلسة فعليًا على السيرفر (auth.php?action=logout) ثم يمسح
  /// الكوكي والعلامة المحلية.
  Future<void> logout() async {
    await _loadCookie();
    try {
      final uri = Uri.parse(ApiConfig.authUrl).replace(queryParameters: {
        'action': 'logout',
      });
      await http.get(uri, headers: _headers());
    } catch (_) {
      // نكمّل تنظيف الجلسة محليًا حتى لو فشل الاتصال بالسيرفر
    }
    _cookie = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phpsessid_cookie');
    await prefs.setBool('logged_in', false);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logged_in') ?? false;
  }

  // ---------------------------------------------------------------------
  // GET ?action=get_fridge&barcode=...
  // ---------------------------------------------------------------------
  Future<FridgeCheckResult> checkFridgeBarcode(String barcode) async {
    await _loadCookie();
    final uri = Uri.parse(ApiConfig.repIndexUrl).replace(queryParameters: {
      'action': 'get_fridge',
      'barcode': barcode,
    });
    final res = await http.get(uri, headers: _headers());
    await _saveCookieFromResponse(res);
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return FridgeCheckResult.fromJson(json);
  }

  // ---------------------------------------------------------------------
  // GET ?action=get_service_requests
  // ---------------------------------------------------------------------
  Future<List<ServiceRequest>> getServiceRequests() async {
    await _loadCookie();
    final uri = Uri.parse(ApiConfig.repIndexUrl).replace(queryParameters: {
      'action': 'get_service_requests',
    });
    final res = await http.get(uri, headers: _headers());
    await _saveCookieFromResponse(res);
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (json['success'] != true) return [];
    final list = (json['requests'] as List<dynamic>? ?? []);
    return list
        .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------
  // POST mode=verify_owner
  // ---------------------------------------------------------------------
  Future<ApiResult> verifyOwner({
    required String username,
    required String password,
  }) async {
    return _postFields({
      'mode': 'verify_owner',
      'owner_username': username,
      'owner_password': password,
    });
  }

  // ---------------------------------------------------------------------
  // POST mode=new (multipart: صورة الفاتورة + صورة الضمان اختياريتان)
  // ---------------------------------------------------------------------
  Future<ApiResult> registerNewFridge({
    required String fridgeType,
    String? serialNumber,
    String? purchaseDate, // 'yyyy-MM-dd'
    File? invoiceImg,
    File? warrantyImg,
  }) async {
    return _postMultipart(
      fields: {
        'mode': 'new',
        'fridge_type': fridgeType,
        if (serialNumber != null) 'serial_number': serialNumber,
        if (purchaseDate != null) 'purchase_date': purchaseDate,
      },
      files: {
        if (invoiceImg != null) 'invoice_img': invoiceImg,
        if (warrantyImg != null) 'warranty_img': warrantyImg,
      },
    );
  }

  // ---------------------------------------------------------------------
  // POST mode=update2 (طلب صيانة / نقل)
  // ---------------------------------------------------------------------
  Future<ApiResult> submitServiceRequest({
    required String barcode,
    required String requestType, // 'maintenance' | 'transfer'
    String? notes,
  }) async {
    return _postFields({
      'mode': 'update2',
      'barcodex': barcode,
      'request_type': requestType,
      if (notes != null) 'request_notes': notes,
    });
  }

  // ---------------------------------------------------------------------
  // POST mode=custody (multipart: صور رخصة البلدية + العنوان الوطني)
  // ---------------------------------------------------------------------
  Future<ApiResult> registerCustody({
    String? fridgeBarcode,
    required String facilityName,
    String? clientName,
    String? responsibleStaff,
    String? phoneNumber,
    required String city,
    required String district,
    String? street,
    String? municipalityLicenseNo,
    File? municipalityLicenseImg,
    String? commercialRegistrationNo,
    String? nationalAddressText,
    File? nationalAddressImg,
    double? latitude,
    double? longitude,
  }) async {
    return _postMultipart(
      fields: {
        'mode': 'custody',
        if (fridgeBarcode != null && fridgeBarcode.isNotEmpty)
          'fridge_barcode': fridgeBarcode,
        'facility_name': facilityName,
        if (clientName != null) 'client_name': clientName,
        if (responsibleStaff != null) 'responsible_staff': responsibleStaff,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'city': city,
        'district': district,
        if (street != null) 'street': street,
        if (municipalityLicenseNo != null)
          'municipality_license_no': municipalityLicenseNo,
        if (commercialRegistrationNo != null)
          'commercial_registration_no': commercialRegistrationNo,
        if (nationalAddressText != null)
          'national_address_text': nationalAddressText,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      },
      files: {
        if (municipalityLicenseImg != null)
          'municipality_license_img': municipalityLicenseImg,
        if (nationalAddressImg != null)
          'national_address_img': nationalAddressImg,
      },
    );
  }

  // ---------------------------------------------------------------------
  // POST mode=close_request (multipart: صورة فاتورة الإصلاح إلزامية)
  // ---------------------------------------------------------------------
  Future<ApiResult> closeServiceRequest({
    required int requestId,
    required File invoiceImg,
    String? closingNotes,
  }) async {
    return _postMultipart(
      fields: {
        'mode': 'close_request',
        'request_id': requestId.toString(),
        if (closingNotes != null) 'closing_notes': closingNotes,
      },
      files: {
        'invoice_img': invoiceImg,
      },
    );
  }

  // ---------------------------------------------------------------------
  // POST mode=complete_transfer (إنهاء طلب نقل — بدون صورة أو ملاحظة)
  // ---------------------------------------------------------------------
  Future<ApiResult> completeTransfer({required int requestId}) async {
    return _postFields({
      'mode': 'complete_transfer',
      'request_id': requestId.toString(),
    });
  }

  // ---------------------------------------------------------------------
  // تتبّع الموقع الدوري -> ../api/rep_locations.php (JSON وليس FormData)
  // ---------------------------------------------------------------------
  Future<void> sendCurrentLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _loadCookie();
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.repLocationsUrl),
        headers: {
          'Content-Type': 'application/json',
          ..._headers(),
        },
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      );
      await _saveCookieFromResponse(res);
    } catch (_) {
      // فشل إرسال طلب واحد مو مشكلة، بنحاول مرة ثانية بالجولة الجاية
      // (نفس فلسفة الكود القديم في rep.js)
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------
  Future<ApiResult> _postFields(Map<String, String> fields) async {
    await _loadCookie();
    final res = await http.post(
      Uri.parse(ApiConfig.repIndexUrl),
      headers: _headers(),
      body: fields,
    );
    await _saveCookieFromResponse(res);
    return _parseResult(res);
  }

  Future<ApiResult> _postMultipart({
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    await _loadCookie();
    final request =
        http.MultipartRequest('POST', Uri.parse(ApiConfig.repIndexUrl));
    request.headers.addAll(_headers());
    request.fields.addAll(fields);
    for (final entry in files.entries) {
      request.files.add(await http.MultipartFile.fromPath(
        entry.key,
        entry.value.path,
      ));
    }
    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    await _saveCookieFromResponse(res);
    return _parseResult(res);
  }

  ApiResult _parseResult(http.Response res) {
    try {
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return ApiResult.fromJson(json);
    } catch (_) {
      return ApiResult(
        success: false,
        error: 'حدث خطأ أثناء معالجة الطلب على السيرفر.',
        raw: const {},
      );
    }
  }
}