/// يمثل عنصر واحد من قائمة "طلبات صيانة قيد التنفيذ"
/// (?action=get_service_requests)
class ServiceRequest {
  final int id;
  final String fridgeBarcode;
  final String requestType;
  final String? notes;
  final String status;
  final DateTime? createdAt;
  final String? facilityName;
  final String? city;
  final String? district;
  final String? street;
  final double? latitude;
  final double? longitude;

  ServiceRequest({
    required this.id,
    required this.fridgeBarcode,
    required this.requestType,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.facilityName,
    required this.city,
    required this.district,
    required this.street,
    required this.latitude,
    required this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  String get mapsUrl => hasLocation
      ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      : '';

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ServiceRequest(
      id: int.parse(json['id'].toString()),
      fridgeBarcode: json['fridge_barcode']?.toString() ?? '',
      requestType: json['request_type']?.toString() ?? '',
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      facilityName: json['facility_name']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      street: json['street']?.toString(),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
    );
  }
}