import 'json.dart';

enum AddressLabel {
  home('home', 'Home'),
  work('work', 'Work'),
  other('other', 'Other');

  const AddressLabel(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static AddressLabel fromApi(Object? v) => values.firstWhere((l) => l.apiValue == v, orElse: () => home);
}

/// COM-C18 / BUY-A03 delivery address.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.province,
    required this.municipality,
    required this.barangay,
    required this.street,
    this.houseNo,
    this.postalCode,
    this.landmark,
    this.fullAddress = '',
    this.isDefault = false,
  });

  final int id;
  final AddressLabel label;
  final String recipientName;

  /// Local format 09XXXXXXXXX.
  final String phone;
  final String province;
  final String municipality;
  final String barangay;
  final String street;
  final String? houseNo;
  final String? postalCode;
  final String? landmark;
  final String fullAddress;
  final bool isDefault;

  /// "+63 917 123 4567"
  String get displayPhone => formatPhPhone(phone);

  factory Address.fromJson(Json j) => Address(
        id: toInt(j['id']),
        label: AddressLabel.fromApi(j['label']),
        recipientName: j['recipient_name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        province: j['province'] as String? ?? '',
        municipality: j['municipality'] as String? ?? '',
        barangay: j['barangay'] as String? ?? '',
        street: j['street'] as String? ?? '',
        houseNo: toStr(j['house_no']),
        postalCode: toStr(j['postal_code']),
        landmark: toStr(j['landmark']),
        fullAddress: j['full_address'] as String? ?? '',
        isDefault: j['is_default'] == true,
      );

  Json toJson() => {
        'label': label.apiValue,
        'recipient_name': recipientName,
        'phone': phone,
        'province': province,
        'municipality': municipality,
        'barangay': barangay,
        'street': street,
        'house_no': houseNo,
        'postal_code': postalCode,
        'landmark': landmark,
        'is_default': isDefault,
      };
}

/// "09171234567" -> "+63 917 123 4567"
String formatPhPhone(String local) {
  final d = local.replaceAll(RegExp(r'\D'), '');
  final n = d.startsWith('0') ? d.substring(1) : (d.startsWith('63') ? d.substring(2) : d);
  if (n.length != 10) return local;
  return '+63 ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
}
